package com.ttshare.service

import android.content.Context
import com.ttshare.data.ArticleRecord
import com.ttshare.data.AppDatabase
import java.io.File
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class ProcessingPipeline(
    private val context: Context,
    private val prefs: android.content.SharedPreferences
) {
    private val webViewLoader = WebViewLoader()
    private val htmlArchiver = HtmlArchiver()
    private val readabilityExtractor = ReadabilityExtractor()
    private val webdavClient = WebdavClient(prefs)
    private val cookieManager = CookieManager(prefs)
    private val db = AppDatabase.getInstance(context)

    data class ProcessResult(
        val record: ArticleRecord,
        val success: Boolean,
        val error: String? = null
    )

    suspend fun process(url: String, title: String): ProcessResult {
        val id = UUID.randomUUID().toString()
        val dateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val source = try { URL(url).host } catch (_: Exception) { "unknown" }
        val folderName = "$dateStr-$source-${htmlArchiver.sanitizeFileName(title)}".take(100)

        return try {
            // 1. Load page with cookies
            val domain = URL(url).host
            val cookies = cookieManager.getCookies(domain)
            val html = webViewLoader.loadPage(url = url, cookieData = cookies?.cookieData)

            // 2. Create temp directory
            val cacheDir = File(context.cacheDir, folderName)
            cacheDir.mkdirs()

            // 3. Archive HTML
            val htmlPath = htmlArchiver.archive(html, title, cacheDir)

            // 4. Extract markdown
            val extractResult = readabilityExtractor.extract(html)
            var mdPath: String? = null
            if (extractResult.markdown != null) {
                mdPath = htmlArchiver.saveMarkdown(extractResult.markdown, cacheDir)
            }

            // 5. Upload to WebDAV
            if (!webdavClient.isConfigured) {
                throw Exception("WebDAV not configured")
            }
            webdavClient.createFolder("/$folderName")
            val htmlRemote = "/$folderName/index.html"
            webdavClient.uploadFile(htmlPath, htmlRemote)

            if (mdPath != null) {
                webdavClient.uploadFile(mdPath, "/$folderName/index.md")
            }

            val record = ArticleRecord(
                id = id,
                title = title,
                source = source,
                url = url,
                savedAt = System.currentTimeMillis(),
                status = "completed",
                htmlWebdavPath = htmlRemote
            )

            db.articleDao().upsert(record)

            ProcessResult(record, true)
        } catch (e: Exception) {
            val record = ArticleRecord(
                id = id,
                title = title,
                source = source,
                url = url,
                savedAt = System.currentTimeMillis(),
                status = "failed",
                errorMessage = e.message
            )
            db.articleDao().upsert(record)
            ProcessResult(record, false, e.message)
        }
    }
}
