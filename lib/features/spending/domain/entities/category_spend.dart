import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';

/// A category together with what has been booked against it.
class CategorySpend extends Equatable {
  const CategorySpend({required this.category, required this.totalScaled});

  final Category category;

  /// Sum of the category's transactions, scaled by `amountScale`.
  final int totalScaled;

  @override
  List<Object?> get props => [category, totalScaled];
}
