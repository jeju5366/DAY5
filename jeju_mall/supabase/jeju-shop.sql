-- 제주 특산물 쇼핑몰 (Supabase > SQL Editor 에 통째로 붙여넣고 Run)
-- 여러 번 실행해도 안전하도록 if not exists / drop policy if exists / create or replace 사용
-- 기존 테이블(cart_items 등)과 겹치지 않도록 모든 테이블에 jeju_ 접두사를 붙였습니다.

-- 1. 상품 -------------------------------------------------------------
create table if not exists public.jeju_products (
  id          bigint generated always as identity primary key,
  name        text not null unique,
  description text,
  emoji       text not null default '🍊',
  category    text,
  price       int  not null check (price >= 0),
  stock       int  not null default 100 check (stock >= 0),
  created_at  timestamptz not null default now()
);

-- 2. 장바구니 ---------------------------------------------------------
create table if not exists public.jeju_cart_items (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  product_id bigint not null references public.jeju_products(id) on delete cascade,
  quantity   int not null default 1 check (quantity > 0),
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

-- 3. 주문 / 주문상품 --------------------------------------------------
-- order_items.line_total = unit_price * quantity (DB가 자동 계산)
-- orders.total_price     = 주문상품 line_total 의 합계 (함수가 자동 갱신)
create table if not exists public.jeju_orders (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  total_price int  not null default 0,
  status      text not null default 'paid' check (status in ('paid', 'returned')),
  created_at  timestamptz not null default now(),
  returned_at timestamptz
);

create table if not exists public.jeju_order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.jeju_orders(id) on delete cascade,
  product_id   bigint references public.jeju_products(id) on delete set null,
  product_name text not null,
  unit_price   int  not null check (unit_price >= 0),
  quantity     int  not null check (quantity > 0),
  line_total   int  generated always as (unit_price * quantity) stored
);

-- 4. 좋아요 / 댓글 / 방명록 -------------------------------------------
create table if not exists public.jeju_likes (
  product_id bigint not null references public.jeju_products(id) on delete cascade,
  user_id    uuid   not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (product_id, user_id)
);

create table if not exists public.jeju_comments (
  id          uuid primary key default gen_random_uuid(),
  product_id  bigint not null references public.jeju_products(id) on delete cascade,
  user_id     uuid   not null default auth.uid() references auth.users(id) on delete cascade,
  author_name text   not null,
  content     text   not null check (char_length(content) between 1 and 500),
  created_at  timestamptz not null default now()
);

create table if not exists public.jeju_guestbook (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  author_name text not null,
  content     text not null check (char_length(content) between 1 and 500),
  created_at  timestamptz not null default now()
);

create index if not exists jeju_cart_user_idx     on public.jeju_cart_items (user_id);
create index if not exists jeju_orders_user_idx   on public.jeju_orders (user_id, created_at desc);
create index if not exists jeju_items_order_idx   on public.jeju_order_items (order_id);
create index if not exists jeju_comments_prod_idx on public.jeju_comments (product_id, created_at);

-- 5. RLS (행 단위 보안) ------------------------------------------------
alter table public.jeju_products    enable row level security;
alter table public.jeju_cart_items  enable row level security;
alter table public.jeju_orders      enable row level security;
alter table public.jeju_order_items enable row level security;
alter table public.jeju_likes       enable row level security;
alter table public.jeju_comments    enable row level security;
alter table public.jeju_guestbook   enable row level security;

drop policy if exists "products_read"      on public.jeju_products;
drop policy if exists "cart_select_own"    on public.jeju_cart_items;
drop policy if exists "cart_insert_own"    on public.jeju_cart_items;
drop policy if exists "cart_update_own"    on public.jeju_cart_items;
drop policy if exists "cart_delete_own"    on public.jeju_cart_items;
drop policy if exists "orders_select_own"  on public.jeju_orders;
drop policy if exists "items_select_own"   on public.jeju_order_items;
drop policy if exists "likes_read"         on public.jeju_likes;
drop policy if exists "likes_insert_own"   on public.jeju_likes;
drop policy if exists "likes_delete_own"   on public.jeju_likes;
drop policy if exists "comments_read"      on public.jeju_comments;
drop policy if exists "comments_insert_own" on public.jeju_comments;
drop policy if exists "comments_delete_own" on public.jeju_comments;
drop policy if exists "guest_read"         on public.jeju_guestbook;
drop policy if exists "guest_insert_own"   on public.jeju_guestbook;
drop policy if exists "guest_delete_own"   on public.jeju_guestbook;

-- 상품: 누구나 조회 (재고 변경은 아래 함수만 가능)
create policy "products_read" on public.jeju_products for select to anon, authenticated using (true);

-- 장바구니: 본인 것만
create policy "cart_select_own" on public.jeju_cart_items for select to authenticated using (user_id = auth.uid());
create policy "cart_insert_own" on public.jeju_cart_items for insert to authenticated with check (user_id = auth.uid());
create policy "cart_update_own" on public.jeju_cart_items for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "cart_delete_own" on public.jeju_cart_items for delete to authenticated using (user_id = auth.uid());

-- 주문: 본인 것만 조회 (생성/수정/반품은 아래 함수만 가능)
create policy "orders_select_own" on public.jeju_orders for select to authenticated using (user_id = auth.uid());
create policy "items_select_own" on public.jeju_order_items for select to authenticated
  using (exists (select 1 from public.jeju_orders o where o.id = order_id and o.user_id = auth.uid()));

-- 좋아요 / 댓글 / 방명록: 누구나 읽기, 로그인 사용자는 본인 것만 쓰기/삭제
create policy "likes_read" on public.jeju_likes for select to anon, authenticated using (true);
create policy "likes_insert_own" on public.jeju_likes for insert to authenticated with check (user_id = auth.uid());
create policy "likes_delete_own" on public.jeju_likes for delete to authenticated using (user_id = auth.uid());

create policy "comments_read" on public.jeju_comments for select to anon, authenticated using (true);
create policy "comments_insert_own" on public.jeju_comments for insert to authenticated with check (user_id = auth.uid());
create policy "comments_delete_own" on public.jeju_comments for delete to authenticated using (user_id = auth.uid());

create policy "guest_read" on public.jeju_guestbook for select to anon, authenticated using (true);
create policy "guest_insert_own" on public.jeju_guestbook for insert to authenticated with check (user_id = auth.uid());
create policy "guest_delete_own" on public.jeju_guestbook for delete to authenticated using (user_id = auth.uid());

-- 6. 주문 함수 (재고/합계를 DB 안에서 한 번에 처리) ----------------------

-- 주문 합계 = 주문상품 line_total(단가 x 수량) 의 합
create or replace function public.jeju_recalc_order(p_order uuid)
returns void language sql security definer set search_path = public as $$
  update public.jeju_orders
     set total_price = coalesce((select sum(line_total) from public.jeju_order_items where order_id = p_order), 0)
   where id = p_order;
$$;

-- 장바구니 전체 주문
create or replace function public.jeju_place_order()
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_order uuid;
  r       record;
begin
  if v_uid is null then raise exception '로그인이 필요합니다'; end if;
  if not exists (select 1 from public.jeju_cart_items where user_id = v_uid) then
    raise exception '장바구니가 비어 있습니다';
  end if;

  for r in
    select p.name, p.stock, c.quantity
      from public.jeju_cart_items c
      join public.jeju_products p on p.id = c.product_id
     where c.user_id = v_uid
       for update of p
  loop
    if r.stock < r.quantity then
      raise exception '"%" 재고가 부족합니다 (남은 수량 %개)', r.name, r.stock;
    end if;
  end loop;

  insert into public.jeju_orders (user_id) values (v_uid) returning id into v_order;

  insert into public.jeju_order_items (order_id, product_id, product_name, unit_price, quantity)
  select v_order, p.id, p.name, p.price, c.quantity
    from public.jeju_cart_items c
    join public.jeju_products p on p.id = c.product_id
   where c.user_id = v_uid;

  update public.jeju_products p
     set stock = p.stock - c.quantity
    from public.jeju_cart_items c
   where c.product_id = p.id and c.user_id = v_uid;

  perform public.jeju_recalc_order(v_order);
  delete from public.jeju_cart_items where user_id = v_uid;
  return v_order;
end $$;

-- 바로 구매 (상품 1개)
create or replace function public.jeju_buy_now(p_product bigint, p_qty int)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_order uuid;
  v_prod  public.jeju_products;
begin
  if v_uid is null then raise exception '로그인이 필요합니다'; end if;
  if p_qty is null or p_qty < 1 then raise exception '수량은 1 이상이어야 합니다'; end if;

  select * into v_prod from public.jeju_products where id = p_product for update;
  if not found then raise exception '상품이 없습니다'; end if;
  if v_prod.stock < p_qty then
    raise exception '"%" 재고가 부족합니다 (남은 수량 %개)', v_prod.name, v_prod.stock;
  end if;

  insert into public.jeju_orders (user_id) values (v_uid) returning id into v_order;
  insert into public.jeju_order_items (order_id, product_id, product_name, unit_price, quantity)
  values (v_order, v_prod.id, v_prod.name, v_prod.price, p_qty);

  update public.jeju_products set stock = stock - p_qty where id = v_prod.id;
  perform public.jeju_recalc_order(v_order);
  return v_order;
end $$;

-- 주문 수량 수정 (결제완료 상태에서만)
create or replace function public.jeju_update_order_item(p_item uuid, p_qty int)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_item  public.jeju_order_items;
  v_order public.jeju_orders;
  v_diff  int;
begin
  if v_uid is null then raise exception '로그인이 필요합니다'; end if;
  if p_qty is null or p_qty < 1 then raise exception '수량은 1 이상이어야 합니다'; end if;

  select * into v_item from public.jeju_order_items where id = p_item;
  if not found then raise exception '주문 항목이 없습니다'; end if;

  select * into v_order from public.jeju_orders
   where id = v_item.order_id and user_id = v_uid for update;
  if not found then raise exception '내 주문이 아닙니다'; end if;
  if v_order.status <> 'paid' then raise exception '결제완료 주문만 수정할 수 있습니다'; end if;

  v_diff := p_qty - v_item.quantity;
  if v_diff > 0 then
    update public.jeju_products set stock = stock - v_diff
     where id = v_item.product_id and stock >= v_diff;
    if not found then raise exception '재고가 부족합니다'; end if;
  elsif v_diff < 0 then
    update public.jeju_products set stock = stock - v_diff where id = v_item.product_id;
  end if;

  update public.jeju_order_items set quantity = p_qty where id = p_item;
  perform public.jeju_recalc_order(v_order.id);
end $$;

-- 주문 반품 (재고 복구)
create or replace function public.jeju_return_order(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_order public.jeju_orders;
begin
  if v_uid is null then raise exception '로그인이 필요합니다'; end if;

  select * into v_order from public.jeju_orders
   where id = p_order and user_id = v_uid for update;
  if not found then raise exception '내 주문이 아닙니다'; end if;
  if v_order.status <> 'paid' then raise exception '이미 반품된 주문입니다'; end if;

  update public.jeju_products p
     set stock = p.stock + i.quantity
    from public.jeju_order_items i
   where i.order_id = p_order and i.product_id = p.id;

  update public.jeju_orders set status = 'returned', returned_at = now() where id = p_order;
end $$;

revoke execute on function public.jeju_recalc_order(uuid) from public, anon, authenticated;
grant execute on function public.jeju_place_order()                to authenticated;
grant execute on function public.jeju_buy_now(bigint, int)         to authenticated;
grant execute on function public.jeju_update_order_item(uuid, int) to authenticated;
grant execute on function public.jeju_return_order(uuid)           to authenticated;

-- 7. 상품 데이터 (가격은 임의 설정) -------------------------------------
insert into public.jeju_products (name, description, emoji, category, price, stock) values
  ('한라봉 3kg',           '새콤달콤 향이 진한 제주 대표 감귤. 산지 직송 선물용 박스.',   '🍊', '과일',   25000, 100),
  ('천혜향 2kg',           '껍질이 얇고 과즙이 풍부한 겨울 제철 천혜향.',               '🍑', '과일',   28000,  80),
  ('제주 흑돼지 오겹살 1kg', '쫄깃한 육질과 고소한 풍미의 냉장 흑돼지 오겹살.',           '🥩', '정육',   38000,  50),
  ('옥돔 구이 세트 (3미)',   '손질해 급랭한 제주 옥돔. 구이용으로 바로 드세요.',          '🐟', '수산',   45000,  40),
  ('오메기떡 12입',         '차조로 만든 제주 전통 떡, 팥고물을 듬뿍 넣었어요.',         '🍡', '간식',   18000,  60),
  ('감귤 초콜릿 선물세트',   '제주 감귤 껍질을 넣어 만든 달콤쌉싸름한 초콜릿.',           '🍫', '간식',   12000, 120),
  ('우도 땅콩 막걸리 6병',   '우도 땅콩으로 빚어 고소하고 부드러운 막걸리.',              '🍶', '주류',   21000,  70),
  ('제주 녹차 티백 40입',    '오설록 인근 차밭에서 수확한 햇녹차 티백.',                  '🍵', '차',     15000,  90),
  ('갈치조림 밀키트 2인',    '은갈치와 무, 양념이 함께 들어 있는 간편 밀키트.',           '🍲', '밀키트', 35000,  45),
  ('제주 꿀 500g',          '한라산 자락에서 채밀한 100% 야생화 꿀.',                    '🍯', '가공',   32000,  55)
on conflict (name) do nothing;
