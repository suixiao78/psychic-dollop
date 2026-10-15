class AnswerRecord {
  final int? id;
  final int questionId;
  final String practiceMode;
  final String selectedAnswer;
  final bool isCorrect;
  final int durationMs;
  final String sessionId;
  final int answeredAt;

  const AnswerRecord({
    this.id,
    required this.questionId,
    required this.practiceMode,
    required this.selectedAnswer,
    required this.isCorrect,
    this.durationMs = 0,
    this.sessionId = '',
    required this.answeredAt,
  });

  factory AnswerRecord.fromMap(Map<String, dynamic> map) {
    return AnswerRecord(
      id: map['id'] as int?,
      questionId: (map['question_id'] as int?) ?? 0,
      practiceMode: (map['practice_mode'] as String?) ?? 'sequence',
      selectedAnswer: (map['selected_answer'] as String?) ?? '',
      isCorrect: ((map['is_correct'] as int?) ?? 0) == 1,
      durationMs: (map['duration_ms'] as int?) ?? 0,
      sessionId: (map['session_id'] as String?) ?? '',
      answeredAt: (map['answered_at'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'question_id': questionId,
      'practice_mode': practiceMode,
      'selected_answer': selectedAnswer,
      'is_correct': isCorrect ? 1 : 0,
      'duration_ms': durationMs,
      'session_id': sessionId,
      'answered_at': answeredAt,
    };
  }
}