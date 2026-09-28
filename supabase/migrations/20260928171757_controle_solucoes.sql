-- Controle compartilhado das solucoes de oleo soluvel e decapagem.
-- O modulo reutiliza a aprovacao de acesso do projeto reducoes-alcob.

create table public.solution_measurements (
  id text primary key,
  system text not null check (system in ('oil', 'pickling')),
  measured_at timestamptz not null,
  payload jsonb not null default '{}'::jsonb,
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint solution_measurements_payload_object check (jsonb_typeof(payload) = 'object')
);

create table public.solution_calibrations (
  record_id text primary key references public.solution_measurements(id) on delete cascade,
  system text not null check (system in ('oil', 'pickling')),
  payload jsonb not null default '{}'::jsonb,
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint solution_calibrations_payload_object check (jsonb_typeof(payload) = 'object')
);

create table public.solution_settings (
  system text primary key check (system in ('oil', 'pickling')),
  config jsonb not null default '{}'::jsonb,
  adaptive_enabled boolean not null default true,
  updated_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  updated_at timestamptz not null default now(),
  constraint solution_settings_config_object check (jsonb_typeof(config) = 'object')
);

create table public.solution_annotations (
  measurement_id text primary key references public.solution_measurements(id) on delete cascade,
  system text not null check (system in ('oil', 'pickling')),
  ph text,
  alkalinity text,
  dirt text,
  updated_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  updated_at timestamptz not null default now()
);

create table public.solution_photos (
  id text primary key,
  measurement_id text not null references public.solution_measurements(id) on delete cascade,
  system text not null check (system in ('oil', 'pickling')),
  storage_path text not null unique,
  original_name text not null,
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  added_at timestamptz not null default now()
);

create index solution_measurements_system_date_idx
on public.solution_measurements (system, measured_at desc);

create index solution_calibrations_system_idx
on public.solution_calibrations (system);

create index solution_photos_measurement_idx
on public.solution_photos (measurement_id, added_at);

create trigger solution_measurements_set_updated_at
before update on public.solution_measurements
for each row execute function public.set_updated_at();

create trigger solution_calibrations_set_updated_at
before update on public.solution_calibrations
for each row execute function public.set_updated_at();

alter table public.solution_measurements enable row level security;
alter table public.solution_calibrations enable row level security;
alter table public.solution_settings enable row level security;
alter table public.solution_annotations enable row level security;
alter table public.solution_photos enable row level security;

create policy "approved users read solution measurements"
on public.solution_measurements for select to authenticated
using ((select private.is_approved()));

create policy "approved users create solution measurements"
on public.solution_measurements for insert to authenticated
with check ((select private.is_approved()) and created_by = (select auth.uid()));

create policy "approved users update solution measurements"
on public.solution_measurements for update to authenticated
using ((select private.is_approved()))
with check ((select private.is_approved()));

create policy "approved users delete solution measurements"
on public.solution_measurements for delete to authenticated
using ((select private.is_approved()));

create policy "approved users read solution calibrations"
on public.solution_calibrations for select to authenticated
using ((select private.is_approved()));

create policy "approved users create solution calibrations"
on public.solution_calibrations for insert to authenticated
with check ((select private.is_approved()) and created_by = (select auth.uid()));

create policy "approved users update solution calibrations"
on public.solution_calibrations for update to authenticated
using ((select private.is_approved()))
with check ((select private.is_approved()));

create policy "approved users delete solution calibrations"
on public.solution_calibrations for delete to authenticated
using ((select private.is_approved()));

create policy "approved users read solution settings"
on public.solution_settings for select to authenticated
using ((select private.is_approved()));

create policy "approved users create solution settings"
on public.solution_settings for insert to authenticated
with check ((select private.is_approved()) and updated_by = (select auth.uid()));

create policy "approved users update solution settings"
on public.solution_settings for update to authenticated
using ((select private.is_approved()))
with check ((select private.is_approved()) and updated_by = (select auth.uid()));

create policy "approved users read solution annotations"
on public.solution_annotations for select to authenticated
using ((select private.is_approved()));

create policy "approved users create solution annotations"
on public.solution_annotations for insert to authenticated
with check ((select private.is_approved()) and updated_by = (select auth.uid()));

create policy "approved users update solution annotations"
on public.solution_annotations for update to authenticated
using ((select private.is_approved()))
with check ((select private.is_approved()) and updated_by = (select auth.uid()));

create policy "approved users delete solution annotations"
on public.solution_annotations for delete to authenticated
using ((select private.is_approved()));

create policy "approved users read solution photos"
on public.solution_photos for select to authenticated
using ((select private.is_approved()));

create policy "approved users create solution photos"
on public.solution_photos for insert to authenticated
with check ((select private.is_approved()) and created_by = (select auth.uid()));

create policy "approved users delete solution photos"
on public.solution_photos for delete to authenticated
using ((select private.is_approved()));

grant select, insert, update, delete on public.solution_measurements to authenticated;
grant select, insert, update, delete on public.solution_calibrations to authenticated;
grant select, insert, update on public.solution_settings to authenticated;
grant select, insert, update, delete on public.solution_annotations to authenticated;
grant select, insert, delete on public.solution_photos to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'solution-sample-photos',
  'solution-sample-photos',
  false,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "approved users read solution sample photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'solution-sample-photos'
  and (select private.is_approved())
);

create policy "approved users upload solution sample photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'solution-sample-photos'
  and (select private.is_approved())
  and owner_id = (select auth.uid()::text)
);

create policy "approved users update solution sample photos"
on storage.objects for update to authenticated
using (
  bucket_id = 'solution-sample-photos'
  and (select private.is_approved())
)
with check (
  bucket_id = 'solution-sample-photos'
  and (select private.is_approved())
);

create policy "approved users delete solution sample photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'solution-sample-photos'
  and (select private.is_approved())
);
