import 'package:equatable/equatable.dart';

/// Which side of the ledger a category sits on.
enum CategoryKind {
  expense,
  income;

  /// Rows written before this column existed have no value; they are
  /// spending, which is all the app tracked at the time.
  static CategoryKind fromStorage(String? value) =>
      value == income.name ? income : expense;

  String get storage => name;
}

/// What happens to a category's transactions when it is deleted.
enum CategoryDeletion {
  /// Transactions survive, uncategorised. The money stays in the ledger, so
  /// the net total does not move.
  keepTransactions,

  /// Transactions are tombstoned with the category. The net total changes by
  /// everything that was booked against it.
  deleteTransactions,
}

/// An income that repeats every month.
///
/// Day and amount travel together because neither is meaningful alone: a
/// schedule with no amount cannot produce a transaction, and an amount with
/// no schedule is just a number on a category. Modelling them as one nullable
/// value makes "is this recurring?" a single question.
class RecurringIncome extends Equatable {
  const RecurringIncome({required this.dayOfMonth, required this.amountScaled});

  /// 1–31. Months that are shorter clamp to their last day, so 31 means "end
  /// of the month" rather than "skip February".
  final int dayOfMonth;

  /// Scaled by `amountScale`.
  final int amountScaled;

  @override
  List<Object?> get props => [dayOfMonth, amountScaled];
}

/// A category, as the rest of the app thinks about it.
///
/// Deliberately free of Flutter and drift types: `colorArgb` and `iconKey` are
/// plain data, and the presentation layer decides what they look like.
class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.colorArgb,
    required this.iconKey,
    this.kind = CategoryKind.expense,
    this.recurring,
  });

  final String id;
  final String name;
  final int colorArgb;
  final String iconKey;
  final CategoryKind kind;

  /// Set when income arrives on a monthly schedule. Always null for expense
  /// categories.
  final RecurringIncome? recurring;

  bool get isIncome => kind == CategoryKind.income;

  bool get isRecurring => recurring != null;

  @override
  List<Object?> get props => [
    id,
    name,
    colorArgb,
    iconKey,
    kind,
    recurring,
  ];
}

/// A category that does not exist yet, so it has no id.
class NewCategory extends Equatable {
  const NewCategory({
    required this.name,
    required this.colorArgb,
    required this.iconKey,
    this.kind = CategoryKind.expense,
    this.recurring,
  });

  final String name;
  final int colorArgb;
  final String iconKey;
  final CategoryKind kind;
  final RecurringIncome? recurring;

  @override
  List<Object?> get props => [name, colorArgb, iconKey, kind, recurring];
}
