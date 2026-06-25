import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewLoader {
  final String userAgent;

  WebViewLoader({String? customUA})
      : userAgent = customUA ??
            'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Version/4.0 Chrome/120.0.6099.230 '
            'Mobile Safari/537.36 MicroMessenger/8.0.47';

  Future<String> loadPage({
    required String url,
    String? cookieData,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<String>();

    final headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        javaScriptEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        cacheEnabled: false,
      ),
      initialUrlRequest: URLRequest(
        url: WebUri(url),
        headers: cookieData != null ? {'Cookie': cookieData} : null,
      ),
      onLoadStop: (controller, url) async {
        await Future.delayed(const Duration(seconds: 2));
        final html = await controller.evaluateJavascript(
          source: 'document.documentElement.outerHTML',
        );
        await headlessWebView.dispose();
        if (!completer.isCompleted) {
          completer.complete(html ?? '');
        }
      },
      onReceivedError: (controller, request, error) {
        headlessWebView.dispose();
        if (!completer.isCompleted) {
          completer.completeError(
              Exception('Page load error: ${error.description}'));
        }
      },
    );

    await headlessWebView.run();

    Timer(timeout, () {
      if (!completer.isCompleted) {
        headlessWebView.dispose();
        completer.completeError(
            TimeoutException('Page load timeout', timeout));
      }
    });

    return completer.future;
  }
}
