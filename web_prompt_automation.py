#!/usr/bin/env python3
"""
브라우저 자동화를 이용해 웹 UI에 프롬프트를 주기적으로 입력하는 스크립트.
Playwright를 사용하며, generate_images.sh와 유사한 단계별 입력을 제공한다.
"""

import asyncio
from dataclasses import dataclass
from pathlib import Path
from typing import List

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError


DEFAULT_BASE_URL = "https://gemini.google.com/app"
DEFAULT_PROMPT_SELECTOR = "textarea"
DEFAULT_SEND_SELECTOR = 'button[aria-label*="send"]'


@dataclass
class Config:
    ids: List[str]
    prompt_template: str
    base_url: str
    prompt_selector: str
    use_enter_submit: bool
    send_button_selector: str
    delay_seconds: int


def read_ids(file_path: Path) -> List[str]:
    with file_path.open(encoding="utf-8") as f:
        return [line.strip() for line in f if line.strip()]


def prompt_text(message: str, validator=None, default: str | None = None) -> str:
    while True:
        raw = input(message).strip()
        if not raw and default is not None:
            raw = default
        if not raw:
            print("값이 비어있습니다. 다시 입력해주세요.")
            continue
        if validator and not validator(raw):
            continue
        return raw


def build_config() -> Config:
    input_file = Path(
        prompt_text("1. 이미지로 만들 이름 목록이 담긴 파일명을 입력하세요 (예: animal.txt): ",
                    validator=lambda p: Path(p).is_file()))
    ids = read_ids(input_file)
    if not ids:
        raise SystemExit("입력 파일에 유효한 ID가 없습니다.")

    prompt_template = prompt_text(
        "2. 프롬프트 템플릿을 입력하세요 (반드시 '{id}'를 포함해야 합니다): ",
        validator=lambda txt: "{id}" in txt
    )

    base_url = prompt_text(
        f"3. 자동화할 웹 페이지 URL을 입력하세요 [{DEFAULT_BASE_URL}]: ",
        default=DEFAULT_BASE_URL
    )

    prompt_selector = prompt_text(
        f"4. 프롬프트 입력창 CSS 셀렉터를 입력하세요 [{DEFAULT_PROMPT_SELECTOR}]: ",
        default=DEFAULT_PROMPT_SELECTOR
    )

    use_enter_submit = prompt_text(
        "5. Enter 키로 전송하시겠습니까? (y/n, 기본: y): ",
        default="y"
    ).lower().startswith("y")

    send_button_selector = ""
    if not use_enter_submit:
        send_button_selector = prompt_text(
            f"5-1. 전송 버튼 CSS 셀렉터를 입력하세요 [{DEFAULT_SEND_SELECTOR}]: ",
            default=DEFAULT_SEND_SELECTOR
        )

    delay_seconds = int(
        prompt_text(
            "6. 각 요청 사이 대기 시간을 초 단위로 입력하세요 (권장: 60 이상): ",
            validator=lambda v: v.isdigit() and int(v) >= 0,
            default="65"
        )
    )

    return Config(
        ids=ids,
        prompt_template=prompt_template,
        base_url=base_url,
        prompt_selector=prompt_selector,
        use_enter_submit=use_enter_submit,
        send_button_selector=send_button_selector,
        delay_seconds=delay_seconds
    )


async def wait_for_user_confirmation(message: str) -> None:
    await asyncio.to_thread(lambda: input(message))


async def run_automation(config: Config) -> None:
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()
        await page.goto(config.base_url)

        print("\n브라우저가 열렸습니다. 로그인 및 모델 선택을 완료한 뒤 Enter 키를 눌러주세요.")
        await wait_for_user_confirmation("준비가 되면 Enter: ")

        prompt_locator = page.locator(config.prompt_selector).first
        try:
            await prompt_locator.wait_for(timeout=15000)
        except PlaywrightTimeoutError:
            raise SystemExit("프롬프트 입력창을 찾을 수 없습니다. 셀렉터를 다시 확인해주세요.")

        total = len(config.ids)
        for idx, item in enumerate(config.ids, start=1):
            final_prompt = config.prompt_template.replace("{id}", item)
            print(f"[{idx}/{total}] '{item}' 입력 중...")

            try:
                await prompt_locator.click(timeout=10000)
                await prompt_locator.fill(final_prompt)
                if config.use_enter_submit:
                    await prompt_locator.press("Enter")
                else:
                    button_locator = page.locator(config.send_button_selector).first
                    await button_locator.click(timeout=10000)
            except PlaywrightTimeoutError as exc:
                print(f"오류: '{item}' 전송 실패 ({exc}). 다음 항목으로 넘어갑니다.")
                continue

            if idx < total and config.delay_seconds > 0:
                await asyncio.sleep(config.delay_seconds)

        print("=== 모든 프롬프트 입력 완료 ===")
        await wait_for_user_confirmation("브라우저를 종료하려면 Enter: ")
        await browser.close()


def main() -> None:
    config = build_config()
    try:
        asyncio.run(run_automation(config))
    except KeyboardInterrupt:
        print("\n사용자에 의해 중단되었습니다.")


if __name__ == "__main__":
    main()
