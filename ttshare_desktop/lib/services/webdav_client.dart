import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;

class WebdavItem {
  final String path;
  final bool isDirectory;
  final int? contentLength;
  final DateTime? lastModified;

  WebdavItem({
    required this.path,
    required this.isDirectory,
    this.contentLength,
    this.lastModified,
  });
}

class WebdavClient {
  String? _baseUrl;
  String? _username;
  String? _password;

  bool get isConfigured =>
      _baseUrl != null && _username != null && _password != null;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('webdav_url');
    _username = prefs.getString('webdav_username');
    _password = prefs.getString('webdav_password');
  }

  Future<void> saveConfig(
      String url, String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', url);
    await prefs.setString('webdav_username', username);
    await prefs.setString('webdav_password', password);
    _baseUrl = url;
    _username = username;
    _password = password;
  }

  Map<String, String> get _authHeaders {
    final bytes = utf8.encode('$_username:$_password');
    return {'Authorization': 'Basic ${base64.encode(bytes)}'};
  }

  Future<List<WebdavItem>> listDirectory(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('PROPFIND', uri);
    request.headers.addAll(_authHeaders);
    request.headers['Depth'] = '1';

    final streamed = await request.send();
    if (streamed.statusCode != 207) {
      throw Exception('Failed to list directory: ${streamed.statusCode}');
    }

    final body = await streamed.stream.bytesToString();
    final document = xml.XmlDocument.parse(body);
    final items = <WebdavItem>[];

    for (final resp in document.findAllElements('D:response')) {
      final href = resp.findElements('D:href').first.innerText;
      final prop = resp
          .findElements('D:propstat')
          .first
          .findElements('D:prop')
          .first;
      final isDir =
          prop.findElements('D:resourcetype').first.findElements('D:collection').isNotEmpty;

      final itemPath = Uri.decodeComponent(href);
      if (itemPath == path) continue;

      int? size;
      try {
        size = int.tryParse(
            prop.findElements('D:getcontentlength').first.innerText);
      } catch (_) {}

      DateTime? lastMod;
      try {
        lastMod = DateTime.tryParse(
            prop.findElements('D:getlastmodified').first.innerText);
      } catch (_) {}

      items.add(WebdavItem(
        path: itemPath,
        isDirectory: isDir,
        contentLength: size,
        lastModified: lastMod,
      ));
    }
    return items;
  }

  Future<String> downloadFile(String remotePath, String localPath) async {
    final uri = Uri.parse('$_baseUrl$remotePath');
    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to download $remotePath: ${response.statusCode}');
    }
    final file = File(localPath);
    await file.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes);
    return response.body;
  }

  Future<void> deleteFile(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('DELETE', uri);
    request.headers.addAll(_authHeaders);
    final streamed = await request.send();
    if (streamed.statusCode != 204 && streamed.statusCode != 200) {
      throw Exception('Failed to delete $path: ${streamed.statusCode}');
    }
  }

  Future<void> deleteDirectory(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('DELETE', uri);
    request.headers.addAll(_authHeaders);
    final streamed = await request.send();
    if (streamed.statusCode != 204 &&
        streamed.statusCode != 200 &&
        streamed.statusCode != 404) {
      throw Exception(
          'Failed to delete directory $path: ${streamed.statusCode}');
    }
  }
}
