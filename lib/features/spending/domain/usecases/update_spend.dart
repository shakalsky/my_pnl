import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Changes the amount on an existing entry.
class UpdateSpend {
  const UpdateSpend(this._repository);

  final TransactionRepository _repository;

  Future<void> call({
    required String id,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  }) {
    if (amountScaled == 0) {
      throw ArgumentError.value(amountScaled, 'amountScaled', 'must not be 0');
    }

    return _repository.updateSpend(
      id: id,
      amountScaled: amountScaled,
      occurredAt: occurredAt,
      note: note,
    );
  }
}
