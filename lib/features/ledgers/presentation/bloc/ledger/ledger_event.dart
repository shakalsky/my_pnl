part of 'ledger_bloc.dart';

sealed class LedgerEvent extends Equatable {
  const LedgerEvent();

  @override
  List<Object?> get props => [];
}

final class LedgerSubscriptionRequested extends LedgerEvent {
  const LedgerSubscriptionRequested();
}

/// Open this ledger: everything the app reads and writes moves to it.
final class LedgerSelected extends LedgerEvent {
  const LedgerSelected(this.ledgerId);

  final String ledgerId;

  @override
  List<Object?> get props => [ledgerId];
}

/// Make another book of the reader's own, under this name, and open it.
final class LedgerPersonalCreated extends LedgerEvent {
  const LedgerPersonalCreated(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

/// Make a family account under this name and open it.
final class LedgerFamilyCreated extends LedgerEvent {
  const LedgerFamilyCreated(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

/// Redeem an invite code and open what it names.
final class LedgerJoinRequested extends LedgerEvent {
  const LedgerJoinRequested(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

/// Discard one of the reader's own books.
final class LedgerDeleted extends LedgerEvent {
  const LedgerDeleted(this.ledgerId);

  final String ledgerId;

  @override
  List<Object?> get props => [ledgerId];
}

/// Give up access to a family account.
final class LedgerLeft extends LedgerEvent {
  const LedgerLeft(this.ledgerId);

  final String ledgerId;

  @override
  List<Object?> get props => [ledgerId];
}

/// Replace the invite code, revoking every invite not yet used.
final class LedgerInviteCodeRotated extends LedgerEvent {
  const LedgerInviteCodeRotated(this.ledgerId);

  final String ledgerId;

  @override
  List<Object?> get props => [ledgerId];
}
