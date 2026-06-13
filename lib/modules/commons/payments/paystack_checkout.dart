import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// Outcome of a Paystack checkout round-trip.
enum PaystackOutcome { success, failed, cancelled, error }

class PaystackResult {
  const PaystackResult(this.outcome, {this.reference, this.message});

  final PaystackOutcome outcome;
  final String? reference;
  final String? message;

  bool get isSuccess => outcome == PaystackOutcome.success;
}

/// Server-side Paystack checkout. The secret key never touches the app:
///
/// 1. `paystack-initialize` Edge Function prices the purchase server-side
///    and returns a hosted-checkout `authorizationUrl` + `reference`.
/// 2. We open that URL in a WebView and watch for the redirect to the
///    callback URL (payment finished or cancelled).
/// 3. `paystack-verify` Edge Function confirms with Paystack and activates
///    the subscription — only then is it "paid".
class PaystackCheckout {
  PaystackCheckout(this._supabase);

  final SupabaseModule _supabase;

  static const String _callbackPrefix =
      'https://www.drivedrivio.com/paystack/return';

  /// Re-verify the caller's recent pending payments. Recovers a payment
  /// that succeeded at Paystack but whose verify call never ran (app
  /// killed between checkout and verify). Best-effort, bounded, and safe
  /// to call on screen open — `paystack-verify` is idempotent and only
  /// settles when Paystack confirms success. Returns the number newly
  /// confirmed.
  Future<int> reconcilePendingPayments({required String purpose}) async {
    if (_supabase.auth.currentUser == null) {
      return 0;
    }
    List<Map<String, dynamic>> rows;
    try {
      final String since = DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 1))
          .toIso8601String();
      rows = await _supabase.client
          .from('payment_intents')
          .select('reference')
          .eq('status', 'pending')
          .eq('purpose', purpose)
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(5);
    } catch (_) {
      return 0;
    }

    int confirmed = 0;
    for (final Map<String, dynamic> row in rows) {
      final String? reference = row['reference'] as String?;
      if (reference == null) {
        continue;
      }
      try {
        final FunctionResponse res = await _supabase.client.functions.invoke(
          'paystack-verify',
          body: <String, dynamic>{'reference': reference},
        );
        final String? status =
            (res.data is Map ? res.data['status'] : null) as String?;
        if (status == 'success') {
          confirmed++;
        }
      } catch (_) {
        // Leave pending; a later open retries.
      }
    }
    return confirmed;
  }

  Future<PaystackResult> run({
    required BuildContext context,
    required String purpose, // 'wallet_topup' | 'subscription'
    int? amountMinor,
    String? planCode,
  }) async {
    final String authUrl;
    final String reference;
    try {
      final Map<String, dynamic> initBody = <String, dynamic>{
        'purpose': purpose,
      };
      if (amountMinor != null) {
        initBody['amountMinor'] = amountMinor;
      }
      if (planCode != null) {
        initBody['planCode'] = planCode;
      }
      final FunctionResponse res = await _supabase.client.functions.invoke(
        'paystack-initialize',
        body: initBody,
      );
      final Object? data = res.data;
      if (data is! Map ||
          data['authorizationUrl'] is! String ||
          data['reference'] is! String) {
        return const PaystackResult(
          PaystackOutcome.error,
          message: "Couldn't start the payment. Try again in a moment.",
        );
      }
      authUrl = data['authorizationUrl'] as String;
      reference = data['reference'] as String;
    } on FunctionException catch (_) {
      return const PaystackResult(
        PaystackOutcome.error,
        message: "Couldn't reach the payment service. Try again.",
      );
    } catch (_) {
      return const PaystackResult(
        PaystackOutcome.error,
        message: "Couldn't start the payment. Try again in a moment.",
      );
    }

    if (!context.mounted) {
      return PaystackResult(PaystackOutcome.cancelled, reference: reference);
    }

    final bool reachedCallback =
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            fullscreenDialog: true,
            builder: (BuildContext _) => _PaystackWebView(
              authorizationUrl: authUrl,
              callbackPrefix: _callbackPrefix,
            ),
          ),
        ) ??
        false;

    if (!reachedCallback) {
      return PaystackResult(PaystackOutcome.cancelled, reference: reference);
    }

    try {
      final FunctionResponse res = await _supabase.client.functions.invoke(
        'paystack-verify',
        body: <String, dynamic>{'reference': reference},
      );
      final Object? data = res.data;
      final String? status = (data is Map ? data['status'] : null) as String?;
      if (status == 'success') {
        return PaystackResult(PaystackOutcome.success, reference: reference);
      }
      if (status == 'failed') {
        return PaystackResult(
          PaystackOutcome.failed,
          reference: reference,
          message: "That payment didn't go through.",
        );
      }
      return PaystackResult(
        PaystackOutcome.error,
        reference: reference,
        message: "We couldn't confirm that payment. It will update shortly.",
      );
    } on FunctionException catch (_) {
      return PaystackResult(
        PaystackOutcome.error,
        reference: reference,
        message: "We couldn't confirm that payment. It will update shortly.",
      );
    } catch (_) {
      return PaystackResult(
        PaystackOutcome.error,
        reference: reference,
        message: "We couldn't confirm that payment. It will update shortly.",
      );
    }
  }
}

class _PaystackWebView extends StatefulWidget {
  const _PaystackWebView({
    required this.authorizationUrl,
    required this.callbackPrefix,
  });

  final String authorizationUrl;
  final String callbackPrefix;

  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  late final WebViewController _controller;
  bool _finished = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(widget.callbackPrefix)) {
              _finish(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  void _finish(bool reachedCallback) {
    if (_finished || !mounted) {
      return;
    }
    _finished = true;
    Navigator.of(context).pop(reachedCallback);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surface,
        foregroundColor: context.text,
        elevation: 0,
        title: const Text('Secure payment'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _finish(false),
        ),
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: context.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(context.accent),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
