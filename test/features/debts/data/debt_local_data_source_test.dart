import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/debts/data/datasources/debt_local_data_source.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';

void main() {
  group('DebtLocalDataSource', () {
    late AppDatabase db;
    late DebtLocalDataSource dataSource;

    const owner = 'user-1';
    const ledger = 'ledger-1';

    /// Another book. A debt belongs to one, so nothing here crosses over.
    const otherLedger = 'ledger-2';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = DebtLocalDataSource(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<Debt> add({
      String counterparty = 'Alex',
      DebtDirection direction = DebtDirection.owedToMe,
      int amountScaled = 2500,
      String? note,
      DateTime? dueAt,
      String ownerId = owner,
      String ledgerId = ledger,
    }) {
      return dataSource.createDebt(
        NewDebt(
          counterparty: counterparty,
          direction: direction,
          amountScaled: amountScaled,
          note: note,
          dueAt: dueAt,
        ),
        ownerId: ownerId,
        ledgerId: ledgerId,
      );
    }

    test('stores a debt with a client-generated id', () async {
      final created = await add(note: 'Concert ticket');

      expect(created.id, hasLength(36));
      expect(created.counterparty, 'Alex');
      expect(created.direction, DebtDirection.owedToMe);
      expect(created.amountScaled, 2500);
      expect(created.note, 'Concert ticket');
      expect(created.isSettled, isFalse);
    });

    test('keeps the direction it was written with', () async {
      await add(counterparty: 'Landlord', direction: DebtDirection.owedByMe);

      final debts = await dataSource.watchDebts(ledger).first;

      expect(debts.single.direction, DebtDirection.owedByMe);
      expect(debts.single.isOwedToMe, isFalse);
    });

    test('stores the due date as UTC', () async {
      final created = await add(dueAt: DateTime(2026, 9, 1, 12));

      expect(created.dueAt?.isUtc, isTrue);
      expect(created.dueAt, DateTime(2026, 9, 1, 12).toUtc());
    });

    test('lists open debts before settled ones', () async {
      final paid = await add(counterparty: 'Kim');
      await add(counterparty: 'Sam');

      await dataSource.setDebtSettled(
        ledgerId: ledger,
        id: paid.id,
        settled: true,
      );

      final debts = await dataSource.watchDebts(ledger).first;

      expect(debts.map((debt) => debt.counterparty), ['Sam', 'Kim']);
      expect(debts.last.isSettled, isTrue);
    });

    test('settling stamps a date, reopening clears it', () async {
      final created = await add();

      await dataSource.setDebtSettled(
        ledgerId: ledger,
        id: created.id,
        settled: true,
      );
      var debt = (await dataSource.watchDebts(ledger).first).single;
      expect(debt.settledAt, isNotNull);

      await dataSource.setDebtSettled(
        ledgerId: ledger,
        id: created.id,
        settled: false,
      );
      debt = (await dataSource.watchDebts(ledger).first).single;
      expect(debt.settledAt, isNull);
    });

    test('updates a debt in place, clearing what was dropped', () async {
      final created = await add(note: 'Concert ticket', dueAt: DateTime(2026));

      final updated = await dataSource.updateDebt(
        Debt(
          id: created.id,
          counterparty: 'Alexandra',
          direction: DebtDirection.owedByMe,
          amountScaled: 4000,
        ),
        ledger,
      );

      expect(updated.counterparty, 'Alexandra');
      expect(updated.direction, DebtDirection.owedByMe);
      expect(updated.amountScaled, 4000);
      expect(updated.note, isNull);
      expect(updated.dueAt, isNull);

      final debts = await dataSource.watchDebts(ledger).first;
      expect(debts, hasLength(1), reason: 'edited, not duplicated');
    });

    test("does not see another ledger's debts", () async {
      await add();
      await add(counterparty: 'Someone else', ledgerId: otherLedger);

      final mine = await dataSource.watchDebts(ledger).first;

      expect(mine.map((debt) => debt.counterparty), ['Alex']);
    });

    test('deleting tombstones the row rather than dropping it', () async {
      final created = await add();

      await dataSource.deleteDebt(ledgerId: ledger, id: created.id);

      expect(await dataSource.watchDebts(ledger).first, isEmpty);

      // Still on disk, so the delete itself syncs.
      final row = await db.select(db.debts).getSingle();
      expect(row.deletedAt, isNotNull);
    });

    test("refuses to touch another ledger's debt", () async {
      final created = await add();

      await expectLater(
        dataSource.deleteDebt(ledgerId: otherLedger, id: created.id),
        throwsStateError,
      );
      await expectLater(
        dataSource.setDebtSettled(
          ledgerId: otherLedger,
          id: created.id,
          settled: true,
        ),
        throwsStateError,
      );
    });

    test('lets a partner settle a debt the other one entered', () async {
      // Which is most of why a shared book is worth having: the debt is the
      // household's, so either of them can mark it squared up.
      final created = await add(ownerId: 'partner-1');

      await dataSource.setDebtSettled(
        ledgerId: ledger,
        id: created.id,
        settled: true,
      );

      final debt = (await dataSource.watchDebts(ledger).first).single;
      expect(debt.settledAt, isNotNull);
    });
  });
}
