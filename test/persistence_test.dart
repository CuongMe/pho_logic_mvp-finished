import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pho_logic/src/game/inventory/inventory_repository.dart';
import 'package:pho_logic/src/game/progress/stage_progress_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'inventory spends requested amounts together and leaves no negative count',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = InventoryRepository();
      final inventory = await repository.loadInventory();

      await repository.addBooster(inventory, '103', 2);
      expect(
        await repository.consumeBooster(inventory, '103', amount: 2),
        isTrue,
      );
      expect(inventory.getBoosterCount('103'), 0);
      expect((await repository.loadInventory()).getBoosterCount('103'), 0);
      expect(await repository.consumeBooster(inventory, '103'), isFalse);
      expect(inventory.getBoosterCount('103'), 0);
    },
  );

  test('stage progress keeps only the latest result per stage', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = StageProgressRepository();

    await repository.saveStageResult(3, StageResult.cleared);
    await repository.saveStageResult(3, StageResult.lose);
    await repository.saveStageResult(4, StageResult.cleared);

    expect(await repository.loadProgress(), {
      3: StageResult.lose,
      4: StageResult.cleared,
    });
  });
}
