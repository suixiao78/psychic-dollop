import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/question.dart';
import 'question_service.dart';

class FavoriteService {
  FavoriteService._();

  static final FavoriteService instance = FavoriteService._();

  Future<bool> isFavorite(int questionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'favorites',
      columns: <String>['id'],
      where: 'question_id = ?',
      whereArgs: <Object?>[questionId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> toggleFavorite(int questionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'favorites',
      columns: <String>['id'],
      where: 'question_id = ?',
      whereArgs: <Object?>[questionId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      await db.delete(
        'favorites',
        where: 'question_id = ?',
        whereArgs: <Object?>[questionId],
      );
      return false;
    }

    await db.insert('favorites', {
      'question_id': questionId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return true;
  }

  Future<List<Question>> getFavoriteQuestions({
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'favorites',
      columns: <String>['question_id'],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    final ids = rows
        .map((row) => row['question_id'] as int?)
        .whereType<int>()
        .toList();

    return QuestionService.instance.getQuestionsByIds(ids);
  }

  Future<int> getFavoriteCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM favorites',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}