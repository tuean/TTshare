import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cookie_entry.dart';

class CookieManager {
  static const _keyPrefix = 'cookies_';
  static const _domainsKey = 'cookie_domains';

  Future<List<CookieEntry>> getAllCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final domains = prefs.getStringList(_domainsKey) ?? [];
    final cookies = <CookieEntry>[];
    for (final domain in domains) {
      final jsonStr = prefs.getString('$_keyPrefix$domain');
      if (jsonStr != null) {
        cookies.add(CookieEntry.fromJson(
            json.decode(jsonStr) as Map<String, dynamic>));
      }
    }
    return cookies;
  }

  Future<CookieEntry?> getCookies(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_keyPrefix$domain');
    if (jsonStr == null) return null;
    return CookieEntry.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
  }

  Future<void> saveCookies(String domain, String cookieData) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final existing = await getCookies(domain);
    final entry = CookieEntry(
      domain: domain,
      cookieData: cookieData,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await prefs.setString('$_keyPrefix$domain', json.encode(entry.toJson()));
    final domains = prefs.getStringList(_domainsKey) ?? [];
    if (!domains.contains(domain)) {
      domains.add(domain);
      await prefs.setStringList(_domainsKey, domains);
    }
  }

  Future<void> clearDomain(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$domain');
    final domains = prefs.getStringList(_domainsKey) ?? [];
    domains.remove(domain);
    await prefs.setStringList(_domainsKey, domains);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final domains = prefs.getStringList(_domainsKey) ?? [];
    for (final domain in domains) {
      await prefs.remove('$_keyPrefix$domain');
    }
    await prefs.remove(_domainsKey);
  }
}
