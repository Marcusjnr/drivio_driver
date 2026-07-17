import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/profile_repository.dart';
import 'package:drivio_driver/modules/commons/types/profile.dart';

/// In-app tawk.to live chat. Loads the hosted direct-chat page in a
/// WebView and injects `Tawk_API.setAttributes({name, email})` so the
/// agent sees who they're talking to — no form for the driver to fill.
class LiveChatPage extends StatefulWidget {
  const LiveChatPage({super.key});

  static const String _chatUrl =
      'https://tawk.to/chat/6a59b01ffa1c091d4755878f/1jtn5fv2o';

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _identified = false;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    // Best-effort: the chat must open even if the profile fetch fails —
    // the driver just shows up unnamed, exactly like a web visitor.
    locator<ProfileRepository>().getMyProfile().then((Profile? p) {
      _profile = p;
      _identify();
    }).catchError((Object _) {});

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
            _identify();
          },
          onNavigationRequest: (NavigationRequest request) {
            final Uri? uri = Uri.tryParse(request.url);
            final String host = uri?.host ?? '';
            // The chat itself stays in-app; links agents send open in
            // the real browser. Host check, not substring — a URL like
            // evil.com/tawk.to/chat must not pass.
            if (host == 'tawk.to' ||
                host.endsWith('.tawk.to') ||
                request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(LiveChatPage._chatUrl));
  }

  /// Runs once both the page and the profile are in. Handles tawk's two
  /// timing cases: widget already booted (call `setAttributes` now) or
  /// still booting (hook `Tawk_API.onLoad`).
  void _identify() {
    final Profile? p = _profile;
    if (_identified || _loading || p == null) return;
    _identified = true;

    final Map<String, String> attrs = <String, String>{
      'name': p.fullName,
      if (p.email != null && p.email!.isNotEmpty) 'email': p.email!,
    };
    final String js = '''
(function () {
  var attrs = ${jsonEncode(attrs)};
  function apply() {
    try { window.Tawk_API.setAttributes(attrs, function () {}); } catch (e) {}
  }
  window.Tawk_API = window.Tawk_API || {};
  if (typeof window.Tawk_API.setAttributes === 'function') { apply(); }
  var prev = window.Tawk_API.onLoad;
  window.Tawk_API.onLoad = function () {
    if (prev) { try { prev(); } catch (e) {} }
    apply();
  };
})();
''';
    _controller.runJavaScript(js);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surface,
        foregroundColor: context.text,
        elevation: 0,
        title: Text(context.l10n.helpSupportLineTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => AppNavigation.pop(),
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
