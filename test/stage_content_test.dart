import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pho_logic/src/game/assets/tile_atlas.dart';
import 'package:pho_logic/src/game/stages/stage_data.dart';
import 'package:pho_logic/src/game/stages/stage_builder.dart';
import 'package:pho_logic/src/game/stages/stage_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all authored campaign stages satisfy the stage contract', () async {
    final atlas = await TileAtlasLoader.load();
    for (var stageId = 1; stageId <= 25; stageId++) {
      final path =
          'assets/stages/stage_${stageId.toString().padLeft(3, '0')}.json';
      final json =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final stage = StageData.fromJson(json);
      final errors = StageValidator.validate(stage);

      expect(errors, isEmpty, reason: '$path: ${errors.join('; ')}');
      for (final tile in stage.tiles) {
        if (TileAtlasLoader.isLikelyAtlasManagedAsset(tile.file)) {
          expect(
            TileAtlasLoader.frameForAssetPath(atlas, tile.file),
            isNotNull,
            reason: '$path references missing atlas frame ${tile.file}',
          );
        } else {
          expect(
            File(tile.file).existsSync(),
            isTrue,
            reason: '$path references ${tile.file}',
          );
        }
      }
      for (final bed in stage.bedTypes) {
        expect(
          File(bed.file).existsSync(),
          isTrue,
          reason: '$path references ${bed.file}',
        );
      }
      for (final blocker in stage.blockerTypes) {
        expect(
          File(blocker.file).existsSync(),
          isTrue,
          reason: '$path references ${blocker.file}',
        );
      }
      if (stageId == 21) {
        final board = StageBuilder.buildBoardState(stage, random: Random(21));
        for (var row = 0; row < stage.rows; row++) {
          for (var column = 0; column < stage.columns; column++) {
            if (stage.tileMap[row][column] == 0) {
              expect(board.tileIds[row][column], lessThan(101));
            }
          }
        }
      }
      if (stageId == 22) {
        expect(
          stage.tileMap.expand((row) => row).where((cell) => cell == -2),
          hasLength(4),
        );
        expect(stage.moves, 24);
        expect(stage.objectives, hasLength(1));
      }
    }
  });
}
