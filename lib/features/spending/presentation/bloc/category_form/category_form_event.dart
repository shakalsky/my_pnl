part of 'category_form_bloc.dart';

sealed class CategoryFormEvent extends Equatable {
  const CategoryFormEvent();

  @override
  List<Object?> get props => [];
}

final class CategoryFormNameChanged extends CategoryFormEvent {
  const CategoryFormNameChanged(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class CategoryFormColorSelected extends CategoryFormEvent {
  const CategoryFormColorSelected(this.colorArgb);

  final int colorArgb;

  @override
  List<Object?> get props => [colorArgb];
}

final class CategoryFormIconSelected extends CategoryFormEvent {
  const CategoryFormIconSelected(this.iconKey);

  final String iconKey;

  @override
  List<Object?> get props => [iconKey];
}

/// Toggles the recurring block. Income categories only.
final class CategoryFormRecurringToggled extends CategoryFormEvent {
  const CategoryFormRecurringToggled({required this.isRecurring});

  final bool isRecurring;

  @override
  List<Object?> get props => [isRecurring];
}

final class CategoryFormRecurringDayChanged extends CategoryFormEvent {
  const CategoryFormRecurringDayChanged(this.day);

  /// Raw text, exactly as typed.
  final String day;

  @override
  List<Object?> get props => [day];
}

final class CategoryFormRecurringAmountChanged extends CategoryFormEvent {
  const CategoryFormRecurringAmountChanged(this.amount);

  /// Raw text, exactly as typed.
  final String amount;

  @override
  List<Object?> get props => [amount];
}

final class CategoryFormSubmitted extends CategoryFormEvent {
  const CategoryFormSubmitted();
}

/// Removes the category being edited. Ignored while creating.
final class CategoryFormDeleted extends CategoryFormEvent {
  const CategoryFormDeleted(this.mode);

  /// What to do with the transactions booked against it.
  final CategoryDeletion mode;

  @override
  List<Object?> get props => [mode];
}
