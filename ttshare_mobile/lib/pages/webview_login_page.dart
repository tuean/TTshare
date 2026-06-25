import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/cookie_manager.dart';

class WebViewLoginPage extends StatefulWidget {
  final String url;
  final String domain;

  const WebViewLoginPage({
    super.key,
    required this.url,
    required this.domain,
  });

  @override
  State<WebViewLoginPage> createState() => _WebViewLoginPageState();
}

class _WebViewLoginPageState extends State<WebViewLoginPage> {
  final _cookieManager = CookieManager();
  InAppWebViewController? _webViewController;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (mounted) Navigator.pop(context, false);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('请登录 ${widget.domain}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Cookie 已保存，关闭',
            onPressed: _saveCookiesAndClose,
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          userAgent:
              'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Version/4.0 Chrome/120.0.6099.230 '
              'Mobile Safari/537.36 MicroMessenger/8.0.47',
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
      ),
    );
  }

  Future<void> _saveCookiesAndClose() async {
    if (_webViewController == null) return;

    final inAppCookieManager = InAppWebViewCookieManager();
    final cookiesResult =
        await inAppCookieManager.getCookies(url: WebUri(widget.url));

    if (cookiesResult.isNotEmpty) {
      final cookieStr =
          cookiesResult.map((c) => '${c.name}=${c.value}').join('; ');
      await _cookieManager.saveCookies(widget.domain, cookieStr);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
