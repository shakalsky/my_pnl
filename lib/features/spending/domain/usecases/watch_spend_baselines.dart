import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Streams what each category usually costs in a month, keyed by category id.
class WatchSpendBaselines {
  const WatchSpendBaselines(this._repository);

  final CategoryRepository _repository;

  Stream<Map<String, SpendBaseline>> call(
    CategoryKind kind, {
    required CalendarMonth month,
    int lookbackMonths = SpendBaseline.lookbackMonths,
  }) => _repository.watchSpendBaselines(
    kind,
    month: month,
    lookbackMonths: lookbackMonths,
  );
}
