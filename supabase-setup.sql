-- Gereja Injil Kristus: database, keamanan, dan storage.
-- Jalankan sekali di Supabase Dashboard > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.site_content (
  id smallint primary key check (id = 1),
  content jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  created_at timestamptz not null default now(),
  form_data jsonb not null default '{}'::jsonb
);

create or replace function public.is_gik_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users where user_id = auth.uid()
  );
$$;
revoke all on function public.is_gik_admin() from public;
grant execute on function public.is_gik_admin() to anon, authenticated;

alter table public.site_content enable row level security;
alter table public.admin_users enable row level security;
alter table public.requests enable row level security;

-- Hak SQL dasar; izin efektif tetap dibatasi oleh RLS di bawah.
grant select on public.site_content to anon, authenticated;
grant insert, update, delete on public.site_content to authenticated;
grant select on public.admin_users to authenticated;
grant select, insert, update, delete on public.requests to authenticated;
grant insert on public.requests to anon;

drop policy if exists "Public can read church content" on public.site_content;
create policy "Public can read church content" on public.site_content
  for select to anon, authenticated using (true);
drop policy if exists "Admins can insert church content" on public.site_content;
create policy "Admins can insert church content" on public.site_content
  for insert to authenticated with check (public.is_gik_admin());
drop policy if exists "Admins can update church content" on public.site_content;
create policy "Admins can update church content" on public.site_content
  for update to authenticated using (public.is_gik_admin()) with check (public.is_gik_admin());
drop policy if exists "Admins can delete church content" on public.site_content;
create policy "Admins can delete church content" on public.site_content
  for delete to authenticated using (public.is_gik_admin());

drop policy if exists "Admin can verify own admin record" on public.admin_users;
create policy "Admin can verify own admin record" on public.admin_users
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "Visitors can submit forms" on public.requests;
create policy "Visitors can submit forms" on public.requests
  for insert to anon, authenticated with check (
    char_length(type) between 1 and 120 and jsonb_typeof(form_data) = 'object'
  );
drop policy if exists "Admins can read form submissions" on public.requests;
create policy "Admins can read form submissions" on public.requests
  for select to authenticated using (public.is_gik_admin());
drop policy if exists "Admins can update form submissions" on public.requests;
create policy "Admins can update form submissions" on public.requests
  for update to authenticated using (public.is_gik_admin()) with check (public.is_gik_admin());
drop policy if exists "Admins can delete form submissions" on public.requests;
create policy "Admins can delete form submissions" on public.requests
  for delete to authenticated using (public.is_gik_admin());

-- Poster ibadah: public boleh melihat gambar; hanya admin terdaftar yang boleh mengelola.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gik-posters', 'gik-posters', true, 15728640, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = true, file_size_limit = 15728640,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "Public can view GIK posters" on storage.objects;
create policy "Public can view GIK posters" on storage.objects
  for select to anon, authenticated using (bucket_id = 'gik-posters');
drop policy if exists "Admins can upload GIK posters" on storage.objects;
create policy "Admins can upload GIK posters" on storage.objects
  for insert to authenticated with check (bucket_id = 'gik-posters' and public.is_gik_admin());
drop policy if exists "Admins can update GIK posters" on storage.objects;
create policy "Admins can update GIK posters" on storage.objects
  for update to authenticated using (bucket_id = 'gik-posters' and public.is_gik_admin())
  with check (bucket_id = 'gik-posters' and public.is_gik_admin());
drop policy if exists "Admins can delete GIK posters" on storage.objects;
create policy "Admins can delete GIK posters" on storage.objects
  for delete to authenticated using (bucket_id = 'gik-posters' and public.is_gik_admin());

-- Aktifkan Realtime untuk sinkronisasi konten dan pengajuan lintas perangkat.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'site_content') then
    alter publication supabase_realtime add table public.site_content;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'requests') then
    alter publication supabase_realtime add table public.requests;
  end if;
end $$;
