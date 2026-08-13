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
    const ledger = 'ledger-1';

    /// Another book. Rates belong to one, so nothing here crosses over.
    const otherLedger = 'ledger-2';

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
      String ledgerId = ledger,
    }) {
      return dataSource.createCurrency(
        NewCurrency(
          ticker: ticker,
          icon: icon,
          exchangeRateScaled: rateScaled,
        ),
        ownerId: ownerId,
        ledgerId: ledgerId,
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

      final currencies = await dataSource.watchCurrencies(ledger).first;

      expect(currencies.map((c) => c.ticker), ['BTC', 'EUR', 'GBP']);
    });

    test('rejects a ticker the ledger already has', () async {
      await add(ticker: 'EUR');

      await expectLater(
        add(ticker: 'EUR'),
        throwsA(isA<CurrencyFailure>()),
      );
    });

    test('lets another ledger use the same ticker', () async {
      await add(ticker: 'EUR');
      await add(ticker: 'EUR', ledgerId: otherLedger);

      final mine = await dataSource.watchCurrencies(ledger).first;
      expect(mine, hasLength(1));
    });

    test("refuses a ticker a partner already added to the same book", () async {
      // Rates are shared furniture, so the clash is per ledger and not per
      // person: two rates for one ticker in one book would make the totals
      // depend on which of them a device happened to read.
      await add(ticker: 'EUR');

      await expectLater(
        add(ticker: 'EUR', ownerId: 'partner-1'),
        throwsA(isA<CurrencyFailure>()),
      );
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
        ledger,
      );

      expect(updated.exchangeRateScaled, 1090000);
      expect(updated.icon, isNull);
      final currencies = await dataSource.watchCurrencies(ledger).first;
      expect(currencies, hasLength(1), reason: 'edited, not duplicated');
    });

    test('deleting tombstones the row and frees the ticker', () async {
      final created = await add(ticker: 'EUR');

      await dataSource.deleteCurrency(ledgerId: ledger, id: created.id);

      expect(await dataSource.watchCurrencies(ledger).first, isEmpty);

      // Still on disk so the delete syncs...
      final row = await db.select(db.currencies).getSingle();
      expect(row.deletedAt, isNotNull);

      // ...and the ticker can be used again.
      await expectLater(add(ticker: 'EUR'), completes);
    });

    test("refuses to touch another ledger's currency", () async {
      final created = await add(ticker: 'EUR');

      await expectLater(
        dataSource.deleteCurrency(ledgerId: otherLedger, id: created.id),
        throwsStateError,
      );
    });

    test("lets a partner correct a rate the other one added", () async {
      final created = await add(ticker: 'EUR');

      // Nothing here says who is asking, and that is the point: a rate in a
      // shared book is either partner's to fix.
      final updated = await dataSource.updateCurrency(
        Currency(
          id: created.id,
          ticker: 'EUR',
          icon: '€',
          exchangeRateScaled: 1120000,
        ),
        ledger,
      );

      expect(updated.exchangeRateScaled, 1120000);
    });
  });
}
