# Nacre

Windows 11에서 macOS iTerm 같은 터미널 환경을 한 번에 구성합니다.

## 기능

- 화면 분할 (좌우·상하), 자동 균등 배치
- 탭바 `+` 버튼 우클릭 메뉴 (새 창, 분할, 닫기)
- Ctrl+C 복사, Ctrl+V 붙여넣기
- Ctrl+마우스 휠로 글자 크기 조절
- Shift+Enter 줄바꿈
- `open` 명령으로 폴더·파일·URL을 Windows에서 열기
- 한 줄 설치

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
