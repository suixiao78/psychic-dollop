import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/category_info.dart';
import '../models/option.dart';
import '../models/question.dart';

class QuestionService {
  QuestionService._();

  static final QuestionService instance = QuestionService._();

  Future<List<SubjectInfo>> getSubjects({String? examLevel}) async {
    final db = await DatabaseHelper.instance.database;
    final conditions = <String>['is_active = ?'];
    final args = <Object?>[1];

    if (examLevel != null && examLevel.isNotEmpty) {
      conditions.add('exam_level = ?');
      args.add(examLevel);
    }

    final rows = await db.rawQuery(
      'SELECT subject_id, subject_name, COUNT(*) AS question_count '
      'FROM questions '
      'WHERE ${conditions.join(' AND ')} '
      'GROUP BY subject_id, subject_name '
      'ORDER BY subject_name ASC',
      args,
    );

    return rows.map(SubjectInfo.fromMap).toList();
  }

  Future<List<ChapterInfo>> getChapters({
    required String subjectId,
    String? examLevel,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final conditions = <String>['is_active = ?', 'subject_id = ?'];
    final args = <Object?>[1, subjectId];

    if (examLevel != null && examLevel.isNotEmpty) {
      conditions.add('exam_level = ?');
      args.add(examLevel);
    }

    final rows = await db.rawQuery(
      'SELECT chapter_id, chapter_name, COUNT(*) AS question_count '
      'FROM questions '
      'WHERE ${conditions.join(' AND ')} '
      'GROUP BY chapter_id, chapter_name '
      'ORDER BY chapter_name ASC',
      args,
    );

    return rows.map(ChapterInfo.fromMap).toList();
  }

  Future<List<Question>> getQuestions({
    String? examLevel,
    String? subjectId,
    String? chapterId,
    String? questionType,
    int? limit,
    int? offset,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final conditions = <String>['is_active = ?'];
    final args = <Object?>[1];

    void addFilter(String column, String? value) {
      if (value == null || value.isEmpty) {
        return;
      }
      conditions.add('$column = ?');
      args.add(value);
    }

    addFilter('exam_level', examLevel);
    addFilter('subject_id', subjectId);
    addFilter('chapter_id', chapterId);
    addFilter('question_type', questionType);

    final rows = await db.query(
      'questions',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );

    final questions = rows
        .map((row) => Question.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    return _attachImages(await _attachOptions(questions));
  }

  Future<List<Question>> getRandomQuestions({
    int? count,
    String? examLevel,
    String? subjectId,
    String? chapterId,
    String? questionType,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final conditions = <String>['is_active = ?'];
    final args = <Object?>[1];

    void addFilter(String column, String? value) {
      if (value == null || value.isEmpty) {
        return;
      }
      conditions.add('$column = ?');
      args.add(value);
    }

    addFilter('exam_level', examLevel);
    addFilter('subject_id', subjectId);
    addFilter('chapter_id', chapterId);
    addFilter('question_type', questionType);

    final sql = StringBuffer(
      'SELECT * FROM questions '
      'WHERE ${conditions.join(' AND ')} '
      'ORDER BY RANDOM()',
    );
    final queryArgs = <Object?>[...args];
    if (count != null) {
      sql.write(' LIMIT ?');
      queryArgs.add(count);
    }

    final rows = await db.rawQuery(sql.toString(), queryArgs);

    final questions = rows
        .map((row) => Question.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    return _attachImages(await _attachOptions(questions));
  }

  Future<Question?> getQuestionById(int questionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'questions',
      where: 'id = ?',
      whereArgs: <Object?>[questionId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final question = Question.fromMap(
      Map<String, dynamic>.from(rows.first),
    );
    final withOptions = await _attachOptions(<Question>[question]);
    final questions = await _attachImages(withOptions);
    return questions.first;
  }

  Future<List<Question>> getQuestionsByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return <Question>[];
    }

    final db = await DatabaseHelper.instance.database;
    final placeholders = List<String>.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'questions',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    final questionMap = <int, Question>{};
    for (final row in rows) {
      final question = Question.fromMap(
        Map<String, dynamic>.from(row),
      );
      final id = question.id;
      if (id != null) {
        questionMap[id] = question;
      }
    }

    final questions = <Question>[];
    for (final id in ids) {
      final question = questionMap[id];
      if (question != null) {
        questions.add(question);
      }
    }

    return _attachImages(await _attachOptions(questions));
  }

  Future<int> getQuestionCount({
    String? examLevel,
    String? subjectId,
    String? chapterId,
    String? questionType,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final conditions = <String>['is_active = ?'];
    final args = <Object?>[1];

    void addFilter(String column, String? value) {
      if (value == null || value.isEmpty) {
        return;
      }
      conditions.add('$column = ?');
      args.add(value);
    }

    addFilter('exam_level', examLevel);
    addFilter('subject_id', subjectId);
    addFilter('chapter_id', chapterId);
    addFilter('question_type', questionType);

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM questions '
      'WHERE ${conditions.join(' AND ')}',
      args,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Question>> _attachImages(List<Question> questions) async {
    if (questions.isEmpty) {
      return <Question>[];
    }

    final ids = questions
        .map((question) => question.id)
        .whereType<int>()
        .toList();

    if (ids.isEmpty) {
      return questions;
    }

    final db = await DatabaseHelper.instance.database;
    final placeholders = List<String>.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'question_images',
      where: 'question_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'question_id ASC, sort_order ASC, id ASC',
    );

    final imagesByQuestion = <int, List<String>>{};
    for (final row in rows) {
      final questionId = row['question_id'] as int?;
      final imagePath = (row['image_path'] as String?) ?? '';
      if (questionId == null || imagePath.isEmpty) {
        continue;
      }
      imagesByQuestion
          .putIfAbsent(questionId, () => <String>[])
          .add(imagePath);
    }

    return questions.map((question) {
      final questionId = question.id;
      final images = questionId == null
          ? const <String>[]
          : (imagesByQuestion[questionId] ?? const <String>[]);
      return question.copyWith(images: images);
    }).toList();
  }

  Future<List<Question>> _attachOptions(List<Question> questions) async {
    if (questions.isEmpty) {
      return <Question>[];
    }

    final ids = questions
        .map((question) => question.id)
        .whereType<int>()
        .toList();

    if (ids.isEmpty) {
      return questions;
    }

    final db = await DatabaseHelper.instance.database;
    final placeholders = List<String>.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'options',
      where: 'question_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'question_id ASC, sort_order ASC, id ASC',
    );

    final optionsByQuestion = <int, List<Option>>{};
    for (final row in rows) {
      final option = Option.fromMap(
        Map<String, dynamic>.from(row),
      );
      final questionId = option.questionId;
      if (questionId == null) {
        continue;
      }
      optionsByQuestion
          .putIfAbsent(questionId, () => <Option>[])
          .add(option);
    }

    return questions.map((question) {
      final questionId = question.id;
      final options = questionId == null
          ? const <Option>[]
          : (optionsByQuestion[questionId] ?? const <Option>[]);
      return question.copyWith(options: options);
    }).toList();
  }
}