class WrongQuestion {
  final int? id;
  final int questionId;
  final int wrongCount;
  final int correctStreak;
  final bool isMastered;
  final String lastSelectedAnswer;
  final int lastWrongAt;
  final int updatedAt;

  const WrongQuestion({
    this.id,
    required this.questionId,
    this.wrongCount = 1,
    this.correctStreak = 0,
    this.isMastered = false,
    this.lastSelectedAnswer = '',
    required this.lastWrongAt,
    required this.updatedAt,
  });

  factory WrongQuestion.fromMap(Map<String, dynamic> map) {
    return WrongQuestion(
      id: map['id'] as int?,
      questionId: (map['question_id'] as int?) ?? 0,
      wrongCount: (map['wrong_count'] as int?) ?? 1,
      correctStreak: (map['correct_streak'] as int?) ?? 0,
      isMastered: ((map['is_mastered'] as int?) ?? 0) == 1,
      lastSelectedAnswer: (map['last_selected_answer'] as String?) ?? '',
      lastWrongAt: (map['last_wrong_at'] as int?) ?? 0,
      updatedAt: (map['updated_at'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'question_id': questionId,
      'wrong_count': wrongCount,
      'correct_streak': correctStreak,
      'is_mastered': isMastered ? 1 : 0,
      'last_selected_answer': lastSelectedAnswer,
      'last_wrong_at': lastWrongAt,
      'updated_at': updatedAt,
    };
  }
}