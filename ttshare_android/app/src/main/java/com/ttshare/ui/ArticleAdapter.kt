package com.ttshare.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.ttshare.R
import com.ttshare.data.ArticleRecord
import java.text.SimpleDateFormat
import java.util.*

class ArticleAdapter(
    private val onRetry: (ArticleRecord) -> Unit
) : RecyclerView.Adapter<ArticleAdapter.ViewHolder>() {

    private val items = mutableListOf<ArticleRecord>()
    private val dateFormat = SimpleDateFormat("MM/dd HH:mm", Locale.getDefault())

    fun submitList(list: List<ArticleRecord>) {
        items.clear()
        items.addAll(list)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_article, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val record = items[position]
        holder.title.text = record.title
        holder.subtitle.text = "${dateFormat.format(Date(record.savedAt))} · ${record.source}"

        when (record.status) {
            "completed" -> {
                holder.status.text = "✅"
                holder.status.setTextColor(holder.itemView.context.getColor(R.color.success))
                holder.itemView.setOnClickListener(null)
            }
            "uploading" -> {
                holder.status.text = "⏳"
                holder.status.setTextColor(holder.itemView.context.getColor(R.color.warning))
                holder.itemView.setOnClickListener(null)
            }
            "failed" -> {
                holder.status.text = "❌"
                holder.status.setTextColor(holder.itemView.context.getColor(R.color.error))
                holder.itemView.setOnClickListener { onRetry(record) }
            }
            else -> {
                holder.status.text = "◻"
                holder.status.setTextColor(holder.itemView.context.getColor(R.color.warning))
                holder.itemView.setOnClickListener(null)
            }
        }
    }

    override fun getItemCount() = items.size

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val title: TextView = view.findViewById(R.id.articleTitle)
        val subtitle: TextView = view.findViewById(R.id.articleSubtitle)
        val status: TextView = view.findViewById(R.id.articleStatus)
    }
}
