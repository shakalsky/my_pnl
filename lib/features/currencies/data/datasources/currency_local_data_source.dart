import 'package:drift/drift.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';

/// Drift queries behind the currency repository.
class CurrencyLocalDataSource {
  const CurrencyLocalDataSource(this._db);

  final AppDatabase _db;

  Stream<List<Currency>> watchCurrencies(String ledgerId) {
    final query = _db.select(_db.currencies)
      ..where(
        (row) => row.ledgerId.equals(ledgerId) & row.deletedAt.isNull(),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.ticker)]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  Future<Currency> createCurrency(
    NewCurrency currency, {
    required String ownerId,
    required String ledgerId,
  }) async {
    await _requireFreeTicker(currency.ticker, ledgerId);

    final row = await _db
        .into(_db.currencies)
        .insertReturning(
          CurrenciesCompanion.insert(
            // Records who added it, and nothing more: a rate is shared
            // furniture, so either partner may edit or remove it.
            ownerId: ownerId,
            ledgerId: Value(ledgerId),
            ticker: currency.ticker,
            icon: Value(currency.icon),
            exchangeRateScaled: currency.exchangeRateScaled,
          ),
        );

    return _toEntity(row);
  }

  Future<Currency> updateCurrency(Currency currency, String ledgerId) async {
    await _requireFreeTicker(currency.ticker, ledgerId, exceptId: currency.id);
    await _requireInLedger(currency.id, ledgerId);

    await (_db.update(_db.currencies)..where(
          (row) => row.id.equals(currency.id) & row.ledgerId.equals(ledgerId),
        ))
        .write(
          CurrenciesCompanion(
            ticker: Value(currency.ticker),
            icon: Value(currency.icon),
            exchangeRateScaled: Value(currency.exchangeRateScaled),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    return _toEntity(await _requireInLedger(currency.id, ledgerId));
  }

  /// Reads a live row back, throwing if it is missing or not the caller's.
  ///
  /// A SELECT rather than the row count a write returns: PowerSync's tables
  /// are views written through INSTEAD OF triggers, and SQLite does not count
  /// rows changed by such a trigger, so `write()` returns 0 even on success.
  Future<CurrencyRow> _requireInLedger(String id, String ledgerId) async {
    final row =
        await (_db.select(_db.currencies)..where(
              (row) =>
                  row.id.equals(id) &
                  row.ledgerId.equals(ledgerId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (row == null) throw StateError('No currency $id in ledger $ledgerId');
    return row;
  }

  /// Tombstones the row, so the removal syncs like any other change.
  Future<void> deleteCurrency({
    required String ledgerId,
    required String id,
  }) async {
    await _requireInLedger(id, ledgerId);

    final now = DateTime.now().toUtc();

    await (_db.update(_db.currencies)..where(
          (row) => row.id.equals(id) & row.ledgerId.equals(ledgerId),
        ))
        .write(
          CurrenciesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
  }

  /// Per ledger, so a shared book cannot end up with two rates for the same
  /// ticker — one per partner — and totals that depend on which of them the
  /// reader's device happened to pick.
  ///
  /// PowerSync's local tables are views and carry no unique constraint, so
  /// the check happens here. Postgres still has the real one — this is to give
  /// a decent message, not to be the only guard.
  Future<void> _requireFreeTicker(
    String ticker,
    String ledgerId, {
    String? exceptId,
  }) async {
    final clash =
        await (_db.select(_db.currencies)
              ..where(
                (row) =>
                    row.ledgerId.equals(ledgerId) &
                    row.ticker.equals(ticker) &
                    row.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();

    if (clash != null && clash.id != exceptId) {
      throw CurrencyFailure('$ticker is already in your list');
    }
  }

  Currency _toEntity(CurrencyRow row) => Currency(
    id: row.id,
    ticker: row.ticker,
    icon: row.icon,
    exchangeRateScaled: row.exchangeRateScaled,
  );
}
