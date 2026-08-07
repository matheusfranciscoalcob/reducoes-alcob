-- Estrutura o código de cada análise para permitir agrupamento por forno e fornada.
-- Chave operacional da fornada: ano + mês + forno + número da fornada.

alter table public.samples
  add column analysis_code text,
  add column analysis_type text not null default 'unclassified',
  add column code_year smallint,
  add column code_month smallint,
  add column code_day smallint,
  add column furnace_number smallint,
  add column heat_number smallint,
  add column furnace_operator_code smallint,
  add column lab_analyst_code smallint,
  add column analysis_sequence smallint,
  add column jumbo_number smallint;

-- Formato padrão: YYYYDDMM.FHHH.FORNEIRO.ANALISTA.SEQUENCIAL
with parsed as (
  select
    sample.id,
    run.code,
    regexp_match(
      replace(run.code, ',', '.'),
      '^([0-9]{4})([0-9]{2})([0-9]{2})[.]([0-9])([0-9]{3})[.]([0-9]+)[.]([0-9]+)[.]([0-9]+)$'
    ) as parts
  from public.samples as sample
  join public.runs as run on run.id = sample.run_id
)
update public.samples as sample
set
  analysis_code = parsed.code,
  analysis_type = 'standard',
  code_year = (parsed.parts)[1]::smallint,
  code_day = (parsed.parts)[2]::smallint,
  code_month = (parsed.parts)[3]::smallint,
  furnace_number = (parsed.parts)[4]::smallint,
  heat_number = (parsed.parts)[5]::smallint,
  furnace_operator_code = (parsed.parts)[6]::smallint,
  lab_analyst_code = (parsed.parts)[7]::smallint,
  analysis_sequence = (parsed.parts)[8]::smallint
from parsed
where sample.id = parsed.id
  and parsed.parts is not null;

-- Formato de monitoramento: F2.MONITORAMENTO J8
with parsed as (
  select
    sample.id,
    run.code,
    run.run_date,
    regexp_match(
      upper(replace(run.code, ' ', '')),
      '^F([0-9]+)[.]?MONITORAMENTO[.]?J([0-9]+)$'
    ) as parts
  from public.samples as sample
  join public.runs as run on run.id = sample.run_id
)
update public.samples as sample
set
  analysis_code = parsed.code,
  analysis_type = 'jumbo_monitoring',
  code_year = extract(year from parsed.run_date)::smallint,
  code_month = extract(month from parsed.run_date)::smallint,
  code_day = extract(day from parsed.run_date)::smallint,
  furnace_number = (parsed.parts)[1]::smallint,
  jumbo_number = (parsed.parts)[2]::smallint
from parsed
where sample.id = parsed.id
  and parsed.parts is not null;

update public.samples as sample
set analysis_code = run.code
from public.runs as run
where run.id = sample.run_id
  and sample.analysis_code is null;

alter table public.samples
  add constraint samples_analysis_type_check
    check (analysis_type in ('standard', 'jumbo_monitoring', 'unclassified')),
  add constraint samples_code_year_check
    check (code_year is null or code_year between 2000 and 2199),
  add constraint samples_code_month_check
    check (code_month is null or code_month between 1 and 12),
  add constraint samples_code_day_check
    check (code_day is null or code_day between 1 and 31),
  add constraint samples_furnace_number_check
    check (furnace_number is null or furnace_number between 1 and 99),
  add constraint samples_heat_number_check
    check (heat_number is null or heat_number between 0 and 999),
  add constraint samples_furnace_operator_code_check
    check (furnace_operator_code is null or furnace_operator_code between 0 and 999),
  add constraint samples_lab_analyst_code_check
    check (lab_analyst_code is null or lab_analyst_code between 0 and 999),
  add constraint samples_analysis_sequence_check
    check (analysis_sequence is null or analysis_sequence between 0 and 9999),
  add constraint samples_jumbo_number_check
    check (jumbo_number is null or jumbo_number between 0 and 9999);

create index samples_heat_group_idx
on public.samples (
  code_year,
  code_month,
  furnace_number,
  heat_number,
  analysis_sequence,
  created_at
)
where analysis_type = 'standard';

create index samples_jumbo_group_idx
on public.samples (
  code_year,
  code_month,
  furnace_number,
  jumbo_number,
  created_at
)
where analysis_type = 'jumbo_monitoring';

comment on column public.samples.analysis_code is
  'Código bruto impresso no laudo.';
comment on column public.samples.analysis_type is
  'standard para YYYYDDMM.FHHH.X.X.X; jumbo_monitoring para F#.MONITORAMENTO J#.';
comment on column public.samples.heat_number is
  'Número da fornada sem os zeros à esquerda. A identidade da fornada inclui ano, mês e forno.';
