import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/usecases/read_overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/usecases/save_overrun_settings.dart';

part 'overrun_settings_event.dart';
part 'overrun_settings_state.dart';

/// Drives the modal that sets when a month counts as unusual.
///
/// Edits a draft and writes it on submit rather than saving every drag: a
/// slider produces a value per frame, and each one would be a write to the
/// platform store and a redraw of the grid behind the sheet.
class OverrunSettingsBloc
    extends Bloc<OverrunSettingsEvent, OverrunSettingsState> {
  OverrunSettingsBloc({
    required ReadOverrunSettings readOverrunSettings,
    required SaveOverrunSettings saveOverrunSettings,
  }) : _read = readOverrunSettings,
       _save = saveOverrunSettings,
       super(const OverrunSettingsState()) {
    on<OverrunSettingsRequested>(_onRequested);
    on<OverrunWarningsToggled>(
      (event, emit) => emit(
        state.copyWith(settings: state.settings.copyWith(enabled: event.on)),
      ),
    );
    on<OverrunThresholdChanged>(
      (event, emit) => emit(
        state.copyWith(
          // Normalized by `withLevel`, so dragging one level past another
          // pushes the looser ones along instead of leaving a set where the
          // middle colour can never appear.
          settings: state.settings.withLevel(event.level, event.percent),
        ),
      ),
    );
    on<OverrunSettingsRestored>(
      (event, emit) =>
          emit(state.copyWith(settings: OverrunSettings.defaults)),
    );
    on<OverrunSettingsSubmitted>(_onSubmitted);
  }

  final ReadOverrunSettings _read;
  final SaveOverrunSettings _save;

  /// Seeds the form with what is in force.
  ///
  /// A failed read leaves the defaults showing: the store answers with them
  /// anyway, and a form with no values in it could not be used at all.
  Future<void> _onRequested(
    OverrunSettingsRequested event,
    Emitter<OverrunSettingsState> emit,
  ) async {
    try {
      emit(state.copyWith(settings: await _read()));
    } on Object catch (e, s) {
      log('Reading the overrun settings failed', error: e, stackTrace: s);
    }
  }

  Future<void> _onSubmitted(
    OverrunSettingsSubmitted event,
    Emitter<OverrunSettingsState> emit,
  ) async {
    if (state.isSubmitting) return;

    emit(state.copyWith(status: OverrunSettingsStatus.submitting));

    try {
      await _save(state.settings);
      emit(state.copyWith(status: OverrunSettingsStatus.success));
    } on Object catch (e, s) {
      log('Saving the overrun settings failed', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: OverrunSettingsStatus.failure,
          errorMessage: 'Could not save your warning settings',
        ),
      );
      emit(state.copyWith(status: OverrunSettingsStatus.editing));
    }
  }
}
