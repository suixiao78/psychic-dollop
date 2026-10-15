import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _databaseName = 'grid_quiz_app.db';
  static const int _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final opened = await _openDatabase();
    _database = opened;
    return opened;
  }

  Future<void> init() async {
    await database;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final databasePath = p.join(databasesPath, _databaseName);
    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        external_id TEXT NOT NULL,
        exam_level TEXT NOT NULL CHECK (
          exam_level IN ('专科', '本科', '硕士', '通用')
        ),
        subject_id TEXT NOT NULL,
        subject_name TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        chapter_name TEXT NOT NULL,
        question_type TEXT NOT NULL CHECK (
          question_type IN ('single', 'multiple', 'judge')
        ),
        stem TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        explanation TEXT NOT NULL DEFAULT '',
        source_file TEXT NOT NULL DEFAULT '',
        source_locator TEXT NOT NULL DEFAULT '',
        difficulty INTEGER NOT NULL DEFAULT 1 CHECK (
          difficulty BETWEEN 1 AND 5
        ),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (
          is_active IN (0, 1)
        ),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE (external_id, exam_level)
      )
    ''');

    await db.execute('''
      CREATE TABLE options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        option_key TEXT NOT NULL,
        content TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE,
        UNIQUE (question_id, option_key)
      )
    ''');

    await db.execute('''
      CREATE TABLE answer_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        practice_mode TEXT NOT NULL CHECK (
          practice_mode IN (
            'sequence',
            'random',
            'exam',
            'wrong_review',
            'favorite_review'
          )
        ),
        selected_answer TEXT NOT NULL,
        is_correct INTEGER NOT NULL CHECK (is_correct IN (0, 1)),
        duration_ms INTEGER NOT NULL DEFAULT 0,
        session_id TEXT NOT NULL DEFAULT '',
        answered_at INTEGER NOT NULL,
        FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE wrong_book (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL UNIQUE,
        wrong_count INTEGER NOT NULL DEFAULT 1,
        correct_streak INTEGER NOT NULL DEFAULT 0,
        is_mastered INTEGER NOT NULL DEFAULT 0 CHECK (
          is_mastered IN (0, 1)
        ),
        last_selected_answer TEXT NOT NULL DEFAULT '',
        last_wrong_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE study_stats (
        stat_date TEXT PRIMARY KEY,
        answered_count INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        target_count INTEGER NOT NULL DEFAULT 20,
        updated_at INTEGER NOT NULL,
        CHECK (correct_count <= answered_count)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_questions_scope
      ON questions (
        exam_level,
        subject_id,
        chapter_id,
        question_type,
        is_active
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_options_question
      ON options (question_id, sort_order)
    ''');

    await db.execute('''
      CREATE INDEX idx_answer_records_question
      ON answer_records (question_id, answered_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_answer_records_time
      ON answer_records (answered_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_answer_records_mode
      ON answer_records (practice_mode, answered_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_wrong_book_mastered
      ON wrong_book (is_mastered, last_wrong_at)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await _onCreate(db, newVersion);
    }
  }

  Future<void> close() async {
    final existing = _database;
    if (existing == null) {
      return;
    }
    await existing.close();
    _database = null;
  }

  Future<void> deleteDatabaseFile() async {
    await close();
    final databasesPath = await getDatabasesPath();
    final databasePath = p.join(databasesPath, _databaseName);
    await deleteDatabase(databasePath);
  }
}