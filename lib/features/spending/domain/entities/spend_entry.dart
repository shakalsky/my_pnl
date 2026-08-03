import 'package:equatable/equatable.dart';

/// A single amount booked against a category.
class SpendEntry extends Equatable {
  const SpendEntry({
    required this.id,
    required this.amountScaled,
    required this.occurredAt,
    this.note,
  });

  final String id;

  /// Scaled by `amountScale`.
  final int amountScaled;

  /// Always UTC. Convert to local only when displaying.
  final DateTime occurredAt;

  final String? note;

  @override
  List<Object?> get props => [id, amountScaled, occurredAt, note];
}
