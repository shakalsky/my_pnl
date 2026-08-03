import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';

/// Removes a currency.
class DeleteCurrency {
  const DeleteCurrency(this._repository);

  final CurrencyRepository _repository;

  Future<void> call(String id) => _repository.deleteCurrency(id);
}
