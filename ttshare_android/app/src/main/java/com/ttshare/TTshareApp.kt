package com.ttshare

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class TTshareApp : Application() {

    companion object {
        const val CHANNEL_ID = "ttshare_channel"
        lateinit var instance: TTshareApp
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "TTshare 保存通知",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "网页快照保存结果通知"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
