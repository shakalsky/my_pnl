import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';

/// Translates between drift rows and domain entities.
///
/// Keeping this in one place is what lets the domain stay ignorant of the
/// database — a column rename stops here.
extension CategoryRowMapper on CategoryRow {
  Category toEntity() => Category(
    id: id,
    name: name,
    colorArgb: colorArgb,
    iconKey: iconKey,
    kind: CategoryKind.fromStorage(kind),
    description: description,
    recurring: _recurring,
  );

  /// A schedule only exists when both halves are stored. A row carrying just
  /// one is treated as not recurring rather than half-configured — it cannot
  /// produce a transaction either way.
  RecurringIncome? get _recurring {
    final day = recurringDayOfMonth;
    final amount = recurringAmountScaled;
    if (day == null || amount == null) return null;

    return RecurringIncome(dayOfMonth: day, amountScaled: amount);
  }
}
