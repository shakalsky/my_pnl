import 'package:flutter/material.dart';

/// The icons a category can be given, keyed by the string stored in the
/// database.
///
/// Keys are stable identifiers, not code points: storing code points would
/// defeat Flutter's icon tree-shaking and break if the icon font changed.
const categoryIcons = <String, IconData>{
  'groceries': Icons.local_grocery_store_outlined,
  'home': Icons.home_outlined,
  'transport': Icons.directions_bus_outlined,
  'dining': Icons.restaurant_outlined,
  'health': Icons.favorite_outline,
  'fun': Icons.sports_esports_outlined,
  'travel': Icons.flight_takeoff_outlined,
  'education': Icons.school_outlined,
  'pets': Icons.pets_outlined,
  'utilities': Icons.build_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'gifts': Icons.card_giftcard_outlined,
  'subscriptions': Icons.subscriptions_outlined,
  'fitness': Icons.fitness_center_outlined,
  'beauty': Icons.spa_outlined,
  'work': Icons.work_outline,
};

/// Falls back rather than throwing: a row synced from a newer build of the
/// app may carry an icon key this one has never heard of.
IconData iconForKey(String key) =>
    categoryIcons[key] ?? Icons.category_outlined;

/// The colors a category can be given, as packed ARGB.
///
/// Kept at a similar muted lightness so no swatch shouts over the others in a
/// list, and ordered so neighbouring entries sit in different hue families.
const categoryColors = <int>[
  0xFF3B7A57,
  0xFF4A5D8A,
  0xFF8A5A44,
  0xFF9C4F6C,
  0xFF3F7F8C,
  0xFF7A5EA8,
  0xFFB08A2E,
  0xFF56606B,
  0xFF6E8B3D,
  0xFF2F6F9E,
  0xFF9A4B45,
  0xFFA05298,
  0xFF2E7D6E,
  0xFF5B4E9C,
  0xFF8C6E5A,
  0xFF6B7F8A,
];
