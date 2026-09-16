import 'package:flutter/material.dart';

/// The icons offered on the category form itself, keyed by the string stored
/// in the database.
///
/// Eleven, not more: the form lays these out six to a row and gives the
/// twelfth cell to the button that opens [categoryMoreIcons]. These are the
/// ones most categories end up wanting, so the sheet behind the button is a
/// detour rather than the usual route.
const categoryQuickIcons = <String, IconData>{
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
};

/// The forty further icons behind the form's "more icons" button.
///
/// Grouped loosely by what they are for — eating, getting about, the home,
/// bills, leisure, health, money, everything else — because a grid of forty
/// is only scannable if neighbours belong together.
const categoryMoreIcons = <String, IconData>{
  'coffee': Icons.local_cafe_outlined,
  'fastFood': Icons.fastfood_outlined,
  'car': Icons.directions_car_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'taxi': Icons.local_taxi_outlined,
  'train': Icons.train_outlined,
  'bike': Icons.pedal_bike_outlined,
  'parcel': Icons.local_shipping_outlined,
  'rent': Icons.apartment_outlined,
  'furniture': Icons.chair_outlined,
  'repairs': Icons.handyman_outlined,
  'cleaning': Icons.cleaning_services_outlined,
  'garden': Icons.local_florist_outlined,
  'electricity': Icons.bolt_outlined,
  'water': Icons.water_drop_outlined,
  'heating': Icons.local_fire_department_outlined,
  'internet': Icons.router_outlined,
  'phone': Icons.smartphone_outlined,
  'subscriptions': Icons.subscriptions_outlined,
  'music': Icons.music_note_outlined,
  'cinema': Icons.movie_outlined,
  'books': Icons.menu_book_outlined,
  'sports': Icons.sports_soccer_outlined,
  'fitness': Icons.fitness_center_outlined,
  'hotel': Icons.hotel_outlined,
  'beach': Icons.beach_access_outlined,
  'medicine': Icons.medication_outlined,
  'dentist': Icons.medical_services_outlined,
  'childcare': Icons.child_friendly_outlined,
  'beauty': Icons.spa_outlined,
  'haircut': Icons.content_cut_outlined,
  'clothes': Icons.checkroom_outlined,
  'gifts': Icons.card_giftcard_outlined,
  'charity': Icons.volunteer_activism_outlined,
  'bank': Icons.account_balance_outlined,
  'savings': Icons.savings_outlined,
  'card': Icons.credit_card_outlined,
  'insurance': Icons.shield_outlined,
  'taxes': Icons.receipt_long_outlined,
  'work': Icons.work_outline,
};

/// Every icon a category can be given.
///
/// The lookup side of the two sets above: which grid an icon was chosen from
/// says nothing about a saved category, so resolving a stored key has to see
/// all of them.
const categoryIcons = <String, IconData>{
  ...categoryQuickIcons,
  ...categoryMoreIcons,
};

/// Falls back rather than throwing: a row synced from a newer build of the
/// app may carry an icon key this one has never heard of.
IconData iconForKey(String key) =>
    categoryIcons[key] ?? Icons.category_outlined;

/// The colors offered as presets on the category form, as packed ARGB.
///
/// Kept at a similar muted lightness so no swatch shouts over the others in a
/// list, and ordered so neighbouring entries sit in different hue families.
///
/// Fifteen, not sixteen: the form lays these out eight to a row and gives the
/// sixteenth cell to the button that opens the full palette. A category is not
/// limited to this list — anything picked there is stored just the same.
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
];
