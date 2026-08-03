part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

final class AuthState extends Equatable {
  const AuthState._({required this.status, this.user});

  /// Before the first value arrives. Routing waits rather than bouncing the
  /// user to sign-in and back on a cold start with a stored session.
  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.authenticated(AuthUser user)
    : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated()
    : this._(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final AuthUser? user;

  @override
  List<Object?> get props => [status, user];
}
