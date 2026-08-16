import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/currency_list_sheet.dart';
import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/repositories/language_store.dart';
import 'package:my_pnl/features/settings/domain/repositories/theme_mode_store.dart';
import 'package:my_pnl/features/settings/domain/usecases/read_language.dart';
import 'package:my_pnl/features/settings/domain/usecases/read_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/usecases/save_language.dart';
import 'package:my_pnl/features/settings/domain/usecases/save_theme_mode.dart';
import 'package:my_pnl/features/settings/presentation/bloc/settings/settings_bloc.dart';
import 'package:my_pnl/features/spending/presentation/widgets/overrun_settings_sheet.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// How the app looks and what language it is read in.
///
/// A page rather than a sheet, unlike the other preferences: these two change
/// the whole app rather than one screen's figures, and a modal that redraws
/// everything behind it — including itself — is a strange thing to watch.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SettingsBloc(
            readThemeMode: ReadThemeMode(context.read<ThemeModeStore>()),
            saveThemeMode: SaveThemeMode(context.read<ThemeModeStore>()),
            readLanguage: ReadLanguage(context.read<LanguageStore>()),
            saveLanguage: SaveLanguage(context.read<LanguageStore>()),
          )..add(const SettingsRequested()),
      child: const SettingsView(),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SettingsBloc>();
    final state = context.watch<SettingsBloc>().state;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SectionHeader(
              title: t.settings.appearance,
              subtitle: t.settings.appearanceSubtitle,
            ),
            RadioGroup<AppThemeMode>(
              groupValue: state.themeMode,
              onChanged: (chosen) {
                if (chosen != null) {
                  bloc.add(SettingsThemeModeSelected(chosen));
                }
              },
              child: Column(
                children: [
                  for (final mode in AppThemeMode.values)
                    RadioListTile<AppThemeMode>(
                      value: mode,
                      title: Text(_themeLabel(mode)),
                      secondary: Icon(_themeIcon(mode)),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            _SectionHeader(
              title: t.settings.language,
              subtitle: t.settings.languageSubtitle,
            ),
            // Nullable on purpose: following the device is one of the options
            // in this group, not the absence of a selection, so null has to be
            // a value the group can hold.
            RadioGroup<String?>(
              groupValue: state.languageTag,
              onChanged: (tag) => bloc.add(SettingsLanguageSelected(tag)),
              child: Column(
                children: [
                  RadioListTile<String?>(
                    value: null,
                    title: Text(t.settings.languageSystem),
                    // Which language following the device currently lands on.
                    // The option itself cannot say — that is the whole of the
                    // difference between it and picking that language outright.
                    subtitle: Text(_languageName(LocaleSettings.currentLocale)),
                    secondary: const Icon(Icons.smartphone_outlined),
                  ),
                  for (final locale in AppLocale.values)
                    RadioListTile<String?>(
                      value: locale.languageTag,
                      // In its own language, in every language: a reader
                      // looking for their own is looking for the word they
                      // would write it with, not for its name in a language
                      // they cannot read.
                      title: Text(_languageName(locale)),
                      secondary: const Icon(Icons.translate),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            // Under the two that change the app itself, because these change
            // what the figures are read against rather than how they are drawn
            // — and unlike the theme, they belong to the book, not the device.
            _SectionHeader(
              title: t.settings.spending,
              subtitle: t.settings.spendingSubtitle,
            ),
            // Modals rather than more of this page: both are lists that are
            // edited — a currency added, a threshold moved — and they open from
            // the category modals as well, where a page would mean leaving the
            // sheet the reader is already in.
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(t.spending.currencies),
              subtitle: Text(t.settings.currenciesSubtitle),
              onTap: () => CurrencyListSheet.show(context),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(t.spending.unusualMonths),
              subtitle: Text(t.settings.unusualMonthsSubtitle),
              onTap: () => OverrunSettingsSheet.show(context),
            ),
          ],
        ),
      ),
    );
  }

  static String _themeLabel(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => t.settings.themeSystem,
    AppThemeMode.light => t.settings.themeLight,
    AppThemeMode.dark => t.settings.themeDark,
  };

  static IconData _themeIcon(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => Icons.brightness_auto_outlined,
    AppThemeMode.light => Icons.light_mode_outlined,
    AppThemeMode.dark => Icons.dark_mode_outlined,
  };

  /// What a language calls itself.
  ///
  /// Not translated, and not translatable: these are the same words in every
  /// locale, which is exactly what makes the list usable to someone who has the
  /// app open in a language they do not read.
  static String _languageName(AppLocale locale) => switch (locale) {
    AppLocale.en => 'English',
    AppLocale.ru => 'Русский',
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
