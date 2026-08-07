create or replace function public.register_element(
  p_symbol text,
  p_display_order integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  inserted_count integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  if not (
    p_symbol in ('Base (Cu)', 'Cu+Ag')
    or p_symbol ~ '^[A-Z][a-z]?$'
  ) then
    raise exception 'Invalid chemical element: %', p_symbol;
  end if;

  insert into public.elements (symbol, display_order, is_default, created_by)
  values (p_symbol, p_display_order, false, (select auth.uid()))
  on conflict (symbol) do nothing;

  get diagnostics inserted_count = row_count;

  if inserted_count > 0 then
    update public.samples
    set chemical_data = jsonb_set(chemical_data, array[p_symbol], '0'::jsonb, true)
    where not chemical_data ? p_symbol;
  end if;

  return inserted_count > 0;
end;
$$;

revoke all on function public.register_element(text, integer) from public;
revoke all on function public.register_element(text, integer) from anon;
grant execute on function public.register_element(text, integer) to authenticated;
