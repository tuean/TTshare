package com.ttshare.service

import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.jsoup.safety.Safelist
import com.vladsch.flexmark.html2md.converter.FlexmarkHtmlConverter
import com.vladsch.flexmark.util.data.MutableDataSet

class ReadabilityExtractor {

    data class ExtractResult(
        val title: String?,
        val contentHtml: String?,
        val markdown: String?,
        val excerpt: String?,
        val error: String?
    )

    fun extract(html: String): ExtractResult {
        return try {
            val doc = Jsoup.parse(html)

            // Remove non-content elements
            doc.select("script, style, nav, footer, header, iframe, .ad, .ads, .advertisement").remove()

            val title = doc.title().ifEmpty { null }

            // Try to find main content using common selectors
            val mainSelectors = listOf(
                "article",
                "[role=main]",
                ".post-content",
                ".article-content",
                ".content",
                "#content",
                ".rich_media_content",  // weixin
                ".RichText",            // zhihu
                "main"
            )

            var contentEl = doc.selectFirst(mainSelectors.joinToString(","))

            // Fallback: use body
            if (contentEl == null) {
                contentEl = doc.body()
            }

            if (contentEl == null) {
                return ExtractResult(title, null, null, null, "No content found")
            }

            // Clean the content HTML
            val contentHtml = contentEl.html()

            // Convert to Markdown
            val options = MutableDataSet()
            val converter = FlexmarkHtmlConverter.builder(options).build()
            val markdown = converter.convert(contentHtml)

            // Generate excerpt
            val text = contentEl.text()
            val excerpt = text.take(200).ifEmpty { null }

            ExtractResult(title, contentHtml, markdown, excerpt, null)
        } catch (e: Exception) {
            ExtractResult(null, null, null, null, e.message)
        }
    }
}
