import 'package:flutter/foundation.dart';

import '../models/practice_mode.dart';
import '../models/question.dart';
import '../services/answer_service.dart';
import '../services/favorite_service.dart';
import '../services/question_service.dart';
import '../services/wrong_book_service.dart';

class PracticeProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService.instance;
  final AnswerService _answerService = AnswerService.instance;
  final WrongBookService _wrongBookService = WrongBookService.instance;
  final FavoriteService _favoriteService = FavoriteService.instance;

  List<Question> _questions = <Question>[];
  int _currentIndex = 0;
  final Map<int, Set<String>> _selectedByIndex = <int, Set<String>>{};
  final Map<int, bool> _answeredByIndex = <int, bool>{};
  final Map<int, bool> _correctByIndex = <int, bool>{};
  bool _isFavorite = false;
  bool _isLoading = false;
  bool _isFinished = false;
  String _errorMessage = '';
  PracticeMode _mode = PracticeMode.sequence;
  String _sessionId = '';
  DateTime? _questionStartedAt;

  List<Question> get questions => _questions;
  int get currentIndex => _currentIndex;

  Set<String> get selectedOptions {
    final selected = _selectedByIndex[_currentIndex];
    if (selected == null) {
      return const <String>{};
    }
    return Set<String>.unmodifiable(selected);
  }

  bool get isAnswered => _answeredByIndex[_currentIndex] ?? false;

  bool? get lastAnswerCorrect => _correctByIndex[_currentIndex];

  bool isAnsweredAt(int index) => _answeredByIndex[index] ?? false;

  bool? correctAt(int index) => _correctByIndex[index];

  bool get isFavorite => _isFavorite;
  bool get isLoading => _isLoading;
  bool get isFinished => _isFinished;
  String get errorMessage => _errorMessage;
  PracticeMode get mode => _mode;
  int get answeredCount => _answeredByIndex.length;
  int get correctCount => _correctByIndex.values.where((bool value) => value).length;
  String get sessionId => _sessionId;

  Question? get currentQuestion {
    if (_currentIndex < 0 || _currentIndex >= _questions.length) {
      return null;
    }
    return _questions[_currentIndex];
  }

  bool get hasPrevious => _currentIndex > 0;

  bool get hasNext => _currentIndex < _questions.length - 1;

  bool get isLastQuestion =>
      _questions.isNotEmpty && _currentIndex == _questions.length - 1;

  bool get isExamMode => _mode == PracticeMode.exam;

  double get progress {
    if (_questions.isEmpty) {
      return 0.0;
    }
    return (_currentIndex + 1) / _questions.length;
  }

  String get selectedAnswer {
    final keys = selectedOptions.toList()..sort();
    return keys.join();
  }

  bool get canSubmit {
    return currentQuestion != null && !isAnswered && selectedOptions.isNotEmpty;
  }

  Future<void> startPractice({
    required PracticeMode mode,
    String? examLevel,
    String? subjectId,
    String? chapterId,
    int? count,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    _mode = mode;
    _isFinished = false;
    notifyListeners();

    try {
      List<Question> loaded = <Question>[];

      switch (mode) {
        case PracticeMode.sequence:
          loaded = await _questionService.getQuestions(
            examLevel: examLevel,
            subjectId: subjectId,
            chapterId: chapterId,
            limit: count,
          );
          break;
        case PracticeMode.random:
        case PracticeMode.exam:
          loaded = await _questionService.getRandomQuestions(
            count: count,
            examLevel: examLevel,
            subjectId: subjectId,
            chapterId: chapterId,
          );
          break;
        case PracticeMode.wrongReview:
          loaded = await _wrongBookService.getWrongQuestions(
            limit: count ?? 500,
          );
          break;
        case PracticeMode.favoriteReview:
          loaded = await _favoriteService.getFavoriteQuestions(
            limit: count ?? 500,
          );
          break;
      }

      _questions = loaded;
      _currentIndex = 0;
      _selectedByIndex.clear();
      _answeredByIndex.clear();
      _correctByIndex.clear();
      _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
      _questionStartedAt = DateTime.now();
      _isFinished = loaded.isEmpty;
      await _loadFavoriteState();
    } catch (error) {
      _errorMessage = error.toString();
      _questions = <Question>[];
      _currentIndex = 0;
      _isFinished = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectOption(String optionKey) {
    if (isAnswered) {
      return;
    }

    final question = currentQuestion;
    if (question == null) {
      return;
    }

    final selected = _selectedByIndex.putIfAbsent(
      _currentIndex,
      () => <String>{},
    );

    if (question.isMultipleChoice) {
      if (selected.contains(optionKey)) {
        selected.remove(optionKey);
      } else {
        selected.add(optionKey);
      }
    } else {
      selected
        ..clear()
        ..add(optionKey);
    }

    notifyListeners();
  }

  Future<void> submitAnswer() async {
    final question = currentQuestion;
    if (question == null || isAnswered || selectedOptions.isEmpty) {
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final startedAt = _questionStartedAt;
      final durationMs = startedAt == null
          ? 0
          : DateTime.now().difference(startedAt).inMilliseconds;

      final isCorrect = await _answerService.submitAnswer(
        question: question,
        selectedAnswer: selectedAnswer,
        practiceMode: _mode.dbValue,
        durationMs: durationMs,
        sessionId: _sessionId,
      );

      _answeredByIndex[_currentIndex] = true;
      _correctByIndex[_currentIndex] = isCorrect;
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> nextQuestion() async {
    if (!hasNext) {
      _isFinished = true;
      notifyListeners();
      return;
    }

    _currentIndex += 1;
    _questionStartedAt = DateTime.now();
    await _loadFavoriteState();
    notifyListeners();
  }

  Future<void> previousQuestion() async {
    if (!hasPrevious) {
      return;
    }

    _currentIndex -= 1;
    _questionStartedAt = DateTime.now();
    await _loadFavoriteState();
    notifyListeners();
  }

  Future<void> jumpToQuestion(int index) async {
    if (index < 0 || index >= _questions.length || index == _currentIndex) {
      return;
    }
    _currentIndex = index;
    _questionStartedAt = DateTime.now();
    await _loadFavoriteState();
    notifyListeners();
  }

  Future<void> toggleFavorite() async {
    final questionId = currentQuestion?.id;
    if (questionId == null) {
      return;
    }

    try {
      _isFavorite = await _favoriteService.toggleFavorite(questionId);
    } catch (error) {
      _errorMessage = error.toString();
    }

    notifyListeners();
  }

  void finishExam() {
    _isFinished = true;
    notifyListeners();
  }

  void reset() {
    _questions = <Question>[];
    _currentIndex = 0;
    _selectedByIndex.clear();
    _answeredByIndex.clear();
    _correctByIndex.clear();
    _isFavorite = false;
    _isLoading = false;
    _isFinished = false;
    _errorMessage = '';
    _mode = PracticeMode.sequence;
    _sessionId = '';
    _questionStartedAt = null;
    notifyListeners();
  }

  Future<void> _loadFavoriteState() async {
    final questionId = currentQuestion?.id;
    if (questionId == null) {
      _isFavorite = false;
      return;
    }
    _isFavorite = await _favoriteService.isFavorite(questionId);
  }
}