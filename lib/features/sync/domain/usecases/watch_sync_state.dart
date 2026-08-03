import 'package:my_pnl/features/sync/domain/entities/sync_state.dart';
import 'package:my_pnl/features/sync/domain/repositories/sync_repository.dart';

/// Streams where sync stands.
class WatchSyncState {
  const WatchSyncState(this._repository);

  final SyncRepository _repository;

  Stream<SyncState> call() => _repository.watchSyncState();
}
