import 'dart:async';
import 'dart:developer';

import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/repositories/theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the chosen appearance in the platform's own key-value store.
///
/// Not in the synced database on purpose: the choice is per device, and a
/// preference that travelled between them would darken a phone because a
/// laptop was.
class PreferencesThemeModeStore implements ThemeModeStore {
  PreferencesThemeModeStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Prefixed, because these preferences share a namespace with every other
  /// plugin's.
  static const key = 'my_pnl.theme_mode';

  final SharedPreferencesAsync _preferences;

  /// Broadcasts a change to whatever is already on screen.
  ///
  /// The platform store has no change notification of its own, so the one write
  /// path is what tells the readers. Broadcast because the app shell and the
  /// settings page listen at the same time.
  final _changes = StreamController<AppThemeMode>.broadcast();

  @override
  Stream<AppThemeMode> watch() async* {
    yield await read();
    yield* _changes.stream;
  }

  @override
  Future<AppThemeMode> read() async {
    try {
      // Stored by name rather than by index: an enum reordered in a later build
      // would otherwise read back as a different appearance on a device that
      // had already chosen one.
      return AppThemeMode.tryParse(await _preferences.getString(key)) ??
          AppThemeMode.system;
    } on Object catch (e, s) {
      // A store that will not open is the same as an untouched one: the app
      // follows the device, which is what it does before anyone chooses.
      log('Reading the theme mode failed', error: e, stackTrace: s);
      return AppThemeMode.system;
    }
  }

  @override
  Future<void> write(AppThemeMode mode) async {
    try {
      await _preferences.setString(key, mode.name);
    } on Object catch (e, s) {
      // Swallowed: the choice still applies for this run, it just will not
      // survive a restart, and that is not worth a message over.
      log('Remembering the theme mode failed', error: e, stackTrace: s);
    }

    // Announced either way. What is on screen has to agree with what the user
    // just chose even when the store refused to keep it.
    if (!_changes.isClosed) _changes.add(mode);
  }

  /// Stops broadcasting. For tests; the app holds one of these for its life.
  Future<void> close() => _changes.close();
}
