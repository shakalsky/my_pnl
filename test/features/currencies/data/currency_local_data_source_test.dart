import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/currencies/data/datasources/currency_local_data_source.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';

void main() {
  group('CurrencyLocalDataSource', () {
    late AppDatabase db;
    late CurrencyLocalDataSource dataSource;

    const owner = 'user-1';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = CurrencyLocalDataSource(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<Currency> add({
      required String ticker,
      String? icon = '€',
      int rateScaled = 1080000,
      String ownerId = owner,
    }) {
      return dataSource.createCurrency(
        NewCurrency(
          ticker: ticker,
          icon: icon,
          exchangeRateScaled: rateScaled,
        ),
        ownerId,
      );
    }

    test('stores a currency with a client-generated id', () async {
      final created = await add(ticker: 'EUR');

      expect(created.id, hasLength(36));
      expect(created.ticker, 'EUR');
      expect(created.icon, '€');
      // 1.08 held as an integer the whole way.
      expect(created.exchangeRateScaled, 1080000);
      expect(created.exchangeRateScaled / rateScale, 1.08);
    });

    test('keeps a null icon null', () async {
      final created = await add(ticker: 'EUR', icon: null);
      expect(created.icon, isNull);
    });

    test('lists currencies by ticker', () async {
      await add(ticker: 'GBP');
      await add(ticker: 'BTC');
      await add(ticker: 'EUR');

      final currencies = await dataSource.watchCurrencies(owner).first;

      expect(currencies.map((c) => c.ticker), ['BTC', 'EUR', 'GBP']);
    });

    test('rejects a ticker the owner already has', () async {
      await add(ticker: 'EUR');

      await expectLater(
        add(ticker: 'EUR'),
        throwsA(isA<CurrencyFailure>()),
      );
    });

    test('lets a different owner use the same ticker', () async {
      await add(ticker: 'EUR');
      await add(ticker: 'EUR', ownerId: 'user-2');

      final mine = await dataSource.watchCurrencies(owner).first;
      expect(mine, hasLength(1));
    });

    test('updates the rate and the icon', () async {
      final created = await add(ticker: 'EUR');

      final updated = await dataSource.updateCurrency(
        // No icon this time — it must be cleared, not left as it was.
        Currency(
          id: created.id,
          ticker: 'EUR',
          exchangeRateScaled: 1090000,
        ),
        owner,
      );

      expect(updated.exchangeRateScaled, 1090000);
      expect(updated.icon, isNull);
      final currencies = await dataSource.watchCurrencies(owner).first;
      expect(currencies, hasLength(1), reason: 'edited, not duplicated');
    });

    test('deleting tombstones the row and frees the ticker', () async {
      final created = await add(ticker: 'EUR');

      await dataSource.deleteCurrency(ownerId: owner, id: created.id);

      expect(await dataSource.watchCurrencies(owner).first, isEmpty);

      // Still on disk so the delete syncs...
      final row = await db.select(db.currencies).getSingle();
      expect(row.deletedAt, isNotNull);

      // ...and the ticker can be used again.
      await expectLater(add(ticker: 'EUR'), completes);
    });

    test("refuses to touch another owner's currency", () async {
      final created = await add(ticker: 'EUR');

      await expectLater(
        dataSource.deleteCurrency(ownerId: 'user-2', id: created.id),
        throwsStateError,
      );
    });
  });
}
