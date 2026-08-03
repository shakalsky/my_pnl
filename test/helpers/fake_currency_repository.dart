import 'dart:async';

import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';

/// In-memory stand-in for [CurrencyRepository].
class FakeCurrencyRepository implements CurrencyRepository {
  FakeCurrencyRepository({List<Currency> initial = const []})
    : _currencies = List.of(initial);

  final List<Currency> _currencies;
  final _controller = StreamController<List<Currency>>.broadcast();

  /// Set to have any write fail.
  Exception? writeError;

  @override
  Stream<List<Currency>> watchCurrencies() async* {
    yield _sorted();
    yield* _controller.stream;
  }

  @override
  Future<Currency> createCurrency(NewCurrency currency) async {
    if (writeError case final error?) throw error;
    _requireFreeTicker(currency.ticker);

    final created = Currency(
      id: newId(),
      ticker: currency.ticker,
      icon: currency.icon,
      exchangeRateScaled: currency.exchangeRateScaled,
    );
    _currencies.add(created);
    _emit();
    return created;
  }

  @override
  Future<Currency> updateCurrency(Currency currency) async {
    if (writeError case final error?) throw error;
    _requireFreeTicker(currency.ticker, exceptId: currency.id);

    final index = _currencies.indexWhere((c) => c.id == currency.id);
    if (index == -1) throw StateError('No currency ${currency.id}');

    _currencies[index] = currency;
    _emit();
    return currency;
  }

  @override
  Future<void> deleteCurrency(String id) async {
    if (writeError case final error?) throw error;

    _currencies.removeWhere((c) => c.id == id);
    _emit();
  }

  void _requireFreeTicker(String ticker, {String? exceptId}) {
    final clash = _currencies.where(
      (c) => c.ticker == ticker && c.id != exceptId,
    );
    if (clash.isNotEmpty) {
      throw CurrencyFailure('$ticker is already in your list');
    }
  }

  List<Currency> _sorted() {
    final sorted = List.of(_currencies)
      ..sort((a, b) => a.ticker.compareTo(b.ticker));
    return List.unmodifiable(sorted);
  }

  void _emit() => _controller.add(_sorted());

  Future<void> close() => _controller.close();
}
