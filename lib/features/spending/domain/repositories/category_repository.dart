import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';

/// Raised when a category cannot be saved for a reason worth showing.
class CategoryFailure implements Exception {
  const CategoryFailure(this.message);

  final String message;

  @override
  String toString() => 'CategoryFailure: $message';
}

/// What the domain needs from storage. The implementation lives in the data
/// layer, so nothing above this line knows drift or PowerSync exists.
///
/// Everything here is about the ledger currently open, and in a family account
/// the categories are shared: both partners record against the same tiles and
/// either may edit them. That is what makes one grid add up to one total.
abstract interface class CategoryRepository {
  /// Categories of one [kind] with their current totals, re-emitted whenever
  /// the underlying rows change — including changes that arrive from sync.
  ///
  /// The totals span everyone in the ledger, so a tile says what the household
  /// spent on it rather than what the reader did.
  ///
  /// [month] narrows the totals to what was booked in that month. Null counts
  /// everything, so a caller with no month in mind gets the running total.
  /// A category with nothing booked in [month] still appears, with zero — the
  /// grid is a list of categories, not of the ones that happened to be used.
  Stream<List<CategorySpend>> watchCategorySpend(
    CategoryKind kind, {
    CalendarMonth? month,
  });

  /// What each category of one [kind] usually costs in a month, keyed by
  /// category id, re-emitted whenever the underlying rows change.
  ///
  /// The average is over the [lookbackMonths] months *before* [month], so the
  /// month being looked at is never part of its own baseline — comparing a
  /// figure against an average it is inside of would flatten exactly the spike
  /// the comparison is for.
  ///
  /// A category with nothing booked in the window is absent rather than
  /// present with a zero average: "no usual month on record" and "usually
  /// costs nothing" are different answers, and only the second one could
  /// sensibly flag anything.
  Stream<Map<String, SpendBaseline>> watchSpendBaselines(
    CategoryKind kind, {
    required CalendarMonth month,
    int lookbackMonths = SpendBaseline.lookbackMonths,
  });

  /// Books any recurring income that has come due since the last run.
  ///
  /// Returns how many transactions were created. Safe to call repeatedly:
  /// each occurrence has a derived id, so a second call is a no-op.
  ///
  /// Only the caller's own recurring categories: a partner's salary is theirs to
  /// book, and an entry recorded here would be labelled with the wrong person.
  Future<int> generateDueRecurringIncome({DateTime? now});

  /// Creates a category and returns it with the id it was given.
  ///
  /// Throws [CategoryFailure] if the owner already has one by that name.
  Future<Category> createCategory(NewCategory category);

  /// Saves edits to an existing category.
  ///
  /// Throws [CategoryFailure] if the new name is taken by another category.
  Future<Category> updateCategory(Category category);

  /// Stores the order the categories are shown in: [orderedIds] first to last.
  ///
  /// The whole list is passed rather than "this one moved there", because the
  /// order is a property of the list and a single move only means anything
  /// against the arrangement it came from.
  Future<void> reorderCategories(List<String> orderedIds);

  /// Removes a category, and does [mode] with the caller's transactions in it.
  ///
  /// A soft delete either way, so the removal syncs.
  ///
  /// In a shared ledger [mode] reaches only the caller's own entries — a
  /// partner's are not theirs to remove. Those stay in the ledger and read as
  /// uncategorised, which is what a tombstoned category makes every read do in
  /// any case.
  Future<void> deleteCategory(String id, CategoryDeletion mode);
}
