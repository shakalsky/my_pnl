import 'dart:async';

import 'package:my_pnl/features/sync/domain/entities/sync_state.dart';
import 'package:my_pnl/features/sync/domain/repositories/sync_repository.dart';

/// Lets a test drive the sync dot through every state without a server.
class FakeSyncRepository implements SyncRepository {
  FakeSyncRepository({SyncState initial = const SyncState()})
    : _current = initial;

  SyncState _current;
  final _controller = StreamController<SyncState>.broadcast();

  @override
  Stream<SyncState> watchSyncState() async* {
    yield _current;
    yield* _controller.stream;
  }

  /// Pushes a new state to whoever is watching.
  void emit(SyncState state) {
    _current = state;
    _controller.add(state);
  }

  Future<void> close() => _controller.close();
}
