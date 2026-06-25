import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ReadabilityExtractor {
  Future<Map<String, dynamic>> extract(String html, String url) async {
    final tmpDir = await getTemporaryDirectory();
    final htmlFile = File('${tmpDir.path}/_readability_input.html');
    await htmlFile.writeAsString(html);

    final readabilityJs = await rootBundle.loadString('assets/readability.js');
    final turndownJs = await rootBundle.loadString('assets/turndown.js');

    final completer = Completer<Map<String, dynamic>>();

    final headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        cacheEnabled: false,
      ),
      initialUrlRequest: URLRequest(url: WebUri('file://${htmlFile.path}')),
      onLoadStop: (controller, url) async {
        try {
          await controller.evaluateJavascript(source: readabilityJs);
          await controller.evaluateJavascript(source: turndownJs);

          final result = await controller.evaluateJavascript(source: '''
(function() {
  try {
    var article = new Readability(document.cloneNode(true)).parse();
    if (!article || !article.content) {
      return JSON.stringify({error: 'Could not extract content'});
    }
    var turndownService = new TurndownService({
      headingStyle: 'atx',
      codeBlockStyle: 'fenced',
      emDelimiter: '*'
    });
    var markdown = turndownService.turndown(article.content);
    return JSON.stringify({
      title: article.title,
      content: article.content,
      markdown: markdown,
      excerpt: article.excerpt,
      byline: article.byline
    });
  } catch(e) {
    return JSON.stringify({error: e.toString()});
  }
})();
''');

          await headlessWebView.dispose();

          if (!completer.isCompleted) {
            final jsonStr = result ?? '{"error":"empty result"}';
            if (jsonStr.startsWith('{')) {
              completer.complete({'raw': jsonStr});
            } else {
              completer.complete({'error': 'unexpected result format'});
            }
          }
        } catch (e) {
          await headlessWebView.dispose();
          if (!completer.isCompleted) {
            completer.complete({'error': e.toString()});
          }
        }
      },
    );

    await headlessWebView.run();

    return completer.future;
  }
}
