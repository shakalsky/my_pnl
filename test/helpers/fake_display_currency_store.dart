import 'package:my_pnl/features/currencies/domain/repositories/display_currency_store.dart';

/// In-memory stand-in for [DisplayCurrencyStore].
///
/// Starts empty, which is a device that has never chosen: totals read in the
/// base currency.
class FakeDisplayCurrencyStore implements DisplayCurrencyStore {
  FakeDisplayCurrencyStore({String? remembered}) : _remembered = remembered;

  String? _remembered;

  /// Every id written, in order, so a test can see that a choice was kept as
  /// well as that it was applied.
  final writes = <String?>[];

  @override
  Future<String?> read() async => _remembered;

  @override
  Future<void> write(String? currencyId) async {
    _remembered = currencyId;
    writes.add(currencyId);
  }
}
