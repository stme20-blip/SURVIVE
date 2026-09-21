# create-room 배포 및 테스트

현재 저장소에는 함수 소스만 있으며 배포 완료를 의미하지 않습니다. 기존 DB/trigger/RLS를 사용하며 migration/reset은 실행하지 않습니다.

## Windows PowerShell

Node.js 20 이상이 필요합니다. 현재 작업 폴더에서:

```powershell
cd 'C:\Users\juoha\Documents\GAME\오염구역-테스트'
npx.cmd supabase --version
npx.cmd supabase login
npx.cmd supabase link --project-ref emcnxoqmdhksahtaxfqc
npx.cmd supabase functions deploy create-room --project-ref emcnxoqmdhksahtaxfqc
```

첫 npx 실행에서 Supabase CLI 패키지 설치에 동의합니다. 전역 npm 설치나 `supabase init`은 필요하지 않습니다. config.toml이 이미 있습니다. login은 본인 계정으로 브라우저 인증하며 link가 DB 비밀번호를 요청하면 로컬 터미널에 입력합니다. 비밀번호/토큰은 소스나 채팅에 붙이지 않습니다.

함수는 플랫폼이 주입하는 `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`를 사용합니다. Godot에 비밀키를 추가하지 않습니다. config의 verify_jwt=false는 legacy gateway 검증 대신 함수가 Auth `/auth/v1/user`에 Bearer를 보내 실제 사용자 검증을 수행하기 위한 설정입니다. 인증 실패 시 DB 접근 전에 401을 반환합니다.

Dashboard에서 확인:

- Edge Functions → create-room 배포 및 Logs 확인.
- rooms와 room_members의 기존 SELECT RLS/host 자동등록 trigger 유지. 클라이언트 쓰기 정책은 추가하지 않습니다.
- rooms insert 시 id/created_at 기본값, host trigger의 display_name/joined_at 처리가 유효해야 합니다. 실패 시 함수 로그의 DB 오류 코드를 확인합니다.
- rooms에는 이름 컬럼이 없으므로 서버 이름은 로컬에만 저장됩니다. 온라인 이름 변경/삭제, 클라우드 저장, 참가/Realtime은 이번 범위에 없습니다.

## Godot 테스트

1. 4.7.1 stable에서 F5 → 비회원으로 플레이 → 새 게임.
2. 서버 이름 입력 → 새로운 서버 만들기. 대기 중 생성/이전 버튼이 잠기는지 확인.
3. 생성 완료 메시지에 6자리 코드 확인 → 계속 → 기존 프롤로그/캐릭터/특성/에피소드 흐름 확인.
4. Dashboard rooms: host_user_id가 로그인 사용자 UUID, max_players=4, status=lobby인지 확인.
5. room_members: 동일 room_id에 host가 정확히 한 행 생성됐는지 확인.
6. 재실행 → 불러오기: 로컬 이름/초대 코드 표시 및 기존 저장의 정상 로드 확인. 로컬 삭제는 DB 서버를 삭제하지 않습니다.
7. 인증 없이 room_menu 단독 실행 → 세션 없음 안내. 연결 차단 → 네트워크 안내. 미배포 함수 → HTTP 오류 안내. 실패 시 새 로컬 방으로 이동하지 않는지 확인.
8. 웹은 최신 버전으로 다시 Export한 후 위 과정을 확인합니다.

HTTP 응답 유실 후 재시도는 서버를 하나 더 만들 수 있습니다. 이 단계는 영속적인 idempotency를 구현하지 않았으며 자동 재시도하지 않습니다. 타임아웃/비정상 응답이면 Dashboard rooms를 먼저 확인합니다. 응답을 받은 뒤 로컬 저장만 실패한 경우 계속 버튼은 저장만 재시도합니다.

## 모의 함수 검증 (DB에 연결하지 않음)

```powershell
node --experimental-strip-types --test supabase/functions/create-room/index.test.mjs
```

참고: https://supabase.com/docs/guides/functions/deploy 및 https://supabase.com/docs/guides/functions/auth-legacy-jwt
