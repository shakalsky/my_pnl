import 'dart:developer';

import 'package:my_pnl/features/ledgers/domain/repositories/active_ledger_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the open ledger in the platform's own key-value store.
///
/// Not in the synced database on purpose: which book you are looking at is a
/// property of the device you are looking at it on, and a choice that travelled
/// would switch a partner's phone out from under them.
class PreferencesActiveLedgerStore implements ActiveLedgerStore {
  PreferencesActiveLedgerStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Prefixed, because these preferences share a namespace with every other
  /// plugin's.
  static const key = 'my_pnl.active_ledger_id';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() async {
    try {
      final stored = await _preferences.getString(key);
      return (stored == null || stored.isEmpty) ? null : stored;
    } on Object catch (e, s) {
      // A store that will not open is the same as an untouched one: the app
      // opens the reader's personal ledger, which always exists.
      log('Reading the active ledger failed', error: e, stackTrace: s);
      return null;
    }
  }

  @override
  Future<void> write(String ledgerId) async {
    try {
      await _preferences.setString(key, ledgerId);
    } on Object catch (e, s) {
      // Swallowed: the switch still applies for this run, it just will not
      // survive a restart, and that is not worth a message over.
      log('Remembering the active ledger failed', error: e, stackTrace: s);
    }
  }
}
