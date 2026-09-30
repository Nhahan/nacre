# Nacre

Windows 11에서 macOS iTerm 같은 터미널 환경을 한 번에 구성합니다.

## 기능

- iTerm 스타일 화면: iTerm2 색상, Meslo LG M 폰트, 통합 탭바
- WSL2 Ubuntu + zsh: 자동완성, 문법 강조, git 브랜치 표시 프롬프트
- 화면 분할: 좌우·상하 분할, 분할 및 창 크기 변경 시 자동 균등 배치
- 탭바 `+` 버튼: 좌클릭 새 탭, 우클릭 메뉴(새 창, 분할, 화면 닫기)
- Ctrl+C 복사(선택 시)·중단, Ctrl+V 붙여넣기
- Ctrl+마우스 휠 글자 크기 조절 (창 크기 유지)
- Shift+Enter 줄바꿈, Alt/Ctrl+←/→ 단어 이동
- `open` 명령: 폴더·파일·URL을 Windows 앱으로 열기
- Node.js, tmux 포함, 한 줄 설치

## 설치

PowerShell에서 실행합니다.

```powershell
irm https://nhahan.github.io/nacre/install.ps1 | iex
```

재부팅하라는 안내가 나오면 재부팅한 뒤 같은 명령을 다시 실행합니다.
설치가 끝나면 바탕화면의 **Ubuntu (WSL)** 을 엽니다.

## 단축키

| 동작 | 키 |
|---|---|
| 화면 좌우 분할 | Ctrl+Shift+V |
| 화면 상하 분할 | Ctrl+Shift+H |
| 분할 화면 이동 | Ctrl+Shift+방향키 |
| 탭 이동 | Alt+1~9 |
| 줄바꿈 | Shift+Enter |
