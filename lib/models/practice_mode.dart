enum PracticeMode {
  sequence,
  random,
  exam,
  wrongReview,
  favoriteReview,
}

extension PracticeModeX on PracticeMode {
  String get dbValue {
    switch (this) {
      case PracticeMode.sequence:
        return 'sequence';
      case PracticeMode.random:
        return 'random';
      case PracticeMode.exam:
        return 'exam';
      case PracticeMode.wrongReview:
        return 'wrong_review';
      case PracticeMode.favoriteReview:
        return 'favorite_review';
    }
  }

  String get label {
    switch (this) {
      case PracticeMode.sequence:
        return '顺序练习';
      case PracticeMode.random:
        return '随机练习';
      case PracticeMode.exam:
        return '模拟考试';
      case PracticeMode.wrongReview:
        return '错题重做';
      case PracticeMode.favoriteReview:
        return '收藏练习';
    }
  }
}