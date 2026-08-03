part of 'category_form_bloc.dart';

enum CategoryFormStatus { editing, submitting, deleting, success, failure }

final class CategoryFormState extends Equatable {
  const CategoryFormState({
    required this.colorArgb,
    required this.iconKey,
    this.kind = CategoryKind.expense,
    this.categoryId,
    this.name = '',
    this.description = '',
    this.isRecurring = false,
    this.recurringDay = '',
    this.recurringAmount = '',
    this.status = CategoryFormStatus.editing,
    this.errorMessage,
  });

  /// Null while creating; set to the category being edited.
  final String? categoryId;

  /// Fixed for the life of the form: which page opened it decides this.
  final CategoryKind kind;

  final String name;
  final String description;
  final int colorArgb;
  final String iconKey;

  /// Whether the recurring block is switched on. Kept separate from the
  /// parsed values so unticking the box does not wipe what was typed.
  final bool isRecurring;

  /// Raw text, exactly as typed.
  final String recurringDay;
  final String recurringAmount;

  final CategoryFormStatus status;

  /// Why the last save was rejected, when there is something worth saying —
  /// a duplicate name, for instance. Null for anything generic.
  final String? errorMessage;

  bool get isEditing => categoryId != null;

  bool get isIncome => kind == CategoryKind.income;

  /// Only income can recur; the expense form never shows the block.
  bool get showsRecurring => isIncome;

  /// The parsed day, or null while the input is not a day of the month.
  int? get recurringDayOfMonth {
    final day = int.tryParse(recurringDay.trim());
    if (day == null || day < 1 || day > 31) return null;
    return day;
  }

  /// The parsed amount, or null while the input is not a positive number.
  int? get recurringAmountScaled {
    final amount = parseAmount(recurringAmount);
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  /// The schedule to save, or null when the box is unticked.
  RecurringIncome? get recurring {
    if (!isRecurring || !showsRecurring) return null;

    final day = recurringDayOfMonth;
    final amount = recurringAmountScaled;
    if (day == null || amount == null) return null;

    return RecurringIncome(dayOfMonth: day, amountScaled: amount);
  }

  /// Whether the form can be submitted. A ticked recurring box has to be
  /// filled in — a half-configured schedule cannot produce a transaction.
  bool get isValid {
    if (name.trim().isEmpty) return false;
    if (isRecurring && showsRecurring) {
      return recurringDayOfMonth != null && recurringAmountScaled != null;
    }
    return true;
  }

  bool get isSubmitting => status == CategoryFormStatus.submitting;

  bool get isDeleting => status == CategoryFormStatus.deleting;

  /// Any in-flight write. Both buttons disable together, so a delete cannot
  /// race a save.
  bool get isBusy => isSubmitting || isDeleting;

  CategoryFormState copyWith({
    String? name,
    String? description,
    int? colorArgb,
    String? iconKey,
    bool? isRecurring,
    String? recurringDay,
    String? recurringAmount,
    CategoryFormStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CategoryFormState(
      categoryId: categoryId,
      kind: kind,
      name: name ?? this.name,
      description: description ?? this.description,
      colorArgb: colorArgb ?? this.colorArgb,
      iconKey: iconKey ?? this.iconKey,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDay: recurringDay ?? this.recurringDay,
      recurringAmount: recurringAmount ?? this.recurringAmount,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    categoryId,
    kind,
    name,
    description,
    colorArgb,
    iconKey,
    isRecurring,
    recurringDay,
    recurringAmount,
    status,
    errorMessage,
  ];
}
