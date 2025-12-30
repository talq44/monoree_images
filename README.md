# monoree_images
모노리에서 사용할 이미지 목록을 업로드 합니다.

## 웹 UI 자동 입력 스크립트

API 사용이 어려울 때를 대비해, Playwright 기반의 웹 자동화 스크립트(`web_prompt_automation.py`)를 추가했습니다. 브라우저에서 Gemini 등 이미지 생성 페이지를 열어 둔 상태에서, 리스트 파일을 기반으로 1~2분 간격으로 프롬프트를 자동 입력합니다.

### 준비

1. Python 3.10+ 환경에서 Playwright 설치:
   ```bash
   pip install playwright
   playwright install
   ```
2. 이미지로 만들 ID 목록 파일(예: `animal.txt`)과 프롬프트 템플릿(예: `A 3D cartoon {id} ...`)을 준비합니다.

### 사용 방법

```bash
python web_prompt_automation.py
```

스크립트는 쉘에서 단계별로 아래 정보를 묻습니다.

1. ID 목록 파일 경로
2. `{id}` 플레이스홀더를 포함한 프롬프트 템플릿
3. 자동화할 웹 페이지 URL (기본: `https://gemini.google.com/app`)
4. 프롬프트 입력창 CSS 셀렉터 (기본: `textarea`)
5. Enter 전송 여부 및 필요 시 전송 버튼 셀렉터
6. 각 요청 사이 대기 시간(초)

브라우저가 열린 뒤 로그인과 모델 선택을 직접 완료하고 Enter를 누르면, 스크립트가 목록을 순회하며 프롬프트를 입력/전송합니다. 페이지 구조나 언어에 따라 CSS 셀렉터가 달라질 수 있으니, 필요 시 개발자도구에서 원하는 요소의 고유 셀렉터를 확인해 입력하면 됩니다.

> 서비스 약관에 따라 자동 입력이 제한될 수 있으므로, 사용 전에 대상 플랫폼 정책을 반드시 확인하세요.
