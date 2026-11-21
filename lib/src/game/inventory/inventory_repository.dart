import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'inventory.dart';

class InventoryRepository {
  static const String _prefsKey = 'player_inventory_v4';
  static final Map<String, int> _defaultBoosters = {
    '101': 0,
    '102': 0,
    '103': 0,
    '104': 0,
    '105': 0,
  };

  Future<Inventory> loadInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      return Inventory.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    }

    final inventory = _createDefaultInventory();
    await saveInventory(inventory);
    return inventory;
  }

  Inventory _createDefaultInventory() =>
      Inventory(boosters: Map<String, int>.from(_defaultBoosters));

  Future<void> saveInventory(Inventory inventory) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_prefsKey, jsonEncode(inventory.toJson()))) {
      throw StateError('SharedPreferences rejected inventory write');
    }
  }

  Future<void> addBooster(Inventory inventory, String id, int amount) async {
    if (amount <= 0) return;
    final nextCount = (inventory.boosters[id] ?? 0) + amount;
    final next = inventory.copy()..boosters[id] = nextCount;
    await saveInventory(next);
    inventory.boosters[id] = nextCount;
  }

  Future<bool> consumeBooster(
    Inventory inventory,
    String id, {
    int amount = 1,
  }) async {
    final currentCount = inventory.boosters[id] ?? 0;
    if (amount <= 0 || currentCount < amount) return false;

    final nextCount = currentCount - amount;
    final next = inventory.copy()..boosters[id] = nextCount;
    await saveInventory(next);
    inventory.boosters[id] = nextCount;
    return true;
  }

  Future<void> resetInventory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<Inventory> forceLoadDefaults() async {
    await resetInventory();
    final inventory = _createDefaultInventory();
    await saveInventory(inventory);
    return inventory;
  }
}
