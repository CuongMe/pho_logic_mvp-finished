import 'package:flutter_test/flutter_test.dart';
import 'package:pho_logic/src/game/stages/stage_data.dart';
import 'package:pho_logic/src/game/stages/stage_validator.dart';
import 'package:pho_logic/src/app/routes.dart';

StageData _stage({
  List<TileDef>? tiles,
  List<List<int>>? tileMap,
  List<List<int>>? bedMap,
  List<Objective>? objectives,
  int moves = 5,
}) => StageData(
  stageKey: 'test_stage',
  name: 'Test Stage',
  rows: 2,
  columns: 3,
  tiles: tiles ?? [TileDef(id: 1, file: 'tile.png', weight: 1)],
  bedTypes: [BedType(id: 0, file: 'bed.png', destructible: false, hp: 0)],
  blockerTypes: [BlockerDef(id: -2, name: 'scooter', file: 'scooter.png')],
  tileMap:
      tileMap ??
      [
        [1, 0, 1],
        [-1, -2, 1],
      ],
  bedMap:
      bedMap ??
      [
        [0, 0, 0],
        [0, 0, 0],
      ],
  moves: moves,
  allowInitialMatches: false,
  objectives: objectives ?? [Objective(type: 'collect', tileId: 1, target: 2)],
);

void main() {
  test('campaign advances through stage 25 and ends deliberately', () {
    expect(Routes.nextStageId(20), 21);
    expect(Routes.nextStageId(24), 25);
    expect(Routes.nextStageId(25), isNull);
  });

  test('accepts zero-weight special definitions and blocker markers', () {
    final errors = StageValidator.validate(
      _stage(
        tiles: [
          TileDef(id: 1, file: 'tile.png', weight: 1),
          TileDef(id: 101, file: 'special.png', weight: 0),
        ],
      ),
    );

    expect(errors, isEmpty);
  });

  test('rejects zero-weight regular tiles and positive-weight specials', () {
    final errors = StageValidator.validate(
      _stage(
        tiles: [
          TileDef(id: 1, file: 'tile.png', weight: 0),
          TileDef(id: 101, file: 'special.png', weight: 2),
        ],
      ),
    );

    expect(
      errors.map((error) => error.message),
      contains(contains('tile id 1')),
    );
    expect(
      errors.map((error) => error.message),
      contains(contains('tile id 101')),
    );
  });

  test('rejects malformed maps, unknown values, and invalid objectives', () {
    final errors = StageValidator.validate(
      _stage(
        tileMap: [
          [1, -3],
        ],
        objectives: [Objective(type: 'collect', tileId: 999, target: 0)],
        moves: 0,
      ),
    );

    expect(
      errors.map((error) => error.message),
      contains(contains('tileMap row 0')),
    );
    expect(
      errors.map((error) => error.message),
      contains(contains('unknown tile map value -3')),
    );
    expect(
      errors.map((error) => error.message),
      contains(contains('objective')),
    );
    expect(errors.map((error) => error.message), contains(contains('moves')));
  });
}
