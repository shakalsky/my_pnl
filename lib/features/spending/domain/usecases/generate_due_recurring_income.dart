import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Books recurring income that has come due.
///
/// Run at startup and whenever the income page opens, rather than on a timer:
/// the app has no background execution, so "catch up on what was missed" is
/// the only scheme that survives being closed for a month.
class GenerateDueRecurringIncome {
  const GenerateDueRecurringIncome(this._repository);

  final CategoryRepository _repository;

  Future<int> call({DateTime? now}) =>
      _repository.generateDueRecurringIncome(now: now);
}
