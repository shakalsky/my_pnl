import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';

/// Streams the user's debts.
class WatchDebts {
  const WatchDebts(this._repository);

  final DebtRepository _repository;

  Stream<List<Debt>> call() => _repository.watchDebts();
}
