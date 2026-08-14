import 'dart:developer';

import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/i18n/strings.g.dart';
// Supabase exports an AuthUser of its own; the domain entity wins here.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// Auth backed by Supabase.
///
/// Supabase's own types stop here: everything above sees [AuthUser] and
/// [AuthFailure].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AuthUser? get currentUser => _toEntity(_client.auth.currentUser);

  @override
  Stream<AuthUser?> watchUser() {
    // onAuthStateChange replays the current session to new listeners, so the
    // router sees a value immediately rather than after the first transition.
    return _client.auth.onAuthStateChange.map(
      (state) => _toEntity(state.session?.user),
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    return _guard(
      () => _client.auth.signInWithPassword(email: email, password: password),
    );
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      // With email confirmation on — Supabase's default — the account is
      // created but no session comes back. Reporting that distinctly is what
      // keeps a successful sign-up from looking like nothing happened.
      return response.session == null
          ? SignUpOutcome.confirmationRequired
          : SignUpOutcome.signedIn;
    });
  }

  @override
  Future<void> signOut() => _guard(_client.auth.signOut);

  AuthUser? _toEntity(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  /// Converts provider errors into [AuthFailure].
  ///
  /// AuthException carries a message meant for the user ("Invalid login
  /// credentials"); anything else is a network or server problem, and its
  /// message is not fit to show.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on Object catch (e) {
      // Logged because this branch swallows the real cause — a bad URL, no
      // network, a DNS failure — behind a generic message.
      log('Auth call failed', error: e);
      throw AuthFailure(t.auth.unreachable);
    }
  }
}
