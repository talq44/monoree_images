#!/bin/bash

# 로컬 AI 이미지 일괄 생성 스크립트
#
# 이 스크립트는 텍스트 파일 목록을 기반으로 Gemini API를 사용하여 이미지를 생성합니다.
# 사용법: ./generate_images.sh

# --- 초기 설정 및 색상 정의 ---
# 터미널 출력에 사용할 색상 코드
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

echo -e "${C_CYAN}=== AI 이미지 일괄 생성 스크립트 시작 ===${C_RESET}"

# --- 1단계: 대상 목록 파일 입력 및 검증 ---
while true; do
    read -p "1. 이미지로 만들 이름 목록이 담긴 파일명을 입력하세요 (예: animal.txt): " INPUT_FILE
    if [ -f "$INPUT_FILE" ]; then
        break
    else
        echo -e "${C_RED}오류: '$INPUT_FILE'을 찾을 수 없습니다. 파일명을 다시 확인해주세요.${C_RESET}"
    fi
done

# --- 2단계: 작업 이름(폴더명) 입력 ---
read -p "2. 생성된 이미지를 저장할 폴더명을 입력하세요 (예: toy3d_images): " OUTPUT_DIR
mkdir -p "$OUTPUT_DIR"
echo -e "${C_GREEN}이미지는 '$OUTPUT_DIR' 폴더에 저장됩니다.${C_RESET}"

# --- 3단계: 이미지 타입 선택 ---
IMAGE_EXT=""
while true; do
    read -p "3. 생성할 이미지 타입을 선택하세요 (1: png, 2: jpeg, 3: webp): " IMG_TYPE
    case $IMG_TYPE in
        1) IMAGE_EXT="png"; break;;
        2) IMAGE_EXT="jpeg"; break;;
        3) IMAGE_EXT="webp"; break;;
        *) echo -e "${C_RED}오류: 1, 2, 3 중에서 선택해야 합니다.${C_RESET}";;
    esac
done
echo -e "${C_GREEN}이미지 타입: $IMAGE_EXT${C_RESET}"

# --- 4단계: 프롬프트 템플릿 입력 및 검증 ---
while true; do
    read -p "4. 프롬프트 템플릿을 입력하세요 (반드시 '{id}'를 포함해야 합니다): " PROMPT_TEMPLATE
    if [[ "$PROMPT_TEMPLATE" == *"{id}"* ]]; then
        break
    else
        echo -e "${C_RED}오류: 프롬프트 템플릿에 '{id}'가 포함되어야 합니다.${C_RESET}"
    fi
done

# --- 5단계: Gemini API 토큰 입력 ---
read -s -p "5. Gemini API 키를 입력하세요: " GEMINI_API_KEY
echo # 줄바꿈

echo -e "\n${C_YELLOW}모든 설정이 완료되었습니다. 이미지 생성을 시작합니다.${C_RESET}"
echo "--------------------------------------------------"

# --- 핵심 실행 로직 ---
# 총 라인 수 계산 (진행률 표시용)
TOTAL_LINES=$(wc -l < "$INPUT_FILE")
CURRENT_LINE=0
ERROR_LOG_FILE="error.log"

# jq 설치 확인
if ! command -v jq &> /dev/null; then
    echo -e "${C_RED}오류: 이 스크립트를 실행하려면 'jq'가 필요합니다. 'sudo apt-get install jq' 또는 'brew install jq'로 설치해주세요.${C_RESET}"
    exit 1
fi

# 입력 파일을 한 줄씩 읽어 루프 실행
while IFS= read -r id || [[ -n "$id" ]]; do
    # 공백 라인 건너뛰기
    if [[ -z "$id" ]]; then
        continue
    fi

    ((CURRENT_LINE++))

    # 4.3. 파일 이름 정제 (공백 및 특수문자를 '_'로 변경)
    SAFE_ID=$(echo "$id" | tr -s ' /' '_')
    OUTPUT_FILENAME="$OUTPUT_DIR/$SAFE_ID.$IMAGE_EXT"

    # 4.4. 재시작 기능: 이미 파일이 존재하면 건너뛰기
    if [ -f "$OUTPUT_FILENAME" ]; then
        echo -e "${C_YELLOW}[$CURRENT_LINE/$TOTAL_LINES] '$id' -> 이미 존재하므로 건너뜁니다.${C_RESET}"
        continue
    fi

    # 4.2. 진행 상황 로그 출력
    echo -e "${C_BLUE}[$CURRENT_LINE/$TOTAL_LINES] '$id' 이미지 생성 중...${C_RESET}"

    # 4. 프롬프트 생성
    FINAL_PROMPT="${PROMPT_TEMPLATE//\{id\}/$id}"

    # API 호출을 위한 JSON 페이로드 생성 (Imagen-2 :predict 형식)
    JSON_PAYLOAD=$(jq -n \
                  --arg prompt "$FINAL_PROMPT" \
                  '{
                    "instances": [
                      {
                        "prompt": $prompt
                      }
                    ],
                    "parameters": {
                      "sampleCount": 1
                    }
                  }')

    # Gemini API 호출 (Imagen-2 모델)
    API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:predict"
    
    API_RESPONSE=$(curl -s -X POST \
        -H "x-goog-api-key: $GEMINI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD" \
        "$API_ENDPOINT")

    # 4.3. 오류 처리 및 응답 파싱
    # jq를 사용하여 base64 인코딩된 이미지 데이터 추출
    # Imagen :predict 응답 형식: { "predictions": [ { "bytesBase64Encoded": "..." } ] }
    BASE64_DATA=$(echo "$API_RESPONSE" | jq -r '.predictions[0].bytesBase64Encoded')

    if [[ -z "$BASE64_DATA" || "$BASE64_DATA" == "null" ]]; then
        ERROR_MESSAGE=$(echo "$API_RESPONSE" | jq -r '.error.message')
        echo -e "${C_RED}오류: '$id' 이미지 생성 실패. API 응답: ${ERROR_MESSAGE:-"알 수 없는 오류"}${C_RESET}"
        echo "$(date): '$id' - ${ERROR_MESSAGE:-$API_RESPONSE}" >> "$ERROR_LOG_FILE"
        
        # 다음 작업을 위해 1분 대기
        echo "1분 후 다음 작업을 시작합니다..."
        sleep 60
        continue
    fi

    # base64 데이터를 디코딩하여 파일로 저장
    echo "$BASE64_DATA" | base64 --decode > "$OUTPUT_FILENAME"

    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}성공: '$OUTPUT_FILENAME' 저장 완료.${C_RESET}"
    else
        echo -e "${C_RED}오류: '$id' 이미지를 파일로 저장하는 데 실패했습니다.${C_RESET}"
        echo "$(date): '$id' - 파일 저장 실패" >> "$ERROR_LOG_FILE"
    fi

    # 3. API 제한을 피하기 위한 1분 딜레이
    if [ "$CURRENT_LINE" -lt "$TOTAL_LINES" ]; then
        echo "1분 후 다음 작업을 시작합니다..."
        sleep 60
    fi
done < "$INPUT_FILE"

echo "--------------------------------------------------"
echo -e "${C_CYAN}=== 모든 작업 완료 ===${C_RESET}"


