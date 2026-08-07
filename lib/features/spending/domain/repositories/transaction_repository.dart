import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';

/// How many entries the all-transactions list loads.
const allEntriesLimit = 200;

/// Money movements. Category totals come from the category repository; this
/// one deals in the individual entries behind them.
abstract interface class TransactionRepository {
  /// Books [amountScaled] against a category.
  ///
  /// [occurredAt] defaults to now. It is stored as UTC either way. [note] is
  /// what the entry is for, in the user's own words; null when they gave none.
  Future<void> recordSpend({
    required String categoryId,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  });

  /// Changes an existing entry.
  ///
  /// [note] replaces whatever the entry carried, so null clears it — the form
  /// that calls this always holds the whole note, and an edit that emptied the
  /// field has to be able to say so.
  Future<void> updateSpend({
    required String id,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  });

  /// Removes an entry.
  ///
  /// A soft delete: the row is tombstoned rather than dropped, because a hard
  /// delete is invisible to sync — a peer cannot tell "deleted" from "not
  /// received yet".
  Future<void> deleteSpend(String id);

  /// A category's entries, newest first, re-emitted as they change.
  Stream<List<SpendEntry>> watchCategoryHistory(String categoryId);

  /// Every entry the owner has, newest first, with its category.
  ///
  /// Capped at [allEntriesLimit]: a full ledger is unbounded, and a modal
  /// cannot usefully show thousands of rows anyway.
  Stream<List<LedgerEntry>> watchAllEntries();

  /// Income minus spending, across every category.
  ///
  /// Income is stored positive and spending negative, so this is a sum rather
  /// than a difference. Callers pass magnitudes when recording; the sign is
  /// applied from the category's kind.
  ///
  /// [month] narrows it to what was booked in that month. Null counts the whole
  /// ledger.
  Stream<int> watchNetTotal({CalendarMonth? month});

  /// What each month came to, newest first.
  ///
  /// Only months with entries appear — a month nothing was recorded in is
  /// absent rather than reported as zero, so a gap in the list is a gap in the
  /// ledger and not a month that broke even.
  Stream<List<MonthlyPnl>> watchMonthlyPnl();

  /// Re-signs rows written before income and spending had signs.
  ///
  /// Idempotent. Returns how many rows it changed.
  Future<int> normalizeAmountSigns();
}
