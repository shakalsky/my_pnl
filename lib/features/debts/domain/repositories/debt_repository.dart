import 'package:my_pnl/features/debts/domain/entities/debt.dart';

/// Raised when a debt cannot be saved for a reason worth showing.
class DebtFailure implements Exception {
  const DebtFailure(this.message);

  final String message;

  @override
  String toString() => 'DebtFailure: $message';
}

abstract interface class DebtRepository {
  /// Every debt the user has, open ones first, re-emitted as they change.
  ///
  /// Settled debts stay in the stream rather than being filtered out here: the
  /// page shows them in their own section, and a caller that wants only the
  /// open ones can say so in one line.
  Stream<List<Debt>> watchDebts();

  /// Records a debt.
  Future<Debt> createDebt(NewDebt debt);

  /// Changes an existing debt.
  Future<Debt> updateDebt(Debt debt);

  /// Removes a debt.
  ///
  /// A soft delete: the row is tombstoned rather than dropped, because a hard
  /// delete is invisible to sync — a peer cannot tell "deleted" from "not
  /// received yet".
  Future<void> deleteDebt(String id);

  /// Marks a debt settled, or reopens it.
  ///
  /// One method for both directions so there is a single place that decides
  /// what settling writes.
  Future<void> setDebtSettled({required String id, required bool settled});
}
