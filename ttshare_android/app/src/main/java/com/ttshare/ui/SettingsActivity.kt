package com.ttshare.ui

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.ttshare.R
import com.ttshare.service.CookieManager
import com.ttshare.service.WebdavClient
import com.google.android.material.switchmaterial.SwitchMaterial

class SettingsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        val prefs = getSharedPreferences("ttshare", MODE_PRIVATE)
        val webdavClient = WebdavClient(prefs)
        val cookieManager = CookieManager(prefs)

        val urlInput = findViewById<EditText>(R.id.webdavUrl)
        val userInput = findViewById<EditText>(R.id.webdavUsername)
        val passInput = findViewById<EditText>(R.id.webdavPassword)
        val verifyBtn = findViewById<Button>(R.id.verifyBtn)
        val cookieList = findViewById<TextView>(R.id.cookieList)
        val clearCookiesBtn = findViewById<Button>(R.id.clearCookiesBtn)

        // Load saved config
        urlInput.setText(prefs.getString("webdav_url", ""))
        userInput.setText(prefs.getString("webdav_username", ""))
        passInput.setText(prefs.getString("webdav_password", ""))

        // Verify connection
        verifyBtn.setOnClickListener {
            val url = urlInput.text.toString().trim()
            val user = userInput.text.toString().trim()
            val pass = passInput.text.toString().trim()

            if (url.isEmpty() || user.isEmpty() || pass.isEmpty()) {
                Toast.makeText(this, "请填写完整信息", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            webdavClient.saveConfig(url, user, pass)
            lifecycleScope.launchWhenResumed {
                verifyBtn.isEnabled = false
                verifyBtn.text = "验证中..."
                val ok = webdavClient.verifyConnection()
                verifyBtn.isEnabled = true
                verifyBtn.text = "验证连接"
                Toast.makeText(
                    this@SettingsActivity,
                    if (ok) "✅ 连接成功" else "❌ 连接失败",
                    Toast.LENGTH_SHORT
                ).show()
            }
        }

        // Cookie list
        refreshCookieList(cookieManager, cookieList)

        clearCookiesBtn.setOnClickListener {
            cookieManager.clearAll()
            refreshCookieList(cookieManager, cookieList)
            Toast.makeText(this, "已清除所有 Cookie", Toast.LENGTH_SHORT).show()
        }
    }

    private fun refreshCookieList(cookieManager: CookieManager, textView: TextView) {
        val cookies = cookieManager.getAllCookies()
        textView.text = if (cookies.isEmpty()) {
            "暂无已保存的 Cookie"
        } else {
            cookies.joinToString("\n") { "✅ ${it.domain}" }
        }
    }
}
