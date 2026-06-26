package com.ttshare.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "articles")
data class ArticleRecord(
    @PrimaryKey val id: String,
    val title: String,
    val source: String,        // domain (mp.weixin.qq.com, zhihu.com)
    val url: String,
    val savedAt: Long,         // timestamp millis
    val status: String,        // pending, uploading, completed, failed
    val htmlWebdavPath: String? = null,
    val mdWebdavPath: String? = null,
    val errorMessage: String? = null
)
