# 서버 생성·참가 배포 및 테스트

`create-room`, `join-room`, `get-room-members`는 모두 ACTIVE 상태다. `20260921030000_join_room.sql` migration도 원격에 적용됐다. 아래 명령은 이후 변경을 배포할 때 사용한다. 기존 DB/trigger/RLS를 사용하며 reset이나 기존 테이블 변경은 하지 않는다.

## Windows PowerShell

Node.js 20 이상이 필요합니다. 현재 작업 폴더에서:

```powershell
cd 'C:\Users\juoha\Documents\GAME\오염구역-테스트'
npx.cmd supabase --version
npx.cmd supabase login
npx.cmd supabase link --project-ref emcnxoqmdhksahtaxfqc
npx.cmd supabase migration list --linked
npx.cmd supabase db push --dry-run
npx.cmd supabase db push
npx.cmd supabase functions deploy create-room --project-ref emcnxoqmdhksahtaxfqc
npx.cmd supabase functions deploy join-room --project-ref emcnxoqmdhksahtaxfqc
npx.cmd supabase functions deploy get-room-members --project-ref emcnxoqmdhksahtaxfqc
npx.cmd supabase functions deploy update-member-profile --project-ref emcnxoqmdhksahtaxfqc
npx.cmd supabase functions deploy leave-room --project-ref emcnxoqmdhksahtaxfqc
npx.cmd supabase functions deploy delete-room --project-ref emcnxoqmdhksahtaxfqc
npx.cmd supabase functions list --project-ref emcnxoqmdhksahtaxfqc
```

CLI 설치·로그인·link는 현재 완료되어 있다. 적용 후 `migration list`는 local/remote 모두 `20260921030000`을 표시해야 한다. 이후 migration을 추가할 때는 `db push --dry-run`으로 대상부터 확인한다. 비밀번호/토큰은 소스나 채팅에 붙이지 않는다.

함수는 플랫폼이 주입하는 `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`를 사용합니다. Godot에 비밀키를 추가하지 않습니다. config의 verify_jwt=false는 legacy gateway 검증 대신 함수가 Auth `/auth/v1/user`에 Bearer를 보내 실제 사용자 검증을 수행하기 위한 설정입니다. 인증 실패 시 DB 접근 전에 401을 반환합니다.

`join_room_by_code(text, uuid)` RPC는 `SECURITY DEFINER`, 안전한 `search_path`, `service_role` 전용 실행 권한을 사용한다. 함수는 인증한 사용자 UUID만 RPC에 전달한다. RPC는 같은 `rooms` 행을 `FOR UPDATE`로 잠근 상태에서 기존 멤버 확인, 최대 4명 검사, 참가자 INSERT를 처리한다. 따라서 중복 참가에는 행을 추가하지 않고, 마지막 자리에 동시에 참가하려 해도 5명이 되지 않는다.

참가자 목록은 `get-room-members` Edge Function으로 읽는다. 이는 Web Godot의 REST 직접 조회 실패를 피하기 위한 경로다. 함수는 인증된 사용자가 해당 방 멤버인지 먼저 확인하고, 멤버일 때만 목록을 반환한다.

Dashboard에서 확인:

- Edge Functions → create-room 배포 및 Logs 확인.
- rooms와 room_members의 기존 SELECT RLS/host 자동등록 trigger 유지. 클라이언트 쓰기 정책은 추가하지 않습니다.
- rooms insert 시 id/created_at 기본값, host trigger의 display_name/joined_at 처리가 유효해야 합니다. 실패 시 함수 로그의 DB 오류 코드를 확인합니다.
- `join-room` 배포 후 Edge Functions Logs에서 `JOIN_FAILED`가 나오면 RPC migration 적용 여부와 함수 환경 변수를 확인합니다. 클라이언트에 rooms/room_members의 쓰기 정책을 추가하지 않습니다.
- rooms에는 이름 컬럼이 없으므로 서버 이름은 로컬에만 저장됩니다. 온라인 이름 변경/삭제, 클라우드 저장, 참가/Realtime은 이번 범위에 없습니다.

## Godot 테스트

1. A 브라우저에서 4.7.1 stable F5 또는 최신 Web Export → 비회원으로 플레이 → 새 게임 → 서버 이름 입력 → 새로운 서버 만들기.
2. A가 계속해서 캐릭터·특성·에피소드를 선택한다. 에피소드 선택 뒤에 실제 서버가 생성되어 로비에 방장 이름과 6자리 코드가 표시되는지 확인한다.
3. B는 시크릿 창 또는 다른 브라우저에서 비회원으로 플레이한다. 시작 화면의 `초대 코드 입력 >`에서 A의 코드를 입력하고 참가한다.
4. B는 캐릭터·특성만 선택한다. 에피소드 선택 화면을 거치지 않고 A가 고른 에피소드가 적용된 로비에 방장과 본인 이름으로 표시되는지 확인한다. 일반 UI에는 UUID가 표시되지 않는다.
5. Dashboard: `rooms`는 한 행을 유지하고 `room_members`에는 host 1행·member 1행, 총 2행이 있어야 한다.
6. B에서 같은 코드를 다시 입력한다. 성공하되 `room_members` 행은 증가하지 않아야 한다.
7. C, D도 같은 코드로 참가하면 총 4명까지 성공한다. E는 `이미 참가 인원이 가득 찬 서버입니다.`를 받고 행 수는 4로 유지된다.
8. 기존 로컬 저장을 불러오면 코드와 참가자 목록이 다시 표시된다. 로컬 삭제는 DB 서버를 삭제하지 않는다.
9. 웹은 최신 버전으로 다시 Export한 후 A/B 과정을 확인한다.

HTTP 응답 유실 후 재시도는 서버를 하나 더 만들 수 있습니다. 이 단계는 영속적인 idempotency를 구현하지 않았으며 자동 재시도하지 않습니다. 타임아웃/비정상 응답이면 Dashboard rooms를 먼저 확인합니다. 응답을 받은 뒤 로컬 저장만 실패한 경우 계속 버튼은 저장만 재시도합니다.

## 검증 명령

```powershell
node --experimental-strip-types --test supabase/functions/create-room/index.test.mjs supabase/functions/join-room/index.test.mjs
```

참고: https://supabase.com/docs/guides/functions/deploy 및 https://supabase.com/docs/guides/functions/auth-legacy-jwt
