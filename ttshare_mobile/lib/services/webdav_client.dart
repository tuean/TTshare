import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WebdavClient {
  String? _baseUrl;
  String? _username;
  String? _password;

  bool get isConfigured =>
      _baseUrl != null && _username != null && _password != null;

  String? get baseUrl => _baseUrl;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('webdav_url');
    _username = prefs.getString('webdav_username');
    _password = prefs.getString('webdav_password');
  }

  Future<void> saveConfig(String url, String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', url);
    await prefs.setString('webdav_username', username);
    await prefs.setString('webdav_password', password);
    _baseUrl = url;
    _username = username;
    _password = password;
  }

  Future<bool> verifyConnection() async {
    try {
      final uri = Uri.parse(_baseUrl!);
      final response = await http.get(uri, headers: _authHeaders);
      return response.statusCode == 200 || response.statusCode == 207;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> get _authHeaders {
    final bytes = utf8.encode('$_username:$_password');
    return {'Authorization': 'Basic ${base64.encode(bytes)}'};
  }

  Future<void> createFolder(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('MKCOL', uri);
    request.headers.addAll(_authHeaders);
    final streamed = await request.send();
    final status = streamed.statusCode;
    // 201=created, 200=ok, 301=redirect, 405=already exists
    if (status != 201 && status != 200 && status != 301 && status != 405) {
      throw Exception('Failed to create folder: $status');
    }
  }

  Future<void> uploadFile(String localPath, String remotePath) async {
    final uri = Uri.parse('$_baseUrl$remotePath');
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final request = http.Request('PUT', uri);
    request.headers.addAll(_authHeaders);
    request.headers['Content-Type'] = 'text/html; charset=utf-8';
    request.bodyBytes = bytes;
    final streamed = await request.send();
    if (streamed.statusCode != 201 && streamed.statusCode != 200) {
      throw Exception('Failed to upload file: ${streamed.statusCode}');
    }
  }

  Future<void> deleteFile(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request('DELETE', uri);
    request.headers.addAll(_authHeaders);
    final streamed = await request.send();
    if (streamed.statusCode != 204 && streamed.statusCode != 200) {
      throw Exception('Failed to delete file: ${streamed.statusCode}');
    }
  }
}
