import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Auth for builds with no backend configured.
///
/// Reports a fixed local user so the app opens straight onto its data instead
/// of a sign-in screen it could never satisfy. Rows written under this id stay
/// on the device — no sync rule matches it.
class LocalOnlyAuthRepository implements AuthRepository {
  const LocalOnlyAuthRepository();

  static const localUser = AuthUser(id: 'local-user');

  @override
  AuthUser? get currentUser => localUser;

  @override
  Stream<AuthUser?> watchUser() => Stream.value(localUser);

  @override
  Future<void> signIn({required String email, required String password}) async {
    throw AuthFailure(t.auth.noBackend);
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    throw AuthFailure(t.auth.noBackend);
  }

  /// A no-op. There is no session to end, and clearing the local database
  /// would throw away the only copy of the data.
  @override
  Future<void> signOut() async {}
}
