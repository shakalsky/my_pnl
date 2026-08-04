import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/features/spending/data/datasources/category_local_data_source.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Binds the local data source to the domain contract.
///
/// The owner id is applied here rather than in the data source so callers
/// never have to remember it — forgetting it would write rows that no sync
/// rule matches and no RLS policy admits.
class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl({
    required CategoryLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
  }) : _local = localDataSource,
       _owner = sessionOwner;

  final CategoryLocalDataSource _local;
  final SessionOwner _owner;

  @override
  Stream<List<CategorySpend>> watchCategorySpend(
    CategoryKind kind, {
    CalendarMonth? month,
  }) => _local.watchCategorySpend(_owner.id, kind, month: month);

  @override
  Stream<Map<String, SpendBaseline>> watchSpendBaselines(
    CategoryKind kind, {
    required CalendarMonth month,
    int lookbackMonths = SpendBaseline.lookbackMonths,
  }) => _local.watchSpendBaselines(
    _owner.id,
    kind,
    month: month,
    lookbackMonths: lookbackMonths,
  );

  @override
  Future<int> generateDueRecurringIncome({DateTime? now}) =>
      _local.generateDueRecurringIncome(
        ownerId: _owner.id,
        now: now ?? DateTime.now(),
      );

  @override
  Future<Category> createCategory(NewCategory category) =>
      _local.createCategory(category, _owner.id);

  @override
  Future<Category> updateCategory(Category category) =>
      _local.updateCategory(category, _owner.id);

  @override
  Future<void> deleteCategory(String id, CategoryDeletion mode) =>
      _local.deleteCategory(ownerId: _owner.id, id: id, mode: mode);
}
