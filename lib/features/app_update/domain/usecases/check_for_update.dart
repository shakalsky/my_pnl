import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';

/// Asks the backend what the minimum build is now.
class CheckForUpdate {
  const CheckForUpdate(this._repository);

  final AppUpdateRepository _repository;

  Future<void> call() => _repository.checkForUpdate();
}
