import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/amount_parse.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/create_category.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_category.dart';
import 'package:my_pnl/features/spending/domain/usecases/update_category.dart';

part 'category_form_event.dart';
part 'category_form_state.dart';

/// Drives the category modal, for both creating and editing.
///
/// One modal, one bloc: the two flows differ only in whether the form starts
/// with a category, so splitting them would duplicate every field event.
class CategoryFormBloc extends Bloc<CategoryFormEvent, CategoryFormState> {
  CategoryFormBloc({
    required CreateCategory createCategory,
    required UpdateCategory updateCategory,
    required DeleteCategory deleteCategory,
    required int defaultColorArgb,
    required String defaultIconKey,
    CategoryKind kind = CategoryKind.expense,
    Category? initial,
  }) : _createCategory = createCategory,
       _updateCategory = updateCategory,
       _deleteCategory = deleteCategory,
       super(
         CategoryFormState(
           categoryId: initial?.id,
           // An existing category keeps its own side of the ledger; a new one
           // takes it from the page that opened the form.
           kind: initial?.kind ?? kind,
           name: initial?.name ?? '',
           description: initial?.description ?? '',
           colorArgb: initial?.colorArgb ?? defaultColorArgb,
           iconKey: initial?.iconKey ?? defaultIconKey,
           isRecurring: initial?.isRecurring ?? false,
           recurringDay: initial?.recurring?.dayOfMonth.toString() ?? '',
           recurringAmount: initial?.recurring == null
               ? ''
               : formatAmountInput(initial!.recurring!.amountScaled),
         ),
       ) {
    on<CategoryFormNameChanged>(
      // Clears the error: the name is the thing a duplicate complaint is
      // about, so editing it makes the complaint stale.
      (event, emit) => emit(state.copyWith(name: event.name, clearError: true)),
    );
    on<CategoryFormColorSelected>(
      (event, emit) => emit(state.copyWith(colorArgb: event.colorArgb)),
    );
    on<CategoryFormIconSelected>(
      (event, emit) => emit(state.copyWith(iconKey: event.iconKey)),
    );
    on<CategoryFormDescriptionChanged>(
      (event, emit) => emit(state.copyWith(description: event.description)),
    );
    on<CategoryFormRecurringToggled>(
      (event, emit) => emit(state.copyWith(isRecurring: event.isRecurring)),
    );
    on<CategoryFormRecurringDayChanged>(
      (event, emit) => emit(state.copyWith(recurringDay: event.day)),
    );
    on<CategoryFormRecurringAmountChanged>(
      (event, emit) => emit(state.copyWith(recurringAmount: event.amount)),
    );
    on<CategoryFormSubmitted>(_onSubmitted);
    on<CategoryFormDeleted>(_onDeleted);
  }

  final CreateCategory _createCategory;
  final UpdateCategory _updateCategory;
  final DeleteCategory _deleteCategory;

  Future<void> _onDeleted(
    CategoryFormDeleted event,
    Emitter<CategoryFormState> emit,
  ) async {
    final id = state.categoryId;
    if (id == null || state.isBusy) return;

    emit(state.copyWith(status: CategoryFormStatus.deleting));

    try {
      await _deleteCategory(id, event.mode);
      emit(state.copyWith(status: CategoryFormStatus.success));
    } on Object catch (e, s) {
      // Logged because this catch is the only thing standing between the real
      // cause and a state change that says nothing about it.
      log('Deleting category $id failed', error: e, stackTrace: s);
      // Back to editing so the sheet stays open and the user can retry.
      emit(state.copyWith(status: CategoryFormStatus.failure));
      emit(state.copyWith(status: CategoryFormStatus.editing));
    }
  }

  Future<void> _onSubmitted(
    CategoryFormSubmitted event,
    Emitter<CategoryFormState> emit,
  ) async {
    if (!state.isValid || state.isSubmitting) return;

    emit(
      state.copyWith(
        status: CategoryFormStatus.submitting,
        clearError: true,
      ),
    );

    try {
      // Blank means "no description"; storing '' would be a second way to
      // say the same thing.
      final description = state.description.trim().isEmpty
          ? null
          : state.description.trim();

      if (state.categoryId case final id?) {
        await _updateCategory(
          Category(
            id: id,
            name: state.name,
            colorArgb: state.colorArgb,
            iconKey: state.iconKey,
            kind: state.kind,
            description: description,
            recurring: state.recurring,
          ),
        );
      } else {
        await _createCategory(
          NewCategory(
            name: state.name,
            colorArgb: state.colorArgb,
            iconKey: state.iconKey,
            kind: state.kind,
            description: description,
            recurring: state.recurring,
          ),
        );
      }
      emit(state.copyWith(status: CategoryFormStatus.success));
    } on CategoryFailure catch (e) {
      // A rejected name: worth stating exactly, and the form keeps its input
      // so it can be corrected rather than retyped.
      emit(
        state.copyWith(
          status: CategoryFormStatus.failure,
          errorMessage: e.message,
        ),
      );
      emit(state.copyWith(status: CategoryFormStatus.editing));
    } on Object catch (e, s) {
      log('Saving category failed', error: e, stackTrace: s);
      // Back to editing so the form stays usable and the user can retry.
      emit(state.copyWith(status: CategoryFormStatus.failure));
      emit(state.copyWith(status: CategoryFormStatus.editing));
    }
  }
}
