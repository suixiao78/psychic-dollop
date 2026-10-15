class Favorite {
  final int? id;
  final int questionId;
  final int createdAt;

  const Favorite({
    this.id,
    required this.questionId,
    required this.createdAt,
  });

  factory Favorite.fromMap(Map<String, dynamic> map) {
    return Favorite(
      id: map['id'] as int?,
      questionId: (map['question_id'] as int?) ?? 0,
      createdAt: (map['created_at'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'question_id': questionId,
      'created_at': createdAt,
    };
  }
}