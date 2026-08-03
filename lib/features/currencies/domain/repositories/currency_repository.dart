import 'package:my_pnl/features/currencies/domain/entities/currency.dart';

/// Raised when a currency cannot be saved for a reason worth showing.
class CurrencyFailure implements Exception {
  const CurrencyFailure(this.message);

  final String message;

  @override
  String toString() => 'CurrencyFailure: $message';
}

abstract interface class CurrencyRepository {
  /// The user's currencies, re-emitted as they change.
  Stream<List<Currency>> watchCurrencies();

  /// Adds a currency.
  ///
  /// Throws [CurrencyFailure] if the ticker is already taken — the local
  /// PowerSync views cannot enforce uniqueness, so it is checked here as well
  /// as in Postgres.
  Future<Currency> createCurrency(NewCurrency currency);

  /// Changes an existing currency.
  Future<Currency> updateCurrency(Currency currency);

  /// Removes a currency.
  Future<void> deleteCurrency(String id);
}
