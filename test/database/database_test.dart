import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/database/database.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<String> insertAccount() async {
      final account = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(
              ownerId: 'user-1',
              name: 'Interactive Brokers',
              currency: 'USD',
            ),
          );
      return account.id;
    }

    test('assigns a time-ordered id when none is given', () async {
      final first = await insertAccount();
      final second = await insertAccount();

      expect(first, isNot(second));
      // UUIDv7 leads with a millisecond timestamp, so ids generated later sort
      // later as plain strings. That is what keeps index inserts sequential.
      expect(first.compareTo(second), lessThanOrEqualTo(0));
      expect(first, hasLength(36));
      expect(first[14], '7', reason: 'version nibble should be 7');
    });

    test('round-trips a transaction with a scaled amount', () async {
      final accountId = await insertAccount();
      final executedAt = DateTime.utc(2026, 3, 14, 9, 30);

      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              ownerId: 'user-1',
              accountId: accountId,
              side: TradeSide.buy,
              amountScaled: (2341.87 * amountScale).round(),
              currency: 'USD',
              executedAt: executedAt,
            ),
          );

      final row = await db.select(db.transactions).getSingle();

      expect(row.side, TradeSide.buy);
      expect(row.amountScaled, 234187);
      expect(row.categoryId, isNull, reason: 'categorized later');
      expect(row.executedAt, executedAt);
      expect(row.deletedAt, isNull);
    });

    test('aggregates in SQL because amounts are integers', () async {
      final accountId = await insertAccount();

      for (final amount in [125, 250, 99]) {
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                ownerId: 'user-1',
                accountId: accountId,
                side: TradeSide.buy,
                amountScaled: amount,
                currency: 'USD',
                executedAt: DateTime.utc(2026, 3, 14),
              ),
            );
      }

      final total = db.transactions.amountScaled.sum();
      final result = await (db.selectOnly(
        db.transactions,
      )..addColumns([total])).getSingle();

      expect(result.read(total), 474);
    });

    test('stores timestamps as ISO-8601 UTC text for Postgres', () async {
      await insertAccount();

      final raw = await db
          .customSelect('select created_at from accounts')
          .getSingle();
      final createdAt = raw.data['created_at'] as String;

      expect(createdAt, endsWith('Z'));
      expect(DateTime.parse(createdAt).isUtc, isTrue);
    });
  });
}
