import 'package:flutter/services.dart';

class ShareReceiver {
  static const _channel = MethodChannel('ttshare/share_receiver');

  Future<Map<String, String>> getSharedContent() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getSharedContent');
      if (result == null) return {'url': '', 'title': ''};
      return {
        'url': (result['url'] as String?) ?? '',
        'title': (result['title'] as String?) ?? '',
      };
    } on MissingPluginException {
      return {'url': '', 'title': ''};
    }
  }
}
