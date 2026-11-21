import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pho_logic/src/audio/sfx_manager.dart';
import 'package:pho_logic/src/game/board/board_controller.dart';
import 'package:pho_logic/src/game/board/special_tile_spawner.dart';
import 'package:pho_logic/src/game/game_state_model.dart';
import 'package:pho_logic/src/game/model/coord.dart';
import 'package:pho_logic/src/game/stages/stage_builder.dart';
import 'package:pho_logic/src/game/stages/stage_data.dart';
import 'package:pho_logic/src/game/utils/debug_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one seeded bounded playthrough records outcomes for all campaign stages', () async {
    final previousLogging = DebugLogger.enabled;
    DebugLogger.enabled = false;
    addTearDown(() => DebugLogger.enabled = previousLogging);

    final outcomes = <String>[];
    for (var stageId = 1; stageId <= 25; stageId++) {
      final path =
          'assets/stages/stage_${stageId.toString().padLeft(3, '0')}.json';
      final stage = StageData.fromJson(
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
      );
      final seed = 0x50484f + stageId;
      final random = Random(seed);
      final grid = StageBuilder.buildGridModel(stage, random: Random(seed));
      final controller = BoardController(
        gridModel: grid,
        stageData: stage,
        sfxManager: SfxManager.instance,
        random: Random(seed ^ 0x5eed),
      );
      final specialSpawner = SpecialTileSpawner(rng: Random(seed));
      controller.initializeInstanceIds();
      controller.stabilizeInitialBoard();

      final blockerCount = grid.cells
          .expand((row) => row)
          .where((cell) => cell.isBlocked)
          .length;
      final gameState = GameStateModel(
        stageData: stage,
        initialBlockersRemaining: blockerCount,
      );
      controller.setOnCellsClearedWithTypes((cleared) async {
        gameState.processClearedTiles(cleared);
      });
      controller.setOnBlockerBreak((_) async {});
      controller.setOnBlockerCleared(
        (_) => gameState.decrementBlockersRemaining(),
      );

      var shuffleCount = 0;
      while (!gameState.isWon && !gameState.isLost) {
        final swaps = <(Coord, Coord)>[];
        for (var row = 0; row < grid.rows; row++) {
          for (var col = 0; col < grid.cols; col++) {
            if (col + 1 < grid.cols) {
              swaps.add((Coord(row, col), Coord(row, col + 1)));
            }
            if (row + 1 < grid.rows) {
              swaps.add((Coord(row, col), Coord(row + 1, col)));
            }
          }
        }
        swaps.shuffle(random);

        var moved = false;
        for (final (a, b) in swaps) {
          if (!controller.canSwap(a, b)) continue;
          final accepted = await controller.attemptSwap(
            a,
            b,
            onSync: () async {},
            onSpecialActivated: (specials, metadata) async {
              for (final entry in specials.entries) {
                if (entry.value != 101 &&
                    entry.value != 102 &&
                    entry.value != 104) {
                  continue;
                }
                final cells =
                    metadata[entry.key]?.activationCells ??
                    specialSpawner
                        .getActivationCells(grid, entry.key, entry.value)
                        .affected;
                await controller.clearTilesForVfx({...cells, entry.key});
              }
            },
          );
          if (accepted) {
            gameState.decrementMoves();
            moved = true;
            break;
          }
        }

        if (!moved) {
          if (shuffleCount >= 3) break;
          shuffleCount++;
          await controller.ensureSolvableOrShuffle(onSync: () async {});
        }
      }

      final status = gameState.isWon
          ? 'win'
          : gameState.isLost
          ? 'loss'
          : 'stalled';
      final objectives = stage.objectives.indexed
          .map(
            (entry) =>
                '${gameState.getObjectiveProgress(entry.$1)}/${entry.$2.target}',
          )
          .join(',');
      final usedMoves = stage.moves - gameState.movesRemaining;
      outcomes.add(
        'stage ${stageId.toString().padLeft(2, '0')}: $status; '
        '$usedMoves/${stage.moves} moves; objectives $objectives; '
        '${gameState.blockersRemaining} blockers remain',
      );
    }

    expect(outcomes, hasLength(25));
    for (final outcome in outcomes) {
      // A seeded random-play sample reports evidence; it is not a solvability proof.
      // ignore: avoid_print
      print('CAMPAIGN SIMULATION $outcome');
    }
  });
}
