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

# --- 5단계: 이미지 생성 서비스 선택 ---
SERVICE=""
while true; do
    read -p "5. 사용할 이미지 생성 서비스를 선택하세요 (1: Gemini, 2: GPT): " SERVICE_CHOICE
    case $SERVICE_CHOICE in
        1) SERVICE="gemini"; SERVICE_LABEL="Gemini"; break;;
        2) SERVICE="gpt"; SERVICE_LABEL="GPT"; break;;
        *) echo -e "${C_RED}오류: 1 또는 2 중에서 선택해야 합니다.${C_RESET}";;
    esac
done
echo -e "${C_GREEN}선택된 서비스: $SERVICE_LABEL${C_RESET}"

# --- 6단계: 서비스별 API 키 입력 ---
if [ "$SERVICE" == "gemini" ]; then
    read -s -p "6. Gemini API 키를 입력하세요: " GEMINI_API_KEY
    echo
else
    read -s -p "6. OpenAI API 키를 입력하세요: " OPENAI_API_KEY
    echo
fi

# jq 설치 확인
if ! command -v jq &> /dev/null; then
    echo -e "${C_RED}오류: 이 스크립트를 실행하려면 'jq'가 필요합니다. 'sudo apt-get install jq' 또는 'brew install jq'로 설치해주세요.${C_RESET}"
    exit 1
fi

# --- 서비스별 추가 설정 ---
if [ "$SERVICE" == "gemini" ]; then
    echo -e "\n${C_BLUE}사용 가능한 Gemini 이미지 생성 모델을 조회 중입니다...${C_RESET}"
    MODEL_LIST_JSON=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY")

    # 'predict'를 지원하거나 이름에 'image'가 포함된 모델을 필터링
    # 포맷: 모델명;지원메소드1,지원메소드2
    MODEL_DATA=$(echo "$MODEL_LIST_JSON" | jq -r '
        .models[] | 
        select(
            (.name | contains("image")) or 
            (.supportedGenerationMethods | index("predict"))
        ) | 
        [.name, (.supportedGenerationMethods | join(","))] | @tsv' | tr -d '"' | sed 's/\t/;/')

    if [[ -z "$MODEL_DATA" ]]; then
        echo -e "${C_RED}오류: 사용 가능한 이미지 생성 모델을 찾을 수 없습니다. API 키를 확인해주세요.${C_RESET}"
        exit 1
    fi

    # 모델 이름과 메소드를 배열에 저장
    MODEL_NAMES=()
    while IFS= read -r line; do
        MODEL_NAMES+=("$line")
    done < <(echo "$MODEL_DATA" | cut -d';' -f1 | sed 's/models\///')

    MODEL_METHODS=()
    while IFS= read -r line; do
        MODEL_METHODS+=("$line")
    done < <(echo "$MODEL_DATA" | cut -d';' -f2)

    echo -e "\n${C_CYAN}사용 가능한 이미지 생성 모델 목록:${C_RESET}"
    i=0
    for name in "${MODEL_NAMES[@]}"; do
        # 유료 모델인 경우 (이름에 'imagen' 포함) 표시 추가
        if [[ "$name" == *"imagen"* ]]; then
            echo "$((i+1)). $name ${C_YELLOW}(유료 계정 필요)${C_RESET}"
        else
            echo "$((i+1)). $name"
        fi
        ((i++))
    done

    # 사용자 선택
    while true; do
        read -p "7. 사용할 Gemini 모델 번호를 선택하세요: " MODEL_CHOICE
        if [[ "$MODEL_CHOICE" =~ ^[0-9]+$ ]] && [ "$MODEL_CHOICE" -ge 1 ] && [ "$MODEL_CHOICE" -le "${#MODEL_NAMES[@]}" ]; then
            SELECTED_MODEL_NAME=${MODEL_NAMES[$((MODEL_CHOICE-1))]}
            SELECTED_MODEL_METHOD_LIST=${MODEL_METHODS[$((MODEL_CHOICE-1))]}
            break
        else
            echo -e "${C_RED}오류: 1부터 ${#MODEL_NAMES[@]} 사이의 숫자를 입력해주세요.${C_RESET}"
        fi
    done

    echo -e "${C_GREEN}선택된 모델: $SELECTED_MODEL_NAME${C_RESET}"
else
    echo -e "\n${C_CYAN}GPT 이미지 모델 선택:${C_RESET}"
    GPT_MODELS=("gpt-image-1" "dall-e-3")
    for idx in "${!GPT_MODELS[@]}"; do
        echo "$((idx+1)). ${GPT_MODELS[$idx]}"
    done

    while true; do
        read -p "7. 사용할 GPT 이미지 모델 번호를 선택하세요: " GPT_MODEL_CHOICE
        if [[ "$GPT_MODEL_CHOICE" =~ ^[0-9]+$ ]] && [ "$GPT_MODEL_CHOICE" -ge 1 ] && [ "$GPT_MODEL_CHOICE" -le "${#GPT_MODELS[@]}" ]; then
            GPT_MODEL=${GPT_MODELS[$((GPT_MODEL_CHOICE-1))]}
            break
        else
            echo -e "${C_RED}오류: 1부터 ${#GPT_MODELS[@]} 사이의 숫자를 입력해주세요.${C_RESET}"
        fi
    done

    echo -e "\n${C_CYAN}GPT 이미지 해상도 선택:${C_RESET}"
    echo "1. 1024x1024"
    echo "2. 512x512"
    echo "3. 256x256"
    while true; do
        read -p "8. 원하는 해상도 번호를 선택하세요: " GPT_SIZE_CHOICE
        case $GPT_SIZE_CHOICE in
            1) GPT_IMAGE_SIZE="1024x1024"; break;;
            2) GPT_IMAGE_SIZE="512x512"; break;;
            3) GPT_IMAGE_SIZE="256x256"; break;;
            *) echo -e "${C_RED}오류: 1, 2, 3 중에서 선택해야 합니다.${C_RESET}";;
        esac
    done

    echo -e "${C_GREEN}선택된 GPT 모델: $GPT_MODEL (${GPT_IMAGE_SIZE})${C_RESET}"
fi

echo -e "\n${C_YELLOW}모든 설정이 완료되었습니다. 이미지 생성을 시작합니다.${C_RESET}"
echo "--------------------------------------------------"

# --- 핵심 실행 로직 ---
TOTAL_LINES=$(wc -l < "$INPUT_FILE")
CURRENT_LINE=0
ERROR_LOG_FILE="error.log"

while IFS= read -r id || [[ -n "$id" ]]; do
    if [[ -z "$id" ]]; then
        continue
    fi

    ((CURRENT_LINE++))

    SAFE_ID=$(echo "$id" | tr -s ' /' '_')
    OUTPUT_FILENAME="$OUTPUT_DIR/$SAFE_ID.$IMAGE_EXT"

    if [ -f "$OUTPUT_FILENAME" ]; then
        echo -e "${C_YELLOW}[$CURRENT_LINE/$TOTAL_LINES] '$id' -> 이미 존재하므로 건너뜁니다.${C_RESET}"
        continue
    fi

    echo -e "${C_BLUE}[$CURRENT_LINE/$TOTAL_LINES] '$id' 이미지 생성 중...${C_RESET}"

    FINAL_PROMPT="${PROMPT_TEMPLATE//\{id\}/$id}"

    BASE64_DATA=""
    IMAGE_URL=""

    if [ "$SERVICE" == "gemini" ]; then
        # 선택된 모델의 지원 메소드에 따라 API 호출 분기
        if [[ "$SELECTED_MODEL_METHOD_LIST" == *"predict"* ]]; then
            # --- 'predict' 방식 API 호출 ---
            API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models/$SELECTED_MODEL_NAME:predict"
            JSON_PAYLOAD=$(jq -n --arg prompt "$FINAL_PROMPT" \
                          '{
                            "instances": [{"prompt": $prompt}],
                            "parameters": {"sampleCount": 1}
                          }')
            
            API_RESPONSE=$(curl -s -X POST \
                -H "x-goog-api-key: $GEMINI_API_KEY" \
                -H "Content-Type: application/json" \
                -d "$JSON_PAYLOAD" \
                "$API_ENDPOINT")

            BASE64_DATA=$(echo "$API_RESPONSE" | jq -r '.predictions[0].bytesBase64Encoded')

        else
            # --- 'generateContent' 방식 API 호출 ---
            API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models/$SELECTED_MODEL_NAME:generateContent?key=$GEMINI_API_KEY"
            JSON_PAYLOAD=$(jq -n --arg prompt "$FINAL_PROMPT" --arg format "$IMAGE_EXT" \
                          '{
                            "contents": [{"parts": [{"text": $prompt}]}],
                            "generationConfig": {"responseMimeType": "image/'$IMAGE_EXT'"}
                          }')

            API_RESPONSE=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "$JSON_PAYLOAD" \
                "$API_ENDPOINT")

            BASE64_DATA=$(echo "$API_RESPONSE" | jq -r '.candidates[0].content.parts[0].inlineData.data')
        fi
    else
        # --- GPT 이미지 생성 API 호출 ---
        API_ENDPOINT="https://api.openai.com/v1/images/generations"
        JSON_PAYLOAD=$(jq -n --arg prompt "$FINAL_PROMPT" --arg model "$GPT_MODEL" --arg size "$GPT_IMAGE_SIZE" \
                      '{
                        "model": $model,
                        "prompt": $prompt,
                        "size": $size
                      }')

        API_RESPONSE=$(curl -s -X POST \
            -H "Authorization: Bearer $OPENAI_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$JSON_PAYLOAD" \
            "$API_ENDPOINT")

        BASE64_DATA=$(echo "$API_RESPONSE" | jq -r '.data[0].b64_json // empty')
        if [[ -z "$BASE64_DATA" || "$BASE64_DATA" == "null" ]]; then
            IMAGE_URL=$(echo "$API_RESPONSE" | jq -r '.data[0].url // empty')
        fi
    fi

    # --- 공통 오류 처리 및 파일 저장 ---
    if [[ -z "$BASE64_DATA" || "$BASE64_DATA" == "null" ]] && [[ -z "$IMAGE_URL" || "$IMAGE_URL" == "null" ]]; then
        ERROR_MESSAGE=$(echo "$API_RESPONSE" | jq -r '.error.message')
        echo -e "${C_RED}오류: '$id' 이미지 생성 실패. API 응답: ${ERROR_MESSAGE:-"알 수 없는 오류"}${C_RESET}"
        echo "$(date): '$id' - ${ERROR_MESSAGE:-$API_RESPONSE}" >> "$ERROR_LOG_FILE"
        
        echo "1분 후 다음 작업을 시작합니다..."
        sleep 60
        continue
    fi

    if [[ -n "$BASE64_DATA" && "$BASE64_DATA" != "null" ]]; then
        echo "$BASE64_DATA" | base64 --decode > "$OUTPUT_FILENAME"
        SAVE_EXIT_CODE=$?
    else
        curl -sL "$IMAGE_URL" -o "$OUTPUT_FILENAME"
        SAVE_EXIT_CODE=$?
    fi

    if [ $SAVE_EXIT_CODE -eq 0 ]; then
        echo -e "${C_GREEN}성공: '$OUTPUT_FILENAME' 저장 완료.${C_RESET}"
    else
        echo -e "${C_RED}오류: '$id' 이미지를 파일로 저장하는 데 실패했습니다.${C_RESET}"
        echo "$(date): '$id' - 파일 저장 실패" >> "$ERROR_LOG_FILE"
    fi

    if [ "$CURRENT_LINE" -lt "$TOTAL_LINES" ]; then
        echo "1분 후 다음 작업을 시작합니다..."
        sleep 60
    fi
done < "$INPUT_FILE"

echo "--------------------------------------------------"
echo -e "${C_CYAN}=== 모든 작업 완료 ===${C_RESET}"
