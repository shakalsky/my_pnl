import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';
import 'package:my_pnl/features/app_update/domain/usecases/check_for_update.dart';
import 'package:my_pnl/features/app_update/domain/usecases/watch_app_update_status.dart';

part 'app_update_event.dart';
part 'app_update_state.dart';

/// Drives the required-update screen.
class AppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState> {
  AppUpdateBloc({
    required WatchAppUpdateStatus watchStatus,
    required CheckForUpdate checkForUpdate,
    required AppUpdateStatus initialStatus,
  }) : _watchStatus = watchStatus,
       _checkForUpdate = checkForUpdate,
       super(AppUpdateState(status: initialStatus)) {
    on<AppUpdateSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    // Droppable: the button is a request to re-ask, and a second tap while one
    // is in flight would only ask the same question twice.
    on<AppUpdateCheckRequested>(
      _onCheckRequested,
      transformer: droppable(),
    );
  }

  final WatchAppUpdateStatus _watchStatus;
  final CheckForUpdate _checkForUpdate;

  Future<void> _onSubscriptionRequested(
    AppUpdateSubscriptionRequested event,
    Emitter<AppUpdateState> emit,
  ) async {
    await emit.forEach<AppUpdateStatus>(
      _watchStatus(),
      onData: (status) => state.copyWith(status: status),
      onError: (error, stackTrace) {
        log('Watching the update status failed',
            error: error, stackTrace: stackTrace);
        return state;
      },
    );
  }

  Future<void> _onCheckRequested(
    AppUpdateCheckRequested event,
    Emitter<AppUpdateState> emit,
  ) async {
    emit(state.copyWith(isChecking: true));
    // Never throws — a failed check leaves the last answer in place, and the
    // screen stays put rather than claiming the app is up to date.
    await _checkForUpdate();
    emit(state.copyWith(isChecking: false));
  }
}
