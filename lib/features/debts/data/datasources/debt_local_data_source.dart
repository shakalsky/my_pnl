import 'package:drift/drift.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';

/// Drift queries behind the debt repository.
class DebtLocalDataSource {
  const DebtLocalDataSource(this._db);

  final AppDatabase _db;

  /// The owner's debts, open ones first and newest first within each group.
  ///
  /// The ordering leans on SQLite sorting NULL before any value: an open debt
  /// has no `settled_at`, so ascending on that column floats the ones that
  /// still need doing to the top without a second query or a CASE expression.
  Stream<List<Debt>> watchDebts(String ownerId) {
    final query = _db.select(_db.debts)
      ..where((row) => row.ownerId.equals(ownerId) & row.deletedAt.isNull())
      ..orderBy([
        (row) => OrderingTerm.asc(row.settledAt),
        (row) => OrderingTerm.desc(row.createdAt),
      ]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  Future<Debt> createDebt(NewDebt debt, String ownerId) async {
    final row = await _db
        .into(_db.debts)
        .insertReturning(
          DebtsCompanion.insert(
            ownerId: ownerId,
            counterparty: debt.counterparty,
            direction: debt.direction.storage,
            amountScaled: debt.amountScaled,
            note: Value(debt.note),
            dueAt: Value(debt.dueAt),
          ),
        );

    return _toEntity(row);
  }

  Future<Debt> updateDebt(Debt debt, String ownerId) async {
    await _requireOwned(debt.id, ownerId);

    await (_db.update(_db.debts)..where(
          (row) => row.id.equals(debt.id) & row.ownerId.equals(ownerId),
        ))
        .write(
          DebtsCompanion(
            counterparty: Value(debt.counterparty),
            direction: Value(debt.direction.storage),
            amountScaled: Value(debt.amountScaled),
            note: Value(debt.note),
            dueAt: Value(debt.dueAt),
            settledAt: Value(debt.settledAt),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    return _toEntity(await _requireOwned(debt.id, ownerId));
  }

  /// Stamps or clears `settled_at`.
  Future<void> setDebtSettled({
    required String ownerId,
    required String id,
    required bool settled,
  }) async {
    await _requireOwned(id, ownerId);

    final now = DateTime.now().toUtc();

    await (_db.update(_db.debts)..where(
          (row) => row.id.equals(id) & row.ownerId.equals(ownerId),
        ))
        .write(
          DebtsCompanion(
            settledAt: Value(settled ? now : null),
            updatedAt: Value(now),
          ),
        );
  }

  /// Tombstones the row, so the removal syncs like any other change.
  Future<void> deleteDebt({
    required String ownerId,
    required String id,
  }) async {
    await _requireOwned(id, ownerId);

    final now = DateTime.now().toUtc();

    await (_db.update(_db.debts)..where(
          (row) => row.id.equals(id) & row.ownerId.equals(ownerId),
        ))
        .write(DebtsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  /// Reads a live row back, throwing if it is missing or not the caller's.
  ///
  /// A SELECT rather than the row count a write returns: PowerSync's tables
  /// are views written through INSTEAD OF triggers, and SQLite does not count
  /// rows changed by such a trigger, so `write()` returns 0 even on success.
  Future<DebtRow> _requireOwned(String id, String ownerId) async {
    final row =
        await (_db.select(_db.debts)..where(
              (row) =>
                  row.id.equals(id) &
                  row.ownerId.equals(ownerId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (row == null) throw StateError('No debt $id owned by $ownerId');
    return row;
  }

  Debt _toEntity(DebtRow row) => Debt(
    id: row.id,
    counterparty: row.counterparty,
    direction: DebtDirection.fromStorage(row.direction),
    amountScaled: row.amountScaled,
    note: row.note,
    dueAt: row.dueAt,
    settledAt: row.settledAt,
  );
}
