import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';

/// Ends the session.
///
/// PowerSync reacts to this on its own: the sync connection is dropped and the
/// local copy cleared, so the next user does not inherit these rows.
class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}
