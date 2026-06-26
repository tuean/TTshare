package com.ttshare.service

import android.content.SharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import java.io.IOException
import java.util.Base64

class WebdavClient(private val prefs: SharedPreferences) {

    private var baseUrl: String?
        get() = prefs.getString("webdav_url", null)
        set(value) = prefs.edit().putString("webdav_url", value).apply()

    private var username: String?
        get() = prefs.getString("webdav_username", null)
        set(value) = prefs.edit().putString("webdav_username", value).apply()

    private var password: String?
        get() = prefs.getString("webdav_password", null)
        set(value) = prefs.edit().putString("webdav_password", value).apply()

    val isConfigured: Boolean
        get() = baseUrl != null && username != null && password != null

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    private val authHeader: String
        get() {
            val raw = "${username ?: ""}:${password ?: ""}"
            return "Basic ${Base64.getEncoder().encodeToString(raw.toByteArray())}"
        }

    fun saveConfig(url: String, user: String, pass: String) {
        baseUrl = url
        username = user
        password = pass
    }

    suspend fun verifyConnection(): Boolean = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder()
                .url(baseUrl ?: return@withContext false)
                .header("Authorization", authHeader)
                .build()
            val response = client.newCall(request).execute()
            response.code in listOf(200, 207, 301, 302)
        } catch (e: Exception) {
            false
        }
    }

    suspend fun createFolder(path: String) = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${baseUrl}$path")
            .method("MKCOL", null)
            .header("Authorization", authHeader)
            .build()
        val response = client.newCall(request).execute()
        if (response.code !in listOf(201, 200, 301, 405)) {
            throw IOException("Failed to create folder: ${response.code}")
        }
    }

    suspend fun uploadFile(localPath: String, remotePath: String) = withContext(Dispatchers.IO) {
        val file = File(localPath)
        val body = file.readBytes().toRequestBody("text/html; charset=utf-8".toMediaType())
        val request = Request.Builder()
            .url("${baseUrl}$remotePath")
            .put(body)
            .header("Authorization", authHeader)
            .build()
        val response = client.newCall(request).execute()
        if (response.code !in listOf(201, 200)) {
            throw IOException("Failed to upload file: ${response.code}")
        }
    }

    suspend fun deleteFile(path: String) = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${baseUrl}$path")
            .delete()
            .header("Authorization", authHeader)
            .build()
        val response = client.newCall(request).execute()
        if (response.code !in listOf(204, 200)) {
            throw IOException("Failed to delete: ${response.code}")
        }
    }
}
