import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/profile_repository.dart';
import 'package:drivio_driver/modules/commons/types/profile.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';

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

class _LiveChatPageState extends State<LiveChatPage>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _loading = true;
  bool _identified = false;
  // The veil keeps painting (and bouncing) through its fade-out; only
  // once the fade ends does it stop existing.
  bool _veilGone = false;
  Profile? _profile;

  /// Gentle bounce for the loading wordmark — up-and-down on an
  /// ease-in-out, like the mark is idling at a traffic light.
  late final AnimationController _bounceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

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

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
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
    // Tab-level page: the Support tab in the bottom bar lands here, so
    // there's no close button — the other tabs are the way out. (When
    // reached via push from a help article, the system back still works.)
    return ScreenScaffold(
      bottomBar: const DriverTabBar(active: DriverTab.support),
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            decoration: BoxDecoration(
              color: context.surface,
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Text(
              context.l10n.helpSupportLineTitle,
              style: AppTextStyles.bodySm.copyWith(
                color: context.text,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                WebViewWidget(controller: _controller),
                // Branded loading veil: the Drivio wordmark bouncing
                // gently until the chat page is in. Fades out over the
                // webview once loaded, then stops painting entirely.
                IgnorePointer(
                  ignoring: true,
                  child: AnimatedOpacity(
                    opacity: _loading ? 1 : 0,
                    duration: const Duration(milliseconds: 350),
                    onEnd: () {
                      if (!_loading && mounted) {
                        _bounceCtrl.stop();
                        setState(() => _veilGone = true);
                      }
                    },
                    child: !_veilGone
                        ? ColoredBox(
                            color: context.bg,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  AnimatedBuilder(
                                    animation: _bounceCtrl,
                                    builder: (BuildContext _, Widget? child) {
                                      final double t = Curves.easeInOut
                                          .transform(_bounceCtrl.value);
                                      return Transform.translate(
                                        offset: Offset(0, -14 * t),
                                        child: child,
                                      );
                                    },
                                    child: const BrandMark(size: 44),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Connecting you to support…',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: context.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
