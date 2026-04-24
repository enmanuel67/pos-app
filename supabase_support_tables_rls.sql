-- Politicas RLS para tablas auxiliares de la app.
-- Ejecutar en Supabase SQL Editor.

alter table public.app_error_logs enable row level security;
alter table public.inventory_drafts enable row level security;

drop policy if exists "app_error_logs_select_anon" on public.app_error_logs;
drop policy if exists "app_error_logs_insert_anon" on public.app_error_logs;
drop policy if exists "app_error_logs_update_anon" on public.app_error_logs;
drop policy if exists "app_error_logs_delete_anon" on public.app_error_logs;

create policy "app_error_logs_select_anon"
on public.app_error_logs
for select
to anon
using (true);

create policy "app_error_logs_insert_anon"
on public.app_error_logs
for insert
to anon
with check (true);

create policy "app_error_logs_update_anon"
on public.app_error_logs
for update
to anon
using (true)
with check (true);

create policy "app_error_logs_delete_anon"
on public.app_error_logs
for delete
to anon
using (true);

drop policy if exists "inventory_drafts_select_anon" on public.inventory_drafts;
drop policy if exists "inventory_drafts_insert_anon" on public.inventory_drafts;
drop policy if exists "inventory_drafts_update_anon" on public.inventory_drafts;
drop policy if exists "inventory_drafts_delete_anon" on public.inventory_drafts;

create policy "inventory_drafts_select_anon"
on public.inventory_drafts
for select
to anon
using (true);

create policy "inventory_drafts_insert_anon"
on public.inventory_drafts
for insert
to anon
with check (true);

create policy "inventory_drafts_update_anon"
on public.inventory_drafts
for update
to anon
using (true)
with check (true);

create policy "inventory_drafts_delete_anon"
on public.inventory_drafts
for delete
to anon
using (true);
