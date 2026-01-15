import 'package:flutter/material.dart';
import 'package:mergeworks/models/game_item.dart';

/// Renders a deterministic, unique glyph for a GameItem without using assets.
/// The glyph is derived from the item's id so the same item always looks the same
/// and different items are visually distinct, even if they share the same emoji.
class UniqueItemGlyph extends StatelessWidget {
  final GameItem item;
  final double size;
  final bool muted;

  const UniqueItemGlyph({super.key, required this.item, required this.size, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Derive glyph by TIER so all items of the same tier share the same silhouette.
    final hash = _stableHash('tier_${item.isWildcard ? 'wild' : item.tier.toString()}');

    final icon = _iconPool[hash % _iconPool.length];

    // Vibrant, high-contrast palette from theme. Color is decorative only and
    // does NOT indicate uniqueness (icon silhouette does).
    final colorChoices = <Color>[
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.inversePrimary,
      cs.error, // occasional warm accent for pop
      cs.surfaceTint,
    ];
    final picked = colorChoices[(item.tier - 1).abs() % colorChoices.length];
    final iconColor = muted ? cs.onSurfaceVariant : picked;

    // Special-case wildcard items for recognizability
    final effectiveIcon = item.isWildcard ? Icons.all_inclusive : icon;

    return Icon(effectiveIcon, size: size, color: iconColor);
  }
}

// Deterministic string hash (djb2 variant). Consistent across web/native and runs.
int _stableHash(String input) {
  int hash = 5381;
  for (final codeUnit in input.codeUnits) {
    hash = ((hash << 5) + hash) + codeUnit; // hash * 33 + c
    hash &= 0x7fffffff; // keep positive 31-bit
  }
  return hash;
}

// Curated pool of minimalist Material icons for distinct silhouettes.
const List<IconData> _iconPool = [
  Icons.auto_awesome,
  Icons.category,
  Icons.casino,
  Icons.ac_unit,
  Icons.anchor,
  Icons.api,
  Icons.architecture,
  Icons.aspect_ratio,
  Icons.bakery_dining,
  Icons.bolt,
  Icons.bubble_chart,
  Icons.cabin,
  Icons.catching_pokemon,
  Icons.chair_alt,
  Icons.change_history,
  Icons.circle,
  Icons.cloud,
  Icons.code,
  Icons.compass_calibration,
  Icons.construction,
  Icons.cottage,
  Icons.cruelty_free,
  Icons.cyclone,
  Icons.dangerous,
  Icons.data_exploration,
  Icons.deblur,
  Icons.diamond,
  Icons.biotech,
  Icons.egg_alt,
  Icons.energy_savings_leaf,
  Icons.explore,
  Icons.extension,
  Icons.factory,
  Icons.fastfood,
  Icons.fingerprint,
  Icons.fireplace,
  Icons.flag,
  Icons.flare,
  Icons.fluorescent,
  Icons.forest,
  Icons.emoji_nature,
  Icons.emoji_objects,
  Icons.generating_tokens,
  Icons.gesture,
  Icons.grass,
  Icons.hail,
  Icons.handyman,
  Icons.hive,
  Icons.icecream,
  Icons.interests,
  Icons.kayaking,
  Icons.key,
  Icons.kitesurfing,
  Icons.landscape,
  Icons.layers,
  Icons.leak_add,
  Icons.light_mode,
  Icons.local_florist,
  Icons.local_fire_department,
  Icons.local_laundry_service,
  Icons.lock_clock,
  Icons.luggage,
  Icons.lunch_dining,
  Icons.memory,
  Icons.military_tech,
  Icons.mood,
  Icons.mosque,
  Icons.nature_people,
  Icons.nightlight,
  Icons.noise_control_off,
  Icons.nordic_walking,
  Icons.oil_barrel,
  Icons.opacity,
  Icons.palette,
  Icons.pets,
  Icons.pie_chart,
  Icons.push_pin,
  Icons.polymer,
  Icons.psychology,
  Icons.published_with_changes,
  Icons.radar,
  Icons.redeem,
  Icons.recycling,
  Icons.rocket_launch,
  Icons.route,
  Icons.sailing,
  Icons.satellite_alt,
  Icons.science,
  Icons.shield_moon,
  Icons.snowshoeing,
  Icons.spa,
  Icons.crop_square,
  Icons.star,
  Icons.stars,
  Icons.storm,
  Icons.sunny_snowing,
  Icons.surfing,
  Icons.terrain,
  Icons.toys,
  Icons.tsunami,
  Icons.water_drop,
  Icons.wind_power,
  Icons.yard,
];
