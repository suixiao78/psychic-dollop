import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/question.dart';
import '../models/wrong_question.dart';
import 'question_service.dart';

class WrongBookService {
  WrongBookService._();

  static final WrongBookService instance = WrongBookService._();

  Future<void> addOrUpdateWrongQuestion(
    DatabaseExecutor executor,
    int questionId,
    String selectedAnswer,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await executor.query(
      'wrong_book',
      where: 'question_id = ?',
      whereArgs: <Object?>[questionId],
      limit: 1,
    );

    if (rows.isEmpty) {
      await executor.insert('wrong_book', {
        'question_id': questionId,
        'wrong_count': 1,
        'correct_streak': 0,
        'is_mastered': 0,
        'last_selected_answer': selectedAnswer,
        'last_wrong_at': now,
        'updated_at': now,
      });
      return;
    }

    final current = WrongQuestion.fromMap(
      Map<String, dynamic>.from(rows.first),
    );

    await executor.update(
      'wrong_book',
      {
        'wrong_count': current.wrongCount + 1,
        'correct_streak': 0,
        'is_mastered': 0,
        'last_selected_answer': selectedAnswer,
        'last_wrong_at': now,
        'updated_at': now,
      },
      where: 'question_id = ?',
      whereArgs: <Object?>[questionId],
    );
  }

  Future<void> markWrongQuestionCorrect(
    DatabaseExecutor executor,
    int questionId,
  ) async {
    final rows = await executor.query(
      'wrong_book',
      where: 'question_id = ?',
      whereArgs: <Object?>[questionId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return;
    }

    final current = WrongQuestion.fromMap(
      Map<String, dynamic>.from(rows.first),
    );
    final nextStreak = current.correctStreak + 1;
    final mastered = nextStreak >= 2 || current.isMastered;

    await executor.update(
      'wrong_book',
      {
        'correct_streak': nextStreak,
        'is_mastered': mastered ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'question_id = ?',
      whereArgs: <Object?>[questionId],
    );
  }

  Future<List<Question>> getWrongQuestions({
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'wrong_book',
      columns: <String>['question_id'],
      where: 'is_mastered = ?',
      whereArgs: <Object?>[0],
      orderBy: 'last_wrong_at DESC',
      limit: limit,
      offset: offset,
    );

    final ids = rows
        .map((row) => row['question_id'] as int?)
        .whereType<int>()
        .toList();

    return QuestionService.instance.getQuestionsByIds(ids);
  }

  Future<int> getWrongCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM wrong_book WHERE is_mastered = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> removeWrongQuestion(int questionId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'wrong_book',
      where: 'question_id = ?',
      whereArgs: <Object?>[questionId],
    );
  }
}