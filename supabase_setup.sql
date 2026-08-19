-- ════════════════════════════════════════════════════════════
--  응원 수를 모든 사람이 같이 보게 만드는 설정 (Supabase)
--
--  쓰는 법
--   1. https://supabase.com 가입 → New project (무료) → 지역은 Seoul
--   2. 왼쪽 메뉴 SQL Editor → 이 파일 내용 전체 복사해서 붙여넣고 Run
--   3. 왼쪽 메뉴 Project Settings → API 에서 아래 두 개를 복사
--        - Project URL      (예: https://abcdefgh.supabase.co)
--        - anon public key  (eyJ... 로 시작하는 긴 문자열)
--   4. index.html 안의 SUPA = { url: '', key: '' } 에 붙여넣기
--
--  anon key는 브라우저에 노출되는 게 정상입니다.
--  아래 정책 때문에 외부에서 할 수 있는 일은 "읽기"와 "1씩 더하기"뿐입니다.
-- ════════════════════════════════════════════════════════════

-- 경기별 응원 수 (match_id = 캠퍼스|시즌|구간|열|경기번호)
create table if not exists public.cheers (
  match_id   text primary key,
  home       integer not null default 0,
  away       integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.cheers enable row level security;

-- 누구나 읽을 수 있다 (사이트에 숫자를 보여줘야 하므로)
drop policy if exists "cheers_read" on public.cheers;
create policy "cheers_read" on public.cheers
  for select to anon, authenticated using (true);

-- 쓰기 정책은 만들지 않는다 → 직접 INSERT/UPDATE/DELETE 불가.
-- 오직 아래 함수를 통해서만 숫자가 올라간다.
create or replace function public.cheer(p_match text, p_side text, p_n integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 한 번에 올릴 수 있는 양을 제한해 장난질을 막는다
  if p_n is null or p_n < 1 or p_n > 50 then
    raise exception '허용 범위를 벗어난 응원 수';
  end if;
  if p_side not in ('h', 'a') then
    raise exception '잘못된 팀 구분';
  end if;
  if p_match is null or length(p_match) > 120 then
    raise exception '잘못된 경기 식별자';
  end if;

  insert into public.cheers as c (match_id, home, away)
  values (p_match,
          case when p_side = 'h' then p_n else 0 end,
          case when p_side = 'a' then p_n else 0 end)
  on conflict (match_id) do update
    set home = c.home + case when p_side = 'h' then p_n else 0 end,
        away = c.away + case when p_side = 'a' then p_n else 0 end,
        updated_at = now();
end;
$$;

grant select   on public.cheers to anon, authenticated;
grant execute  on function public.cheer(text, text, integer) to anon, authenticated;

-- 확인용: 응원이 많이 들어온 경기 순서대로 보기
--   select match_id, home, away, home + away as total
--   from public.cheers order by total desc limit 20;
