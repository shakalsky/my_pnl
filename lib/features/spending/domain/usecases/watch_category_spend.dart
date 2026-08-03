import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Streams every category with its total, for one month or for all time.
class WatchCategorySpend {
  const WatchCategorySpend(this._repository);

  final CategoryRepository _repository;

  Stream<List<CategorySpend>> call(CategoryKind kind, {CalendarMonth? month}) =>
      _repository.watchCategorySpend(kind, month: month);
}
