import 'practice_mode.dart';

class QuizArguments {
  final PracticeMode mode;
  final String title;
  final String? examLevel;
  final String? subjectId;
  final String? chapterId;
  final int count;

  const QuizArguments({
    required this.mode,
    required this.title,
    this.examLevel,
    this.subjectId,
    this.chapterId,
    this.count = 20,
  });
}