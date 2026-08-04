import 'dart:async';
import 'dart:developer';

import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the warning thresholds in the platform's own key-value store.
///
/// Not in the synced database on purpose: the thresholds are per device, and a
/// preference that travelled between them would change what a second device
/// warns about without anyone touching it.
class PreferencesOverrunSettingsStore implements OverrunSettingsStore {
  PreferencesOverrunSettingsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Prefixed, because these preferences share a namespace with every other
  /// plugin's.
  static const enabledKey = 'my_pnl.overrun_enabled';
  static const mildKey = 'my_pnl.overrun_mild_percent';
  static const highKey = 'my_pnl.overrun_high_percent';
  static const severeKey = 'my_pnl.overrun_severe_percent';

  final SharedPreferencesAsync _preferences;

  /// Broadcasts a save to whatever is already on screen.
  ///
  /// The platform store has no change notification of its own, so the one write
  /// path is what tells the readers. Broadcast because the grid and the form
  /// listen at the same time.
  final _changes = StreamController<OverrunSettings>.broadcast();

  @override
  Stream<OverrunSettings> watch() async* {
    yield await read();
    yield* _changes.stream;
  }

  @override
  Future<OverrunSettings> read() async {
    try {
      // Each key read separately rather than as one JSON blob: a build that
      // adds a level should find the others still set, not fall back wholesale
      // because the shape changed.
      final settings = OverrunSettings(
        enabled:
            await _preferences.getBool(enabledKey) ??
            OverrunSettings.defaults.enabled,
        mildPercent:
            await _preferences.getInt(mildKey) ??
            OverrunSettings.defaults.mildPercent,
        highPercent:
            await _preferences.getInt(highKey) ??
            OverrunSettings.defaults.highPercent,
        severePercent:
            await _preferences.getInt(severeKey) ??
            OverrunSettings.defaults.severePercent,
      );

      // Normalized on the way out: these values came from a store an older or
      // newer build may have written, and a threshold of zero would flag every
      // category in the grid.
      return settings.normalized;
    } on Object catch (e, s) {
      // A store that will not open is the same as an untouched one.
      log('Reading the overrun settings failed', error: e, stackTrace: s);
      return OverrunSettings.defaults;
    }
  }

  @override
  Future<void> write(OverrunSettings settings) async {
    final normalized = settings.normalized;

    try {
      await _preferences.setBool(enabledKey, normalized.enabled);
      await _preferences.setInt(mildKey, normalized.mildPercent);
      await _preferences.setInt(highKey, normalized.highPercent);
      await _preferences.setInt(severeKey, normalized.severePercent);
    } on Object catch (e, s) {
      // Swallowed: the choice still applies for this run, it just will not
      // survive a restart, and that is not worth a message over.
      log('Remembering the overrun settings failed', error: e, stackTrace: s);
    }

    // Announced either way. What is on screen has to agree with what the user
    // just chose even when the store refused to keep it.
    if (!_changes.isClosed) _changes.add(normalized);
  }

  /// Stops broadcasting. For tests; the app holds one of these for its life.
  Future<void> close() => _changes.close();
}
