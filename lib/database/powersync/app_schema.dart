import 'package:powersync/powersync.dart';

/// The PowerSync schema.
///
/// This must mirror the drift tables in `lib/database/tables/`. PowerSync
/// creates the local SQLite views from this definition, drift reads and writes
/// through them, and the two only agree because you keep them in step — there
/// is no codegen linking them. Change one, change the other.
///
/// Notes on the shape:
/// * `id` is implicit. PowerSync adds a text primary key to every table; do
///   not declare it here.
/// * Only text/integer/real exist. Timestamps are ISO-8601 UTC strings, which
///   is what drift writes when `store_date_time_values_as_text` is on, and
///   what Postgres `timestamptz` accepts.
/// * Column names are snake_case to match both drift's default SQL naming and
///   the Postgres tables the sync rules select from.
const appSchema = Schema([
  Table('accounts', [
    Column.text('owner_id'),
    Column.text('name'),
    Column.text('currency'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),
  Table('categories', [
    Column.text('owner_id'),
    Column.text('name'),
    Column.integer('color_argb'),
    Column.text('icon_key'),
    Column.text('kind'),
    Column.integer('recurring_day_of_month'),
    Column.integer('recurring_amount_scaled'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),
  Table('currencies', [
    Column.text('owner_id'),
    Column.text('ticker'),
    Column.text('icon'),
    Column.integer('exchange_rate_scaled'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),
  Table(
    'debts',
    [
      Column.text('owner_id'),
      Column.text('counterparty'),
      Column.text('direction'),
      Column.integer('amount_scaled'),
      Column.text('note'),
      Column.text('due_at'),
      Column.text('settled_at'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('by_settled_at', [IndexedColumn('settled_at')]),
    ],
  ),
  Table('goals', [
    Column.text('owner_id'),
    Column.integer('target_amount_scaled'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),
  Table(
    'transactions',
    [
      Column.text('owner_id'),
      Column.text('account_id'),
      Column.text('category_id'),
      Column.text('side'),
      Column.integer('amount_scaled'),
      Column.text('currency'),
      Column.text('executed_at'),
      Column.text('note'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('by_account', [IndexedColumn('account_id')]),
      Index('by_category', [IndexedColumn('category_id')]),
      Index('by_executed_at', [IndexedColumn('executed_at')]),
    ],
  ),
]);
