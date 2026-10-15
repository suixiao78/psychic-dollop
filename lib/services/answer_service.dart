import '../db/database_helper.dart';
import '../models/question.dart';
import 'stats_service.dart';
import 'wrong_book_service.dart';

class AnswerService {
  AnswerService._();

  static final AnswerService instance = AnswerService._();

  Future<bool> submitAnswer({
    required Question question,
    required String selectedAnswer,
    required String practiceMode,
    int durationMs = 0,
    String sessionId = '',
    int? targetCount,
  }) async {
    final questionId = question.id;
    if (questionId == null) {
      throw StateError('题目尚未保存到数据库，无法提交答案');
    }

    final normalizedAnswer = normalizeAnswer(selectedAnswer);
    final isCorrect = isAnswerCorrect(
      question: question,
      selectedAnswer: normalizedAnswer,
    );

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.insert('answer_records', {
        'question_id': questionId,
        'practice_mode': practiceMode,
        'selected_answer': normalizedAnswer,
        'is_correct': isCorrect ? 1 : 0,
        'duration_ms': durationMs,
        'session_id': sessionId,
        'answered_at': DateTime.now().millisecondsSinceEpoch,
      });

      if (isCorrect) {
        await WrongBookService.instance.markWrongQuestionCorrect(
          txn,
          questionId,
        );
      } else {
        await WrongBookService.instance.addOrUpdateWrongQuestion(
          txn,
          questionId,
          normalizedAnswer,
        );
      }
    });

    await StatsService.instance.recordAnswer(
      isCorrect: isCorrect,
      durationMs: durationMs,
      targetCount: targetCount,
    );

    return isCorrect;
  }

  bool isAnswerCorrect({
    required Question question,
    required String selectedAnswer,
  }) {
    return normalizeAnswer(question.correctAnswer) ==
        normalizeAnswer(selectedAnswer);
  }

  String normalizeAnswer(String answer) {
    final characters = answer
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .split('')
      ..sort();
    return characters.join();
  }
}