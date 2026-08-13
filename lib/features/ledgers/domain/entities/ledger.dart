import 'package:equatable/equatable.dart';

/// How many books one reader may have.
///
/// More than one personal account is for keeping your own spending in more than
/// one place — a household budget apart from a side business, say. Three is a
/// limit rather than a design: the switcher is a list read at a glance, and every
/// extra book is another set of categories to keep up to date.
///
/// One family account, because it answers "who am I sharing with" and that has a
/// single answer. Joining someone else's counts against it exactly as creating
/// your own does — the limit is on being in one, not on having made it.
///
/// Enforced in three places, and all three are needed: here for the message the
/// reader gets, in the local data source so an offline device cannot overshoot,
/// and in the Postgres insert policy, which is the only one of the three a
/// modified client cannot talk its way past.
abstract final class LedgerLimits {
  static const personal = 3;
  static const family = 1;
}

/// Whether a ledger is one person's or a household's.
///
/// Not a permission: a family ledger with one member behaves exactly like a
/// personal one. What it decides is what the app offers to do with the ledger —
/// only a family ledger can be shared, joined or left, and only a personal one
/// is guaranteed to exist.
enum LedgerKind {
  personal,
  family
  ;

  /// Anything unrecognised reads as personal. A value only reaches here from a
  /// row a newer build wrote, and treating it as a family account would offer
  /// to share a book on the strength of a string nobody understands.
  static LedgerKind fromStorage(String? value) =>
      value == family.name ? family : personal;

  String get storage => name;
}

/// What a member may do with the ledger itself.
///
/// Says nothing about the rows inside it — both roles read everything and write
/// their own entries. It is only about the book: the owner can rotate the invite
/// code and remove members, a member can leave.
enum LedgerRole {
  owner,
  member
  ;

  static LedgerRole fromStorage(String? value) =>
      value == owner.name ? owner : member;

  String get storage => name;
}

/// What to show for a member whose stored name is [displayName].
///
/// An email is shortened to the part before the `@`: everyone in a household
/// tends to be labelled with the same domain, so it is the half that says
/// nothing about which of them this is. A member whose own device has not
/// written a name yet gets a word rather than a blank, because the label's job
/// is to say "not you".
///
/// A function as well as [LedgerMember.label], because entries are labelled with
/// it too and they carry a name rather than a member.
String ledgerMemberLabel(String? displayName) {
  final name = displayName?.trim();
  if (name == null || name.isEmpty) return 'Partner';

  final at = name.indexOf('@');
  return at > 0 ? name.substring(0, at) : name;
}

/// One person with access to a ledger.
class LedgerMember extends Equatable {
  const LedgerMember({
    required this.userId,
    required this.role,
    this.displayName,
  });

  final String userId;
  final LedgerRole role;

  /// What to show beside this member's entries.
  ///
  /// Written by their own device from their sign-in email — `auth.users` is not
  /// readable by clients, so a partner's name travels as ordinary synced data or
  /// not at all. Null until their device has written it, which is what
  /// [label] falls back for.
  final String? displayName;

  bool get isOwner => role == LedgerRole.owner;

  /// Something to put on screen whatever the row carries.
  String get label => ledgerMemberLabel(displayName);

  @override
  List<Object?> get props => [userId, role, displayName];
}

/// A book of records: one set of categories, one set of transactions, one goal.
class Ledger extends Equatable {
  const Ledger({
    required this.id,
    required this.name,
    required this.kind,
    this.inviteCode,
    this.members = const [],
  });

  final String id;
  final String name;
  final LedgerKind kind;

  /// The code a partner types to join. Null on a personal ledger, which nobody
  /// else can join.
  final String? inviteCode;

  /// Everyone with access, the creator included.
  final List<LedgerMember> members;

  bool get isFamily => kind == LedgerKind.family;

  bool get isPersonal => kind == LedgerKind.personal;

  /// Whether anybody else is in here. A family ledger nobody has joined yet
  /// still reads as one person's, because that is what it is until they do.
  bool get isShared => members.length > 1;

  /// Everyone but [userId] — who the totals on screen are shared with.
  List<LedgerMember> partnersOf(String userId) =>
      members.where((member) => member.userId != userId).toList();

  @override
  List<Object?> get props => [id, name, kind, inviteCode, members];
}
