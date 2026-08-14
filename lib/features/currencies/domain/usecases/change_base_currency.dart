import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/base_currency_store.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Moves the app onto another base currency, clearing the currencies whose rates
/// were quoted against the old one.
///
/// Every added currency holds one number — what one of its units is worth in the
/// base — so the moment the base changes, every one of those numbers means
/// something else. They are removed rather than recalculated: a rate the app
/// worked out on the user's behalf is a rate nobody checked, and a wrong one
/// shows a total that looks perfectly ordinary.
///
/// Amounts already recorded are left alone. They are stored as plain scaled
/// integers, so nothing about them changes — only the sign they are written with.
class ChangeBaseCurrency {
  const ChangeBaseCurrency({
    required CurrencyRepository repository,
    required BaseCurrencyStore store,
  }) : _repository = repository,
       _store = store;

  final CurrencyRepository _repository;
  final BaseCurrencyStore _store;

  /// Makes [currency] the base and removes [existing].
  ///
  /// [existing] is passed in rather than read here: the caller is already
  /// watching the list, and what gets removed should be exactly what the user
  /// was shown before they agreed to it.
  ///
  /// The chosen currency goes with the rest when it is one of them — a currency
  /// cannot be quoted against itself, and leaving the row behind would put the
  /// base into the list of alternatives to the base.
  ///
  /// The removals happen first, so a failure part-way leaves the base as it was
  /// and the rates still meaning what they say. Throws [CurrencyFailure] on a
  /// currency the app cannot work with, and whatever the repository throws when a
  /// removal fails.
  Future<void> call({
    required BaseCurrency currency,
    required List<Currency> existing,
  }) async {
    if (!currency.isValid) {
      throw CurrencyFailure(t.currencies.notACurrency(ticker: currency.ticker));
    }

    for (final stale in existing) {
      await _repository.deleteCurrency(stale.id);
    }

    await _store.write(currency);
  }
}
