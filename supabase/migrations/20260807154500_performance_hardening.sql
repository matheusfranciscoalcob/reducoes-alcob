create index if not exists elements_created_by_idx on public.elements (created_by);
create index if not exists runs_created_by_idx on public.runs (created_by);
create index if not exists samples_created_by_idx on public.samples (created_by);

drop policy if exists "authenticated users add elements" on public.elements;
create policy "authenticated users add elements"
on public.elements for insert
to authenticated
with check (created_by = (select auth.uid()));

drop policy if exists "authenticated users update elements" on public.elements;
create policy "authenticated users update elements"
on public.elements for update
to authenticated
using (true)
with check ((select auth.uid()) is not null);

drop policy if exists "authenticated users create runs" on public.runs;
create policy "authenticated users create runs"
on public.runs for insert
to authenticated
with check (created_by = (select auth.uid()));

drop policy if exists "authenticated users update runs" on public.runs;
create policy "authenticated users update runs"
on public.runs for update
to authenticated
using (true)
with check ((select auth.uid()) is not null);

drop policy if exists "authenticated users create samples" on public.samples;
create policy "authenticated users create samples"
on public.samples for insert
to authenticated
with check (created_by = (select auth.uid()));

drop policy if exists "authenticated users update samples" on public.samples;
create policy "authenticated users update samples"
on public.samples for update
to authenticated
using (true)
with check ((select auth.uid()) is not null);
