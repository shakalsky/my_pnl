import 'dart:async';

import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/base_currency_store.dart';

/// In-memory stand-in for [BaseCurrencyStore].
///
/// Starts on the currency the app ships with, which is a device that has never
/// chosen.
class FakeBaseCurrencyStore implements BaseCurrencyStore {
  FakeBaseCurrencyStore({BaseCurrency initial = BaseCurrency.usd})
    : _current = initial;

  BaseCurrency _current;
  final _changes = StreamController<BaseCurrency>.broadcast();

  /// Every base written, in order, so a test can see that a choice was kept as
  /// well as that it was applied.
  final writes = <BaseCurrency>[];

  @override
  Stream<BaseCurrency> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<BaseCurrency> read() async => _current;

  @override
  Future<void> write(BaseCurrency currency) async {
    _current = currency;
    writes.add(currency);
    if (!_changes.isClosed) _changes.add(currency);
  }

  Future<void> close() => _changes.close();
}
