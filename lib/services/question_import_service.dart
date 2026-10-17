import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/option.dart';
import '../models/question.dart';

class QuestionImportService {
  QuestionImportService._();

  static final QuestionImportService instance = QuestionImportService._();

  static const String assetPath = 'assets/questions.json';
  static const int questionBankVersion = 5;
  static const String _questionBankVersionKey = 'question_bank_version';

  Future<int> ensureImported({bool forceReimport = false}) async {
    final db = await DatabaseHelper.instance.database;
    final preferences = await SharedPreferences.getInstance();
    final savedVersion = preferences.getInt(_questionBankVersionKey) ?? 0;
    final count = await _countQuestions(db);

    if (!forceReimport && savedVersion == questionBankVersion && count > 0) {
      return count;
    }

    final imported = await importFromAssets(
      clearExisting: forceReimport || count > 0,
    );
    await preferences.setInt(_questionBankVersionKey, questionBankVersion);
    return imported;
  }

  Future<int> importFromAssets({bool clearExisting = false}) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('题库 JSON 根节点必须是对象');
    }

    final subjects = decoded['subjects'];
    if (subjects is! List) {
      throw const FormatException('题库 JSON 缺少 subjects 数组');
    }

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    var importedCount = 0;

    await db.transaction((txn) async {
      if (clearExisting) {
        await txn.delete('questions');
      }

      for (final subjectRaw in subjects) {
        if (subjectRaw is! Map<String, dynamic>) {
          continue;
        }

        final subjectId = subjectRaw['id']?.toString() ?? '';
        final subjectName = subjectRaw['name']?.toString() ?? '';
        if (subjectId.isEmpty || subjectName.isEmpty) {
          continue;
        }

        final chapters = subjectRaw['chapters'];
        if (chapters is! List) {
          continue;
        }

        for (final chapterRaw in chapters) {
          if (chapterRaw is! Map<String, dynamic>) {
            continue;
          }

          final chapterId = chapterRaw['id']?.toString() ?? '';
          final chapterName = chapterRaw['name']?.toString() ?? '';
          if (chapterId.isEmpty || chapterName.isEmpty) {
            continue;
          }

          final questions = chapterRaw['questions'];
          if (questions is! List) {
            continue;
          }

          for (final questionRaw in questions) {
            if (questionRaw is! Map<String, dynamic>) {
              continue;
            }

            final externalId = questionRaw['id']?.toString() ?? '';
            final stem = questionRaw['stem']?.toString() ?? '';
            if (externalId.isEmpty || stem.isEmpty) {
              continue;
            }

            final options = _parseOptions(questionRaw['options']);
            final images = _parseImages(questionRaw['images']);
            final question = Question(
              externalId: externalId,
              examLevel: questionRaw['examLevel']?.toString() ?? '通用',
              subjectId: subjectId,
              subjectName: subjectName,
              chapterId: chapterId,
              chapterName: chapterName,
              questionType: questionRaw['type']?.toString() ?? 'single',
              stem: stem,
              correctAnswer: _parseAnswer(questionRaw['answer']),
              explanation: questionRaw['explanation']?.toString() ?? '',
              sourceFile: questionRaw['sourceFile']?.toString() ?? '',
              sourceLocator: questionRaw['sourceLocator']?.toString() ?? '',
              sourceImage: questionRaw['sourceImage']?.toString() ?? '',
              needsImage:
                  questionRaw['needsImage'] == true || questionRaw['needsImage'] == 1,
              difficulty:
                  int.tryParse(questionRaw['difficulty']?.toString() ?? '') ?? 1,
              isActive: true,
              createdAt: now,
              updatedAt: now,
              options: options,
            );

            final questionId = await txn.insert(
              'questions',
              question.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            if (questionId <= 0) {
              continue;
            }

            for (final option in options) {
              await txn.insert(
                'options',
                option.toMap(questionId: questionId),
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }

            for (var imageIndex = 0; imageIndex < images.length; imageIndex++) {
              await txn.insert(
                'question_images',
                <String, Object?>{
                  'question_id': questionId,
                  'image_path': images[imageIndex],
                  'sort_order': imageIndex,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }

            importedCount += 1;
          }
        }
      }
    });

    return importedCount;
  }

  Future<int> _countQuestions(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM questions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  String _parseAnswer(Object? rawAnswer) {
    if (rawAnswer == null) {
      return '';
    }

    final rawText = rawAnswer is List
        ? rawAnswer.map((dynamic item) => item.toString()).join()
        : rawAnswer.toString();

    final characters = rawText
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .split('')
      ..sort();

    return characters.join();
  }

  List<String> _parseImages(Object? rawImages) {
    if (rawImages is! List) {
      return const <String>[];
    }
    final images = <String>[];
    for (final raw in rawImages) {
      final path = raw?.toString().trim() ?? '';
      if (path.isNotEmpty) {
        images.add(path);
      }
    }
    return images;
  }

  List<Option> _parseOptions(Object? rawOptions) {
    if (rawOptions is! List) {
      return const <Option>[];
    }

    final options = <Option>[];

    for (var index = 0; index < rawOptions.length; index++) {
      final raw = rawOptions[index];
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final key = raw['key']?.toString().trim().toUpperCase() ?? '';
      final content = raw['text']?.toString() ?? '';
      if (key.isEmpty || content.isEmpty) {
        continue;
      }

      options.add(
        Option(
          optionKey: key,
          content: content,
          sortOrder: index,
        ),
      );
    }

    return options;
  }
}