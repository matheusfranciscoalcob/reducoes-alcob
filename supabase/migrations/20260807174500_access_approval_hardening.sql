create index if not exists user_access_approved_by_idx
on public.user_access (approved_by);

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  is_owner boolean;
begin
  if new.email is null then
    return new;
  end if;

  is_owner := lower(new.email) = 'matheusferfran2010@gmail.com';

  insert into public.user_access (
    user_id,
    email,
    approved,
    approved_at
  )
  values (
    new.id,
    lower(new.email),
    is_owner,
    case when is_owner then now() else null end
  )
  on conflict (user_id) do update
  set email = excluded.email;

  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;
