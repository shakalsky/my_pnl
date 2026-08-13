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
--
-- Re-runnable from top to bottom. The one-time backfill near the end is written
-- to be idempotent too, so running this again after a deploy changes nothing.

-- Needed for uuid_generate_v5 below, which is how the server works out the same
-- derived ids the client does. Supabase keeps extensions in their own schema.
create extension if not exists "uuid-ossp" with schema extensions;

-- Ledgers -------------------------------------------------------------------
-- A ledger is a book of records: one set of categories, one set of
-- transactions, one goal. Every other table carries a `ledger_id` saying which
-- book its row belongs to.
--
-- This is what a family account is. Two people whose rows carry the same
-- `ledger_id` see one set of totals, while their own books stay separate — and
-- `owner_id` on those rows stops meaning "who may read this" and starts meaning
-- "who wrote it".

create table if not exists public.ledgers (
  id          uuid        primary key,
  -- Who created it. Decides who may rename it or change the invite code, and
  -- nothing else: who may *read* it is public.ledger_members.
  owner_id    uuid        not null references auth.users (id) on delete cascade,
  name        text        not null,
  kind        text        not null check (kind in ('personal', 'family')),
  -- What a partner types to join. Null on a personal ledger, which nobody else
  -- can join. Changing it revokes every unused invite, which is the only way to
  -- take one back.
  invite_code text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

-- One live ledger per code, so `join_ledger_by_code` cannot be ambiguous. The
-- client generates codes at random and retries on collision; this is what makes
-- a collision fail rather than silently share the wrong book.
create unique index if not exists ledgers_invite_code_idx
  on public.ledgers (invite_code)
  where invite_code is not null and deleted_at is null;

-- Who may read a ledger. The sync rules bucket on this table, so a row here is
-- exactly what puts a ledger's data on a device.
--
-- Rows are hard-deleted when someone leaves, unlike everything else in this
-- schema. A tombstoned access grant that still grants access is worse than a
-- removal nobody can audit, and the sync-rule parameter query cannot filter on
-- `deleted_at` — see powersync/sync_rules.yaml.
create table if not exists public.ledger_members (
  id           uuid        primary key,
  ledger_id    uuid        not null references public.ledgers (id) on delete cascade,
  user_id      uuid        not null references auth.users (id) on delete cascade,
  -- What to call this member beside their entries. Written by their own device
  -- from their sign-in email: auth.users is not readable by clients, so a
  -- partner's name has to travel as ordinary synced data or not at all.
  display_name text,
  role         text        not null check (role in ('owner', 'member')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

-- One membership per person per ledger. The client derives the id from the pair
-- so two devices joining at once write one row; this is the backstop.
create unique index if not exists ledger_members_ledger_user_idx
  on public.ledger_members (ledger_id, user_id);

create index if not exists ledger_members_user_idx
  on public.ledger_members (user_id);

-- Is the caller in this ledger?
--
-- `security definer`, which is not a shortcut but the point: a policy on
-- ledger_members that queried ledger_members through RLS would recurse until
-- Postgres gave up. Running the lookup as the function's owner skips the
-- policies inside it, so the recursion never starts.
--
-- `stable` so the planner calls it once per query rather than once per row.
create or replace function public.is_ledger_member(ledger uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.ledger_members m
    where m.ledger_id = ledger
      and m.user_id = auth.uid()
  );
$$;

-- How many books of their own the caller has, and whether they are already in a
-- family account.
--
-- The limits: three personal accounts, one family account. Enforced here as well
-- as on the client, because the client's copy of the count is only as good as the
-- client — and a device that has been offline can be looking at a list a book out
-- of date.
--
-- `security definer` for the same reason as above: the count has to see rows the
-- caller's own policies would filter, and running it as the owner keeps a policy
-- from querying the table it is protecting.
--
-- Counting personal books by owner rather than by membership is the same set:
-- nobody else is ever in one. Counting family accounts by *membership* is the
-- point of the limit — one the caller joined counts against it exactly as one
-- they created does.
create or replace function public.personal_ledger_count()
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int
  from public.ledgers l
  where l.owner_id = auth.uid()
    and l.kind = 'personal'
    and l.deleted_at is null;
$$;

create or replace function public.family_ledger_count()
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int
  from public.ledger_members m
  join public.ledgers l on l.id = m.ledger_id
  where m.user_id = auth.uid()
    and l.kind = 'family'
    and l.deleted_at is null;
$$;

-- Joins the caller to the family account with this code.
--
-- A function rather than an insert from the client, because a client cannot
-- look the ledger up: sync only ever delivers ledgers you are already in, so
-- there is nothing on the device to match a code against. `security definer` is
-- what lets the lookup see a ledger the caller has no access to yet — and the
-- only thing it will tell them about it is its id, once they are in.
--
-- Idempotent: joining twice, or from two devices, lands on the same derived id
-- and updates the name instead of adding a second membership.
create or replace function public.join_ledger_by_code(
  code text,
  member_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  target_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in to join a family account'
      using errcode = '28000';
  end if;

  select l.id into target_id
  from public.ledgers l
  where l.invite_code = upper(btrim(code))
    and l.kind = 'family'
    and l.deleted_at is null
  limit 1;

  if target_id is null then
    raise exception 'No family account with that code'
      using errcode = 'P0002';
  end if;

  -- One family account per person. Excluding the target is what keeps redeeming
  -- the same code twice idempotent — a second device joining the book this
  -- caller is already in must not be told they are in one too many.
  if exists (
    select 1
    from public.ledger_members m
    join public.ledgers l on l.id = m.ledger_id
    where m.user_id = auth.uid()
      and l.kind = 'family'
      and l.deleted_at is null
      and l.id <> target_id
  ) then
    raise exception
      'You are already in a family account. Leave it before joining another.'
      using errcode = '23505';
  end if;

  insert into public.ledger_members (id, ledger_id, user_id, display_name, role)
  values (
    extensions.uuid_generate_v5(
      extensions.uuid_ns_url(),
      'ledger-member:' || target_id::text || ':' || auth.uid()::text
    ),
    target_id,
    auth.uid(),
    member_name,
    'member'
  )
  on conflict (id) do update
    set display_name =
          coalesce(excluded.display_name, ledger_members.display_name),
        updated_at = now();

  return target_id;
end;
$$;

revoke execute on function public.join_ledger_by_code(text, text) from public;
grant execute on function public.join_ledger_by_code(text, text) to authenticated;

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

-- How much is being saved up. One live row per ledger — in a family account
-- that is one goal the household shares, which is the only reading that agrees
-- with the shared total it is measured against.
create table if not exists public.goals (
  id                   uuid        primary key,
  owner_id             uuid        not null references auth.users (id) on delete cascade,
  -- Scaled by 100, like every other amount. See lib/database/scales.dart.
  target_amount_scaled bigint      not null check (target_amount_scaled > 0),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

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

-- Which ledger each row belongs to ------------------------------------------
-- Added rather than declared above, because these tables shipped before
-- ledgers existed and rows already on devices have to stay valid.
--
-- Nullable, and that is not laziness: an older build still uploads rows without
-- it, and a NOT NULL here would reject those with a 42501 the connector treats
-- as fatal — the user's spending would be dropped rather than queued. Once
-- app_requirements.min_version rules out every build that predates this,
-- `alter table ... alter column ledger_id set not null` is safe, and the `or
-- owner_id = auth.uid()` clauses in the policies below can go with it.

alter table public.accounts
  add column if not exists ledger_id uuid references public.ledgers (id);
alter table public.categories
  add column if not exists ledger_id uuid references public.ledgers (id);
alter table public.currencies
  add column if not exists ledger_id uuid references public.ledgers (id);
alter table public.debts
  add column if not exists ledger_id uuid references public.ledgers (id);
alter table public.goals
  add column if not exists ledger_id uuid references public.ledgers (id);
alter table public.transactions
  add column if not exists ledger_id uuid references public.ledgers (id);

-- Only where a unique index below does not already cover the column: every read
-- in the app starts by narrowing to one ledger, so this is the entry point for
-- all of them.
create index if not exists accounts_ledger_idx
  on public.accounts (ledger_id);
create index if not exists debts_ledger_settled_idx
  on public.debts (ledger_id, settled_at);
create index if not exists transactions_ledger_executed_at_idx
  on public.transactions (ledger_id, executed_at desc);

-- Uniqueness moved from the owner to the ledger. In a family account the
-- categories are shared, so two partners must not be able to keep a "Food"
-- each — the grid would show both and the totals would split between them.
drop index if exists public.categories_owner_name_idx;
drop index if exists public.currencies_owner_ticker_idx;
drop index if exists public.goals_owner_idx;

-- One live category name per ledger, case-insensitive. Partial, so a deleted
-- category does not block reusing its name.
create unique index if not exists categories_ledger_name_idx
  on public.categories (ledger_id, lower(name))
  where deleted_at is null;

-- One live row per ticker per ledger. Partial, so a tombstoned currency does
-- not block re-adding it later.
create unique index if not exists currencies_ledger_ticker_idx
  on public.currencies (ledger_id, ticker)
  where deleted_at is null;

-- One live goal per ledger. Partial, so a cleared goal does not block setting a
-- new one. Saving a goal updates the existing row rather than inserting.
create unique index if not exists goals_ledger_idx
  on public.goals (ledger_id)
  where deleted_at is null;

-- Backfill ------------------------------------------------------------------
-- Everything that existed before ledgers did belongs to its owner's personal
-- book. This gives every user one and points their rows at it.
--
-- The ids are UUIDv5 over the same strings `personalLedgerId` and
-- `ledgerMemberId` hash in lib/database/tables/ledgers.dart, so the server and
-- the client independently arrive at the same uuid. That is what stops a device
-- that has not synced yet from creating a *second* personal ledger — the insert
-- it makes collides with this row instead.
--
-- Idempotent: `on conflict do nothing`, and the updates only touch nulls.

insert into public.ledgers (id, owner_id, name, kind)
select
  extensions.uuid_generate_v5(
    extensions.uuid_ns_url(), 'ledger:personal:' || u.id::text
  ),
  u.id,
  'Personal',
  'personal'
from auth.users u
on conflict (id) do nothing;

insert into public.ledger_members (id, ledger_id, user_id, role)
select
  extensions.uuid_generate_v5(
    extensions.uuid_ns_url(),
    'ledger-member:'
      || extensions.uuid_generate_v5(
           extensions.uuid_ns_url(), 'ledger:personal:' || u.id::text
         )::text
      || ':' || u.id::text
  ),
  extensions.uuid_generate_v5(
    extensions.uuid_ns_url(), 'ledger:personal:' || u.id::text
  ),
  u.id,
  'owner'
from auth.users u
on conflict (id) do nothing;

do $$
declare
  target text;
begin
  foreach target in array
    array['accounts', 'categories', 'currencies', 'debts', 'goals',
          'transactions']
  loop
    execute format(
      'update public.%I set ledger_id = extensions.uuid_generate_v5('
      || 'extensions.uuid_ns_url(), ''ledger:personal:'' || owner_id::text) '
      || 'where ledger_id is null',
      target
    );
  end loop;
end
$$;

-- Row level security -------------------------------------------------------
-- Uploads go through the ordinary Supabase client, so these policies are what
-- actually protects the data. A policy failure surfaces as Postgres 42501,
-- which SupabaseConnector treats as fatal and discards rather than retrying.
--
-- Two rules run through everything below, and the difference between them is
-- the whole of what "each partner sees both, edits their own" means:
--
--  * READ is by ledger. Anyone in the ledger sees every row in it. This is what
--    puts a partner's spending into the wheel, the category tiles and the
--    all-transactions list.
--  * WRITE is by ledger for the furniture — accounts, categories, currencies,
--    debts, the goal — because a shared book whose categories only one partner
--    could edit would be unusable. It is by *author* for `transactions`, so
--    neither partner can alter or delete what the other recorded.
--
-- The trailing `or owner_id = auth.uid()` on the read policies covers rows an
-- older build uploaded with no ledger_id; see the note on the columns above.
--
-- There is deliberately no DELETE policy on any of these tables. Every removal
-- in the app is a tombstone — `deleted_at` set through the UPDATE policies — so
-- a real DELETE reaching Postgres would mean a bug, and refusing it is how that
-- bug stays visible instead of quietly destroying history. `ledger_members` is
-- the one exception, for the reason given on the table.

alter table public.accounts        enable row level security;
alter table public.app_requirements enable row level security;
alter table public.categories      enable row level security;
alter table public.currencies      enable row level security;
alter table public.debts           enable row level security;
alter table public.goals           enable row level security;
alter table public.ledgers         enable row level security;
alter table public.ledger_members  enable row level security;
alter table public.transactions    enable row level security;

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

-- Ledgers. `or owner_id = auth.uid()` on the read is not redundant: the creator
-- inserts the ledger and their membership as two statements, and between them
-- the membership check below has to be able to see the ledger it names.
drop policy if exists "members may read their ledgers" on public.ledgers;
create policy "members may read their ledgers"
  on public.ledgers for select
  using (public.is_ledger_member(id) or owner_id = auth.uid());

-- The limits live on the insert, which is the one place a client cannot go
-- around them. `personal_ledger_count()` runs against the command's snapshot, so
-- the row being inserted is not in it: `< 3` means "three already" and refuses
-- the fourth.
drop policy if exists "you may create your own ledgers" on public.ledgers;
create policy "you may create your own ledgers"
  on public.ledgers for insert
  with check (
    owner_id = auth.uid()
    and case kind
      when 'personal' then public.personal_ledger_count() < 3
      when 'family' then public.family_ledger_count() = 0
      -- No third kind exists. Refusing rather than allowing means a client that
      -- invents one cannot use it to sidestep either count above.
      else false
    end
  );

-- Renaming, and rotating the invite code, belong to whoever created the book.
-- A partner who could rotate the code could lock the creator's other invites
-- out of a book that is not theirs.
drop policy if exists "the creator may change a ledger" on public.ledgers;
create policy "the creator may change a ledger"
  on public.ledgers for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Memberships. Reading them is how a device learns what to call a partner
-- beside their entries.
drop policy if exists "members may read the membership list"
  on public.ledger_members;
create policy "members may read the membership list"
  on public.ledger_members for select
  using (public.is_ledger_member(ledger_id) or user_id = auth.uid());

-- Only ever yourself, and only into a ledger you created. Joining someone
-- else's family account goes through `join_ledger_by_code`, which is the only
-- thing that can check a code — this policy exists for the creator adding
-- themselves to the ledger they have just made.
drop policy if exists "you may add yourself to a ledger you own"
  on public.ledger_members;
create policy "you may add yourself to a ledger you own"
  on public.ledger_members for insert
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.ledgers l
      where l.id = ledger_id and l.owner_id = auth.uid()
    )
  );

-- Your own row only: this is how a device writes the name shown beside its
-- entries.
drop policy if exists "you may edit your own membership"
  on public.ledger_members;
create policy "you may edit your own membership"
  on public.ledger_members for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Leaving, or being removed by whoever created the ledger. A hard delete, for
-- the reason given on the table.
drop policy if exists "you may leave, and the creator may remove you"
  on public.ledger_members;
create policy "you may leave, and the creator may remove you"
  on public.ledger_members for delete
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.ledgers l
      where l.id = ledger_id and l.owner_id = auth.uid()
    )
  );

-- The shared furniture: readable and writable by anyone in the ledger. Inserts
-- still have to be honest about who made them, because `owner_id` is what
-- labels a row's author.

drop policy if exists "accounts are private to their owner" on public.accounts;
drop policy if exists "ledger members may read accounts" on public.accounts;
create policy "ledger members may read accounts"
  on public.accounts for select
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid());

drop policy if exists "ledger members may write accounts" on public.accounts;
create policy "ledger members may write accounts"
  on public.accounts for insert
  with check (
    owner_id = auth.uid()
    and (ledger_id is null or public.is_ledger_member(ledger_id))
  );

drop policy if exists "ledger members may change accounts" on public.accounts;
create policy "ledger members may change accounts"
  on public.accounts for update
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid())
  with check (ledger_id is null or public.is_ledger_member(ledger_id));

drop policy if exists "categories are private to their owner"
  on public.categories;
drop policy if exists "ledger members may read categories" on public.categories;
create policy "ledger members may read categories"
  on public.categories for select
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid());

drop policy if exists "ledger members may write categories"
  on public.categories;
create policy "ledger members may write categories"
  on public.categories for insert
  with check (
    owner_id = auth.uid()
    and (ledger_id is null or public.is_ledger_member(ledger_id))
  );

drop policy if exists "ledger members may change categories"
  on public.categories;
create policy "ledger members may change categories"
  on public.categories for update
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid())
  with check (ledger_id is null or public.is_ledger_member(ledger_id));

drop policy if exists "currencies are private to their owner"
  on public.currencies;
drop policy if exists "ledger members may read currencies" on public.currencies;
create policy "ledger members may read currencies"
  on public.currencies for select
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid());

drop policy if exists "ledger members may write currencies"
  on public.currencies;
create policy "ledger members may write currencies"
  on public.currencies for insert
  with check (
    owner_id = auth.uid()
    and (ledger_id is null or public.is_ledger_member(ledger_id))
  );

drop policy if exists "ledger members may change currencies"
  on public.currencies;
create policy "ledger members may change currencies"
  on public.currencies for update
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid())
  with check (ledger_id is null or public.is_ledger_member(ledger_id));

drop policy if exists "debts are private to their owner" on public.debts;
drop policy if exists "ledger members may read debts" on public.debts;
create policy "ledger members may read debts"
  on public.debts for select
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid());

drop policy if exists "ledger members may write debts" on public.debts;
create policy "ledger members may write debts"
  on public.debts for insert
  with check (
    owner_id = auth.uid()
    and (ledger_id is null or public.is_ledger_member(ledger_id))
  );

drop policy if exists "ledger members may change debts" on public.debts;
create policy "ledger members may change debts"
  on public.debts for update
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid())
  with check (ledger_id is null or public.is_ledger_member(ledger_id));

drop policy if exists "goals are private to their owner" on public.goals;
drop policy if exists "ledger members may read the goal" on public.goals;
create policy "ledger members may read the goal"
  on public.goals for select
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid());

drop policy if exists "ledger members may write the goal" on public.goals;
create policy "ledger members may write the goal"
  on public.goals for insert
  with check (
    owner_id = auth.uid()
    and (ledger_id is null or public.is_ledger_member(ledger_id))
  );

drop policy if exists "ledger members may change the goal" on public.goals;
create policy "ledger members may change the goal"
  on public.goals for update
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid())
  with check (ledger_id is null or public.is_ledger_member(ledger_id));

-- Entries are the exception. Both partners read them — that is the point of a
-- family account — but `owner_id = auth.uid()` on every write is what keeps one
-- partner from editing or deleting what the other recorded. The client enforces
-- the same rule so the UI does not offer what this would refuse; this is what
-- makes it true.

drop policy if exists "transactions are private to their owner"
  on public.transactions;
drop policy if exists "ledger members may read transactions"
  on public.transactions;
create policy "ledger members may read transactions"
  on public.transactions for select
  using (public.is_ledger_member(ledger_id) or owner_id = auth.uid());

drop policy if exists "you may write your own transactions"
  on public.transactions;
create policy "you may write your own transactions"
  on public.transactions for insert
  with check (
    owner_id = auth.uid()
    and (ledger_id is null or public.is_ledger_member(ledger_id))
  );

drop policy if exists "you may change your own transactions"
  on public.transactions;
create policy "you may change your own transactions"
  on public.transactions for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

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
      public.ledgers,
      public.ledger_members,
      public.transactions;
  else
    alter publication powersync set table
      public.accounts,
      public.categories,
      public.currencies,
      public.debts,
      public.goals,
      public.ledgers,
      public.ledger_members,
      public.transactions;
  end if;
end
$$;
