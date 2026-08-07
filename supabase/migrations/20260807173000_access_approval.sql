-- Acesso por aprovação: somente o aprovador abaixo pode liberar usuários.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table public.user_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  approved boolean not null default false,
  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create unique index user_access_email_lower_idx
on public.user_access (lower(email));

create index user_access_pending_idx
on public.user_access (requested_at)
where approved = false;

create trigger user_access_set_updated_at
before update on public.user_access
for each row execute function public.set_updated_at();

create or replace function private.is_approver()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'matheusferfran2010@gmail.com';
$$;

create or replace function private.is_approved()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and (
      (select private.is_approver())
      or exists (
        select 1
        from public.user_access access
        where access.user_id = (select auth.uid())
          and access.approved = true
      )
    );
$$;

revoke all on function private.is_approver() from public, anon;
revoke all on function private.is_approved() from public, anon;
grant execute on function private.is_approver() to authenticated;
grant execute on function private.is_approved() to authenticated;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  is_owner boolean := lower(coalesce(new.email, '')) = 'matheusferfran2010@gmail.com';
begin
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert or update of email on auth.users
for each row execute function private.handle_new_user();

insert into public.user_access (user_id, email, approved, approved_at)
select
  id,
  lower(email),
  lower(email) = 'matheusferfran2010@gmail.com',
  case when lower(email) = 'matheusferfran2010@gmail.com' then now() else null end
from auth.users
where email is not null
on conflict (user_id) do update
set email = excluded.email;

alter table public.user_access enable row level security;

create policy "users read own access and approver reads all"
on public.user_access for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_approver())
);

create policy "approver manages access"
on public.user_access for update
to authenticated
using ((select private.is_approver()))
with check ((select private.is_approver()));

grant select on public.user_access to authenticated;
grant update (approved, approved_at, approved_by) on public.user_access to authenticated;

drop policy if exists "authenticated users read elements" on public.elements;
drop policy if exists "authenticated users add elements" on public.elements;
drop policy if exists "authenticated users update elements" on public.elements;

create policy "approved users read elements"
on public.elements for select to authenticated
using ((select private.is_approved()));

create policy "approved users add elements"
on public.elements for insert to authenticated
with check (
  (select private.is_approved())
  and created_by = (select auth.uid())
);

create policy "approved users update elements"
on public.elements for update to authenticated
using ((select private.is_approved()))
with check ((select private.is_approved()));

drop policy if exists "authenticated users read runs" on public.runs;
drop policy if exists "authenticated users create runs" on public.runs;
drop policy if exists "authenticated users update runs" on public.runs;
drop policy if exists "authenticated users delete runs" on public.runs;

create policy "approved users read runs"
on public.runs for select to authenticated
using ((select private.is_approved()));

create policy "approved users create runs"
on public.runs for insert to authenticated
with check (
  (select private.is_approved())
  and created_by = (select auth.uid())
);

create policy "approved users update runs"
on public.runs for update to authenticated
using ((select private.is_approved()))
with check ((select private.is_approved()));

create policy "approved users delete runs"
on public.runs for delete to authenticated
using ((select private.is_approved()));

drop policy if exists "authenticated users read samples" on public.samples;
drop policy if exists "authenticated users create samples" on public.samples;
drop policy if exists "authenticated users update samples" on public.samples;
drop policy if exists "authenticated users delete samples" on public.samples;

create policy "approved users read samples"
on public.samples for select to authenticated
using ((select private.is_approved()));

create policy "approved users create samples"
on public.samples for insert to authenticated
with check (
  (select private.is_approved())
  and created_by = (select auth.uid())
);

create policy "approved users update samples"
on public.samples for update to authenticated
using ((select private.is_approved()))
with check ((select private.is_approved()));

create policy "approved users delete samples"
on public.samples for delete to authenticated
using ((select private.is_approved()));

drop policy if exists "authenticated users read lab reports" on storage.objects;
drop policy if exists "authenticated users upload lab reports" on storage.objects;
drop policy if exists "authenticated users update lab reports" on storage.objects;
drop policy if exists "authenticated users delete lab reports" on storage.objects;

create policy "approved users read lab reports"
on storage.objects for select to authenticated
using (
  bucket_id = 'lab-reports'
  and (select private.is_approved())
);

create policy "approved users upload lab reports"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'lab-reports'
  and (select private.is_approved())
);

create policy "approved users update lab reports"
on storage.objects for update to authenticated
using (
  bucket_id = 'lab-reports'
  and (select private.is_approved())
)
with check (
  bucket_id = 'lab-reports'
  and (select private.is_approved())
);

create policy "approved users delete lab reports"
on storage.objects for delete to authenticated
using (
  bucket_id = 'lab-reports'
  and (select private.is_approved())
);
