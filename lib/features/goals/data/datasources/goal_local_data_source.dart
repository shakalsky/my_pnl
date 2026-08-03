import 'package:drift/drift.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';

/// Drift queries behind the goal repository.
class GoalLocalDataSource {
  const GoalLocalDataSource(this._db);

  final AppDatabase _db;

  /// The owner's goal, or null when none is set.
  ///
  /// Newest first with a limit of one rather than `getSingle`: Postgres keeps
  /// one live row per owner, but two devices that each set a goal while offline
  /// can both land before either sees the other. Reading the newest keeps the
  /// page working until the unique index rejects the loser.
  Stream<SavingsGoal?> watchGoal(String ownerId) {
    final query = _db.select(_db.goals)
      ..where((row) => row.ownerId.equals(ownerId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(1);

    return query.watch().map(
      (rows) => rows.isEmpty ? null : _toEntity(rows.first),
    );
  }

  /// Sets the goal, editing the live row when there is one.
  Future<SavingsGoal> saveGoal({
    required String ownerId,
    required int targetAmountScaled,
  }) async {
    final existing = await _liveRow(ownerId);

    if (existing == null) {
      final row = await _db
          .into(_db.goals)
          .insertReturning(
            GoalsCompanion.insert(
              ownerId: ownerId,
              targetAmountScaled: targetAmountScaled,
            ),
          );

      return _toEntity(row);
    }

    await (_db.update(_db.goals)..where(
          (row) => row.id.equals(existing.id) & row.ownerId.equals(ownerId),
        ))
        .write(
          GoalsCompanion(
            targetAmountScaled: Value(targetAmountScaled),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    // Read back rather than trusting the write: PowerSync's tables are views
    // written through INSTEAD OF triggers, so `write()` returns 0 either way.
    final updated = await _liveRow(ownerId);
    if (updated == null) throw StateError('Goal for $ownerId vanished');
    return _toEntity(updated);
  }

  /// Tombstones the goal, so the removal syncs like any other change.
  ///
  /// Every live row, not just the newest: if two ever raced past the unique
  /// index, clearing has to leave nothing behind.
  Future<void> clearGoal(String ownerId) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.goals)..where(
          (row) => row.ownerId.equals(ownerId) & row.deletedAt.isNull(),
        ))
        .write(GoalsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  Future<GoalRow?> _liveRow(String ownerId) {
    final query = _db.select(_db.goals)
      ..where((row) => row.ownerId.equals(ownerId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  SavingsGoal _toEntity(GoalRow row) => SavingsGoal(
    id: row.id,
    targetAmountScaled: row.targetAmountScaled,
  );
}
