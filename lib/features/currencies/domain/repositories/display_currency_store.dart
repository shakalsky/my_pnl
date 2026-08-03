/// Remembers which currency totals are read in.
///
/// A device preference rather than user data: it says nothing about what was
/// spent, only how the reader wants to see it, so it lives beside the app rather
/// than in the synced database. That also makes it the one thing holding the
/// choice together across the pages, each of which drives its own bloc.
abstract interface class DisplayCurrencyStore {
  /// The id of the currency last chosen, or null for the base currency.
  ///
  /// Never throws: an unreadable preference is the same as never having set one.
  Future<String?> read();

  /// Remembers [currencyId], or that the base currency is showing when it is
  /// null.
  ///
  /// Never throws either — failing to remember a display choice is not worth
  /// interrupting anyone over.
  Future<void> write(String? currencyId);
}
