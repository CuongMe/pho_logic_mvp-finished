import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pho_logic/src/audio/sfx_manager.dart';
import 'package:pho_logic/src/game/board/board_controller.dart';
import 'package:pho_logic/src/game/board/special_activation_resolver.dart';
import 'package:pho_logic/src/game/board/special_combo_resolver.dart';
import 'package:pho_logic/src/game/board/special_tile_spawner.dart';
import 'package:pho_logic/src/game/game_state_model.dart';
import 'package:pho_logic/src/game/model/coord.dart';
import 'package:pho_logic/src/game/model/grid_model.dart';
import 'package:pho_logic/src/game/stages/stage_data.dart';
import 'package:pho_logic/src/game/utils/debug_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late bool previousLogging;

  setUpAll(() {
    previousLogging = DebugLogger.enabled;
    DebugLogger.enabled = false;
  });

  tearDownAll(() => DebugLogger.enabled = previousLogging);

  test(
    'swap accepts a match and promptly restores a non-matching swap',
    () async {
      final grid = _grid([
        [2, 1, 2, 3],
        [3, 1, 3, 2],
        [2, 2, 1, 3],
        [1, 3, 2, 1],
      ]);
      final controller = _controller(grid);
      controller.initializeInstanceIds();

      var syncCount = 0;
      final invalidSwap = await controller.attemptSwap(
        const Coord(3, 0),
        const Coord(3, 1),
        onSync: () async => syncCount++,
      );
      expect(invalidSwap, isFalse);
      expect(syncCount, 2);
      expect(grid.cells[3].map((cell) => cell.tileTypeId), [1, 3, 2, 1]);

      final validSwap = await controller.attemptSwap(
        const Coord(2, 1),
        const Coord(2, 2),
        onSync: () async => syncCount++,
      );
      expect(validSwap, isTrue);
      expect(syncCount, greaterThan(2));
    },
  );

  test('gravity crosses voids but treats blockers as solid barriers', () {
    final grid = _grid(
      [
        [1, 3],
        [2, null],
        [null, null],
        [null, null],
      ],
      voids: {const Coord(1, 0)},
      blockers: {const Coord(2, 1)},
    );
    _controller(grid).applyGravity();

    expect(grid.cells[0][0].tileTypeId, isNull);
    expect(grid.cells[1][0].tileTypeId, 2);
    expect(grid.cells[3][0].tileTypeId, 1);
    expect(grid.cells[0][1].tileTypeId, isNull);
    expect(grid.cells[1][1].tileTypeId, 3);
    expect(grid.cells[2][1].blocker, BlockerType.scooterTileBlocker);
    expect(grid.cells[3][1].tileTypeId, isNull);
  });

  test('cascade resolution runs each clear, fall, and refill phase', () async {
    final grid = _grid(List.generate(3, (_) => List.filled(3, 1)));
    final controller = _controller(grid, tiles: const [1]);
    controller.initializeInstanceIds();
    expect(controller.detectMatches().hasMatches, isTrue);
    var syncCount = 0;

    final processed = await controller.runCascade(
      maxCascades: 2,
      onSync: () async => syncCount++,
    );

    expect(processed, isTrue);
    expect(syncCount, 6);
  });

  test(
    'special activation and special combination resolve their clear sets',
    () {
      final grid = _grid([
        [1, 2, 3],
        [4, 104, 5],
        [6, 1, 2],
      ]);
      final spawner = SpecialTileSpawner(rng: Random(7));
      final activation =
          SpecialActivationResolver(
            spawner: spawner,
            rows: grid.rows,
            cols: grid.cols,
          ).expandClearsWithSpecials(
            gridModel: grid,
            initialToClear: const {},
            swapA: const Coord(1, 1),
            swapB: const Coord(1, 0),
          );
      expect(activation.activatedSpecials[const Coord(1, 1)], 104);
      expect(activation.cellsToClear, hasLength(9));

      final comboGrid = _grid([
        [1, 2, 3],
        [4, 101, 102],
        [6, 1, 2],
      ]);
      final combo = SpecialComboResolver(rng: Random(7)).resolveCombo(
        grid: comboGrid,
        a: const Coord(1, 1),
        b: const Coord(1, 2),
      );
      expect(combo.isCombo, isTrue);
      expect(combo.meta['combo'], '101+102');
      expect(
        combo.cellsToClear,
        containsAll([const Coord(1, 1), const Coord(1, 2)]),
      );
    },
  );

  test('objectives clamp progress and determine win and loss outcomes', () {
    final stage = _stage(moves: 1, objectiveTarget: 2);
    final clearingGame = GameStateModel(
      stageData: stage,
      initialBlockersRemaining: 1,
    );
    clearingGame.processClearedTiles({
      const Coord(0, 0): 1,
      const Coord(0, 1): 1,
      const Coord(0, 2): 1,
    });
    expect(clearingGame.getObjectiveProgress(0), 2);
    expect(clearingGame.isWon, isFalse);
    clearingGame.decrementBlockersRemaining();
    expect(clearingGame.isWon, isTrue);
    expect(clearingGame.isLost, isFalse);

    final losingGame = GameStateModel(stageData: stage);
    losingGame.processClearedTiles({const Coord(0, 0): 1});
    losingGame.decrementMoves();
    expect(losingGame.isLost, isTrue);
    expect(losingGame.isWon, isFalse);
  });
}

GridModel _grid(
  List<List<int?>> tiles, {
  Set<Coord> voids = const {},
  Set<Coord> blockers = const {},
}) {
  return GridModel(
    rows: tiles.length,
    cols: tiles.first.length,
    cells: [
      for (var row = 0; row < tiles.length; row++)
        [
          for (var col = 0; col < tiles[row].length; col++)
            Cell(
              tileTypeId: tiles[row][col],
              tileInstanceId: tiles[row][col] == null ? null : row * 10 + col,
              bedId: voids.contains(Coord(row, col)) ? -1 : 0,
              blocker: blockers.contains(Coord(row, col))
                  ? BlockerType.scooterTileBlocker
                  : BlockerType.none,
            ),
        ],
    ],
  );
}

BoardController _controller(
  GridModel grid, {
  List<int> tiles = const [1, 2, 3],
}) {
  final stage = _stage(rows: grid.rows, columns: grid.cols, tiles: tiles);
  return BoardController(
    gridModel: grid,
    stageData: stage,
    sfxManager: SfxManager.instance,
    random: Random(11),
  );
}

StageData _stage({
  int rows = 3,
  int columns = 3,
  List<int> tiles = const [1, 2, 3],
  int moves = 5,
  int objectiveTarget = 2,
}) => StageData(
  stageKey: 'test-stage',
  name: 'Test stage',
  rows: rows,
  columns: columns,
  tiles: [
    for (final id in tiles) TileDef(id: id, file: 'tile-$id.png', weight: 1),
  ],
  bedTypes: [BedType(id: 0, file: 'bed.png', destructible: false, hp: 0)],
  blockerTypes: const [],
  tileMap: List.generate(rows, (_) => List.filled(columns, 0)),
  bedMap: List.generate(rows, (_) => List.filled(columns, 0)),
  moves: moves,
  allowInitialMatches: true,
  objectives: [Objective(type: 'collect', tileId: 1, target: objectiveTarget)],
);
