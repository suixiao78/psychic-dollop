import 'package:flutter/foundation.dart';

import '../models/study_stat.dart';
import '../services/preferences_service.dart';
import '../services/stats_service.dart';

class StatsProvider extends ChangeNotifier {
  final StatsService _statsService = StatsService.instance;
  final PreferencesService _preferencesService = PreferencesService.instance;

  StudyStat _today = StudyStat(
    statDate: StatsService.dateKey(DateTime.now()),
  );
  int _totalAnswered = 0;
  int _totalCorrect = 0;
  List<StudyStat> _recentStats = <StudyStat>[];
  bool _isLoading = false;
  String _errorMessage = '';

  StudyStat get today => _today;
  int get totalAnswered => _totalAnswered;
  int get totalCorrect => _totalCorrect;
  List<StudyStat> get recentStats => _recentStats;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  double get accuracy {
    if (_totalAnswered <= 0) {
      return 0.0;
    }
    return _totalCorrect / _totalAnswered;
  }

  double get todayProgress => _today.progress;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final targetCount = await _preferencesService.getDailyTarget();
      final todayStat = await _statsService.getTodayStat(
        defaultTarget: targetCount,
      );
      _today = todayStat.copyWith(targetCount: targetCount);

      final overall = await _statsService.getOverallStats();
      _totalAnswered = overall['answered'] ?? 0;
      _totalCorrect = overall['correct'] ?? 0;

      _recentStats = await _statsService.getRecentStats(days: 7);
    } catch (error) {
      _errorMessage = error.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setDailyTarget(int value) async {
    if (value <= 0) {
      return;
    }

    await _preferencesService.setDailyTarget(value);
    await _statsService.setTargetCount(value);
    await load();
  }
}