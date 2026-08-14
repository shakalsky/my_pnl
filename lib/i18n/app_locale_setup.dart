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
