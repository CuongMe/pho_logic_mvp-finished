import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum StageResult { cleared, lose }

extension StageResultStorage on StageResult {
  String get storageValue => switch (this) {
    StageResult.cleared => 'cleared',
    StageResult.lose => 'lose',
  };

  String get label => switch (this) {
    StageResult.cleared => 'Cleared',
    StageResult.lose => 'Lose',
  };

  static StageResult? fromStorage(String value) => switch (value) {
    'cleared' => StageResult.cleared,
    'lose' => StageResult.lose,
    _ => null,
  };
}

/// Persists the latest result for each stage.
class StageProgressRepository {
  static const String _prefsKey = 'stage_progress_v1';

  Future<Map<int, StageResult>> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid stage progress payload');
    }

    final progress = <int, StageResult>{};
    for (final entry in decoded.entries) {
      final stageId = int.tryParse(entry.key);
      final result = entry.value is String
          ? StageResultStorage.fromStorage(entry.value as String)
          : null;
      if (stageId == null || stageId <= 0 || result == null) {
        throw FormatException('Invalid saved stage result for ${entry.key}');
      }
      progress[stageId] = result;
    }
    return progress;
  }

  Future<void> saveStageResult(int stageId, StageResult result) async {
    if (stageId <= 0) return;
    final progress = await loadProgress();
    progress[stageId] = result;
    final serializable = <String, String>{
      for (final entry in progress.entries)
        entry.key.toString(): entry.value.storageValue,
    };
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_prefsKey, jsonEncode(serializable))) {
      throw StateError('SharedPreferences rejected stage progress write');
    }
  }
}
