import 'package:flutter/foundation.dart';

import '../models/category_info.dart';
import '../services/preferences_service.dart';
import '../services/question_import_service.dart';
import '../services/question_service.dart';

class QuestionProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService.instance;
  final QuestionImportService _questionImportService =
      QuestionImportService.instance;
  final PreferencesService _preferencesService = PreferencesService.instance;

  bool _isLoading = false;
  bool _isReady = false;
  String _selectedExamLevel = '本科';
  List<SubjectInfo> _subjects = const <SubjectInfo>[];
  List<ChapterInfo> _chapters = const <ChapterInfo>[];
  String? _selectedSubjectId;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  String get selectedExamLevel => _selectedExamLevel;
  List<SubjectInfo> get subjects => _subjects;
  List<ChapterInfo> get chapters => _chapters;
  String? get selectedSubjectId => _selectedSubjectId;
  String get errorMessage => _errorMessage;

  Future<void> init() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _questionImportService.ensureImported();
      final savedLevel = await _preferencesService.getSelectedExamLevel();
      if (savedLevel != null && savedLevel.isNotEmpty) {
        _selectedExamLevel = savedLevel;
      }
      _subjects = await _questionService.getSubjects(
        examLevel: _selectedExamLevel,
      );
      _isReady = true;
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setExamLevel(String examLevel) async {
    if (examLevel == _selectedExamLevel) {
      return;
    }

    _selectedExamLevel = examLevel;
    _selectedSubjectId = null;
    _chapters = const <ChapterInfo>[];
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _preferencesService.setSelectedExamLevel(examLevel);
      _subjects = await _questionService.getSubjects(
        examLevel: _selectedExamLevel,
      );
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectSubject(String subjectId) async {
    _selectedSubjectId = subjectId;
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _chapters = await _questionService.getChapters(
        subjectId: subjectId,
        examLevel: _selectedExamLevel,
      );
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}