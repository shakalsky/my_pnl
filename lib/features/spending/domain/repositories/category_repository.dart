import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';

/// Raised when a category cannot be saved for a reason worth showing.
class CategoryFailure implements Exception {
  const CategoryFailure(this.message);

  final String message;

  @override
  String toString() => 'CategoryFailure: $message';
}

/// What the domain needs from storage. The implementation lives in the data
/// layer, so nothing above this line knows drift or PowerSync exists.
abstract interface class CategoryRepository {
  /// Categories of one [kind] with their current totals, re-emitted whenever
  /// the underlying rows change — including changes that arrive from sync.
  ///
  /// [month] narrows the totals to what was booked in that month. Null counts
  /// everything, so a caller with no month in mind gets the running total.
  /// A category with nothing booked in [month] still appears, with zero — the
  /// grid is a list of categories, not of the ones that happened to be used.
  Stream<List<CategorySpend>> watchCategorySpend(
    CategoryKind kind, {
    CalendarMonth? month,
  });

  /// Books any recurring income that has come due since the last run.
  ///
  /// Returns how many transactions were created. Safe to call repeatedly:
  /// each occurrence has a derived id, so a second call is a no-op.
  Future<int> generateDueRecurringIncome({DateTime? now});

  /// Creates a category and returns it with the id it was given.
  ///
  /// Throws [CategoryFailure] if the owner already has one by that name.
  Future<Category> createCategory(NewCategory category);

  /// Saves edits to an existing category.
  ///
  /// Throws [CategoryFailure] if the new name is taken by another category.
  Future<Category> updateCategory(Category category);

  /// Removes a category, and does [mode] with its transactions.
  ///
  /// A soft delete either way, so the removal syncs.
  Future<void> deleteCategory(String id, CategoryDeletion mode);
}
