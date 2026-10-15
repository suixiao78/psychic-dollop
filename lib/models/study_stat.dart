class StudyStat {
  final String statDate;
  final int answeredCount;
  final int correctCount;
  final int durationMs;
  final int targetCount;
  final int updatedAt;

  const StudyStat({
    required this.statDate,
    this.answeredCount = 0,
    this.correctCount = 0,
    this.durationMs = 0,
    this.targetCount = 20,
    this.updatedAt = 0,
  });

  double get accuracy {
    if (answeredCount <= 0) {
      return 0.0;
    }
    return correctCount / answeredCount;
  }

  double get progress {
    if (targetCount <= 0) {
      return 0.0;
    }
    return (answeredCount / targetCount).clamp(0.0, 1.0).toDouble();
  }

  factory StudyStat.fromMap(Map<String, dynamic> map) {
    return StudyStat(
      statDate: (map['stat_date'] as String?) ?? '',
      answeredCount: (map['answered_count'] as int?) ?? 0,
      correctCount: (map['correct_count'] as int?) ?? 0,
      durationMs: (map['duration_ms'] as int?) ?? 0,
      targetCount: (map['target_count'] as int?) ?? 20,
      updatedAt: (map['updated_at'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'stat_date': statDate,
      'answered_count': answeredCount,
      'correct_count': correctCount,
      'duration_ms': durationMs,
      'target_count': targetCount,
      'updated_at': updatedAt,
    };
  }

  StudyStat copyWith({
    String? statDate,
    int? answeredCount,
    int? correctCount,
    int? durationMs,
    int? targetCount,
    int? updatedAt,
  }) {
    return StudyStat(
      statDate: statDate ?? this.statDate,
      answeredCount: answeredCount ?? this.answeredCount,
      correctCount: correctCount ?? this.correctCount,
      durationMs: durationMs ?? this.durationMs,
      targetCount: targetCount ?? this.targetCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}