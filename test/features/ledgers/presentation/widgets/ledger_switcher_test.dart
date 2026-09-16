import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/create_family_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/create_personal_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/delete_personal_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/join_family_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/leave_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/rotate_invite_code.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/select_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/watch_ledgers.dart';
import 'package:my_pnl/features/ledgers/presentation/bloc/ledger/ledger_bloc.dart';
import 'package:my_pnl/features/ledgers/presentation/widgets/ledger_switcher.dart';

import '../../../../helpers/helpers.dart';

/// An extra book of the reader's own, for the cases that need more than one.
Ledger _personal(String name) => Ledger(
  id: 'ledger-$name',
  name: name,
  kind: LedgerKind.personal,
  members: const [
    LedgerMember(
      userId: FakeLedgerRepository.viewerId,
      role: LedgerRole.owner,
    ),
  ],
);

void main() {
  group('LedgerSwitcher', () {
    late FakeLedgerRepository repository;

    setUp(() {
      repository = FakeLedgerRepository();
    });

    tearDown(() => repository.close());

    /// Pumps the switcher with the bloc the overview page gives it.
    Future<void> pumpSwitcher(WidgetTester tester) async {
      await tester.pumpApp(
        BlocProvider(
          create: (_) => LedgerBloc(
            watchLedgers: WatchLedgers(repository),
            activeId: repository.activeId,
            selectLedger: SelectLedger(repository),
            createPersonalLedger: CreatePersonalLedger(repository),
            createFamilyLedger: CreateFamilyLedger(repository),
            joinFamilyLedger: JoinFamilyLedger(repository),
            leaveLedger: LeaveLedger(repository),
            deletePersonalLedger: DeletePersonalLedger(repository),
            rotateInviteCode: RotateInviteCode(repository),
          )..add(const LedgerSubscriptionRequested()),
          child: const Scaffold(body: LedgerSwitcher()),
        ),
        ledgerRepository: repository,
        // Signed in, because the sheet describes the members relative to
        // whoever is reading: "shared with kate" rather than a list of two
        // people one of whom is you.
        authRepository: FakeAuthRepository(
          initialUser: const AuthUser(
            id: FakeLedgerRepository.viewerId,
            email: 'me@example.com',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openSheet(WidgetTester tester) async {
      await pumpSwitcher(tester);
      await tester.tap(find.byType(LedgerSwitcher));
      await tester.pumpAndSettle();
    }

    /// Walks the form the way a reader does: open it, pick the kind, name it.
    Future<void> createAccount(
      WidgetTester tester, {
      required String kind,
      required String name,
    }) async {
      await tester.tap(find.widgetWithText(FilledButton, 'New account'));
      await tester.pumpAndSettle();

      // The segment's own label: `ButtonSegment` is a data class rather than a
      // widget, so there is nothing of that type in the tree to find.
      await tester.tap(find.text(kind));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
    }

    testWidgets('names the open book when it is the only one', (tester) async {
      await pumpSwitcher(tester);

      // Named rather than left as a bare icon: a reader who has not made a
      // second book yet still has to be able to see which one they are in.
      expect(find.widgetWithText(TextButton, 'Personal'), findsOneWidget);
    });

    testWidgets('names the open book once there is a second', (tester) async {
      repository = FakeLedgerRepository(
        initial: [
          FakeLedgerRepository.personal,
          FakeLedgerRepository.family,
        ],
      );
      await pumpSwitcher(tester);

      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('marks a shared book with a different icon', (tester) async {
      repository = FakeLedgerRepository(
        initial: [
          FakeLedgerRepository.personal,
          FakeLedgerRepository.family,
        ],
        activeId: FakeLedgerRepository.family.id,
      );
      await pumpSwitcher(tester);

      // Whose totals these are should be readable at a glance, not only after
      // opening the sheet.
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Home'), findsOneWidget);
    });

    group('the sheet it opens', () {
      testWidgets('lists the books, marking the open one', (tester) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            FakeLedgerRepository.family,
          ],
        );
        await openSheet(tester);

        expect(find.widgetWithText(ListTile, 'Personal'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Home'), findsOneWidget);
        expect(find.text('Shared with kate'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('says a family account nobody has joined is not shared', (
        tester,
      ) async {
        await openSheet(tester);
        await createAccount(tester, kind: 'Family', name: 'Home');

        // A promise the code has not kept yet: there is an invite out, and
        // nobody on the other end of it.
        expect(find.text('Nobody has joined yet'), findsOneWidget);
      });

      testWidgets('creating a family account opens it', (tester) async {
        await openSheet(tester);
        await createAccount(tester, kind: 'Family', name: 'Home');

        // Making one and staying in the personal book would leave the reader
        // looking for what they had just made.
        expect(repository.activeId, isNot(FakeLedgerRepository.personal.id));
        expect(find.text('Invite code'), findsOneWidget);
        expect(find.text('NEWCDE'), findsOneWidget);
      });

      testWidgets('switching opens the book that was tapped', (tester) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            FakeLedgerRepository.family,
          ],
        );
        await openSheet(tester);

        await tester.tap(find.widgetWithText(ListTile, 'Home'));
        await tester.pumpAndSettle();

        expect(repository.activeId, FakeLedgerRepository.family.id);
      });

      testWidgets('joining with a code opens what it names', (tester) async {
        repository = FakeLedgerRepository()
          ..joinable = FakeLedgerRepository.family;
        await openSheet(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Join with a code'),
          'abc123',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Join'));
        await tester.pumpAndSettle();

        expect(repository.activeId, FakeLedgerRepository.family.id);
      });

      testWidgets('says so when the code matches nothing', (tester) async {
        await openSheet(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Join with a code'),
          'nope12',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Join'));
        await tester.pumpAndSettle();

        expect(find.text('No family account with that code'), findsOneWidget);
        expect(repository.activeId, FakeLedgerRepository.personal.id);
      });

      testWidgets("names an account of the reader's own", (tester) async {
        await openSheet(tester);
        await createAccount(tester, kind: 'Just me', name: 'Side business');

        // The name is the one thing the reader chooses about a book, and it is
        // what they pick out of the switcher afterwards.
        expect(find.widgetWithText(ListTile, 'Side business'), findsOneWidget);
        expect(repository.activeId, isNot(FakeLedgerRepository.personal.id));
      });

      testWidgets('creates nothing without a name', (tester) async {
        await openSheet(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'New account'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
        await tester.pumpAndSettle();

        // Still on the form, with nothing made: a book named nothing would be an
        // empty row in the switcher.
        expect(find.text('New account'), findsWidgets);
        expect(repository.activeId, FakeLedgerRepository.personal.id);
      });

      testWidgets('says why a second family account is refused', (
        tester,
      ) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            FakeLedgerRepository.family,
          ],
        );
        await openSheet(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'New account'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Family'));
        await tester.pumpAndSettle();

        // Selectable and then explained, rather than disabled and silent: being
        // told is how the reader finds out there is a limit at all.
        expect(
          find.textContaining('already in a family account'),
          findsOneWidget,
        );
        final create = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Create'),
        );
        expect(create.onPressed, isNull);
      });

      testWidgets('says why a fourth account of your own is refused', (
        tester,
      ) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            _personal('two'),
            _personal('three'),
          ],
        );
        await openSheet(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'New account'));
        await tester.pumpAndSettle();

        // Three of their own, so the form opens on the kind there is room for;
        // picking their own is what surfaces the reason.
        await tester.tap(find.text('Just me'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('already have ${LedgerLimits.personal}'),
          findsOneWidget,
        );
        final create = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Create'),
        );
        expect(create.onPressed, isNull);
      });

      testWidgets('will not join while already in a family account', (
        tester,
      ) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            FakeLedgerRepository.family,
          ],
        );
        await openSheet(tester);

        // Disabled with the reason under it, not hidden: a reader holding a code
        // their partner just sent needs telling why it will not go in.
        expect(
          find.text('Leave the family account you are in to join another.'),
          findsOneWidget,
        );
        final join = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Join'),
        );
        expect(join.onPressed, isNull);
      });

      testWidgets('stops offering a new account at both limits', (
        tester,
      ) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            _personal('two'),
            _personal('three'),
            FakeLedgerRepository.family,
          ],
        );
        await openSheet(tester);

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'New account'),
        );
        expect(button.onPressed, isNull);
        expect(
          find.textContaining('Remove one to make another'),
          findsOneWidget,
        );
      });

      testWidgets("removes an extra account of the reader's own", (
        tester,
      ) async {
        repository = FakeLedgerRepository(
          initial: [FakeLedgerRepository.personal, _personal('Side business')],
        );
        await openSheet(tester);

        await tester.tap(find.byTooltip('Remove Side business'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ListTile, 'Side business'), findsNothing);
      });

      testWidgets('asks before removing, and says what it does not do', (
        tester,
      ) async {
        repository = FakeLedgerRepository(
          initial: [FakeLedgerRepository.personal, _personal('Side business')],
        );
        await openSheet(tester);

        await tester.tap(find.byTooltip('Remove Side business'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Nothing is erased'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ListTile, 'Side business'), findsOneWidget);
      });

      testWidgets('offers no remove on the first account', (tester) async {
        repository = FakeLedgerRepository(
          initial: [FakeLedgerRepository.personal, _personal('Side business')],
        );
        await openSheet(tester);

        // Every fallback in the app lands on it, so there is nothing to offer.
        expect(find.byTooltip('Remove Personal'), findsNothing);
      });

      testWidgets('offers no remove on a family account', (tester) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            FakeLedgerRepository.family,
          ],
          activeId: FakeLedgerRepository.family.id,
        );
        await openSheet(tester);

        // Removing it would take the book from the partner too. Leaving is the
        // action that only affects the leaver.
        expect(find.byTooltip('Remove Home'), findsNothing);
        expect(find.text('Leave this account'), findsOneWidget);
      });

      testWidgets('lists who is in a shared book', (tester) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            FakeLedgerRepository.family,
          ],
          activeId: FakeLedgerRepository.family.id,
        );
        await openSheet(tester);

        expect(find.text('Members'), findsOneWidget);
        expect(find.text('kate'), findsOneWidget);
        expect(find.text('Created this account'), findsOneWidget);
      });

      testWidgets('leaving asks first, and says what stays behind', (
        tester,
      ) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            FakeLedgerRepository.family,
          ],
          activeId: FakeLedgerRepository.family.id,
        );
        await openSheet(tester);

        await tester.tap(find.text('Leave this account'));
        await tester.pumpAndSettle();

        // Someone leaving expects their spending to go with them, and it cannot
        // — a partner is still reading totals it is part of.
        expect(
          find.textContaining('stay in this account'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(repository.activeId, FakeLedgerRepository.family.id);
      });

      testWidgets('leaving moves the reader back to their own book', (
        tester,
      ) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            FakeLedgerRepository.family,
          ],
          activeId: FakeLedgerRepository.family.id,
        );
        await openSheet(tester);

        await tester.tap(find.text('Leave this account'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
        await tester.pumpAndSettle();

        expect(repository.activeId, FakeLedgerRepository.personal.id);
      });

      testWidgets('a new code warns that the old one stops working', (
        tester,
      ) async {
        repository = FakeLedgerRepository(
          initial: [
            FakeLedgerRepository.personal,
            FakeLedgerRepository.family,
          ],
          activeId: FakeLedgerRepository.family.id,
        );
        await openSheet(tester);

        await tester.tap(find.byTooltip('New code'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'New code'));
        await tester.pumpAndSettle();

        // The code shows in a SelectableText; the join field's placeholder is
        // also a code-shaped string, so the assertion says which it means.
        expect(
          tester
              .widgetList<SelectableText>(find.byType(SelectableText))
              .map((text) => text.data),
          ['ROTATE'],
        );
      });
    });
  });
}
