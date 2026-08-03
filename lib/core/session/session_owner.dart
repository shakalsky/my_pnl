import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';

/// Supplies the `owner_id` written on every row.
///
/// Sync rules bucket on this value and the Postgres RLS policies check it, so
/// it has to be the signed-in user's id for anything to sync.
abstract interface class SessionOwner {
  String get id;
}

/// Takes the owner id from the current session.
///
/// Reads through [AuthRepository] rather than the auth provider directly, so
/// the data layer has one notion of who is signed in and tests can drive it.
class AuthSessionOwner implements SessionOwner {
  const AuthSessionOwner(this._authRepository);

  /// Used when nobody is signed in. Rows written under it never upload — no
  /// sync rule matches, and no RLS policy admits them — so they stay local.
  static const signedOutId = 'local-user';

  final AuthRepository _authRepository;

  @override
  String get id => _authRepository.currentUser?.id ?? signedOutId;
}
