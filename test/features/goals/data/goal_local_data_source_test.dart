import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/goals/data/datasources/goal_local_data_source.dart';

void main() {
  group('GoalLocalDataSource', () {
    late AppDatabase db;
    late GoalLocalDataSource dataSource;

    const owner = 'user-1';
    const ledger = 'ledger-1';

    /// Another book, which nothing done to [ledger] may reach.
    const otherLedger = 'ledger-2';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = GoalLocalDataSource(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('reports no goal until one is set', () async {
      expect(await dataSource.watchGoal(ledger).first, isNull);
    });

    test('stores a goal with a client-generated id', () async {
      final saved = await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 500000,
      );

      expect(saved.id, hasLength(36));
      expect(saved.targetAmountScaled, 500000);
      expect(
        (await dataSource.watchGoal(ledger).first)?.targetAmountScaled,
        500000,
      );
    });

    test('saving again edits the goal rather than adding a second', () async {
      final first = await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 500000,
      );
      final second = await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 750000,
      );

      expect(second.id, first.id, reason: 'the same row');
      expect(second.targetAmountScaled, 750000);

      final rows = await db.select(db.goals).get();
      expect(rows.where((row) => row.deletedAt == null), hasLength(1));
    });

    test('clearing tombstones the row and frees the slot', () async {
      await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 500000,
      );

      await dataSource.clearGoal(ledger);

      expect(await dataSource.watchGoal(ledger).first, isNull);

      // Still on disk so the removal syncs...
      final row = await db.select(db.goals).getSingle();
      expect(row.deletedAt, isNotNull);

      // ...and a new goal can be set afterwards.
      final again = await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 100000,
      );
      expect(again.targetAmountScaled, 100000);
      expect(await dataSource.watchGoal(ledger).first, again);
    });

    test('keeps what was already saved before the app', () async {
      final saved = await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 500000,
        startingAmountScaled: 120000,
      );

      expect(saved.startingAmountScaled, 120000);
      expect(
        (await dataSource.watchGoal(ledger).first)?.startingAmountScaled,
        120000,
      );
    });

    test('reads a goal set without one as nothing put aside', () async {
      final saved = await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 500000,
      );

      expect(saved.startingAmountScaled, 0);
      // Null on the row, which is what a build predating the column syncs.
      expect((await db.select(db.goals).getSingle()).startingAmountScaled, 0);
    });

    test('saving again can take the starting amount back to nothing', () async {
      await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 500000,
        startingAmountScaled: 120000,
      );

      final cleared = await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 500000,
      );

      expect(cleared.startingAmountScaled, 0);
    });

    test("does not see another ledger's goal", () async {
      await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: otherLedger,
        targetAmountScaled: 500000,
      );

      expect(await dataSource.watchGoal(ledger).first, isNull);
    });

    test("clearing leaves another ledger's goal alone", () async {
      await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 500000,
      );
      await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: otherLedger,
        targetAmountScaled: 900000,
      );

      await dataSource.clearGoal(ledger);

      expect(await dataSource.watchGoal(ledger).first, isNull);
      expect(
        (await dataSource.watchGoal(otherLedger).first)?.targetAmountScaled,
        900000,
      );
    });

    test('a partner may raise the goal the other one set', () async {
      // The goal belongs to the book rather than to whoever set it, so in a
      // family account either of them can move it.
      final set = await dataSource.saveGoal(
        ownerId: owner,
        ledgerId: ledger,
        targetAmountScaled: 500000,
      );

      final raised = await dataSource.saveGoal(
        ownerId: 'partner-1',
        ledgerId: ledger,
        targetAmountScaled: 800000,
      );

      expect(raised.id, set.id, reason: 'the same row, not a second goal');
      expect(
        (await dataSource.watchGoal(ledger).first)?.targetAmountScaled,
        800000,
      );
    });
  });
}
