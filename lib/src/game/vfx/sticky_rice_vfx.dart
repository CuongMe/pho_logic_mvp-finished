import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../model/coord.dart';
import '../utils/debug_logger.dart';
import '../board/board_game.dart';
import '../board/tile_component.dart';
import '../board/match_burst_particle.dart';
import '../../audio/sfx_manager.dart';

/// Visual effects for Sticky Rice Bomb (103) special tile
/// Implements "bomb warning → explode outward" sequence
/// VFX only - does NOT mutate gridModel or call syncFromModel
class StickyRiceVfx {
  /// List of random colors for tiles about to be destroyed
  static const List<Color> _glowColors = [
    Color(0xFF9B59B6), // Purple
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFF9800), // Orange
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
  ];

  // Timing constants (tunable)
  static const double _warnBombDur =
      0.85; // Duration for bomb warning (pulse + grayscale)
  static const double _perTileTintDur =
      0.3; // Duration for each tile's color tint (0.35-0.5s range)
  static const double _perTileClearDur =
      0.12; // Duration for each tile's clear scale effect (0.10-0.15s range)
  static const Duration _stepGap = Duration(milliseconds: 50);

  // Rate limiter for bloop sounds
  static int _bloopCount = 0;
  static int _bloopWindowStartMs = 0;

  /// Check if bloop is allowed based on rate limit (max bloops per second)
  static bool _allowBloop({int maxPerSec = 8}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _bloopWindowStartMs >= 1000) {
      _bloopWindowStartMs = now;
      _bloopCount = 0;
    }
    if (_bloopCount >= maxPerSec) return false;
    _bloopCount++;
    return true;
  }

  /// Play the Sticky Rice Bomb VFX
  ///
  /// Parameters:
  /// - game: The BoardGame instance
  /// - tile: The tile component for the Sticky Rice Bomb
  /// - activationCells: Set of coords that will be cleared by this bomb
  ///
  /// Returns: Future that completes when VFX is done
  /// BoardController should clear activationCells and call syncFromModel after this completes
  ///
  /// Must abort quietly if TileComponent is null/removed
  static Future<void> play({
    required BoardGame game,
    required TileComponent tile,
    required Set<Coord> activationCells,
  }) async {
    DebugLogger.vfx(
      'Starting VFX at coord=${tile.coord}, instanceId=${tile.instanceId}',
      vfxType: 'StickyRice',
    );
    DebugLogger.vfx(
      'Will clear ${activationCells.length} tiles',
      vfxType: 'StickyRice',
    );

    // Safety check: abort if bomb tile is removed
    if (tile.isRemoved || !game.children.contains(tile)) {
      DebugLogger.vfx('Bomb tile removed, aborting', vfxType: 'StickyRice');
      return;
    }

    final bombCoord = tile.coord;
    final random = math.Random();
    final warningDuration = game.reducedMotion ? 0.08 : _warnBombDur;
    final tintDuration = game.reducedMotion ? 0.06 : _perTileTintDur;
    final clearDuration = game.reducedMotion ? 0.05 : _perTileClearDur;
    final stepGap = game.reducedMotion ? Duration.zero : _stepGap;

    // ===== PHASE 1: BOMB WARNING =====
    DebugLogger.vfx(
      'PHASE 1: Bomb warning (tint overlay + pulse)',
      vfxType: 'StickyRice',
    );

    // Store base scale for relative pulse
    final baseScale = tile.scale.clone();

    // Remove any existing ColorEffect on bomb first (avoid stacking)
    final bombEffectsToRemove = <Component>[];
    for (final child in tile.children) {
      if (child is ColorEffect) {
        bombEffectsToRemove.add(child);
      }
    }
    for (final effect in bombEffectsToRemove) {
      effect.removeFromParent();
    }

    // Bomb tile: Black tint overlay ColorEffect
    final bombTintEffectBlack = ColorEffect(
      Colors.black, // Black tint overlay for warning effect
      EffectController(duration: warningDuration, curve: Curves.easeOut),
      opacityFrom: 0.0,
      opacityTo: 0.75,
    );

    // Bomb tile: Slow pulse relative to base scale (baseScale → baseScale*1.10 → baseScale)
    final bombPulseEffect = SequenceEffect([
      ScaleEffect.to(
        baseScale * 1.10,
        EffectController(duration: warningDuration / 2, curve: Curves.easeOut),
      ),
      ScaleEffect.to(
        baseScale,
        EffectController(duration: warningDuration / 2, curve: Curves.easeOut),
      ),
    ]);

    tile.add(bombTintEffectBlack);
    tile.add(bombPulseEffect);

    // Wait for bomb warning to complete
    try {
      await Future.wait([
        bombTintEffectBlack.completed,
        bombPulseEffect.completed,
      ]).timeout(
        Duration(milliseconds: (warningDuration * 1000).round() + 200),
        onTimeout: () {
          DebugLogger.warn('Bomb warning timeout', category: 'StickyRiceVfx');
          return <void>[];
        },
      );
    } catch (e) {
      DebugLogger.error('Bomb warning error: $e', category: 'StickyRiceVfx');
    }

    // Safety check: abort if bomb tile removed
    if (tile.isRemoved || !game.children.contains(tile)) {
      DebugLogger.vfx(
        'Bomb tile removed during warning, aborting',
        vfxType: 'StickyRice',
      );
      return;
    }

    // ===== PHASE 2: SEQUENTIAL COLOR WARNING (outward) =====
    DebugLogger.vfx(
      'PHASE 2: Sequential color warning (outward)',
      vfxType: 'StickyRice',
    );

    // Order coords by Manhattan distance from bomb (closest → farthest)
    // Exclude bomb and optionally filter playable cells
    final orderedCoords = activationCells
        .where((c) => c != bombCoord && game.isPlayableCell(c))
        .toList();
    orderedCoords.sort((a, b) {
      final distA =
          (a.row - bombCoord.row).abs() + (a.col - bombCoord.col).abs();
      final distB =
          (b.row - bombCoord.row).abs() + (b.col - bombCoord.col).abs();
      return distA.compareTo(distB);
    });

    final rings = <int, List<Coord>>{};
    for (final coord in orderedCoords) {
      final distance =
          (coord.row - bombCoord.row).abs() + (coord.col - bombCoord.col).abs();
      rings.putIfAbsent(distance, () => []).add(coord);
    }

    DebugLogger.vfx(
      'Applying color effects to ${orderedCoords.length} tiles in distance rings',
      vfxType: 'StickyRice',
    );

    // Start all tiles in a Manhattan-distance ring together.
    for (final ring in rings.values) {
      if (tile.isRemoved || !game.children.contains(tile)) return;

      final effects = <ColorEffect>[];
      for (final coord in ring) {
        final targetTile = game.getTileAt(coord);
        if (targetTile == null || targetTile.isRemoved) continue;
        for (final effect
            in targetTile.children.whereType<ColorEffect>().toList()) {
          effect.removeFromParent();
        }
        final effect = ColorEffect(
          _glowColors[random.nextInt(_glowColors.length)],
          EffectController(duration: tintDuration, curve: Curves.easeOut),
          opacityFrom: 0.0,
          opacityTo: 0.75,
        );
        targetTile.add(effect);
        effects.add(effect);
      }
      await Future.wait(
        effects.map((effect) async {
          try {
            await effect.completed.timeout(
              Duration(milliseconds: (tintDuration * 1000).round() + 100),
            );
          } catch (_) {
            // Removed components and paused games must not hold the board lock forever.
          }
        }),
      );
      await Future.delayed(stepGap);
    }
    // Safety check: abort if bomb tile removed
    if (tile.isRemoved || !game.children.contains(tile)) {
      DebugLogger.vfx(
        'Bomb tile removed after color warning, aborting',
        vfxType: 'StickyRice',
      );
      return;
    }

    // ===== PHASE 3: SEQUENTIAL CLEAR (outward) =====
    DebugLogger.vfx(
      'PHASE 3: Sequential clear (outward)',
      vfxType: 'StickyRice',
    );

    // Use same ordered coords list (outward order)
    DebugLogger.vfx(
      'Clearing ${orderedCoords.length} tiles in distance rings',
      vfxType: 'StickyRice',
    );

    // Clear cells in distance rings so each wave moves outward together.
    for (final ring in rings.values) {
      if (tile.isRemoved || !game.children.contains(tile)) return;

      final effects = <ScaleEffect>[];
      for (final coord in ring) {
        final targetTile = game.getTileAt(coord);
        if (targetTile == null || targetTile.isRemoved) continue;
        final tileTypeId = targetTile.tileTypeId;
        final crumbSprite = tileTypeId < 101
            ? game.crumbParticleByTileId[tileTypeId]
            : null;
        final sparkleSprite = game.sparkleSpriteForVfx;
        if (crumbSprite != null || sparkleSprite != null) {
          spawnMatchBurst(
            game: game,
            center: game.coordToWorld(coord),
            tileSize: game.tileSize,
            crumbSprite: crumbSprite,
            sparkleSprite: sparkleSprite,
            isSpecialClear: true,
          );
        }
        if (_allowBloop(maxPerSec: 8)) {
          SfxManager.instance.playConfigured(SfxType.bloop);
        }
        final effect = ScaleEffect.to(
          Vector2.all(0.01),
          EffectController(duration: clearDuration, curve: Curves.easeIn),
        );
        targetTile.add(effect);
        effects.add(effect);
      }
      await Future.wait(
        effects.map((effect) async {
          try {
            await effect.completed.timeout(
              Duration(milliseconds: (clearDuration * 1000).round() + 100),
            );
          } catch (_) {
            // Removed components and paused games must not hold the board lock forever.
          }
        }),
      );
      await Future.delayed(stepGap);
    }
    // ===== PHASE 4: BOMB CLEAR (optional final pop) =====
    DebugLogger.vfx('PHASE 4: Bomb clear', vfxType: 'StickyRice');

    // Play celebration sound after clearing all tiles
    SfxManager.instance.play(SfxType.yayCheer);

    // Safety check
    if (tile.isRemoved || !game.children.contains(tile)) {
      DebugLogger.vfx(
        'Bomb tile removed before final clear, aborting',
        vfxType: 'StickyRice',
      );
      return;
    }

    // Get bomb position for burst
    final bombPosition = game.coordToWorld(bombCoord);
    final bombTileTypeId = tile.tileTypeId;

    // Get crumb sprite for bomb (if it's a regular tile < 101, though it shouldn't be)
    Sprite? crumbSprite;
    if (bombTileTypeId < 101) {
      crumbSprite = game.crumbParticleByTileId[bombTileTypeId];
    }

    // Get sparkle sprite
    final sparkleSprite = game.sparkleSpriteForVfx;

    // Spawn burst effect at bomb position
    if (crumbSprite != null || sparkleSprite != null) {
      spawnMatchBurst(
        game: game,
        center: bombPosition,
        tileSize: game.tileSize,
        crumbSprite: crumbSprite,
        sparkleSprite: sparkleSprite,
        isSpecialClear: true,
      );
    }

    // Visually clear bomb using SCALE ONLY (scale to 0.01 to make it disappear)
    final bombClearScaleEffect = ScaleEffect.to(
      Vector2.all(0.01),
      EffectController(duration: clearDuration, curve: Curves.easeIn),
    );

    tile.add(bombClearScaleEffect);

    // Wait for bomb clear scale effect
    try {
      await bombClearScaleEffect.completed.timeout(
        Duration(milliseconds: (clearDuration * 1000).round() + 100),
        onTimeout: () {
          DebugLogger.warn(
            'Bomb clear scale effect timeout',
            category: 'StickyRiceVfx',
          );
        },
      );
    } catch (e) {
      DebugLogger.error(
        'Bomb clear scale effect error: $e',
        category: 'StickyRiceVfx',
      );
    }

    // ===== PHASE 5: Complete =====
    DebugLogger.vfx('PHASE 5: VFX complete', vfxType: 'StickyRice');
    DebugLogger.vfx(
      'BoardController should now clear activationCells and call syncFromModel',
      vfxType: 'StickyRice',
    );

    // Return - BoardController will handle clearing activationCells and calling syncFromModel
    // VFX does NOT mutate gridModel - only visual effects
  }
}
