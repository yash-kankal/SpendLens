-- Run this in the Supabase SQL editor before using the app.
-- The app uses Supabase Auth user ids and Row Level Security on every table.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  email text not null unique,
  updated_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id text primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  amount double precision not null check (amount >= 0),
  category text not null,
  date timestamptz not null,
  note text,
  is_recurring boolean not null default false,
  ai_tag text,
  created_at timestamptz not null default now()
);

create index if not exists expenses_owner_date_idx on public.expenses(owner_id, date desc);

create table if not exists public.budgets (
  id text primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  month integer not null check (month between 1 and 12),
  year integer not null,
  total_budget double precision not null check (total_budget >= 0),
  category_limits jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(owner_id, month, year)
);

create table if not exists public.friends (
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, friend_id),
  check (user_id <> friend_id)
);

create table if not exists public.splits (
  id text primary key,
  title text not null,
  total_amount double precision not null check (total_amount >= 0),
  paid_by_user_id uuid not null references auth.users(id) on delete cascade,
  paid_by_name text not null,
  participant_ids uuid[] not null,
  shares jsonb not null default '{}'::jsonb,
  settled jsonb not null default '{}'::jsonb,
  date timestamptz not null,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists splits_participant_ids_idx on public.splits using gin(participant_ids);
create index if not exists splits_date_idx on public.splits(date desc);

alter table public.profiles enable row level security;
alter table public.expenses enable row level security;
alter table public.budgets enable row level security;
alter table public.friends enable row level security;
alter table public.splits enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles for select
to authenticated
using (true);

drop policy if exists "profiles_upsert_self" on public.profiles;
create policy "profiles_upsert_self"
on public.profiles for all
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "expenses_owner_all" on public.expenses;
create policy "expenses_owner_all"
on public.expenses for all
to authenticated
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

drop policy if exists "budgets_owner_all" on public.budgets;
create policy "budgets_owner_all"
on public.budgets for all
to authenticated
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

drop policy if exists "friends_visible_to_user" on public.friends;
create policy "friends_visible_to_user"
on public.friends for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "friends_insert_self" on public.friends;
create policy "friends_insert_self"
on public.friends for insert
to authenticated
with check (auth.uid() = user_id or auth.uid() = friend_id);

drop policy if exists "friends_delete_self" on public.friends;
create policy "friends_delete_self"
on public.friends for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists "splits_participants_select" on public.splits;
create policy "splits_participants_select"
on public.splits for select
to authenticated
using (auth.uid() = any(participant_ids));

drop policy if exists "splits_participants_insert" on public.splits;
create policy "splits_participants_insert"
on public.splits for insert
to authenticated
with check (auth.uid() = any(participant_ids));

drop policy if exists "splits_participants_update" on public.splits;
create policy "splits_participants_update"
on public.splits for update
to authenticated
using (auth.uid() = any(participant_ids))
with check (auth.uid() = any(participant_ids));

drop policy if exists "splits_participants_delete" on public.splits;
create policy "splits_participants_delete"
on public.splits for delete
to authenticated
using (auth.uid() = any(participant_ids));
