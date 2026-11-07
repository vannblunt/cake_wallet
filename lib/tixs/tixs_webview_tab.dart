import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'tixs_auth_bridge.dart';
import 'tixs_theme.dart';

/// Persistent full-screen WebView for a Tixs web section.
///
/// Cookies are shared across all TixsWebViewTab instances through the system
/// WebView cookie store, so a sign-in on the Events tab is visible on
/// My Tickets and Profile without re-authentication.
class TixsWebViewTab extends StatefulWidget {
  const TixsWebViewTab({
    super.key,
    required this.initialUrl,
    required this.authBridge,
    this.onSignIn,
  });

  final String initialUrl;
  final TixsAuthBridge authBridge;
  final VoidCallback? onSignIn;

  @override
  State<TixsWebViewTab> createState() => _TixsWebViewTabState();
}

class _TixsWebViewTabState extends State<TixsWebViewTab> {
  InAppWebViewController? _controller;
  bool _loading = true;
  double _progress = 0;

  static const _trustedOrigins = {'tixs.ai', 'www.tixs.ai', 'pay.tixs.ai'};

  static InAppWebViewSettings _settings() => InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        iframeAllowFullscreen: true,
        javaScriptEnabled: true,
        transparentBackground: false,
        // Block non-tixs.ai navigations from opening externally without intent
        allowsLinkPreview: false,
      );

  bool _isTrusted(Uri uri) => _trustedOrigins.contains(uri.host);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
          initialSettings: _settings(),
          onWebViewCreated: (c) => _controller = c,
          onLoadStart: (_, __) => setState(() => _loading = true),
          onProgressChanged: (_, p) => setState(() => _progress = p / 100),
          onLoadStop: (_, url) async {
            setState(() => _loading = false);
            if (url != null && _isTrusted(url)) {
              final signedIn = await widget.authBridge.syncFromWebView();
              if (signedIn) widget.onSignIn?.call();
            }
          },
          shouldOverrideUrlLoading: (c, action) async {
            final uri = action.request.url;
            if (uri == null) return NavigationActionPolicy.CANCEL;
            // Allow tixs.ai navigation inline; external links cancel
            if (_isTrusted(uri)) return NavigationActionPolicy.ALLOW;
            // Allow mailto/tel schemes
            if (uri.scheme == 'mailto' || uri.scheme == 'tel') {
              return NavigationActionPolicy.CANCEL; // let system handle
            }
            return NavigationActionPolicy.CANCEL;
          },
          onConsoleMessage: (_, msg) {
            // Intentionally suppressed: never forward page console output to logs
          },
        ),
        if (_loading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              backgroundColor: TixsTheme.surface,
              color: TixsTheme.primary,
              minHeight: 2,
            ),
          ),
      ],
    );
  }

  void reload() => _controller?.reload();

  void loadUrl(String url) =>
      _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
}
