-- Undoes seed_demo_transactions.sql.
--
-- Deletes one user's transactions whose note carries the seed tag, and nothing
-- else. Real entries are written by the app with no note at all, so this cannot
-- reach them — but the tag is the whole safety net, so keep `v_tag` in step with
-- the seed script.
--
-- A hard delete, not the app's soft delete. PowerSync turns a removed Postgres
-- row into a REMOVE for the buckets it was in, so devices drop their local copy
-- on the next sync — nothing is left behind to tombstone. The app's own deletes
-- are soft for a different reason: a client cannot tell "deleted" from "not
-- arrived yet", which is not a problem the server has.
--
-- If you would rather keep the rows and only hide them, swap the delete for:
--
--   update public.transactions
--      set deleted_at = now(), updated_at = now()
--    where owner_id = v_owner and note like v_tag || '%' and deleted_at is null;

do $$
declare
  -- ── configuration ────────────────────────────────────────────────────────
  v_owner_email text := 'max3047380@mail.ru';
  v_tag         text := 'seed:demo';
  -- ─────────────────────────────────────────────────────────────────────────

  v_owner   uuid;
  v_removed int;
begin
  select id into v_owner from auth.users where email = v_owner_email;
  if v_owner is null then
    raise exception 'no user with email %', v_owner_email;
  end if;

  delete from public.transactions
  where owner_id = v_owner
    and note like v_tag || '%';

  get diagnostics v_removed = row_count;

  raise notice
    'removed % seeded transactions for % (tag "%")',
    v_removed, v_owner_email, v_tag;
end
$$;
