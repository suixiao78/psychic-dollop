import 'package:flutter/foundation.dart';

import '../models/question.dart';
import '../services/favorite_service.dart';

class FavoriteProvider extends ChangeNotifier {
  final FavoriteService _favoriteService = FavoriteService.instance;

  List<Question> _items = <Question>[];
  bool _isLoading = false;
  String _errorMessage = '';

  List<Question> get items => _items;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get count => _items.length;

  bool isFavorite(int questionId) {
    return _items.any((question) => question.id == questionId);
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _items = await _favoriteService.getFavoriteQuestions(limit: 500);
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> toggle(int questionId) async {
    final state = await _favoriteService.toggleFavorite(questionId);
    await load();
    return state;
  }
}