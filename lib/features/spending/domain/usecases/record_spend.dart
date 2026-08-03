import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Books an amount against a category.
class RecordSpend {
  const RecordSpend(this._repository);

  final TransactionRepository _repository;

  Future<void> call({
    required String categoryId,
    required int amountScaled,
    DateTime? occurredAt,
  }) {
    if (amountScaled == 0) {
      throw ArgumentError.value(amountScaled, 'amountScaled', 'must not be 0');
    }

    return _repository.recordSpend(
      categoryId: categoryId,
      amountScaled: amountScaled,
      occurredAt: occurredAt,
    );
  }
}
