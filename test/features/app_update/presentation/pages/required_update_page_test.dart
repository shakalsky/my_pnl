import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';
import 'package:my_pnl/features/app_update/presentation/pages/required_update_page.dart';

import '../../../../helpers/helpers.dart';

const _current = AppVersion(major: 1, minor: 0, patch: 0, build: 5);

const _requirement = UpdateRequirement(
  minVersion: AppVersion(major: 1, minor: 2, patch: 0),
  storeUrl: 'https://example.com/app',
);

void main() {
  group('RequiredUpdatePage', () {
    late FakeAppUpdateRepository repository;

    setUp(
      () => repository = FakeAppUpdateRepository(
        currentVersion: _current,
        requirement: _requirement,
      ),
    );
    tearDown(() => repository.close);

    Future<List<Uri>> openPage(
      WidgetTester tester, {
      bool storeOpens = true,
    }) async {
      final opened = <Uri>[];

      await tester.pumpApp(
        RequiredUpdatePage(
          openStore: (url) async {
            opened.add(url);
            return storeOpens;
          },
        ),
        appUpdateRepository: repository,
      );
      await tester.pumpAndSettle();

      return opened;
    }

    testWidgets('names both versions', (tester) async {
      await openPage(tester);

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('You have 1.0.0'), findsOneWidget);
      expect(find.text('Needs 1.2.0'), findsOneWidget);
    });

    testWidgets('opens the store link', (tester) async {
      final opened = await openPage(tester);

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://example.com/app')]);
    });

    testWidgets('says so when nothing can open the link', (tester) async {
      await openPage(tester, storeOpens: false);

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(find.text('Could not open the store'), findsOneWidget);
    });

    testWidgets('explains without a button when no link is set', (
      tester,
    ) async {
      repository = FakeAppUpdateRepository(
        currentVersion: _current,
        requirement: const UpdateRequirement(
          minVersion: AppVersion(major: 1, minor: 2, patch: 0),
        ),
      );
      await openPage(tester);

      expect(find.text('Update now'), findsNothing);
      expect(
        find.text('Get the latest version from your app store.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the reason the release gives, when there is one', (
      tester,
    ) async {
      repository = FakeAppUpdateRepository(
        currentVersion: _current,
        requirement: const UpdateRequirement(
          minVersion: AppVersion(major: 1, minor: 2, patch: 0),
          message: 'Accounts moved to a new format.',
        ),
      );
      await openPage(tester);

      expect(find.text('Accounts moved to a new format.'), findsOneWidget);
      expect(find.textContaining('no longer supported'), findsNothing);
    });

    testWidgets('re-asks the backend when the user says they updated', (
      tester,
    ) async {
      await openPage(tester);

      await tester.tap(find.text('I have updated'));
      await tester.pumpAndSettle();

      expect(repository.checkCount, 1);
    });

    testWidgets('keeps the screen when the requirement still stands', (
      tester,
    ) async {
      await openPage(tester);

      await tester.tap(find.text('I have updated'));
      await tester.pumpAndSettle();

      // Not a way past the gate: the answer did not change, so neither does
      // what is on screen.
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Needs 1.2.0'), findsOneWidget);
    });

    testWidgets('follows the requirement being lifted', (tester) async {
      await openPage(tester);

      repository.require(null);
      await tester.pumpAndSettle();

      // The page itself stops claiming a version is needed; the router is what
      // moves the user off it, which app_test covers.
      expect(find.text('Needs 1.2.0'), findsNothing);
      expect(find.text('You have 1.0.0'), findsOneWidget);
    });

    testWidgets('cannot be dismissed with the back button', (tester) async {
      await openPage(tester);

      // `PopScope` is generic and the page builds it without a type argument,
      // which infers `dynamic` — the finder has to name the same type.
      final scope = tester.widget<PopScope<dynamic>>(
        find.byType(PopScope<dynamic>),
      );

      expect(scope.canPop, isFalse);
    });
  });
}
