import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/sync/domain/entities/sync_state.dart';
import 'package:my_pnl/features/sync/domain/usecases/watch_sync_state.dart';

part 'sync_indicator_event.dart';

/// Drives the sync dot.
///
/// The domain [SyncState] is the bloc's state as-is: there is nothing to add
/// to it, and wrapping it would only mean copying four fields around.
class SyncIndicatorBloc extends Bloc<SyncIndicatorEvent, SyncState> {
  SyncIndicatorBloc({required WatchSyncState watchSyncState})
    : _watchSyncState = watchSyncState,
      super(const SyncState()) {
    on<SyncIndicatorSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
  }

  final WatchSyncState _watchSyncState;

  Future<void> _onSubscriptionRequested(
    SyncIndicatorSubscriptionRequested event,
    Emitter<SyncState> emit,
  ) {
    return emit.forEach<SyncState>(
      _watchSyncState(),
      onData: (state) => state,
      onError: (error, stackTrace) {
        log('Watching sync state failed', error: error, stackTrace: stackTrace);
        // A status stream that itself broke is a failure worth showing red.
        return SyncState(
          health: SyncHealth.failed,
          lastSyncedAt: state.lastSyncedAt,
          lastFailedAt: DateTime.now().toUtc(),
          lastError: error.toString(),
        );
      },
    );
  }
}
