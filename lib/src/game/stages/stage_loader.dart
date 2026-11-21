import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'stage_data.dart';
import 'stage_validator.dart';

class StageLoader {
  static Future<StageData> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final stage = StageData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    StageValidator.validateOrThrow(stage);
    return stage;
  }
}
