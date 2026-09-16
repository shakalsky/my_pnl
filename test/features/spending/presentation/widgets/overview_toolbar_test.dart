import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:my_pnl/features/spending/presentation/widgets/overview_toolbar.dart';

import '../../../../helpers/helpers.dart';

/// A second book of the reader's own, named the way a reader names one.
const _sideBusiness = Ledger(
  id: 'ledger-side',
  name: 'Side business',
  kind: LedgerKind.personal,
  members: [
    LedgerMember(
      userId: FakeLedgerRepository.viewerId,
      role: LedgerRole.owner,
    ),
  ],
);

void main() {
  group('OverviewToolbar', () {
    late FakeLedgerRepository repository;

    tearDown(() => repository.close());

    /// Pumps the toolbar at a phone's width, which is the only width the row's
    /// crowding shows up at.
    ///
    /// [width] defaults to the narrow end of the phones in use — the case that
    /// has to hold, since anything wider only has more room for the name.
    Future<void> pumpToolbar(
      WidgetTester tester, {
      required List<Ledger> ledgers,
      required String activeId,
      double width = 360,
    }) async {
      repository = FakeLedgerRepository(initial: ledgers, activeId: activeId);
      tester.view
        ..physicalSize = Size(width, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
          child: const Scaffold(body: OverviewToolbar()),
        ),
        ledgerRepository: repository,
      );
      await tester.pumpAndSettle();
    }

    /// How much of [name] the row actually drew, against what it would take
    /// unconstrained. Anything short of it is an ellipsis eating the name.
    void expectNameFullyDrawn(WidgetTester tester, String name) {
      final painted = tester.renderObject<RenderParagraph>(
        find.text(name),
      );
      expect(
        painted.size.width,
        painted.getMaxIntrinsicWidth(double.infinity),
        reason: '"$name" was clipped by the row it sits in',
      );
    }

    testWidgets('names a personal book in full on a phone', (tester) async {
      await pumpToolbar(
        tester,
        ledgers: [
          FakeLedgerRepository.personal,
          FakeLedgerRepository.family,
        ],
        activeId: FakeLedgerRepository.personal.id,
        // The common phone rather than the narrow one: at 360 the five actions
        // leave 100 logical pixels, and "Personal" wants 113. The row cannot
        // hold both, and the actions are the half that cannot ellipsise.
        width: 390,
      );

      // A personal book is the one most readers are in most of the time, and it
      // used to be the one the row cut down to an ellipsis.
      expectNameFullyDrawn(tester, 'Personal');
    });

    testWidgets('names a family book in full on a phone', (tester) async {
      await pumpToolbar(
        tester,
        ledgers: [
          FakeLedgerRepository.personal,
          FakeLedgerRepository.family,
        ],
        activeId: FakeLedgerRepository.family.id,
      );

      expectNameFullyDrawn(tester, 'Home');
    });

    testWidgets('a long name gets the row down to the first action', (
      tester,
    ) async {
      await pumpToolbar(
        tester,
        ledgers: [
          FakeLedgerRepository.personal,
          _sideBusiness,
          FakeLedgerRepository.family,
        ],
        activeId: _sideBusiness.id,
      );

      // A name longer than the row can hold is still cut short — the actions
      // beside it are not negotiable. What it must not do is stop short of
      // them: sharing the free width with a spacer left half the row blank and
      // the name in an ellipsis beside it.
      final switcher = tester.getRect(find.byType(LedgerSwitcher));
      final firstAction = tester.getRect(find.byType(IconButton).first);
      expect(switcher.right, moreOrLessEquals(firstAction.left));
    });
  });
}
