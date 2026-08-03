import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/domain/usecases/sign_in.dart';

/// Creates an account.
class SignUp {
  const SignUp(this._repository);

  final AuthRepository _repository;

  Future<SignUpOutcome> call({
    required String email,
    required String password,
  }) {
    final trimmed = email.trim();
    if (!isValidEmail(trimmed)) {
      throw const AuthFailure('Enter a valid email address');
    }
    if (password.length < minPasswordLength) {
      throw const AuthFailure(
        'Password must be at least $minPasswordLength characters',
      );
    }

    return _repository.signUp(email: trimmed, password: password);
  }
}
