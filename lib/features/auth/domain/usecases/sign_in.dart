import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Signs an existing user in.
class SignIn {
  const SignIn(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String email, required String password}) {
    final trimmed = email.trim();
    if (!isValidEmail(trimmed)) {
      throw AuthFailure(t.auth.invalidEmail);
    }
    if (password.isEmpty) {
      throw AuthFailure(t.auth.enterPassword);
    }

    return _repository.signIn(email: trimmed, password: password);
  }
}

/// Deliberately loose. Anything stricter rejects addresses that are legal, and
/// the only real check is whether the backend accepts it.
bool isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

/// Supabase's own default. Enforced here so the form can say so before a round
/// trip, not to replace the server's rule.
const minPasswordLength = 6;
