import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/domain/usecases/sign_in.dart';
import 'package:my_pnl/i18n/strings.g.dart';

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
      throw AuthFailure(t.auth.invalidEmail);
    }
    if (password.length < minPasswordLength) {
      throw AuthFailure(t.auth.passwordTooShort(count: minPasswordLength));
    }

    return _repository.signUp(email: trimmed, password: password);
  }
}
