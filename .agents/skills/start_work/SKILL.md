---
name: "작업시작"
description: "github에서 최신 코드를 pull하고 웹 빌드 후 터널링 테스트 환경을 자동으로 구성합니다."
---

# 작업시작 (Start Work)

사용자가 채팅에서 `작업시작` 이라고 명령하면, 즉시 아래의 단계를 순차적으로 자동 실행하여 테스트 환경을 완벽하게 세팅하세요:

1. 작업 디렉토리를 `/Users/ray/Documents/Ray_project/chatting_app` 으로 맞추고, `git pull`을 실행해 최신 소스코드를 다운로드하세요.
2. `flutter pub get` 명령어로 패키지를 업데이트하세요.
3. `flutter build web` 명령어로 웹 빌드를 진행하고, 빌드가 끝날 때까지 대기하세요.
4. `run_command` 도구를 이용해 `python3 -m http.server 45678 -d build/web` 백그라운드 태스크를 실행하여 로컬 서버를 띄우세요.
5. `run_command` 도구를 이용해 `npx -y cloudflared tunnel --url http://localhost:45678` 백그라운드 태스크를 실행하세요.
6. cloudflared 터널 로그에서 `https://*.trycloudflare.com` 형태의 외부 접속 URL을 찾아낸 뒤, 그 URL을 사용자에게 알려주며 세팅이 완료되었다고 보고하세요.
