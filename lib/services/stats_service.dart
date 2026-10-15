import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/study_stat.dart';

class StatsService {
  StatsService._();

  static final StatsService instance = StatsService._();

  static String dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<StudyStat> getTodayStat({int defaultTarget = 20}) async {
    final db = await DatabaseHelper.instance.database;
    final today = dateKey(DateTime.now());
    final rows = await db.query(
      'study_stats',
      where: 'stat_date = ?',
      whereArgs: <Object?>[today],
      limit: 1,
    );

    if (rows.isEmpty) {
      return StudyStat(
        statDate: today,
        targetCount: defaultTarget,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }

    return StudyStat.fromMap(
      Map<String, dynamic>.from(rows.first),
    );
  }

  Future<void> recordAnswer({
    required bool isCorrect,
    int durationMs = 0,
    int? targetCount,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final today = dateKey(DateTime.now());
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'study_stats',
        where: 'stat_date = ?',
        whereArgs: <Object?>[today],
        limit: 1,
      );

      if (rows.isEmpty) {
        await txn.insert('study_stats', {
          'stat_date': today,
          'answered_count': 1,
          'correct_count': isCorrect ? 1 : 0,
          'duration_ms': durationMs,
          'target_count': targetCount ?? 20,
          'updated_at': now,
        });
        return;
      }

      final current = StudyStat.fromMap(
        Map<String, dynamic>.from(rows.first),
      );

      await txn.update(
        'study_stats',
        {
          'answered_count': current.answeredCount + 1,
          'correct_count': current.correctCount + (isCorrect ? 1 : 0),
          'duration_ms': current.durationMs + durationMs,
          'target_count': targetCount ?? current.targetCount,
          'updated_at': now,
        },
        where: 'stat_date = ?',
        whereArgs: <Object?>[today],
      );
    });
  }

  Future<Map<String, int>> getOverallStats() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT '
      'COALESCE(SUM(answered_count), 0) AS answered, '
      'COALESCE(SUM(correct_count), 0) AS correct '
      'FROM study_stats',
    );

    final row = rows.first;
    return <String, int>{
      'answered': (row['answered'] as num?)?.toInt() ?? 0,
      'correct': (row['correct'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<StudyStat>> getRecentStats({int days = 7}) async {
    final safeDays = days <= 0 ? 1 : days;
    final db = await DatabaseHelper.instance.database;
    final since = dateKey(
      DateTime.now().subtract(Duration(days: safeDays - 1)),
    );

    final rows = await db.query(
      'study_stats',
      where: 'stat_date >= ?',
      whereArgs: <Object?>[since],
      orderBy: 'stat_date ASC',
    );

    return rows
        .map((row) => StudyStat.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> setTargetCount(int targetCount) async {
    if (targetCount <= 0) {
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final today = dateKey(DateTime.now());
    final now = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'study_stats',
      where: 'stat_date = ?',
      whereArgs: <Object?>[today],
      limit: 1,
    );

    if (rows.isEmpty) {
      await db.insert('study_stats', {
        'stat_date': today,
        'answered_count': 0,
        'correct_count': 0,
        'duration_ms': 0,
        'target_count': targetCount,
        'updated_at': now,
      });
      return;
    }

    await db.update(
      'study_stats',
      {
        'target_count': targetCount,
        'updated_at': now,
      },
      where: 'stat_date = ?',
      whereArgs: <Object?>[today],
    );
  }
}