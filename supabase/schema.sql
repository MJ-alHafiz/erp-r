-- Respack ERP database foundation. Run once in the Supabase SQL editor as project owner.
create extension if not exists pgcrypto;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 150),
  created_at timestamptz not null default now()
);

create table if not exists public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'operator' check (role in ('owner','admin','manager','operator','viewer')),
  created_at timestamptz not null default now(),
  primary key (organization_id,user_id)
);

create table if not exists public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  order_number text not null,
  customer_name text not null,
  product_spec text not null,
  quantity_kg numeric(14,3) not null check (quantity_kg > 0),
  unit_price numeric(14,4) not null default 0 check (unit_price >= 0),
  due_date date,
  status text not null default 'pending' check (status in ('pending','confirmed','in_production','completed','cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id,order_number),
  unique (organization_id,id)
);

create table if not exists public.work_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  work_order_number text not null,
  sales_order_id uuid,
  machine text,
  target_kg numeric(14,3) not null check (target_kg > 0),
  produced_kg numeric(14,3) not null default 0 check (produced_kg >= 0),
  scrap_kg numeric(14,3) not null default 0 check (scrap_kg >= 0),
  status text not null default 'planned' check (status in ('planned','in_progress','on_hold','complete','cancelled')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id,work_order_number),
  unique (organization_id,id),
  constraint work_order_sales_order_same_org foreign key (organization_id,sales_order_id) references public.sales_orders(organization_id,id)
);

create table if not exists public.materials (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  sku text not null,
  name text not null,
  unit text not null default 'kg',
  reorder_level numeric(14,3) not null default 0 check (reorder_level >= 0),
  created_at timestamptz not null default now(),
  unique (organization_id,sku),
  unique (organization_id,id)
);

create table if not exists public.inventory_lots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  material_id uuid not null,
  lot_number text not null,
  quantity_on_hand numeric(14,3) not null default 0 check (quantity_on_hand >= 0),
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0),
  received_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (organization_id,material_id,lot_number),
  unique (organization_id,id),
  constraint lot_material_same_org foreign key (organization_id,material_id) references public.materials(organization_id,id)
);

create table if not exists public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  material_id uuid not null,
  lot_id uuid not null,
  transaction_type text not null check (transaction_type in ('receipt','issue','adjustment')),
  quantity_delta numeric(14,3) not null check (quantity_delta <> 0),
  reference text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint transaction_material_same_org foreign key (organization_id,material_id) references public.materials(organization_id,id),
  constraint transaction_lot_same_org foreign key (organization_id,lot_id) references public.inventory_lots(organization_id,id)
);

create table if not exists public.quality_rolls (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  work_order_id uuid not null,
  barcode text not null,
  weight_kg numeric(14,3) not null check (weight_kg > 0),
  thickness_micron numeric(10,2) check (thickness_micron is null or thickness_micron >= 0),
  result text not null default 'pass' check (result in ('pass','fail','hold')),
  inspector text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id,barcode),
  constraint roll_work_order_same_org foreign key (organization_id,work_order_id) references public.work_orders(organization_id,id)
);

create or replace function public.is_org_member(p_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.organization_members m where m.organization_id = p_org and m.user_id = (select auth.uid()))
$$;

create or replace function public.can_write_org(p_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.organization_members m where m.organization_id = p_org and m.user_id = (select auth.uid()) and m.role <> 'viewer')
$$;

revoke all on function public.is_org_member(uuid) from public;
revoke all on function public.can_write_org(uuid) from public;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.can_write_org(uuid) to authenticated;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.sales_orders enable row level security;
alter table public.work_orders enable row level security;
alter table public.materials enable row level security;
alter table public.inventory_lots enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.quality_rolls enable row level security;

create policy "Members can read their organizations" on public.organizations for select to authenticated using (public.is_org_member(id));
create policy "Users can read their own memberships" on public.organization_members for select to authenticated using (user_id = (select auth.uid()));

create policy "Members read sales orders" on public.sales_orders for select to authenticated using (public.is_org_member(organization_id));
create policy "Operators create sales orders" on public.sales_orders for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Operators update sales orders" on public.sales_orders for update to authenticated using (public.can_write_org(organization_id)) with check (public.can_write_org(organization_id));
create policy "Members read work orders" on public.work_orders for select to authenticated using (public.is_org_member(organization_id));
create policy "Operators create work orders" on public.work_orders for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Operators update work orders" on public.work_orders for update to authenticated using (public.can_write_org(organization_id)) with check (public.can_write_org(organization_id));
create policy "Members read materials" on public.materials for select to authenticated using (public.is_org_member(organization_id));
create policy "Operators create materials" on public.materials for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Operators update materials" on public.materials for update to authenticated using (public.can_write_org(organization_id)) with check (public.can_write_org(organization_id));
create policy "Members read lots" on public.inventory_lots for select to authenticated using (public.is_org_member(organization_id));
create policy "Members read inventory transactions" on public.inventory_transactions for select to authenticated using (public.is_org_member(organization_id));
create policy "Members read QC rolls" on public.quality_rolls for select to authenticated using (public.is_org_member(organization_id));
create policy "Operators create QC rolls" on public.quality_rolls for insert to authenticated with check (public.can_write_org(organization_id));

create or replace function public.apply_inventory_transaction()
returns trigger language plpgsql security definer set search_path = '' as $$
declare updated_count integer;
begin
  update public.inventory_lots
     set quantity_on_hand = quantity_on_hand + new.quantity_delta
   where id = new.lot_id and organization_id = new.organization_id and material_id = new.material_id
     and quantity_on_hand + new.quantity_delta >= 0;
  get diagnostics updated_count = row_count;
  if updated_count <> 1 then raise exception 'Invalid lot or insufficient on-hand quantity'; end if;
  return new;
end;
$$;

create trigger inventory_transaction_apply
after insert on public.inventory_transactions
for each row execute function public.apply_inventory_transaction();

create or replace function public.receive_material(
  p_organization_id uuid, p_material_id uuid, p_lot_number text, p_quantity numeric, p_unit_cost numeric
) returns uuid language plpgsql security invoker set search_path = '' as $$
declare new_lot uuid;
begin
  if not public.can_write_org(p_organization_id) then raise exception 'Not authorized for this organization'; end if;
  if p_quantity <= 0 or p_unit_cost < 0 or length(trim(p_lot_number)) = 0 then raise exception 'Invalid receipt values'; end if;
  insert into public.inventory_lots(organization_id,material_id,lot_number,quantity_on_hand,unit_cost)
    values(p_organization_id,p_material_id,trim(p_lot_number),0,p_unit_cost) returning id into new_lot;
  insert into public.inventory_transactions(organization_id,material_id,lot_id,transaction_type,quantity_delta,reference,created_by)
    values(p_organization_id,p_material_id,new_lot,'receipt',p_quantity,'Receipt: '||trim(p_lot_number),(select auth.uid()));
  return new_lot;
end;
$$;

grant execute on function public.receive_material(uuid,uuid,text,numeric,numeric) to authenticated;

-- Expose only the intended browser roles. Supabase projects normally grant these,
-- but explicit table grants keep the expected app permissions clear.
grant usage on schema public to authenticated;
grant select on public.organizations, public.organization_members, public.sales_orders, public.work_orders, public.materials, public.inventory_lots, public.inventory_transactions, public.quality_rolls to authenticated;
grant insert, update on public.sales_orders, public.work_orders, public.materials to authenticated;
grant insert on public.quality_rolls to authenticated;
