import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';

/// Raised when a sign-in or sign-up is rejected.
///
/// Carries a message fit to show the user; the data layer is responsible for
/// turning provider-specific errors into one of these.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => 'AuthFailure: $message';
}

/// What happened after a sign-up.
enum SignUpOutcome {
  /// A session exists and the app can carry on.
  signedIn,

  /// The account was created but the provider wants the address confirmed
  /// first. Nothing is signed in yet, so the UI has to say so — otherwise a
  /// successful sign-up looks identical to a silent failure.
  confirmationRequired,
}

abstract interface class AuthRepository {
  /// The current user, or null when signed out.
  ///
  /// Synchronous because routing has to decide redirects during a build, with
  /// no chance to await.
  AuthUser? get currentUser;

  /// Emits on every sign-in and sign-out, starting with the current value.
  Stream<AuthUser?> watchUser();

  Future<void> signIn({required String email, required String password});

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
