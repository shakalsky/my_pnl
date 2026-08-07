-- Postgres side of the local database.
--
-- Run this in the Supabase SQL editor. It must stay in step with the drift
-- tables in lib/database/tables/ and the PowerSync schema in
-- lib/database/powersync/app_schema.dart.
--
-- Note what is deliberately missing: `id` has NO default. Ids are generated on
-- the client as UUIDv7 so rows can be created offline and uploads stay
-- idempotent. A server-side default would hand out a second id for a retried
-- insert and duplicate the row.

create table if not exists public.accounts (
  id          uuid        primary key,
  owner_id    uuid        not null references auth.users (id) on delete cascade,
  name        text        not null,
  currency    text        not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table if not exists public.categories (
  id          uuid        primary key,
  owner_id    uuid        not null references auth.users (id) on delete cascade,
  name        text        not null,
  -- Packed ARGB. An icon *key*, not a font code point: code points would tie
  -- rows to one Flutter version and defeat icon tree-shaking.
  color_argb  bigint      not null,
  icon_key    text        not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

-- Added after the fact, so each is nullable or defaulted: rows already synced
-- to devices must stay valid.
alter table public.categories
  add column if not exists kind text not null default 'expense'
    check (kind in ('expense', 'income')),
  -- Day and amount of a recurring income. Both null means it does not recur.
  add column if not exists recurring_day_of_month int
    check (recurring_day_of_month between 1 and 31),
  add column if not exists recurring_amount_scaled bigint
    check (recurring_amount_scaled > 0),
  -- Where the category sits in the grid, low first. Null on a row nobody has
  -- dragged yet, which the client sorts after the arranged ones by age.
  add column if not exists sort_order int;

-- One live category name per owner, case-insensitive. Partial, so a deleted
-- category does not block reusing its name.
create unique index if not exists categories_owner_name_idx
  on public.categories (owner_id, lower(name))
  where deleted_at is null;

create table if not exists public.currencies (
  id                   uuid        primary key,
  owner_id             uuid        not null references auth.users (id) on delete cascade,
  ticker               text        not null,
  icon                 text,
  -- What one unit is worth in the base currency, scaled by 1e6. Six decimal
  -- places because cents round a minor currency's rate to zero.
  exchange_rate_scaled bigint      not null check (exchange_rate_scaled > 0),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

-- One live row per ticker per owner. Partial, so a tombstoned currency does
-- not block re-adding it later.
create unique index if not exists currencies_owner_ticker_idx
  on public.currencies (owner_id, ticker)
  where deleted_at is null;

-- The oldest client build still allowed to run, per platform.
--
-- Deliberately outside PowerSync: it is read with a direct select, not synced.
-- A synced copy would arrive only after a signed-in client's first sync, which
-- is too late for a gate whose job is to stop stale clients — and it would say
-- nothing at all on the sign-in screen, where nobody has a JWT yet. It is also
-- not owner-scoped: one row serves every user, so it appears in no bucket.
--
-- Leave min_version at the app's current version until a release genuinely
-- breaks compatibility. Raising it locks out every older build immediately.
create table if not exists public.app_requirements (
  platform    text        primary key
    check (platform in
      ('android', 'ios', 'macos', 'windows', 'linux', 'web')),
  -- Semantic version, `major.minor.patch`, as shown in the stores.
  min_version text        not null,
  -- Build number, compared only when the three numbers above tie. This is the
  -- value after the `+` in pubspec.yaml.
  min_build   bigint      not null default 0,
  -- Where to send the user. Null falls back to a plain "update from the store"
  -- message with no button.
  store_url   text,
  -- Optional line shown instead of the default explanation.
  message     text,
  updated_at  timestamptz not null default now()
);

-- Seed with the shipping version, so the gate exists but blocks nobody. Bump
-- min_version when a release stops being compatible.
insert into public.app_requirements (platform, min_version, min_build, store_url)
values
  ('android', '1.0.0', 1, null),
  ('ios',     '1.0.0', 1, null)
on conflict (platform) do nothing;

-- How much the user is trying to save up. One live row per owner.
create table if not exists public.goals (
  id                   uuid        primary key,
  owner_id             uuid        not null references auth.users (id) on delete cascade,
  -- Scaled by 100, like every other amount. See lib/database/scales.dart.
  target_amount_scaled bigint      not null check (target_amount_scaled > 0),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

-- One live goal per owner. Partial, so a cleared goal does not block setting a
-- new one. Saving a goal updates the existing row rather than inserting.
create unique index if not exists goals_owner_idx
  on public.goals (owner_id)
  where deleted_at is null;

-- Money owed, in either direction. Not a transaction: a debt is a promise, so
-- booking it into the ledger would count the same cash twice.
create table if not exists public.debts (
  id            uuid        primary key,
  owner_id      uuid        not null references auth.users (id) on delete cascade,
  counterparty  text        not null,
  direction     text        not null
    check (direction in ('owed_to_me', 'owed_by_me')),
  -- Magnitude only, scaled by 100. The direction column says which way the
  -- money points, so a sign here would be a second source of truth.
  amount_scaled bigint      not null check (amount_scaled > 0),
  note          text,
  due_at        timestamptz,
  -- Null while the debt is open. A timestamp rather than a flag: the date it
  -- was squared up is worth keeping.
  settled_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

create index if not exists debts_owner_settled_idx
  on public.debts (owner_id, settled_at);

create table if not exists public.transactions (
  id              uuid        primary key,
  owner_id        uuid        not null references auth.users (id) on delete cascade,
  account_id      uuid        not null references public.accounts (id),
  category_id     uuid        references public.categories (id),
  side            text        not null check (side in ('buy', 'sell')),
  -- Scaled integer, never a float. See lib/database/scales.dart.
  amount_scaled   bigint      not null,  -- 2 decimal places
  currency        text        not null,
  executed_at     timestamptz not null,
  note            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create index if not exists transactions_account_idx
  on public.transactions (account_id);
create index if not exists transactions_category_idx
  on public.transactions (category_id);
create index if not exists transactions_executed_at_idx
  on public.transactions (owner_id, executed_at desc);

-- Row level security -------------------------------------------------------
-- Uploads go through the ordinary Supabase client, so these policies are what
-- actually protects the data. A policy failure surfaces as Postgres 42501,
-- which SupabaseConnector treats as fatal and discards rather than retrying.

alter table public.accounts         enable row level security;
alter table public.app_requirements enable row level security;
alter table public.categories       enable row level security;
alter table public.currencies       enable row level security;
alter table public.debts            enable row level security;
alter table public.goals            enable row level security;
alter table public.transactions     enable row level security;

-- Dropped first because `create policy` has no IF NOT EXISTS. Without this,
-- re-running the script aborts here, and in the Supabase SQL editor the whole
-- transaction rolls back — including the publication below, which then shows
-- up as "Publication 'powersync' not found" on the PowerSync side.

-- The one table everybody may read, signed in or not: the update gate has to
-- work before sign-in, so the anon key needs access. Read-only on purpose —
-- there is no write policy, so only the dashboard or a service-role key can
-- raise the minimum. The value is public information either way.
drop policy if exists "app requirements are world readable"
  on public.app_requirements;
create policy "app requirements are world readable"
  on public.app_requirements for select
  to anon, authenticated
  using (true);

drop policy if exists "accounts are private to their owner" on public.accounts;
create policy "accounts are private to their owner"
  on public.accounts for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "categories are private to their owner"
  on public.categories;
create policy "categories are private to their owner"
  on public.categories for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "currencies are private to their owner"
  on public.currencies;
create policy "currencies are private to their owner"
  on public.currencies for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "debts are private to their owner"
  on public.debts;
create policy "debts are private to their owner"
  on public.debts for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "goals are private to their owner"
  on public.goals;
create policy "goals are private to their owner"
  on public.goals for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "transactions are private to their owner"
  on public.transactions;
create policy "transactions are private to their owner"
  on public.transactions for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Replication --------------------------------------------------------------
-- PowerSync reads changes from this publication. Every synced table must be
-- listed, and PowerSync fails its connection test outright if the publication
-- is missing.
--
-- `set table` replaces the list, so re-running this after adding a table is
-- the way to register it — no separate ALTER needed.

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'powersync')
  then
    create publication powersync for table
      public.accounts,
      public.categories,
      public.currencies,
      public.debts,
      public.goals,
      public.transactions;
  else
    alter publication powersync set table
      public.accounts,
      public.categories,
      public.currencies,
      public.debts,
      public.goals,
      public.transactions;
  end if;
end
$$;
