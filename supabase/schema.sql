-- Respack ERP database blueprint for manufacturing operations.
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
  primary key (organization_id, user_id)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_code text not null,
  customer_name text not null,
  industry text,
  credit_term text,
  address text,
  created_at timestamptz not null default now(),
  unique (organization_id, customer_code)
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_code text not null,
  supplier_name text not null,
  category text,
  lead_time_days integer,
  address text,
  created_at timestamptz not null default now(),
  unique (organization_id, supplier_code)
);

create table if not exists public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete set null,
  order_number text not null,
  order_date date not null default current_date,
  due_date date,
  product_spec text not null,
  quantity_kg numeric(14,3) not null check (quantity_kg > 0),
  sales_price numeric(14,4) not null default 0 check (sales_price >= 0),
  status text not null default 'pending' check (status in ('pending','confirmed','in_production','completed','cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, order_number)
);

create table if not exists public.purchase_requisitions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  requisition_number text not null,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  material_id uuid not null,
  quantity numeric(14,3) not null check (quantity > 0),
  request_date date not null default current_date,
  status text not null default 'draft' check (status in ('draft','approved','ordered','received')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, requisition_number)
);

create table if not exists public.materials (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  sku text not null,
  name text not null,
  unit text not null default 'kg',
  reorder_level numeric(14,3) not null default 0 check (reorder_level >= 0),
  created_at timestamptz not null default now(),
  unique (organization_id, sku)
);

create table if not exists public.bom_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  product_code text not null,
  product_name text not null,
  material_id uuid not null references public.materials(id) on delete restrict,
  quantity_per_unit numeric(14,4) not null check (quantity_per_unit > 0),
  scrap_pct numeric(10,2) not null default 0 check (scrap_pct >= 0),
  uom text not null default 'kg',
  created_at timestamptz not null default now(),
  unique (organization_id, product_code)
);

create table if not exists public.work_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  work_order_number text not null,
  sales_order_id uuid references public.sales_orders(id) on delete set null,
  machine text,
  target_kg numeric(14,3) not null check (target_kg > 0),
  produced_kg numeric(14,3) not null default 0 check (produced_kg >= 0),
  scrap_kg numeric(14,3) not null default 0 check (scrap_kg >= 0),
  status text not null default 'planned' check (status in ('planned','in_progress','on_hold','complete','cancelled')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, work_order_number)
);

create table if not exists public.production_routes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  route_name text not null,
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  station text not null,
  sequence_no integer not null check (sequence_no > 0),
  target_minutes integer not null check (target_minutes > 0),
  status text not null default 'planned' check (status in ('planned','in_progress','completed')),
  created_at timestamptz not null default now(),
  unique (organization_id, work_order_id, station, sequence_no)
);

create table if not exists public.inventory_lots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete restrict,
  lot_number text not null,
  quantity_on_hand numeric(14,3) not null default 0 check (quantity_on_hand >= 0),
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0),
  received_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (organization_id, material_id, lot_number)
);

create table if not exists public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  material_id uuid not null references public.materials(id) on delete restrict,
  lot_id uuid not null references public.inventory_lots(id) on delete restrict,
  transaction_type text not null check (transaction_type in ('receipt','issue','adjustment')),
  quantity_delta numeric(14,3) not null check (quantity_delta <> 0),
  reference text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.quality_rolls (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  work_order_id uuid not null references public.work_orders(id) on delete restrict,
  barcode text not null,
  weight_kg numeric(14,3) not null check (weight_kg > 0),
  thickness_micron numeric(10,2) check (thickness_micron is null or thickness_micron >= 0),
  result text not null default 'pass' check (result in ('pass','fail','hold')),
  inspector text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, barcode)
);

create table if not exists public.deliveries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  delivery_number text not null,
  customer_id uuid not null references public.customers(id) on delete restrict,
  sales_order_id uuid not null references public.sales_orders(id) on delete restrict,
  dispatch_date date not null default current_date,
  quantity_kg numeric(14,3) not null check (quantity_kg > 0),
  destination text not null,
  status text not null default 'planned' check (status in ('planned','dispatched','delivered')),
  created_at timestamptz not null default now(),
  unique (organization_id, delivery_number)
);

create table if not exists public.financial_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entry_type text not null check (entry_type in ('cost','revenue','expense')),
  reference text not null,
  account_code text not null,
  amount numeric(14,4) not null check (amount >= 0),
  entry_date date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.goods_receipts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  material_id uuid not null references public.materials(id) on delete restrict,
  receipt_number text not null,
  lot_number text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_cost numeric(14,4) not null default 0 check (unit_cost >= 0),
  received_at date not null default current_date,
  created_at timestamptz not null default now(),
  unique (organization_id, receipt_number)
);

create or replace function public.is_org_member(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
  );
$$;

create or replace function public.can_write_org(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
      and m.role <> 'viewer'
  );
$$;

revoke all on function public.is_org_member(uuid) from public;
revoke all on function public.can_write_org(uuid) from public;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.can_write_org(uuid) to authenticated;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.customers enable row level security;
alter table public.suppliers enable row level security;
alter table public.sales_orders enable row level security;
alter table public.purchase_requisitions enable row level security;
alter table public.materials enable row level security;
alter table public.bom_items enable row level security;
alter table public.work_orders enable row level security;
alter table public.production_routes enable row level security;
alter table public.inventory_lots enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.quality_rolls enable row level security;
alter table public.deliveries enable row level security;
alter table public.financial_entries enable row level security;
alter table public.goods_receipts enable row level security;

create policy "Members can view their organization" on public.organizations
  for select to authenticated using (public.is_org_member(id));

create policy "Users can view their memberships" on public.organization_members
  for select to authenticated using (user_id = (select auth.uid()));

create policy "Members can view customers" on public.customers
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can manage customers" on public.customers
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update customers" on public.customers
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view suppliers" on public.suppliers
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can manage suppliers" on public.suppliers
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update suppliers" on public.suppliers
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view sales orders" on public.sales_orders
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can create sales orders" on public.sales_orders
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update sales orders" on public.sales_orders
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view requisitions" on public.purchase_requisitions
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can create requisitions" on public.purchase_requisitions
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update requisitions" on public.purchase_requisitions
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view materials" on public.materials
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can manage materials" on public.materials
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update materials" on public.materials
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view BOM items" on public.bom_items
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can manage BOM" on public.bom_items
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update BOM" on public.bom_items
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view work orders" on public.work_orders
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can manage work orders" on public.work_orders
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update work orders" on public.work_orders
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view route steps" on public.production_routes
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can manage route steps" on public.production_routes
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update route steps" on public.production_routes
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view lots" on public.inventory_lots
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can manage lots" on public.inventory_lots
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update lots" on public.inventory_lots
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view transactions" on public.inventory_transactions
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can create transactions" on public.inventory_transactions
  for insert to authenticated with check (public.can_write_org(organization_id));

create policy "Members can view quality" on public.quality_rolls
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can create quality" on public.quality_rolls
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update quality" on public.quality_rolls
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view deliveries" on public.deliveries
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can create deliveries" on public.deliveries
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update deliveries" on public.deliveries
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view financial entries" on public.financial_entries
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can create financial entries" on public.financial_entries
  for insert to authenticated with check (public.can_write_org(organization_id));
create policy "Writers can update financial entries" on public.financial_entries
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id));

create policy "Members can view goods receipts" on public.goods_receipts
  for select to authenticated using (public.is_org_member(organization_id));
create policy "Writers can create goods receipts" on public.goods_receipts
  for insert to authenticated with check (public.can_write_org(organization_id));

create or replace function public.apply_inventory_transaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare updated_count integer;
begin
  update public.inventory_lots
     set quantity_on_hand = quantity_on_hand + new.quantity_delta
   where id = new.lot_id
     and organization_id = new.organization_id
     and material_id = new.material_id
     and quantity_on_hand + new.quantity_delta >= 0;

  get diagnostics updated_count = row_count;

  if updated_count <> 1 then
    raise exception 'Invalid lot or insufficient on-hand quantity';
  end if;

  return new;
end;
$$;

create trigger inventory_transaction_apply
after insert on public.inventory_transactions
for each row execute function public.apply_inventory_transaction();

create or replace function public.record_goods_receipt(
  p_organization_id uuid,
  p_supplier_id uuid,
  p_material_id uuid,
  p_lot_number text,
  p_quantity numeric,
  p_unit_cost numeric,
  p_receipt_number text,
  p_received_at date
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_lot_id uuid;
begin
  if not public.can_write_org(p_organization_id) then
    raise exception 'Not authorized for this organization';
  end if;

  if p_quantity <= 0 or p_unit_cost < 0 or length(trim(p_lot_number)) = 0 or length(trim(p_receipt_number)) = 0 then
    raise exception 'Invalid receipt values';
  end if;

  insert into public.inventory_lots (
    organization_id,
    material_id,
    lot_number,
    quantity_on_hand,
    unit_cost,
    received_at
  ) values (
    p_organization_id,
    p_material_id,
    trim(p_lot_number),
    0,
    p_unit_cost,
    coalesce(p_received_at, current_date)
  ) returning id into new_lot_id;

  insert into public.inventory_transactions (
    organization_id,
    material_id,
    lot_id,
    transaction_type,
    quantity_delta,
    reference,
    created_by
  ) values (
    p_organization_id,
    p_material_id,
    new_lot_id,
    'receipt',
    p_quantity,
    'Receipt: ' || trim(p_receipt_number),
    auth.uid()
  );

  insert into public.goods_receipts (
    organization_id,
    supplier_id,
    material_id,
    receipt_number,
    lot_number,
    quantity,
    unit_cost,
    received_at
  ) values (
    p_organization_id,
    p_supplier_id,
    p_material_id,
    trim(p_receipt_number),
    trim(p_lot_number),
    p_quantity,
    p_unit_cost,
    coalesce(p_received_at, current_date)
  );

  return new_lot_id;
end;
$$;

grant execute on function public.record_goods_receipt(uuid, uuid, uuid, text, numeric, numeric, text, date) to authenticated;

grant usage on schema public to authenticated;
grant select on public.organizations, public.organization_members, public.customers, public.suppliers, public.sales_orders, public.purchase_requisitions, public.materials, public.bom_items, public.work_orders, public.production_routes, public.inventory_lots, public.inventory_transactions, public.quality_rolls, public.deliveries, public.financial_entries, public.goods_receipts to authenticated;
grant insert, update on public.customers, public.suppliers, public.sales_orders, public.purchase_requisitions, public.materials, public.bom_items, public.work_orders, public.production_routes, public.inventory_lots, public.quality_rolls, public.deliveries, public.financial_entries, public.goods_receipts to authenticated;
