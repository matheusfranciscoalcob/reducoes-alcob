-- Projeto isolado: reducoes-alcob
-- Histórico compartilhado de corridas, amostras e laudos.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.elements (
  symbol text primary key,
  display_order integer not null,
  is_default boolean not null default false,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  constraint elements_symbol_format check (
    symbol in ('Base (Cu)', 'Cu+Ag') or symbol ~ '^[A-Z][a-z]?$'
  )
);

create table public.runs (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  run_date date not null,
  shift text not null check (shift in ('A (06-14h)', 'B (14-22h)', 'C (22-06h)')),
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.samples (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.runs(id) on delete cascade,
  sample_order integer not null check (sample_order > 0),
  chemical_data jsonb not null default '{}'::jsonb,
  photo_path text,
  photo_name text,
  ocr_confidence numeric(5,2),
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  unique (run_id, sample_order),
  constraint samples_chemical_data_object check (jsonb_typeof(chemical_data) = 'object')
);

create index runs_run_date_idx on public.runs (run_date desc, created_at desc);
create index samples_run_id_idx on public.samples (run_id, sample_order);

create trigger runs_set_updated_at
before update on public.runs
for each row execute function public.set_updated_at();

alter table public.elements enable row level security;
alter table public.runs enable row level security;
alter table public.samples enable row level security;

create policy "authenticated users read elements"
on public.elements for select to authenticated using (true);
create policy "authenticated users add elements"
on public.elements for insert to authenticated with check (auth.uid() is not null);
create policy "authenticated users update elements"
on public.elements for update to authenticated using (true) with check (auth.uid() is not null);

create policy "authenticated users read runs"
on public.runs for select to authenticated using (true);
create policy "authenticated users create runs"
on public.runs for insert to authenticated with check (created_by = auth.uid());
create policy "authenticated users update runs"
on public.runs for update to authenticated using (true) with check (auth.uid() is not null);
create policy "authenticated users delete runs"
on public.runs for delete to authenticated using (true);

create policy "authenticated users read samples"
on public.samples for select to authenticated using (true);
create policy "authenticated users create samples"
on public.samples for insert to authenticated with check (created_by = auth.uid());
create policy "authenticated users update samples"
on public.samples for update to authenticated using (true) with check (auth.uid() is not null);
create policy "authenticated users delete samples"
on public.samples for delete to authenticated using (true);

grant usage on schema public to authenticated;
grant select, insert, update on public.elements to authenticated;
grant select, insert, update, delete on public.runs to authenticated;
grant select, insert, update, delete on public.samples to authenticated;

insert into public.elements (symbol, display_order, is_default)
values
  ('Base (Cu)', 10, true), ('Pb', 20, true), ('Ni', 30, true),
  ('Sn', 40, true), ('Ag', 50, true), ('Zn', 60, true),
  ('Fe', 70, true), ('Sb', 80, true), ('Te', 90, true),
  ('P', 100, true), ('S', 110, true), ('As', 120, true),
  ('Se', 130, true), ('Ti', 140, true), ('Hg', 150, true),
  ('B', 160, true), ('Cr', 170, true), ('Si', 180, true),
  ('Al', 190, true), ('Bi', 200, true), ('Co', 210, true),
  ('Mn', 220, true), ('Cd', 230, true), ('Mg', 240, true),
  ('Zr', 250, true), ('Cu+Ag', 260, true)
on conflict (symbol) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'lab-reports',
  'lab-reports',
  false,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "authenticated users read lab reports"
on storage.objects for select to authenticated
using (bucket_id = 'lab-reports');

create policy "authenticated users upload lab reports"
on storage.objects for insert to authenticated
with check (bucket_id = 'lab-reports' and auth.uid() is not null);

create policy "authenticated users update lab reports"
on storage.objects for update to authenticated
using (bucket_id = 'lab-reports')
with check (bucket_id = 'lab-reports' and auth.uid() is not null);

create policy "authenticated users delete lab reports"
on storage.objects for delete to authenticated
using (bucket_id = 'lab-reports');
