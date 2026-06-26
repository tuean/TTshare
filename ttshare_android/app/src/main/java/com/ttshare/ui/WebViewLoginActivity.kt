package com.ttshare.ui

import android.annotation.SuppressLint
import android.os.Build
import android.os.Bundle
import android.webkit.CookieManager as AndroidCookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import com.ttshare.R
import com.ttshare.service.CookieManager

class WebViewLoginActivity : AppCompatActivity() {

    private var domain: String = ""

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_webview_login)

        val url = intent.getStringExtra("url") ?: return finish()
        domain = intent.getStringExtra("domain") ?: return finish()

        title = "请登录 $domain"

        val webView = findViewById<WebView>(R.id.loginWebView)
        webView.settings.javaScriptEnabled = true
        webView.settings.userAgentString =
            "Mozilla/5.0 (Linux; Android ${Build.VERSION.RELEASE}; ${Build.MODEL}) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/120.0.6099.230 " +
            "Mobile Safari/537.36 MicroMessenger/8.0.47"

        // Capture cookies after each page load
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, loadedUrl: String?) {
                super.onPageFinished(view, loadedUrl)
                // Save cookies after login
                val cookieManager = AndroidCookieManager.getInstance()
                val cookies = cookieManager.getCookie(url)
                if (cookies != null && cookies.isNotEmpty()) {
                    val prefs = getSharedPreferences("ttshare", MODE_PRIVATE)
                    val cm = CookieManager(prefs)
                    cm.saveCookies(domain, cookies)
                }
            }
        }

        webView.loadUrl(url)
    }
}
