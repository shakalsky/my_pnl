/// Remembers which ledger this device was last looking at.
///
/// A device preference rather than user data, like the display currency: which
/// book you have open says nothing about what was spent, and a phone and a
/// tablet can reasonably be left on different ones.
abstract interface class ActiveLedgerStore {
  /// The id last opened, or null on a device that has never chosen.
  ///
  /// Never throws: an unreadable preference is the same as never having set one,
  /// which resolves to the personal ledger.
  Future<String?> read();

  /// Remembers [ledgerId].
  ///
  /// Never throws either — failing to remember which book was open is not worth
  /// interrupting anyone over, and the choice still applies for this run.
  Future<void> write(String ledgerId);
}
