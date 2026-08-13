import 'package:my_pnl/core/session/ledger_scope.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/core/streams/switch_latest.dart';
import 'package:my_pnl/features/spending/data/datasources/category_local_data_source.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Binds the local data source to the domain contract.
///
/// The ledger and owner ids are applied here rather than in the data source so
/// callers never have to remember either — forgetting the ledger would write
/// rows no read returns, and forgetting the owner would write rows no sync rule
/// matches and no RLS policy admits.
class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl({
    required CategoryLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
    required LedgerScope ledgerScope,
  }) : _local = localDataSource,
       _owner = sessionOwner,
       _ledger = ledgerScope;

  final CategoryLocalDataSource _local;
  final SessionOwner _owner;
  final LedgerScope _ledger;

  // Both reads below are built over `_ledger.changes` rather than `_ledger.id`:
  // a page subscribes once and has to keep up with a switch made while it is on
  // screen. See `switchLatest`.
  @override
  Stream<List<CategorySpend>> watchCategorySpend(
    CategoryKind kind, {
    CalendarMonth? month,
  }) => switchLatest(
    _ledger.changes,
    (ledgerId) => _local.watchCategorySpend(ledgerId, kind, month: month),
  );

  @override
  Stream<Map<String, SpendBaseline>> watchSpendBaselines(
    CategoryKind kind, {
    required CalendarMonth month,
    int lookbackMonths = SpendBaseline.lookbackMonths,
  }) => switchLatest(
    _ledger.changes,
    (ledgerId) => _local.watchSpendBaselines(
      ledgerId,
      kind,
      month: month,
      lookbackMonths: lookbackMonths,
    ),
  );

  @override
  Future<int> generateDueRecurringIncome({DateTime? now}) =>
      _local.generateDueRecurringIncome(
        ownerId: _owner.id,
        ledgerId: _ledger.id,
        now: now ?? DateTime.now(),
      );

  @override
  Future<Category> createCategory(NewCategory category) =>
      _local.createCategory(
        category,
        ownerId: _owner.id,
        ledgerId: _ledger.id,
      );

  @override
  Future<Category> updateCategory(Category category) =>
      _local.updateCategory(category, _ledger.id);

  @override
  Future<void> reorderCategories(List<String> orderedIds) =>
      _local.reorderCategories(ledgerId: _ledger.id, orderedIds: orderedIds);

  @override
  Future<void> deleteCategory(String id, CategoryDeletion mode) =>
      _local.deleteCategory(
        ledgerId: _ledger.id,
        ownerId: _owner.id,
        id: id,
        mode: mode,
      );
}
