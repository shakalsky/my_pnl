import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';

/// One entry with the category it belongs to.
///
/// The per-category history does not need this — it already knows the
/// category. A list spanning every category does.
class LedgerEntry extends Equatable {
  const LedgerEntry({required this.entry, this.category});

  final SpendEntry entry;

  /// Null once the owning category has been deleted with its entries kept.
  final Category? category;

  bool get isCategorised => category != null;

  @override
  List<Object?> get props => [entry, category];
}
