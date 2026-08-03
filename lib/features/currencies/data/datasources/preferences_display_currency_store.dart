import 'dart:developer';

import 'package:my_pnl/features/currencies/domain/repositories/display_currency_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the choice in the platform's own key-value store.
///
/// Not in the synced database on purpose: the choice is per device, and a
/// preference that travelled between them would change what a second device
/// shows without anyone touching it.
class PreferencesDisplayCurrencyStore implements DisplayCurrencyStore {
  PreferencesDisplayCurrencyStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Prefixed, because these preferences share a namespace with every other
  /// plugin's.
  static const key = 'my_pnl.display_currency_id';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() async {
    try {
      return await _preferences.getString(key);
    } on Object catch (e, s) {
      // A store that will not open is the same as an empty one: totals read in
      // the base currency, which is what they are recorded in anyway.
      log('Reading the display currency failed', error: e, stackTrace: s);
      return null;
    }
  }

  @override
  Future<void> write(String? currencyId) async {
    try {
      if (currencyId == null) {
        await _preferences.remove(key);
      } else {
        await _preferences.setString(key, currencyId);
      }
    } on Object catch (e, s) {
      // Swallowed: the choice still applies for this run, it just will not
      // survive a restart, and that is not worth a message over.
      log('Remembering the display currency failed', error: e, stackTrace: s);
    }
  }
}
