import 'stage_data.dart';

class StageValidationError {
  final String message;

  StageValidationError(this.message);

  @override
  String toString() => 'StageValidationError: $message';
}

class StageValidator {
  static List<StageValidationError> validate(StageData stage) {
    final errors = <StageValidationError>[];
    if (stage.rows <= 0) {
      errors.add(StageValidationError('rows must be > 0'));
    }
    if (stage.columns <= 0) {
      errors.add(StageValidationError('columns must be > 0'));
    }
    if (stage.moves <= 0) {
      errors.add(StageValidationError('moves must be > 0'));
    }

    void validateMap(String name, List<List<int>> map) {
      if (map.length != stage.rows) {
        errors.add(
          StageValidationError(
            '$name rows (${map.length}) != rows (${stage.rows})',
          ),
        );
      }
      for (var row = 0; row < map.length; row++) {
        if (map[row].length != stage.columns) {
          errors.add(
            StageValidationError(
              '$name row $row length (${map[row].length}) != columns (${stage.columns})',
            ),
          );
        }
      }
    }

    validateMap('tileMap', stage.tileMap);
    validateMap('bedMap', stage.bedMap);

    final tileIds = <int>{};
    var hasSpawnableTile = false;
    for (final tile in stage.tiles) {
      if (!tileIds.add(tile.id)) {
        errors.add(StageValidationError('duplicate tile id ${tile.id}'));
      }
      final isRegular = tile.id >= 1 && tile.id <= 6;
      final isSpecial = tile.id >= 101 && tile.id <= 105;
      if (!isRegular && !isSpecial) {
        errors.add(StageValidationError('unknown tile id ${tile.id}'));
      }
      if (tile.file.trim().isEmpty) {
        errors.add(
          StageValidationError('tile id ${tile.id} has an empty file path'),
        );
      }
      if (isSpecial && tile.weight != 0) {
        errors.add(
          StageValidationError('special tile id ${tile.id} must have weight 0'),
        );
      } else if (isRegular && tile.weight <= 0) {
        errors.add(
          StageValidationError(
            'spawnable tile id ${tile.id} must have positive weight',
          ),
        );
      } else if (isRegular) {
        hasSpawnableTile = true;
      }
    }

    final blockerIds = stage.blockerTypes.map((blocker) => blocker.id).toSet();
    for (final blocker in stage.blockerTypes) {
      if (blocker.id != -2 || blocker.file.trim().isEmpty) {
        errors.add(
          StageValidationError('invalid blocker definition ${blocker.id}'),
        );
      }
    }

    for (var row = 0; row < stage.tileMap.length; row++) {
      for (var column = 0; column < stage.tileMap[row].length; column++) {
        final value = stage.tileMap[row][column];
        if (value > 0 && !tileIds.contains(value)) {
          errors.add(
            StageValidationError(
              'tileMap references unknown tile id $value at [$row,$column]',
            ),
          );
        } else if (value == 0 && !hasSpawnableTile) {
          errors.add(
            StageValidationError(
              'tileMap weighted spawn at [$row,$column] has no spawnable tiles',
            ),
          );
        } else if (value < -2) {
          errors.add(
            StageValidationError(
              'unknown tile map value $value at [$row,$column]',
            ),
          );
        } else if (value == -2 && !blockerIds.contains(-2)) {
          errors.add(
            StageValidationError(
              'tileMap blocker at [$row,$column] has no blocker definition',
            ),
          );
        }
      }
    }

    final bedIds = stage.bedTypes.map((bed) => bed.id).toSet();
    for (final bed in stage.bedTypes) {
      if (bed.id < 0 || bed.file.trim().isEmpty || bed.hp < 0) {
        errors.add(StageValidationError('invalid bed definition ${bed.id}'));
      }
    }
    for (var row = 0; row < stage.bedMap.length; row++) {
      for (var column = 0; column < stage.bedMap[row].length; column++) {
        final value = stage.bedMap[row][column];
        if (value < -1 || (value > 0 && !bedIds.contains(value))) {
          errors.add(
            StageValidationError(
              'bedMap references unknown bed id $value at [$row,$column]',
            ),
          );
        }
      }
    }

    if (stage.objectives.isEmpty) {
      errors.add(
        StageValidationError('stage must define at least one objective'),
      );
    }
    for (var index = 0; index < stage.objectives.length; index++) {
      final objective = stage.objectives[index];
      if (objective.type != 'collect' ||
          objective.tileId == null ||
          !tileIds.contains(objective.tileId) ||
          objective.target <= 0) {
        errors.add(StageValidationError('invalid objective at index $index'));
      }
    }

    return errors;
  }

  static void validateOrThrow(StageData stage) {
    final errors = validate(stage);
    if (errors.isNotEmpty) {
      throw FormatException(
        'Invalid stage ${stage.stageKey}: ${errors.join('; ')}',
      );
    }
  }
}
