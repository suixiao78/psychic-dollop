import 'option.dart';

class Question {
  final int? id;
  final String externalId;
  final String examLevel;
  final String subjectId;
  final String subjectName;
  final String chapterId;
  final String chapterName;
  final String questionType;
  final String stem;
  final String correctAnswer;
  final String explanation;
  final String sourceFile;
  final String sourceLocator;
  final int difficulty;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  final List<Option> options;

  const Question({
    this.id,
    required this.externalId,
    required this.examLevel,
    required this.subjectId,
    required this.subjectName,
    required this.chapterId,
    required this.chapterName,
    required this.questionType,
    required this.stem,
    required this.correctAnswer,
    this.explanation = '',
    this.sourceFile = '',
    this.sourceLocator = '',
    this.difficulty = 1,
    this.isActive = true,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.options = const <Option>[],
  });

  bool get isSingleChoice => questionType == 'single';
  bool get isMultipleChoice => questionType == 'multiple';
  bool get isJudge => questionType == 'judge';

  List<String> get answerKeys {
    if (correctAnswer.isEmpty) {
      return const <String>[];
    }
    return correctAnswer
        .split('')
        .where((String key) => key.trim().isNotEmpty)
        .toList(growable: false);
  }

  factory Question.fromMap(
    Map<String, dynamic> map, {
    List<Option> options = const <Option>[],
  }) {
    return Question(
      id: map['id'] as int?,
      externalId: (map['external_id'] as String?) ?? '',
      examLevel: (map['exam_level'] as String?) ?? '通用',
      subjectId: (map['subject_id'] as String?) ?? '',
      subjectName: (map['subject_name'] as String?) ?? '',
      chapterId: (map['chapter_id'] as String?) ?? '',
      chapterName: (map['chapter_name'] as String?) ?? '',
      questionType: (map['question_type'] as String?) ?? 'single',
      stem: (map['stem'] as String?) ?? '',
      correctAnswer: (map['correct_answer'] as String?) ?? '',
      explanation: (map['explanation'] as String?) ?? '',
      sourceFile: (map['source_file'] as String?) ?? '',
      sourceLocator: (map['source_locator'] as String?) ?? '',
      difficulty: (map['difficulty'] as int?) ?? 1,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      createdAt: (map['created_at'] as int?) ?? 0,
      updatedAt: (map['updated_at'] as int?) ?? 0,
      options: options,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'external_id': externalId,
      'exam_level': examLevel,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'chapter_id': chapterId,
      'chapter_name': chapterName,
      'question_type': questionType,
      'stem': stem,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'source_file': sourceFile,
      'source_locator': sourceLocator,
      'difficulty': difficulty,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Question copyWith({
    int? id,
    String? externalId,
    String? examLevel,
    String? subjectId,
    String? subjectName,
    String? chapterId,
    String? chapterName,
    String? questionType,
    String? stem,
    String? correctAnswer,
    String? explanation,
    String? sourceFile,
    String? sourceLocator,
    int? difficulty,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
    List<Option>? options,
  }) {
    return Question(
      id: id ?? this.id,
      externalId: externalId ?? this.externalId,
      examLevel: examLevel ?? this.examLevel,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      chapterId: chapterId ?? this.chapterId,
      chapterName: chapterName ?? this.chapterName,
      questionType: questionType ?? this.questionType,
      stem: stem ?? this.stem,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      sourceFile: sourceFile ?? this.sourceFile,
      sourceLocator: sourceLocator ?? this.sourceLocator,
      difficulty: difficulty ?? this.difficulty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      options: options ?? this.options,
    );
  }
}