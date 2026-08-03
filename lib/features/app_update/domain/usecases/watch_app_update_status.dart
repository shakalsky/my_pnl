import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';

/// Streams where the running build stands, starting with what is known now.
class WatchAppUpdateStatus {
  const WatchAppUpdateStatus(this._repository);

  final AppUpdateRepository _repository;

  Stream<AppUpdateStatus> call() async* {
    // The current answer first: a screen built after the check already ran
    // would otherwise sit empty until the next change.
    yield _repository.status;
    yield* _repository.watchStatus();
  }
}
