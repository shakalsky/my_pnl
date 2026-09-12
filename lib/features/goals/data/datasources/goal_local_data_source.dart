import 'package:drift/drift.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';

/// Drift queries behind the goal repository.
class GoalLocalDataSource {
  const GoalLocalDataSource(this._db);

  final AppDatabase _db;

  /// The ledger's goal, or null when none is set.
  ///
  /// Newest first with a limit of one rather than `getSingle`: Postgres keeps
  /// one live row per ledger, but two devices that each set a goal while offline
  /// can both land before either sees the other. Reading the newest keeps the
  /// page working until the unique index rejects the loser — and in a family
  /// account those two devices can now belong to two different people, which
  /// makes the race commonplace rather than theoretical.
  Stream<SavingsGoal?> watchGoal(String ledgerId) {
    final query = _db.select(_db.goals)
      ..where((row) => row.ledgerId.equals(ledgerId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(1);

    return query.watch().map(
      (rows) => rows.isEmpty ? null : _toEntity(rows.first),
    );
  }

  /// Sets the goal, editing the live row when there is one.
  Future<SavingsGoal> saveGoal({
    required String ownerId,
    required String ledgerId,
    required int targetAmountScaled,
    int startingAmountScaled = 0,
  }) async {
    final existing = await _liveRow(ledgerId);

    if (existing == null) {
      final row = await _db
          .into(_db.goals)
          .insertReturning(
            GoalsCompanion.insert(
              // Records who set it. The goal belongs to the ledger, so in a
              // family account either partner can raise or clear it.
              ownerId: ownerId,
              ledgerId: Value(ledgerId),
              targetAmountScaled: targetAmountScaled,
              startingAmountScaled: Value(startingAmountScaled),
            ),
          );

      return _toEntity(row);
    }

    await (_db.update(_db.goals)..where(
          (row) => row.id.equals(existing.id) & row.ledgerId.equals(ledgerId),
        ))
        .write(
          GoalsCompanion(
            targetAmountScaled: Value(targetAmountScaled),
            // Written even when zero: clearing the field is an edit like any
            // other, and leaving the old figure in place would go on counting
            // money the reader has just said is not there.
            startingAmountScaled: Value(startingAmountScaled),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    // Read back rather than trusting the write: PowerSync's tables are views
    // written through INSTEAD OF triggers, so `write()` returns 0 either way.
    final updated = await _liveRow(ledgerId);
    if (updated == null) throw StateError('Goal for ledger $ledgerId vanished');
    return _toEntity(updated);
  }

  /// Tombstones the goal, so the removal syncs like any other change.
  ///
  /// Every live row, not just the newest: if two ever raced past the unique
  /// index, clearing has to leave nothing behind.
  Future<void> clearGoal(String ledgerId) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.goals)..where(
          (row) => row.ledgerId.equals(ledgerId) & row.deletedAt.isNull(),
        ))
        .write(GoalsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  Future<GoalRow?> _liveRow(String ledgerId) {
    final query = _db.select(_db.goals)
      ..where((row) => row.ledgerId.equals(ledgerId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  // Null reads as nothing put aside: a row written before the column existed
  // says nothing about a starting amount, and "nothing" is the right reading.
  SavingsGoal _toEntity(GoalRow row) => SavingsGoal(
    id: row.id,
    targetAmountScaled: row.targetAmountScaled,
    startingAmountScaled: row.startingAmountScaled ?? 0,
  );
}
