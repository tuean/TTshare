package com.ttshare

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.NotificationCompat
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.DividerItemDecoration
import androidx.recyclerview.widget.LinearLayoutManager
import com.ttshare.data.AppDatabase
import com.ttshare.data.ArticleRecord
import com.ttshare.service.CookieManager
import com.ttshare.service.ProcessingPipeline
import com.ttshare.ui.ArticleAdapter
import com.ttshare.ui.SettingsActivity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity() {

    private lateinit var adapter: ArticleAdapter
    private lateinit var pipeline: ProcessingPipeline
    private lateinit var db: AppDatabase

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val prefs = getSharedPreferences("ttshare", MODE_PRIVATE)
        pipeline = ProcessingPipeline(this, prefs)
        db = AppDatabase.getInstance(this)

        adapter = ArticleAdapter { record ->
            if (record.status == "failed") {
                // Retry
                Toast.makeText(this, "重新保存: ${record.title}", Toast.LENGTH_SHORT).show()
                processUrl(record.url, record.title)
            }
        }

        val recyclerView = findViewById<androidx.recyclerview.widget.RecyclerView>(R.id.articleList)
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.addItemDecoration(DividerItemDecoration(this, DividerItemDecoration.VERTICAL))
        recyclerView.adapter = adapter

        findViewById<com.google.android.material.floatingactionbutton.FloatingActionButton>(R.id.settingsFab).setOnClickListener {
            startActivity(Intent(this, SettingsActivity::class.java))
        }

        // Handle incoming share intent
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        loadRecords()
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return

        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""

        // Extract URL from shared text
        val url = text.split("\\s+".toRegex()).firstOrNull { it.startsWith("http") }
        if (url == null) {
            Toast.makeText(this, "未找到有效的 URL", Toast.LENGTH_SHORT).show()
            return
        }

        val title = subject.ifEmpty { url }
        processUrl(url, title)
    }

    private fun processUrl(url: String, title: String) {
        lifecycleScope.launch {
            val result = pipeline.process(url, title)
            loadRecords()
            showNotification(result.success, title)
        }
    }

    private fun loadRecords() {
        lifecycleScope.launch {
            val records = withContext(Dispatchers.IO) {
                db.articleDao().getAll()
            }
            adapter.submitList(records)
        }
    }

    private fun showNotification(success: Boolean, title: String) {
        val builder = NotificationCompat.Builder(this, TTshareApp.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(if (success) "✅ 保存成功" else "❌ 保存失败")
            .setContentText(
                if (success) "$title 已上传到坚果云"
                else "$title 保存失败，点击重试"
            )
            .setAutoCancel(true)

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(System.currentTimeMillis().toInt(), builder.build())
    }
}
