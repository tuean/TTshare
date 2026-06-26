package com.ttshare.service

import android.content.SharedPreferences
import android.content.Context
import java.io.File

class CookieManager(private val prefs: SharedPreferences) {

    data class CookieEntry(
        val domain: String,
        val cookieData: String
    )

    fun getCookies(domain: String): CookieEntry? {
        val data = prefs.getString("cookie_$domain", null) ?: return null
        return CookieEntry(domain, data)
    }

    fun saveCookies(domain: String, cookieData: String) {
        prefs.edit().putString("cookie_$domain", cookieData).apply()
        val domains = prefs.getStringSet("cookie_domains", mutableSetOf())?.toMutableSet()
            ?: mutableSetOf()
        domains.add(domain)
        prefs.edit().putStringSet("cookie_domains", domains).apply()
    }

    fun getAllDomains(): List<String> {
        return prefs.getStringSet("cookie_domains", emptySet())?.toList() ?: emptyList()
    }

    fun getAllCookies(): List<CookieEntry> {
        return getAllDomains().mapNotNull { domain ->
            getCookies(domain)?.let { CookieEntry(domain, it.cookieData) }
        }
    }

    fun clearDomain(domain: String) {
        prefs.edit().remove("cookie_$domain").apply()
        val domains = prefs.getStringSet("cookie_domains", mutableSetOf())?.toMutableSet()
            ?: mutableSetOf()
        domains.remove(domain)
        prefs.edit().putStringSet("cookie_domains", domains).apply()
    }

    fun clearAll() {
        val domains = getAllDomains()
        val editor = prefs.edit()
        for (domain in domains) {
            editor.remove("cookie_$domain")
        }
        editor.remove("cookie_domains").apply()
    }
}
