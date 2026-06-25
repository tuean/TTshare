package com.example.ttshare_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ttshare/share_receiver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getSharedContent") {
                    val sharedUrl = getSharedUrl()
                    val sharedTitle = getSharedTitle()
                    result.success(mapOf(
                        "url" to (sharedUrl ?: ""),
                        "title" to (sharedTitle ?: "")
                    ))
                    clearSharedIntent()
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun getSharedUrl(): String? {
        return when {
            intent?.action == Intent.ACTION_SEND && intent?.type == "text/plain" -> {
                intent?.getStringExtra(Intent.EXTRA_TEXT)?.split(" ")?.firstOrNull {
                    it.startsWith("http://") || it.startsWith("https://")
                }
            }
            else -> null
        }
    }

    private fun getSharedTitle(): String? {
        return intent?.getStringExtra(Intent.EXTRA_SUBJECT)
    }

    private fun clearSharedIntent() {
        intent?.removeExtra(Intent.EXTRA_TEXT)
        intent?.removeExtra(Intent.EXTRA_SUBJECT)
    }
}
