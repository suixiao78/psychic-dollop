import 'package:flutter/foundation.dart';

import '../models/question.dart';
import '../services/wrong_book_service.dart';

class WrongBookProvider extends ChangeNotifier {
  final WrongBookService _wrongBookService = WrongBookService.instance;

  List<Question> _items = <Question>[];
  bool _isLoading = false;
  String _errorMessage = '';

  List<Question> get items => _items;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get count => _items.length;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _items = await _wrongBookService.getWrongQuestions(limit: 500);
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> remove(int questionId) async {
    await _wrongBookService.removeWrongQuestion(questionId);
    await load();
  }
}