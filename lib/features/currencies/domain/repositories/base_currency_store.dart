import 'package:my_pnl/core/money/base_currency.dart';

/// Remembers which currency amounts are recorded and shown in.
///
/// A device preference rather than a row in the synced database, like the
/// display currency and the overrun thresholds beside it: there is no settings
/// table to sync it in, and the numbers themselves are untouched by the choice —
/// it decides what a figure is labelled with, not what was spent.
///
/// The cost of that is worth stating plainly: a second device keeps its own base
/// until it is changed there too, so the same figures can read `$42.35` on one
/// and `€42.35` on the other.
abstract interface class BaseCurrencyStore {
  /// The base in force, re-emitted whenever it is changed.
  ///
  /// A stream because every figure on screen is labelled with it: choosing
  /// another currency has to relabel what is already showing rather than wait
  /// for the app to be opened again.
  ///
  /// Never errors — an unreadable preference is [BaseCurrency.usd].
  Stream<BaseCurrency> watch();

  /// The base as it stands, for the app shell to apply before the first frame.
  ///
  /// Never throws: an unreadable preference is the same as never having chosen.
  Future<BaseCurrency> read();

  /// Remembers [currency] and re-emits it to [watch].
  ///
  /// Never throws either — the choice still applies for this run even if the
  /// store refused to keep it.
  Future<void> write(BaseCurrency currency);
}
