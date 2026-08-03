import 'package:drift/drift.dart';
import 'package:my_pnl/database/tables/accounts.dart';
import 'package:my_pnl/database/tables/categories.dart';
import 'package:my_pnl/database/tables/synced_table.dart';

enum TradeSide { buy, sell }

/// A single money movement.
///
/// Numeric columns are scaled integers, never doubles — see
/// `lib/database/scales.dart`.
@DataClassName('TransactionRow')
class Transactions extends Table with SyncedTable {
  TextColumn get ownerId => text()();

  /// References [Accounts.id].
  ///
  /// PowerSync exposes tables as views, so SQLite enforces no foreign key
  /// here — the constraint lives in Postgres. Because ids are client-generated
  /// UUIDs, the value written offline is still the value the server sees.
  TextColumn get accountId => text()();

  /// References [Categories.id]. Nullable so a transaction can be recorded
  /// first and categorized later.
  TextColumn get categoryId => text().nullable()();

  TextColumn get side => textEnum<TradeSide>()();

  /// Amount scaled by `amountScale` (2 decimal places), in [currency].
  IntColumn get amountScaled => integer()();

  TextColumn get currency => text()();

  /// Fill time. Stored as UTC no matter what the caller passes in.
  TextColumn get executedAt => text().map(const UtcDateTimeConverter())();

  TextColumn get note => text().nullable()();
}
