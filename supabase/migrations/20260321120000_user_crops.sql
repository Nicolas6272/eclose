-- Account-owned crops. Each row belongs to one auth user (not a device).
-- RLS: a user can only read/write their own rows.
--
-- If you already created the old table, drop it first then recreate:
--   drop table if exists public.user_crops;

create table if not exists public.user_crops (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  catalog_crop_id integer not null,
  name text not null,
  custom_name text,
  planted_at timestamptz not null,
  created_at timestamptz not null default now(),
  last_watered_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create index if not exists user_crops_user_id_idx on public.user_crops (user_id);

alter table public.user_crops enable row level security;

create policy "user_crops_select_own"
  on public.user_crops
  for select
  using (auth.uid() = user_id);

create policy "user_crops_insert_own"
  on public.user_crops
  for insert
  with check (auth.uid() = user_id);

create policy "user_crops_update_own"
  on public.user_crops
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "user_crops_delete_own"
  on public.user_crops
  for delete
  using (auth.uid() = user_id);
