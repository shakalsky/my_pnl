import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';

/// Adds a currency, or saves edits to one.
///
/// Validation lives here rather than in the form so the same rules apply to
/// any caller — an import, a sync fixup, a future bulk edit.
class SaveCurrency {
  const SaveCurrency(this._repository);

  final CurrencyRepository _repository;

  /// Adds a new currency and returns it with its id.
  Future<Currency> create(NewCurrency currency) {
    final ticker = _validTicker(currency.ticker);
    _checkRate(currency.exchangeRateScaled);

    return _repository.createCurrency(
      NewCurrency(
        ticker: ticker,
        icon: _cleanIcon(currency.icon),
        exchangeRateScaled: currency.exchangeRateScaled,
      ),
    );
  }

  /// Saves edits to an existing currency.
  Future<Currency> update(Currency currency) {
    final ticker = _validTicker(currency.ticker);
    _checkRate(currency.exchangeRateScaled);

    return _repository.updateCurrency(
      Currency(
        id: currency.id,
        ticker: ticker,
        icon: _cleanIcon(currency.icon),
        exchangeRateScaled: currency.exchangeRateScaled,
      ),
    );
  }

  String _validTicker(String value) {
    final ticker = value.trim().toUpperCase();

    if (ticker.isEmpty) {
      throw const CurrencyFailure('Enter a ticker');
    }
    if (ticker == baseCurrency) {
      throw const CurrencyFailure('$baseCurrency is the base currency');
    }
    if (!RegExp(r'^[A-Z0-9]{2,10}$').hasMatch(ticker)) {
      throw const CurrencyFailure(
        'Tickers are 2 to 10 letters or digits',
      );
    }

    return ticker;
  }

  void _checkRate(int exchangeRateScaled) {
    if (exchangeRateScaled <= 0) {
      throw const CurrencyFailure('The exchange rate must be above zero');
    }
  }

  /// An empty icon is stored as null rather than '', so there is one way to
  /// say "no icon".
  String? _cleanIcon(String? icon) {
    final trimmed = icon?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
