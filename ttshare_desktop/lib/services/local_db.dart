import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/article.dart';

class LocalDB {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'ttshare.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE articles (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            source TEXT NOT NULL,
            savedAt TEXT NOT NULL,
            syncedAt TEXT,
            isFavorite INTEGER DEFAULT 0,
            webdavPath TEXT NOT NULL,
            htmlContent TEXT,
            mdContent TEXT,
            errorMessage TEXT
          )
        ''');
        await db.execute('''
          CREATE VIRTUAL TABLE articles_fts USING fts5(
            title, mdContent, content='articles', content_rowid='rowid'
          )
        ''');
        await db.execute('''
          CREATE TRIGGER articles_ai AFTER INSERT ON articles BEGIN
            INSERT INTO articles_fts(rowid, title, mdContent)
            VALUES (new.rowid, new.title, new.mdContent);
          END
        ''');
        await db.execute('''
          CREATE TRIGGER articles_ad AFTER DELETE ON articles BEGIN
            INSERT INTO articles_fts(articles_fts, rowid, title, mdContent)
            VALUES ('delete', old.rowid, old.title, old.mdContent);
          END
        ''');
        await db.execute('''
          CREATE TRIGGER articles_au AFTER UPDATE ON articles BEGIN
            INSERT INTO articles_fts(articles_fts, rowid, title, mdContent)
            VALUES ('delete', old.rowid, old.title, old.mdContent);
            INSERT INTO articles_fts(rowid, title, mdContent)
            VALUES (new.rowid, new.title, new.mdContent);
          END
        ''');
      },
    );
  }

  Future<void> upsertArticle(Article article) async {
    final db = await database;
    await db.insert('articles', article.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Article>> getAllArticles() async {
    final db = await database;
    final maps = await db.query('articles', orderBy: 'savedAt DESC');
    return maps.map((m) => Article.fromMap(m)).toList();
  }

  Future<List<Article>> searchArticles(String query) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT articles.* FROM articles
      JOIN articles_fts ON articles.rowid = articles_fts.rowid
      WHERE articles_fts MATCH ?
      ORDER BY savedAt DESC
    ''', [query]);
    return maps.map((m) => Article.fromMap(m)).toList();
  }

  Future<List<Article>> getFavorites() async {
    final db = await database;
    final maps = await db.query('articles',
        where: 'isFavorite = 1', orderBy: 'savedAt DESC');
    return maps.map((m) => Article.fromMap(m)).toList();
  }

  Future<void> markFavorite(String id, bool favorite) async {
    final db = await database;
    await db.update('articles',
        {'isFavorite': favorite ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteArticle(String id) async {
    final db = await database;
    await db.delete('articles', where: 'id = ?', whereArgs: [id]);
  }

  Future<Article?> getArticle(String id) async {
    final db = await database;
    final maps = await db.query('articles', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Article.fromMap(maps.first);
  }
}
