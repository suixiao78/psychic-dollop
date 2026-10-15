class Option {
  final int? id;
  final int? questionId;
  final String optionKey;
  final String content;
  final int sortOrder;

  const Option({
    this.id,
    this.questionId,
    required this.optionKey,
    required this.content,
    this.sortOrder = 0,
  });

  factory Option.fromMap(Map<String, dynamic> map) {
    return Option(
      id: map['id'] as int?,
      questionId: map['question_id'] as int?,
      optionKey: (map['option_key'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap({int? questionId}) {
    final map = <String, dynamic>{
      'option_key': optionKey,
      'content': content,
      'sort_order': sortOrder,
    };
    final targetQuestionId = questionId ?? this.questionId;
    if (id != null) {
      map['id'] = id;
    }
    if (targetQuestionId != null) {
      map['question_id'] = targetQuestionId;
    }
    return map;
  }

  Option copyWith({
    int? id,
    int? questionId,
    String? optionKey,
    String? content,
    int? sortOrder,
  }) {
    return Option(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      optionKey: optionKey ?? this.optionKey,
      content: content ?? this.content,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}