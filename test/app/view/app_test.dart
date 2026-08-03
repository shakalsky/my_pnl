import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/app/app.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';
import 'package:my_pnl/features/app_update/presentation/pages/required_update_page.dart';
import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';
import 'package:my_pnl/features/auth/presentation/pages/sign_in_page.dart';
import 'package:my_pnl/features/spending/presentation/pages/spending_overview_page.dart';

import '../../helpers/helpers.dart';

void main() {
  group('App', () {
    late AppDatabase database;
    late FakeCategoryRepository spending;
    late FakeCurrencyRepository currencies;
    late FakeDebtRepository debts;
    late FakeGoalRepository goals;
    late FakeAppUpdateRepository updates;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      spending = FakeCategoryRepository();
      currencies = FakeCurrencyRepository();
      debts = FakeDebtRepository();
      goals = FakeGoalRepository();
      updates = FakeAppUpdateRepository();
    });

    tearDown(() async {
      await updates.close();
      await goals.close();
      await debts.close();
      await currencies.close();
      await spending.close();
      await database.close();
    });

    Future<void> pumpAppWith(
      WidgetTester tester,
      FakeAuthRepository auth,
    ) async {
      await tester.pumpWidget(
        App(
          database: database,
          appUpdateRepository: updates,
          authRepository: auth,
          categoryRepository: spending,
          currencyRepository: currencies,
          displayCurrencyStore: FakeDisplayCurrencyStore(),
          debtRepository: debts,
          goalRepository: goals,
          transactionRepository: spending,
          syncRepository: FakeSyncRepository(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sends a signed-out user to sign-in', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.close);

      await pumpAppWith(tester, auth);

      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(SpendingOverviewPage), findsNothing);
    });

    testWidgets('opens the overview for a restored session', (tester) async {
      final auth = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
      );
      addTearDown(auth.close);

      await pumpAppWith(tester, auth);

      expect(find.byType(SpendingOverviewPage), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);
    });

    testWidgets('redirects to the overview once signed in', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.close);

      await pumpAppWith(tester, auth);
      expect(find.byType(SignInPage), findsOneWidget);

      await auth.signIn(email: 'a@b.com', password: 'secret1');
      await tester.pumpAndSettle();

      expect(find.byType(SpendingOverviewPage), findsOneWidget);
    });

    group('the update gate', () {
      /// Older than the running build the fake reports.
      const needsNewer = UpdateRequirement(
        minVersion: AppVersion(major: 9, minor: 0, patch: 0),
      );

      testWidgets('holds a signed-in user on the update screen', (
        tester,
      ) async {
        updates = FakeAppUpdateRepository(requirement: needsNewer);
        final auth = FakeAuthRepository(
          initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
        );
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);

        expect(find.byType(RequiredUpdatePage), findsOneWidget);
        expect(find.byType(SpendingOverviewPage), findsNothing);
      });

      testWidgets('holds a signed-out user there as well', (tester) async {
        // Checked before auth on purpose: a build the backend has stopped
        // supporting has no business signing anyone in.
        updates = FakeAppUpdateRepository(requirement: needsNewer);
        final auth = FakeAuthRepository();
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);

        expect(find.byType(RequiredUpdatePage), findsOneWidget);
        expect(find.byType(SignInPage), findsNothing);
      });

      testWidgets('lets the user in when a check clears the requirement', (
        tester,
      ) async {
        updates = FakeAppUpdateRepository(requirement: needsNewer);
        final auth = FakeAuthRepository(
          initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
        );
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);
        expect(find.byType(RequiredUpdatePage), findsOneWidget);

        updates.require(null);
        await tester.pumpAndSettle();

        expect(find.byType(SpendingOverviewPage), findsOneWidget);
        expect(find.byType(RequiredUpdatePage), findsNothing);
      });

      testWidgets('sends a blocked signed-out user on to sign-in', (
        tester,
      ) async {
        updates = FakeAppUpdateRepository(requirement: needsNewer);
        final auth = FakeAuthRepository();
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);

        updates.require(null);
        await tester.pumpAndSettle();

        // The auth gate takes over once the update gate lets go.
        expect(find.byType(SignInPage), findsOneWidget);
      });

      testWidgets('stays out of the way when nothing is required', (
        tester,
      ) async {
        final auth = FakeAuthRepository(
          initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
        );
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);

        expect(find.byType(SpendingOverviewPage), findsOneWidget);
      });
    });

    testWidgets('returns to sign-in on sign-out', (tester) async {
      final auth = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
      );
      addTearDown(auth.close);

      await pumpAppWith(tester, auth);
      expect(find.byType(SpendingOverviewPage), findsOneWidget);

      await auth.signOut();
      await tester.pumpAndSettle();

      expect(find.byType(SignInPage), findsOneWidget);
    });
  });
}
