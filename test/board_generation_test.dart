import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pho_logic/src/audio/sfx_manager.dart';
import 'package:pho_logic/src/game/board/board_controller.dart';
import 'package:pho_logic/src/game/stages/stage_builder.dart';
import 'package:pho_logic/src/game/stages/stage_data.dart';
import 'package:pho_logic/src/game/utils/debug_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => DebugLogger.enabled = false);
  tearDownAll(() => DebugLogger.enabled = true);

  test(
    '10,000 seeded initial boards start match-free and have a legal move',
    () {
      final stageJson = jsonDecode(
        File('assets/stages/stage_001.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final stage = StageData.fromJson(stageJson);

      for (var seed = 0; seed < 10000; seed++) {
        final grid = StageBuilder.buildGridModel(stage, random: Random(seed));
        final controller = BoardController(
          gridModel: grid,
          stageData: stage,
          sfxManager: SfxManager.instance,
          random: Random(seed),
        );
        controller.initializeInstanceIds();
        controller.stabilizeInitialBoard();

        expect(
          controller.detectMatches().hasMatches,
          isFalse,
          reason: 'seed $seed',
        );
        expect(controller.hasPossibleMove(), isTrue, reason: 'seed $seed');
      }
    },
  );
}
