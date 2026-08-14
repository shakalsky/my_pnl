import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Records a debt, or saves edits to one.
///
/// Validation lives here rather than in the form so the same rules apply to
/// any caller — an import, a shortcut, a future bulk edit.
class SaveDebt {
  const SaveDebt(this._repository);

  final DebtRepository _repository;

  /// Records a new debt and returns it with its id.
  Future<Debt> create(NewDebt debt) {
    return _repository.createDebt(
      NewDebt(
        counterparty: _validCounterparty(debt.counterparty),
        direction: debt.direction,
        amountScaled: _validAmount(debt.amountScaled),
        note: _cleanNote(debt.note),
        dueAt: debt.dueAt?.toUtc(),
      ),
    );
  }

  /// Saves edits to an existing debt.
  ///
  /// [Debt.settledAt] is carried through untouched — settling goes through
  /// `MarkDebtSettled`, so editing an amount cannot reopen a squared-up debt
  /// by accident.
  Future<Debt> update(Debt debt) {
    return _repository.updateDebt(
      Debt(
        id: debt.id,
        counterparty: _validCounterparty(debt.counterparty),
        direction: debt.direction,
        amountScaled: _validAmount(debt.amountScaled),
        note: _cleanNote(debt.note),
        dueAt: debt.dueAt?.toUtc(),
        settledAt: debt.settledAt,
      ),
    );
  }

  String _validCounterparty(String value) {
    final name = value.trim();

    if (name.isEmpty) {
      throw DebtFailure(t.debts.enterCounterparty);
    }
    if (name.length > 60) {
      throw DebtFailure(t.debts.nameTooLong);
    }

    return name;
  }

  /// A magnitude: the direction carries the sign, so a negative amount here
  /// would mean the same debt twice over.
  int _validAmount(int amountScaled) {
    if (amountScaled <= 0) {
      throw DebtFailure(t.debts.amountAboveZero);
    }

    return amountScaled;
  }

  /// An empty note is stored as null rather than '', so there is one way to
  /// say "no note".
  String? _cleanNote(String? note) {
    final trimmed = note?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
