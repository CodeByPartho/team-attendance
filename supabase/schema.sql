-- Team Attendance: Supabase schema
-- Run this in the Supabase SQL editor to create the tables for a real
-- backend. The app ships in local demo mode by default and does not
-- connect to Supabase yet; see the README for wiring steps.

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text not null default 'Staff',
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees (id) on delete cascade,
  work_date date not null,
  check_in timestamptz,
  check_out timestamptz,
  created_at timestamptz not null default now(),
  unique (employee_id, work_date),
  constraint check_out_after_check_in
    check (check_out is null or check_in is null or check_out >= check_in)
);

-- One row per employee per day; check in sets check_in, check out sets
-- check_out. A record with check_in set and check_out null means the
-- employee is currently present.

create index if not exists attendance_work_date_idx
  on public.attendance (work_date);

create index if not exists attendance_employee_idx
  on public.attendance (employee_id);

-- Monthly summary for one employee: days present and total hours.
create or replace view public.monthly_attendance_summary as
select
  employee_id,
  date_trunc('month', work_date)::date as month,
  count(*) filter (where check_in is not null) as days_present,
  coalesce(
    sum(extract(epoch from (check_out - check_in)) / 3600)
      filter (where check_in is not null and check_out is not null),
    0
  ) as total_hours
from public.attendance
group by employee_id, date_trunc('month', work_date);

-- Row level security: enable it and add your own policies before going
-- live. The starter policy below keeps the tables readable and writable
-- only to signed in users; tighten it to an admin role for production.
alter table public.employees enable row level security;
alter table public.attendance enable row level security;

create policy "Signed in users can manage employees"
  on public.employees
  for all
  to authenticated
  using (true)
  with check (true);

create policy "Signed in users can manage attendance"
  on public.attendance
  for all
  to authenticated
  using (true)
  with check (true);
