package com.ttshare.data

import androidx.room.*

@Dao
interface ArticleDao {
    @Query("SELECT * FROM articles ORDER BY savedAt DESC")
    suspend fun getAll(): List<ArticleRecord>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(record: ArticleRecord)

    @Query("DELETE FROM articles WHERE id = :id")
    suspend fun delete(id: String)
}
