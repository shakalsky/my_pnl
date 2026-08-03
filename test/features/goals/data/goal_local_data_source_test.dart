import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/goals/data/datasources/goal_local_data_source.dart';

void main() {
  group('GoalLocalDataSource', () {
    late AppDatabase db;
    late GoalLocalDataSource dataSource;

    const owner = 'user-1';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = GoalLocalDataSource(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('reports no goal until one is set', () async {
      expect(await dataSource.watchGoal(owner).first, isNull);
    });

    test('stores a goal with a client-generated id', () async {
      final saved = await dataSource.saveGoal(
        ownerId: owner,
        targetAmountScaled: 500000,
      );

      expect(saved.id, hasLength(36));
      expect(saved.targetAmountScaled, 500000);
      expect((await dataSource.watchGoal(owner).first)?.targetAmountScaled,
          500000);
    });

    test('saving again edits the goal rather than adding a second', () async {
      final first = await dataSource.saveGoal(
        ownerId: owner,
        targetAmountScaled: 500000,
      );
      final second = await dataSource.saveGoal(
        ownerId: owner,
        targetAmountScaled: 750000,
      );

      expect(second.id, first.id, reason: 'the same row');
      expect(second.targetAmountScaled, 750000);

      final rows = await db.select(db.goals).get();
      expect(rows.where((row) => row.deletedAt == null), hasLength(1));
    });

    test('clearing tombstones the row and frees the slot', () async {
      await dataSource.saveGoal(ownerId: owner, targetAmountScaled: 500000);

      await dataSource.clearGoal(owner);

      expect(await dataSource.watchGoal(owner).first, isNull);

      // Still on disk so the removal syncs...
      final row = await db.select(db.goals).getSingle();
      expect(row.deletedAt, isNotNull);

      // ...and a new goal can be set afterwards.
      final again = await dataSource.saveGoal(
        ownerId: owner,
        targetAmountScaled: 100000,
      );
      expect(again.targetAmountScaled, 100000);
      expect(await dataSource.watchGoal(owner).first, again);
    });

    test("does not see another owner's goal", () async {
      await dataSource.saveGoal(ownerId: 'user-2', targetAmountScaled: 500000);

      expect(await dataSource.watchGoal(owner).first, isNull);
    });

    test("clearing leaves another owner's goal alone", () async {
      await dataSource.saveGoal(ownerId: owner, targetAmountScaled: 500000);
      await dataSource.saveGoal(ownerId: 'user-2', targetAmountScaled: 900000);

      await dataSource.clearGoal(owner);

      expect(await dataSource.watchGoal(owner).first, isNull);
      expect(
        (await dataSource.watchGoal('user-2').first)?.targetAmountScaled,
        900000,
      );
    });
  });
}
