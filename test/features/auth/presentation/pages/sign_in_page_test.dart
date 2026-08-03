import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/presentation/pages/sign_in_page.dart';

import '../../../../helpers/helpers.dart';

void main() {
  group('SignInPage', () {
    late FakeAuthRepository auth;

    setUp(() => auth = FakeAuthRepository());
    tearDown(() => auth.close());

    Future<void> pumpPage(WidgetTester tester) =>
        tester.pumpApp(const SignInPage(), authRepository: auth);

    Future<void> fillIn(
      WidgetTester tester, {
      required String email,
      required String password,
    }) async {
      await tester.enterText(find.byType(TextField).first, email);
      await tester.enterText(find.byType(TextField).last, password);
      await tester.pump();
    }

    testWidgets('keeps the button disabled until the form is valid', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await fillIn(tester, email: 'a@b.com', password: 'secret1');

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('signs in with the entered credentials', (tester) async {
      await pumpPage(tester);
      await fillIn(tester, email: 'a@b.com', password: 'secret1');

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(auth.lastEmail, 'a@b.com');
      expect(auth.lastPassword, 'secret1');
    });

    testWidgets('switches to sign-up', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Create an account'));
      await tester.pump();

      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
    });

    testWidgets('explains when a new account needs confirming', (
      tester,
    ) async {
      auth.signUpOutcome = SignUpOutcome.confirmationRequired;
      await pumpPage(tester);

      await tester.tap(find.text('Create an account'));
      await tester.pump();
      await fillIn(tester, email: 'a@b.com', password: 'secret1');

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Check your inbox'), findsOneWidget);
    });

    testWidgets('shows why a sign-in was rejected', (tester) async {
      auth.failure = const AuthFailure('Invalid login credentials');
      await pumpPage(tester);
      await fillIn(tester, email: 'a@b.com', password: 'wrong');

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid login credentials'), findsOneWidget);
      expect(find.byType(SignInPage), findsOneWidget, reason: 'stays put');
    });
  });
}
