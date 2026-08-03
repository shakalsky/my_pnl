import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AuthSessionOwner', () {
    test('uses the signed-in user id', () {
      final repository = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
      );
      addTearDown(repository.close);

      expect(AuthSessionOwner(repository).id, 'user-1');
    });

    test('falls back to the local id when signed out', () {
      final repository = FakeAuthRepository();
      addTearDown(repository.close);

      expect(
        AuthSessionOwner(repository).id,
        AuthSessionOwner.signedOutId,
      );
    });

    test('follows a sign-in without being rebuilt', () async {
      final repository = FakeAuthRepository();
      addTearDown(repository.close);
      final owner = AuthSessionOwner(repository);

      expect(owner.id, AuthSessionOwner.signedOutId);
      await repository.signIn(email: 'a@b.com', password: 'secret1');
      expect(owner.id, 'user-1');
    });
  });
}
