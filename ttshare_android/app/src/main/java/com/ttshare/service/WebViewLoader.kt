package com.ttshare.service

import android.annotation.SuppressLint
import android.os.Build
import android.webkit.WebView
import android.webkit.WebViewClient
import com.ttshare.TTshareApp
import kotlinx.coroutines.*
import kotlinx.coroutines.CompletableDeferred

class WebViewLoader {

    private val userAgent: String by lazy {
        "Mozilla/5.0 (Linux; Android ${Build.VERSION.RELEASE}; ${Build.MODEL}) " +
        "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/120.0.6099.230 " +
        "Mobile Safari/537.36 MicroMessenger/8.0.47"
    }

    @SuppressLint("SetJavaScriptEnabled")
    suspend fun loadPage(
        url: String,
        cookieData: String? = null,
        timeoutMs: Long = 30_000
    ): String = withContext(Dispatchers.Main) {
        val context = TTshareApp.instance
        val result = CompletableDeferred<String>()

        val webView = WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.userAgentString = this@WebViewLoader.userAgent
            settings.mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            settings.cacheMode = android.webkit.WebSettings.LOAD_NO_CACHE
        }

        if (cookieData != null) {
            val pairs = cookieData.split(";").map { it.trim() }
            for (pair in pairs) {
                val eq = pair.indexOf('=')
                if (eq > 0) {
                    val name = pair.substring(0, eq)
                    val value = pair.substring(eq + 1)
                    android.webkit.CookieManager.getInstance().setCookie(url, "$name=$value")
                }
            }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, loadedUrl: String?) {
                MainScope().launch {
                    delay(2000)
                    view?.evaluateJavascript(
                        "document.documentElement.outerHTML"
                    ) { html ->
                        result.complete(html ?: "")
                        webView.destroy()
                    }
                }
            }

            override fun onReceivedError(
                view: WebView?, request: android.webkit.WebResourceRequest?,
                error: android.webkit.WebResourceError?
            ) {
                if (!result.isCompleted) {
                    result.completeExceptionally(
                        Exception("Page load error: ${error?.description}")
                    )
                }
                webView.destroy()
            }
        }

        webView.loadUrl(url)

        withTimeout(timeoutMs) { result.await() }
    }
}
