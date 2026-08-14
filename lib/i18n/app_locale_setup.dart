import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Picks up the language the device is set to, and points everything that
/// formats text at it.
///
/// Two libraries have to agree here, not one. `slang` owns the app's own
/// wording through [t]; `intl` owns everything the app does not write itself —
/// month names, weekdays, times — which [DateFormat] reads from
/// [Intl.defaultLocale] rather than from anything passed at the call site. A
/// locale applied to only one of the two shows Russian text under an English
/// month heading.
///
/// Returns the locale that was actually taken up, which is the closest match
/// among [AppLocale.values] rather than whatever the device asked for.
///
/// `useDeviceLocale` also leaves slang listening, so a language changed in the
/// system settings while the app is open reaches [t] on its own. Only the
/// [Intl] half is left to follow, which [applyToIntl] does.
Future<AppLocale> applyDeviceLocale() async {
  final locale = await LocaleSettings.useDeviceLocale();
  await applyToIntl(locale);
  return locale;
}

/// Puts a chosen language into force, or hands the choice back to the device.
///
/// [languageTag] is what the settings store kept — `en`, `ru` — or null for
/// "follow the device". A tag this build ships no strings for is treated as
/// null rather than as a request: it can only have come from a store written by
/// a build that had one more language than this one, and falling back to the
/// device beats falling back to English for a reader who set neither.
///
/// Only the [Intl] half is applied here for the same reason [applyDeviceLocale]
/// does it — slang's own change reaches the widgets through the stream the app
/// shell listens on, and this returns as soon as both halves agree.
Future<AppLocale> applyLanguageChoice(String? languageTag) async {
  final chosen = languageTag == null ? null : _shippedLocaleFor(languageTag);

  // `useDeviceLocale` also leaves slang listening for a language changed in the
  // system settings, which is the other half of what "follow the device" means.
  if (chosen == null) {
    final device = await applyDeviceLocale();
    return device;
  }

  // Awaited: the locales other than the base one are loaded on demand — slang
  // defers them — so the strings for a language just chosen are not in memory
  // until this returns, and `listenToDeviceLocale: false` is what stops the
  // system language overriding the choice the moment it changes.
  await LocaleSettings.setLocale(chosen);
  await applyToIntl(chosen);
  return chosen;
}

/// The locale this build ships for [languageTag], or null for one it does not.
///
/// Matched exactly rather than through `AppLocaleUtils.parse`, which answers
/// every tag with its closest match and so could never say no.
AppLocale? _shippedLocaleFor(String languageTag) {
  for (final locale in AppLocale.values) {
    if (locale.languageTag == languageTag) return locale;
  }
  return null;
}

/// Points [Intl] at [locale], loading its date symbols first.
///
/// The symbols are loaded before [Intl.defaultLocale] moves: a [DateFormat]
/// built for a locale nothing has loaded yet throws, and the widgets that build
/// one do so on the very next frame.
Future<void> applyToIntl(AppLocale locale) async {
  final tag = locale.languageTag;
  await initializeDateFormatting(tag);
  Intl.defaultLocale = tag;
}
