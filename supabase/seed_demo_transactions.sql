-- Fills one user's ledger with six months of made-up transactions.
--
-- Run it in the Supabase SQL editor, where the postgres role bypasses RLS —
-- `auth.uid()` is null there, so the owner is resolved by email below instead.
--
-- Every row it writes carries the tag in `v_tag` at the front of its note, and
-- remove_demo_transactions.sql deletes exactly the rows carrying that tag. Keep
-- the two in step if you change it.
--
-- What it deliberately copies from the app, because the overview reads the data
-- back on these assumptions (see transaction_local_data_source.dart):
--
--   * `side` is always 'buy'. The app never writes 'sell'; the direction of the
--     money is carried by the sign of the amount, not by this column.
--   * income is stored positive and spending negative, which is what makes the
--     headline figure a plain SUM.
--   * amounts are integers scaled by 100. Never a float.
--   * months are UTC months, which is how the overview groups them. Truncating
--     in the session's timezone would spill rows into a neighbouring month for
--     any user not on UTC.
--
-- Ids are generated server-side here. The no-default rule in schema.sql is
-- about idempotent uploads from a client that may retry offline; a one-shot
-- seed has no retry to be idempotent about.

do $$
declare
  -- ── configuration ────────────────────────────────────────────────────────
  v_owner_email     text := 'max3047380@mail.ru';
  v_months          int  := 6;      -- including the month happening now
  v_min_per_month   int  := 6;      -- expense entries, per month
  v_max_per_month   int  := 14;
  v_min_expense     bigint := 250;     -- $2.50, scaled by 100
  v_max_expense     bigint := 25000;   -- $250.00
  v_min_income      bigint := 150000;  -- $1,500.00
  v_max_income      bigint := 400000;  -- $4,000.00
  v_tag             text := 'seed:demo';
  -- ─────────────────────────────────────────────────────────────────────────

  v_owner       uuid;
  v_account     uuid;
  v_currency    text;
  v_expense     uuid[];
  v_income      uuid[];
  v_month_start timestamptz;
  v_month_end   timestamptz;
  v_executed_at timestamptz;
  v_amount      bigint;
  v_category    uuid;
  v_per_month   int;
  v_written     int := 0;
  m             int;
  i             int;
begin
  select id into v_owner from auth.users where email = v_owner_email;
  if v_owner is null then
    raise exception 'no user with email %', v_owner_email;
  end if;

  -- The account the app itself books against: the oldest live one, which is the
  -- 'Cash' row it creates on first use.
  select id, currency into v_account, v_currency
  from public.accounts
  where owner_id = v_owner and deleted_at is null
  order by created_at
  limit 1;

  if v_account is null then
    raise exception
      'user % has no account — open the app once so it creates "Cash"',
      v_owner_email;
  end if;

  select array_agg(id order by created_at) into v_expense
  from public.categories
  where owner_id = v_owner and deleted_at is null and kind = 'expense';

  select array_agg(id order by created_at) into v_income
  from public.categories
  where owner_id = v_owner and deleted_at is null and kind = 'income';

  if v_expense is null then
    raise exception
      'user % has no expense categories — add a few in the app first',
      v_owner_email;
  end if;

  -- Oldest month first, so created_at runs the same way as executed_at.
  for m in reverse v_months - 1 .. 0 loop
    v_month_start :=
      (date_trunc('month', now() at time zone 'utc')
        - make_interval(months => m)) at time zone 'utc';

    -- Nothing can have been spent in the part of this month that has not
    -- happened yet, and the app refuses to page past the current month anyway.
    v_month_end := least(v_month_start + interval '1 month', now());

    -- One income entry per income category per month: a salary lands once, and
    -- the overview's headline is income minus spending, so it needs both sides.
    if v_income is not null then
      foreach v_category in array v_income loop
        v_amount := v_min_income
          + floor(random() * (v_max_income - v_min_income + 1))::bigint;
        v_executed_at :=
          v_month_start + random() * (v_month_end - v_month_start);

        insert into public.transactions (
          id, owner_id, account_id, category_id,
          side, amount_scaled, currency, executed_at, note
        )
        values (
          gen_random_uuid(), v_owner, v_account, v_category,
          'buy', v_amount, v_currency, v_executed_at, v_tag || ' income'
        );

        v_written := v_written + 1;
      end loop;
    end if;

    v_per_month := v_min_per_month
      + floor(random() * (v_max_per_month - v_min_per_month + 1))::int;

    for i in 1 .. v_per_month loop
      v_category := v_expense[1 + floor(random() * array_length(v_expense, 1))::int];
      v_amount := v_min_expense
        + floor(random() * (v_max_expense - v_min_expense + 1))::bigint;
      v_executed_at :=
        v_month_start + random() * (v_month_end - v_month_start);

      insert into public.transactions (
        id, owner_id, account_id, category_id,
        side, amount_scaled, currency, executed_at, note
      )
      values (
        gen_random_uuid(), v_owner, v_account, v_category,
        -- Negative: spending. The sign is the app's only record of which way
        -- the money went.
        'buy', -v_amount, v_currency, v_executed_at, v_tag || ' spend'
      );

      v_written := v_written + 1;
    end loop;
  end loop;

  raise notice
    'seeded % transactions for % across % months, tagged "%"',
    v_written, v_owner_email, v_months, v_tag;
end
$$;
