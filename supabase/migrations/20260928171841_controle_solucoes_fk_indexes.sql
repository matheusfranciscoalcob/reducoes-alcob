create index solution_measurements_created_by_idx
on public.solution_measurements (created_by);

create index solution_calibrations_created_by_idx
on public.solution_calibrations (created_by);

create index solution_settings_updated_by_idx
on public.solution_settings (updated_by);

create index solution_annotations_updated_by_idx
on public.solution_annotations (updated_by);

create index solution_photos_created_by_idx
on public.solution_photos (created_by);
