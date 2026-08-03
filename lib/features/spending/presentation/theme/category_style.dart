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
};

/// Falls back rather than throwing: a row synced from a newer build of the
/// app may carry an icon key this one has never heard of.
IconData iconForKey(String key) =>
    categoryIcons[key] ?? Icons.category_outlined;

/// The colors a category can be given, as packed ARGB.
const categoryColors = <int>[
  0xFF3B7A57,
  0xFF4A5D8A,
  0xFF8A5A44,
  0xFF9C4F6C,
  0xFF3F7F8C,
  0xFF7A5EA8,
  0xFFB08A2E,
  0xFF56606B,
];
