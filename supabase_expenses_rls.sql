-- Permisos para que la app Flutter pueda sincronizar gastos con la anon key.
-- Ejecutar en Supabase SQL Editor.

alter table public.expenses enable row level security;
alter table public.expense_entries enable row level security;

drop policy if exists "expenses_select_anon" on public.expenses;
drop policy if exists "expenses_insert_anon" on public.expenses;
drop policy if exists "expenses_update_anon" on public.expenses;

create policy "expenses_select_anon"
on public.expenses
for select
to anon
using (true);

create policy "expenses_insert_anon"
on public.expenses
for insert
to anon
with check (true);

create policy "expenses_update_anon"
on public.expenses
for update
to anon
using (true)
with check (true);

drop policy if exists "expense_entries_select_anon" on public.expense_entries;
drop policy if exists "expense_entries_insert_anon" on public.expense_entries;
drop policy if exists "expense_entries_update_anon" on public.expense_entries;

create policy "expense_entries_select_anon"
on public.expense_entries
for select
to anon
using (true);

create policy "expense_entries_insert_anon"
on public.expense_entries
for insert
to anon
with check (true);

create policy "expense_entries_update_anon"
on public.expense_entries
for update
to anon
using (true)
with check (true);
