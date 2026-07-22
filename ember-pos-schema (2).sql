-- =====================================================================
-- EMBER POS — Supabase schema
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- Column names are camelCase (quoted) to match the app's JS objects
-- 1:1 — no translation layer needed in the frontend code.
-- =====================================================================

-- ---------- LOCATIONS ----------
create table if not exists locations (
  id text primary key,
  name text not null
);

-- ---------- STAFF ----------
create table if not exists staff (
  id integer primary key,
  name text not null,
  role text not null,               -- 'Admin' | 'Supervisor' | 'Waiter' | 'Kitchen' | 'Cashier'
  email text,
  commission numeric default 0,
  "locationId" text,                -- 'all' for admin, otherwise a locations.id
  orders integer default 0,
  sales numeric default 0,
  tips numeric default 0,
  perf numeric default 0,
  status text default 'Off shift'
);

-- ---------- MENU ITEMS ----------
create table if not exists menu_items (
  id integer primary key,
  name text not null,
  cat text,
  price numeric not null,
  emoji text,
  prep integer default 10,
  avail boolean default true,
  stock text default 'ok',
  recipe jsonb default '[]'::jsonb  -- [{invId, qty}, ...]
);

-- ---------- TABLES (floor plan) ----------
create table if not exists tables (
  id text primary key,
  seats integer,
  status text default 'available',  -- available | occupied | reserved | cleaning
  waiter text,
  since integer,
  "time" text,
  "locationId" text
);

-- ---------- INVENTORY ----------
create table if not exists inventory (
  id integer primary key,
  name text not null,
  unit text,
  stock numeric default 0,
  reorder numeric default 0,
  supplier text,
  expiry text,
  status text default 'ok',
  "locationId" text
);

-- ---------- ORDERS (kitchen tickets) ----------
create table if not exists orders (
  id text primary key,
  "table" text,
  waiter text,
  status text default 'new',        -- new | preparing | ready | served
  placed integer default 0,
  items jsonb default '[]'::jsonb,  -- [{n, q, itemId}, ...]
  discount numeric default 0,
  voided boolean default false,
  "locationId" text
);

-- ---------- PAYMENTS DUE ----------
create table if not exists payments_due (
  id text primary key,
  "table" text,
  waiter text,
  total numeric not null,
  items integer,
  discount numeric default 0,
  "locationId" text
);

-- ---------- COMPLETED PAYMENTS ----------
create table if not exists completed_payments (
  id text primary key,
  "table" text,
  total numeric not null,
  method text,
  ts timestamptz default now(),
  refunded boolean default false,
  discount numeric default 0,
  "locationId" text
);

-- ---------- PURCHASE ORDERS ----------
create table if not exists purchase_orders (
  id text primary key,
  supplier text,
  items text,
  status text default 'Pending',    -- Pending | In transit | Delivered
  eta text,
  "locationId" text
);

-- ---------- AUDIT LOG (append-only) ----------
create table if not exists audit_log (
  id text primary key,
  actor text,
  action text,
  details text,
  ts timestamptz default now()
);

-- ---------- NOTIFICATIONS ----------
create table if not exists notifications (
  id text primary key,
  title text,
  body text,
  kind text,
  ts timestamptz default now(),
  read boolean default false
);

-- ---------- SINGLETON CONFIG TABLES ----------
create table if not exists tax_config (
  id integer primary key default 1,
  label text default 'VAT',
  rate numeric default 0.16,
  "taxId" text default ''
);
insert into tax_config (id, label, rate, "taxId")
  values (1, 'VAT', 0.16, 'P000000000A')
  on conflict (id) do nothing;

create table if not exists business_config (
  id integer primary key default 1,
  "restaurantName" text default 'Ember Restaurant',
  "siteUrl" text default ''
);
insert into business_config (id, "restaurantName", "siteUrl")
  values (1, 'Ember Restaurant', 'https://your-restaurant-website.example.com')
  on conflict (id) do nothing;

-- =====================================================================
-- SEED DATA — mirrors the app's built-in demo data, so the database
-- starts populated instead of empty. Safe to re-run (upserts on id).
-- =====================================================================
insert into locations (id, name) values
  ('loc1','Ember — Westlands (Main)'),
  ('loc2','Ember — Karen Branch'),
  ('loc3','Ember — CBD Express')
on conflict (id) do update set name = excluded.name;

insert into staff (id, name, role, email, commission, "locationId", orders, sales, tips, perf, status) values
  (0,'Restaurant Owner','Admin','ember@restaraunt.com',0,'all',0,0,0,100,'On shift'),
  (1,'Grace Njoroge','Waiter','grace@emberpos.test',6,'loc1',34,38400,2100,92,'On shift'),
  (2,'John Kamau','Waiter','john@emberpos.test',6,'loc1',29,31200,1850,87,'On shift'),
  (3,'Peter Otieno','Waiter','peter@emberpos.test',5,'loc2',18,19800,900,74,'Off shift'),
  (4,'Amina Hassan','Supervisor','amina@emberpos.test',0,'loc1',0,0,0,95,'On shift'),
  (5,'Brian Mutiso','Kitchen','',0,'loc1',0,0,0,88,'On shift'),
  (6,'Diana Wambui','Cashier','diana@emberpos.test',0,'loc1',0,0,0,91,'On shift'),
  (7,'Naomi Chebet','Kitchen','',0,'loc2',0,0,0,83,'Off shift')
on conflict (id) do update set name=excluded.name, role=excluded.role, email=excluded.email,
  commission=excluded.commission, "locationId"=excluded."locationId", status=excluded.status;

insert into menu_items (id, name, cat, price, emoji, prep, avail, stock, recipe) values
  (1,'Grilled Beef Burger','Mains',850,'🍔',12,true,'ok','[{"invId":1,"qty":1},{"invId":2,"qty":1}]'),
  (2,'Nyama Choma Platter','Mains',1400,'🍖',20,true,'low','[{"invId":1,"qty":2}]'),
  (3,'Margherita Pizza','Mains',1100,'🍕',15,true,'ok','[{"invId":4,"qty":1}]'),
  (4,'Grilled Tilapia','Mains',1250,'🐟',18,true,'ok','[{"invId":3,"qty":1}]'),
  (5,'Chicken Samosas (5)','Starters',400,'🥟',8,true,'ok','[]'),
  (6,'Garden Salad','Starters',450,'🥗',6,true,'ok','[]'),
  (7,'Sweet Potato Fries','Extras',350,'🍟',7,true,'ok','[{"invId":6,"qty":0.1}]'),
  (8,'Passion Mojito','Drinks',500,'🍹',4,true,'ok','[{"invId":5,"qty":0.2}]'),
  (9,'Fresh Juice','Drinks',300,'🧃',3,true,'low','[{"invId":5,"qty":0.3}]'),
  (10,'Craft Lager','Drinks',450,'🍺',1,true,'ok','[{"invId":7,"qty":1}]'),
  (11,'Chocolate Lava Cake','Desserts',550,'🍫',10,true,'ok','[{"invId":8,"qty":0.2}]'),
  (12,'Mango Cheesecake','Desserts',500,'🍰',5,false,'out','[{"invId":8,"qty":0.2}]')
on conflict (id) do update set name=excluded.name, price=excluded.price, avail=excluded.avail;

insert into tables (id, seats, status, waiter, since, "time", "locationId") values
  ('T1',2,'available',null,null,null,'loc1'),
  ('T2',4,'occupied','Grace N.',14,null,'loc1'),
  ('T3',4,'occupied','Grace N.',38,null,'loc1'),
  ('T4',6,'reserved',null,null,'8:00 PM','loc1'),
  ('T5',2,'cleaning',null,null,null,'loc1'),
  ('T6',2,'available',null,null,null,'loc2'),
  ('T7',4,'occupied','Peter O.',6,null,'loc2'),
  ('T8',8,'available',null,null,null,'loc2'),
  ('T9',4,'available',null,null,null,'loc3'),
  ('T10',2,'available',null,null,null,'loc3')
on conflict (id) do update set status=excluded.status, waiter=excluded.waiter;

insert into inventory (id, name, unit, stock, reorder, supplier, expiry, status, "locationId") values
  (1,'Beef Patty','pcs',42,50,'Farm Fresh Ltd',null,'low','loc1'),
  (2,'Burger Buns','pcs',120,60,'City Bakers',null,'ok','loc1'),
  (3,'Tilapia Fillet','kg',8,10,'Lake Suppliers',null,'low','loc2'),
  (4,'Mozzarella Cheese','kg',15,8,'Dairy Co',null,'ok','loc1'),
  (5,'Passion Fruit','kg',3,6,'Green Grocers',null,'critical','loc2'),
  (6,'Cooking Oil','L',34,15,'Bidco','2026-09-01','ok','loc1'),
  (7,'Lager (crate)','crate',22,10,'Beverage Distributors',null,'ok','loc2'),
  (8,'Cream Cheese','kg',1,5,'Dairy Co',null,'critical','loc1')
on conflict (id) do update set stock=excluded.stock, status=excluded.status;


-- IMPORTANT CAVEAT — read this before relying on it:
-- This app authenticates people through FIREBASE, not Supabase Auth.
-- Supabase RLS can only check the Supabase session (auth.uid()/role) —
-- it has no way to know "this request came from an admin who signed in
-- with Firebase." Because of that mismatch, the policies below can only
-- gate by the anon/public key itself, not by which staff role is using
-- the app. In practice that means: anyone who extracts your public anon
-- key (visible in this HTML file's source) could read and write every
-- table directly, bypassing the app's own admin/waiter permission checks.
--
-- This is fine for an internal prototype / trusted-staff pilot. Before
-- handling real customer payment data or opening this to the internet
-- long-term, the correct fix is one of:
--   (a) Migrate login to Supabase Auth (email/password or custom JWT)
--       so policies can check auth.uid() / a role claim, or
--   (b) Keep Firebase for login, but route all writes through a Supabase
--       Edge Function that verifies the Firebase ID token server-side
--       and then uses the service_role key — never the anon key — to
--       touch the database.
-- Ask me to build (b) — it's the more realistic near-term fix for an
-- app that's already committed to Firebase for staff login.
-- =====================================================================

alter table locations enable row level security;
alter table staff enable row level security;
alter table menu_items enable row level security;
alter table tables enable row level security;
alter table inventory enable row level security;
alter table orders enable row level security;
alter table payments_due enable row level security;
alter table completed_payments enable row level security;
alter table purchase_orders enable row level security;
alter table audit_log enable row level security;
alter table notifications enable row level security;
alter table tax_config enable row level security;
alter table business_config enable row level security;

-- Open read/write policy for the anon key on every table (see caveat above).
do $$
declare t text;
begin
  for t in select unnest(array[
    'locations','staff','menu_items','tables','inventory','orders',
    'payments_due','completed_payments','purchase_orders','audit_log',
    'notifications','tax_config','business_config'
  ])
  loop
    -- Clean up the old (possibly broken) policy name if this schema was run before
    execute format('drop policy if exists "anon_all_%s" on %I;', t, t);
    execute format('drop policy if exists "open_all_%s" on %I;', t, t);
    -- No "to <role>" clause = applies to every role Postgres sees the
    -- request as (anon, authenticated, etc). This avoids a real failure
    -- mode: Supabase's newer publishable/secret API key system may not
    -- map to the classic "anon" role the same way the old JWT anon key
    -- did, in which case a "to anon" policy silently blocks everything —
    -- reads return empty, writes fail — with no visible error in the app.
    execute format(
      'create policy "open_all_%s" on %I for all using (true) with check (true);',
      t, t
    );
  end loop;
end $$;

-- =====================================================================
-- REALTIME (optional but recommended)
-- Turns on live sync so e.g. a new order appears on the Kitchen Display
-- the instant a waiter sends it — without anyone refreshing the page.
-- Safe to re-run: skips any table that's already in the publication
-- instead of erroring (which is what caused the 42710 error).
-- =====================================================================
do $$
declare t text;
begin
  for t in select unnest(array['orders','tables','inventory','notifications','payments_due'])
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I;', t);
    end if;
  end loop;
end $$;
