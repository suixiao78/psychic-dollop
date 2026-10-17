import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService._();

  static final PreferencesService instance = PreferencesService._();

  static const String _dailyTargetKey = 'daily_target';
  static const String _selectedExamLevelKey = 'selected_exam_level';

  Future<SharedPreferences> get _preferences async {
    return SharedPreferences.getInstance();
  }

  Future<int> getDailyTarget() async {
    final preferences = await _preferences;
    return preferences.getInt(_dailyTargetKey) ?? 20;
  }

  Future<void> setDailyTarget(int value) async {
    final preferences = await _preferences;
    await preferences.setInt(_dailyTargetKey, value);
  }

  Future<String?> getSelectedExamLevel() async {
    final preferences = await _preferences;
    return preferences.getString(_selectedExamLevelKey);
  }

  Future<void> setSelectedExamLevel(String value) async {
    final preferences = await _preferences;
    await preferences.setString(_selectedExamLevelKey, value);
  }

  Future<int?> getInt(String key) async {
    final preferences = await _preferences;
    return preferences.getInt(key);
  }

  Future<void> setInt(String key, int value) async {
    final preferences = await _preferences;
    await preferences.setInt(key, value);
  }

  Future<void> clear() async {
    final preferences = await _preferences;
    await preferences.clear();
  }
}