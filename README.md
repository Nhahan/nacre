# Nacre

Windows 11에서 macOS iTerm 같은 터미널 환경을 한 번에 구성합니다.

- WSL2 (Ubuntu) + WezTerm
- zsh (자동완성, 문법 강조, git 브랜치 표시 프롬프트)
- Node.js, tmux

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
