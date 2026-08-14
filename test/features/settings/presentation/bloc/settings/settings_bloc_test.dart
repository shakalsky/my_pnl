import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/usecases/read_language.dart';
import 'package:my_pnl/features/settings/domain/usecases/read_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/usecases/save_language.dart';
import 'package:my_pnl/features/settings/domain/usecases/save_theme_mode.dart';
import 'package:my_pnl/features/settings/presentation/bloc/settings/settings_bloc.dart';
import 'package:my_pnl/i18n/strings.g.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  // Following the device asks the platform what language it is set to, and
  // slang reads that off the widgets binding. A bloc test has none by default.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsBloc', () {
    late FakeThemeModeStore themes;
    late FakeLanguageStore languages;

    SettingsBloc build({
      AppThemeMode theme = AppThemeMode.system,
      String? language,
    }) {
      themes = FakeThemeModeStore(initial: theme);
      languages = FakeLanguageStore(remembered: language);
      return SettingsBloc(
        readThemeMode: ReadThemeMode(themes),
        saveThemeMode: SaveThemeMode(themes),
        readLanguage: ReadLanguage(languages),
        saveLanguage: SaveLanguage(languages),
      );
    }

    tearDown(() async {
      await themes.close();
      // The locale is one value for the whole process and the language events
      // below really do move it. Put back, or the next test reads in whatever
      // was chosen here.
      await LocaleSettings.setLocale(AppLocale.en);
    });

    blocTest<SettingsBloc, SettingsState>(
      'opens on the settings in force',
      build: () => build(theme: AppThemeMode.dark, language: 'ru'),
      act: (bloc) => bloc.add(const SettingsRequested()),
      expect: () => const <SettingsState>[
        SettingsState(
          themeMode: AppThemeMode.dark,
          languageTag: 'ru',
          status: SettingsStatus.ready,
        ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      'opens following the device when neither has been chosen',
      build: build,
      act: (bloc) => bloc.add(const SettingsRequested()),
      expect: () => const <SettingsState>[
        SettingsState(status: SettingsStatus.ready),
      ],
      verify: (bloc) => expect(bloc.state.followsDeviceLanguage, isTrue),
    );

    blocTest<SettingsBloc, SettingsState>(
      'shows the defaults when the settings cannot be read',
      build: () {
        final bloc = build();
        themes.readError = Exception('nope');
        return bloc;
      },
      act: (bloc) => bloc.add(const SettingsRequested()),
      expect: () => const <SettingsState>[
        SettingsState(status: SettingsStatus.ready),
      ],
      verify: (bloc) => expect(bloc.state.themeMode, AppThemeMode.system),
    );

    blocTest<SettingsBloc, SettingsState>(
      'applies an appearance and remembers it',
      build: build,
      act: (bloc) => bloc
        ..add(const SettingsRequested())
        ..add(const SettingsThemeModeSelected(AppThemeMode.dark)),
      skip: 1,
      expect: () => const <SettingsState>[
        SettingsState(
          themeMode: AppThemeMode.dark,
          status: SettingsStatus.ready,
        ),
      ],
      verify: (_) => expect(themes.writes, [AppThemeMode.dark]),
    );

    blocTest<SettingsBloc, SettingsState>(
      'writes nothing for an appearance already in force',
      build: () => build(theme: AppThemeMode.dark),
      act: (bloc) => bloc
        ..add(const SettingsRequested())
        ..add(const SettingsThemeModeSelected(AppThemeMode.dark)),
      skip: 1,
      expect: () => const <SettingsState>[],
      verify: (_) => expect(themes.writes, isEmpty),
    );

    blocTest<SettingsBloc, SettingsState>(
      'puts a chosen language into force and remembers it',
      build: build,
      act: (bloc) => bloc
        ..add(const SettingsRequested())
        ..add(const SettingsLanguageSelected('ru')),
      skip: 1,
      expect: () => const <SettingsState>[
        SettingsState(languageTag: 'ru', status: SettingsStatus.ready),
      ],
      verify: (_) {
        expect(languages.writes, ['ru']);
        // The point of the whole exercise: the app is now in Russian, not
        // merely recorded as wanting to be.
        expect(LocaleSettings.currentLocale, AppLocale.ru);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'hands the language back to the device',
      build: () => build(language: 'ru'),
      act: (bloc) => bloc
        ..add(const SettingsRequested())
        ..add(const SettingsLanguageSelected(null)),
      skip: 1,
      expect: () => const <SettingsState>[
        SettingsState(status: SettingsStatus.ready),
      ],
      // Written as an absence rather than as a tag, which is what a later read
      // has to see to know nobody has chosen.
      verify: (_) => expect(languages.writes, [null]),
    );

    blocTest<SettingsBloc, SettingsState>(
      'ignores a language tag this build ships no strings for',
      build: build,
      act: (bloc) => bloc
        ..add(const SettingsRequested())
        ..add(const SettingsLanguageSelected('xx')),
      skip: 1,
      verify: (_) => expect(LocaleSettings.currentLocale, isNot(isNull)),
    );
  });
}
