import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/usecases/read_language.dart';
import 'package:my_pnl/features/settings/domain/usecases/read_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/usecases/save_language.dart';
import 'package:my_pnl/features/settings/domain/usecases/save_theme_mode.dart';
import 'package:my_pnl/i18n/app_locale_setup.dart';

part 'settings_event.dart';
part 'settings_state.dart';

/// Drives the settings page.
///
/// Applies as it goes rather than collecting a draft and saving it: both of
/// these settings are things you judge by looking at them, and a theme that
/// only arrives once you press Save is one you cannot try. That is also why
/// nothing here reports a failure — the store swallows one, the choice still
/// holds for this run, and the reader can see for themselves that it took.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required ReadThemeMode readThemeMode,
    required SaveThemeMode saveThemeMode,
    required ReadLanguage readLanguage,
    required SaveLanguage saveLanguage,
  }) : _readThemeMode = readThemeMode,
       _saveThemeMode = saveThemeMode,
       _readLanguage = readLanguage,
       _saveLanguage = saveLanguage,
       super(const SettingsState()) {
    // One handler over the whole event type, sequentially, rather than three
    // handlers side by side. Seeding the page reads two stores and so takes a
    // moment, and a choice made in that moment has to land after the read
    // rather than under it — three handlers would let the read finish last and
    // put back what the reader had just changed.
    on<SettingsEvent>(_onEvent, transformer: sequential());
  }

  final ReadThemeMode _readThemeMode;
  final SaveThemeMode _saveThemeMode;
  final ReadLanguage _readLanguage;
  final SaveLanguage _saveLanguage;

  Future<void> _onEvent(SettingsEvent event, Emitter<SettingsState> emit) =>
      switch (event) {
        SettingsRequested() => _onRequested(event, emit),
        SettingsThemeModeSelected() => _onThemeModeSelected(event, emit),
        SettingsLanguageSelected() => _onLanguageSelected(event, emit),
      };

  /// Seeds the page with what is in force.
  ///
  /// Read rather than watched: this page is the only thing that changes either
  /// setting, so there is nothing to hear from that it did not do itself.
  Future<void> _onRequested(
    SettingsRequested event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          themeMode: await _readThemeMode(),
          languageTag: await _readLanguage(),
          clearLanguageTag: true,
          status: SettingsStatus.ready,
        ),
      );
    } on Object catch (e, s) {
      // Neither store throws, so this is for a fault below them. The defaults
      // already in [state] are what the app is showing anyway.
      log('Reading the settings failed', error: e, stackTrace: s);
      emit(state.copyWith(status: SettingsStatus.ready));
    }
  }

  /// Applies an appearance, then remembers it.
  ///
  /// In that order: the store's write is what tells the app shell to redraw, so
  /// the page has already moved its own tick by the time the theme changes
  /// underneath it.
  Future<void> _onThemeModeSelected(
    SettingsThemeModeSelected event,
    Emitter<SettingsState> emit,
  ) async {
    if (event.mode == state.themeMode) return;

    emit(state.copyWith(themeMode: event.mode));
    await _saveThemeMode(event.mode);
  }

  /// Applies a language, then remembers it.
  ///
  /// The application is slang's business rather than the store's: setting a
  /// locale is what puts the change through the stream the app shell listens
  /// on, and the store only has to make it survive a restart. A null tag hands
  /// the choice back to the device — and leaves slang following it again, so a
  /// language changed in the system settings reaches the app on its own.
  Future<void> _onLanguageSelected(
    SettingsLanguageSelected event,
    Emitter<SettingsState> emit,
  ) async {
    if (event.languageTag == state.languageTag &&
        state.status == SettingsStatus.ready) {
      return;
    }

    emit(state.copyWith(languageTag: event.languageTag, clearLanguageTag: true));
    await applyLanguageChoice(event.languageTag);
    await _saveLanguage(event.languageTag);
  }
}
