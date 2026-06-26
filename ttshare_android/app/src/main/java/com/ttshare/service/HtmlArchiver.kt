package com.ttshare.service

import android.content.Context
import java.io.File

class HtmlArchiver {

    data class ArchiveResult(
        val htmlPath: String,
        val mdPath: String?
    )

    fun archive(html: String, title: String, contentDir: File): String {
        if (!contentDir.exists()) contentDir.mkdirs()

        val htmlFile = File(contentDir, "index.html")
        val wrappedHtml = """
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
</head>
<body>
$html
</body>
</html>
""".trimIndent()

        htmlFile.writeText(wrappedHtml)
        return htmlFile.absolutePath
    }

    fun saveMarkdown(markdown: String, contentDir: File): String {
        if (!contentDir.exists()) contentDir.mkdirs()
        val mdFile = File(contentDir, "index.md")
        mdFile.writeText(markdown)
        return mdFile.absolutePath
    }

    fun sanitizeFileName(name: String): String {
        return name
            .replace(Regex("""[<>:"/\\|?*]"""), "_")
            .replace(Regex("\\s+"), "_")
            .take(100)
    }
}
