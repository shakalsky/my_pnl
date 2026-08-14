import 'dart:developer';

import 'package:my_pnl/features/settings/domain/repositories/language_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the chosen language in the platform's own key-value store.
///
/// No change stream here, unlike the theme beside it. slang already has one:
/// the app shell listens to `LocaleSettings.getLocaleStream()`, and setting a
/// locale is what puts a change through it. This only has to outlive the run,
/// so that a language chosen once is still in force at the next launch.
class PreferencesLanguageStore implements LanguageStore {
  PreferencesLanguageStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Prefixed, because these preferences share a namespace with every other
  /// plugin's.
  static const key = 'my_pnl.language_tag';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() async {
    try {
      return await _preferences.getString(key);
    } on Object catch (e, s) {
      // A store that will not open is the same as an empty one: the app follows
      // the device, which is what it does before anyone chooses.
      log('Reading the language failed', error: e, stackTrace: s);
      return null;
    }
  }

  @override
  Future<void> write(String? languageTag) async {
    try {
      if (languageTag == null) {
        // Removed rather than written empty: "no preference" is the absence of
        // one, and the read above has to tell it from a tag.
        await _preferences.remove(key);
      } else {
        await _preferences.setString(key, languageTag);
      }
    } on Object catch (e, s) {
      // Swallowed: the choice still applies for this run, it just will not
      // survive a restart, and that is not worth a message over.
      log('Remembering the language failed', error: e, stackTrace: s);
    }
  }
}
