import 'package:equatable/equatable.dart';

/// The signed-in user, as the app thinks about it.
class AuthUser extends Equatable {
  const AuthUser({required this.id, this.email});

  /// Matches `owner_id` on every row and the `sub` claim of the JWT that
  /// PowerSync's sync rules bucket on.
  final String id;

  /// Null for the local-only user, which has no account behind it.
  final String? email;

  /// Whether this user exists on the backend, as opposed to the placeholder
  /// used when the app runs without one.
  bool get isRemote => email != null;

  @override
  List<Object?> get props => [id, email];
}
