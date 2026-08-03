import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/amount_parse.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/usecases/record_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/update_spend.dart';

part 'amount_entry_event.dart';
part 'amount_entry_state.dart';

/// Drives the modal that books an amount against a category.
///
/// One modal for both booking and correcting an amount: the flows differ only
/// in whether the form starts with an entry behind it.
class AmountEntryBloc extends Bloc<AmountEntryEvent, AmountEntryState> {
  AmountEntryBloc({
    required RecordSpend recordSpend,
    required UpdateSpend updateSpend,
    required Category category,
    SpendEntry? entry,
  }) : _recordSpend = recordSpend,
       _updateSpend = updateSpend,
       super(
         AmountEntryState(
           category: category,
           entryId: entry?.id,
           // Magnitude, not the stored value: spending is held negative, and
           // showing "-12.50" in a field the user types a price into invites
           // them to delete the minus and wonder why nothing changed.
           input: entry == null
               ? ''
               : formatAmountInput(entry.amountScaled.abs()),
           // A new entry starts with no date at all rather than with now: the
           // clock should read at the moment it is saved, not the moment the
           // sheet opened.
           occurredAt: entry?.occurredAt,
         ),
       ) {
    on<AmountEntryChanged>(
      (event, emit) => emit(state.copyWith(input: event.input)),
    );
    on<AmountEntryDateChanged>(
      // The one place the zone changes hands: the picker deals in the reader's
      // own dates, everything from here down is UTC.
      (event, emit) =>
          emit(state.copyWith(occurredAt: event.occurredAt.toUtc())),
    );
    on<AmountEntrySubmitted>(_onSubmitted);
  }

  final RecordSpend _recordSpend;
  final UpdateSpend _updateSpend;

  Future<void> _onSubmitted(
    AmountEntrySubmitted event,
    Emitter<AmountEntryState> emit,
  ) async {
    final amount = state.amountScaled;
    if (amount == null || amount == 0 || state.isSubmitting) return;

    emit(state.copyWith(status: AmountEntryStatus.submitting));

    try {
      // A null date leaves the entry where it is — on an edit that is the date
      // it already carries, and on a new one it is now.
      if (state.entryId case final id?) {
        await _updateSpend(
          id: id,
          amountScaled: amount,
          occurredAt: state.occurredAt,
        );
      } else {
        await _recordSpend(
          categoryId: state.category.id,
          amountScaled: amount,
          occurredAt: state.occurredAt,
        );
      }
      emit(state.copyWith(status: AmountEntryStatus.success));
    } on Object {
      // Back to editing so the amount survives and can be retried.
      emit(state.copyWith(status: AmountEntryStatus.failure));
      emit(state.copyWith(status: AmountEntryStatus.editing));
    }
  }
}
