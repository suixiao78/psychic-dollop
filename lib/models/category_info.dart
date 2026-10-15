class SubjectInfo {
  final String id;
  final String name;
  final int questionCount;

  const SubjectInfo({
    required this.id,
    required this.name,
    required this.questionCount,
  });

  factory SubjectInfo.fromMap(Map<String, Object?> map) {
    return SubjectInfo(
      id: (map['subject_id'] as String?) ?? '',
      name: (map['subject_name'] as String?) ?? '',
      questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChapterInfo {
  final String id;
  final String name;
  final int questionCount;

  const ChapterInfo({
    required this.id,
    required this.name,
    required this.questionCount,
  });

  factory ChapterInfo.fromMap(Map<String, Object?> map) {
    return ChapterInfo(
      id: (map['chapter_id'] as String?) ?? '',
      name: (map['chapter_name'] as String?) ?? '',
      questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
    );
  }
}