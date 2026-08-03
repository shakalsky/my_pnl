import 'dart:async';

import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';

/// In-memory stand-in for [AuthRepository].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();

  /// Set to have sign-in and sign-up fail.
  AuthFailure? failure;

  /// Credentials the last successful call was made with.
  String? lastEmail;
  String? lastPassword;
  bool signUpCalled = false;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> watchUser() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (failure case final error?) throw error;
    lastEmail = email;
    lastPassword = password;
    _emit(AuthUser(id: 'user-1', email: email));
  }

  /// What [signUp] reports. Default matches a project with email confirmation
  /// switched off.
  SignUpOutcome signUpOutcome = SignUpOutcome.signedIn;

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    if (failure case final error?) throw error;
    signUpCalled = true;
    lastEmail = email;
    lastPassword = password;

    if (signUpOutcome == SignUpOutcome.signedIn) {
      _emit(AuthUser(id: 'user-1', email: email));
    }
    return signUpOutcome;
  }

  @override
  Future<void> signOut() async => _emit(null);

  void _emit(AuthUser? user) {
    _user = user;
    _controller.add(user);
  }

  Future<void> close() => _controller.close();
}
