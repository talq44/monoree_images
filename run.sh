#!/bin/bash

# 로컬 AI 이미지 일괄 생성을 위한 사용자 인터페이스 스크립트
# run.sh

# --- 색상 정의 ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'

echo -e "${C_CYAN}=== 로컬 AI 이미지 일괄 생성기 (Mac Silicon) ===${C_RESET}"
echo "Python 가상환경을 활성화하고 이미지 생성을 준비합니다."

# --- 가상환경 활성화 ---
if [ -d "venv" ]; then
    source venv/bin/activate
    echo -e "${C_GREEN}✅ Python 가상환경이 활성화되었습니다.${C_RESET}"
else
    echo -e "${C_RED}❌ 'venv' 디렉토리를 찾을 수 없습니다. 'setup.sh' 또는 'python3 -m venv venv'를 먼저 실행해주세요.${C_RESET}"
    exit 1
fi

# --- 1단계: 대상 목록 파일 입력 ---
while true; do
    read -p "1. 키워드 목록 파일 경로를 입력하세요 (예: animal.txt): " INPUT_FILE
    if [ -z "$INPUT_FILE" ]; then
        echo -e "${C_RED}오류: 파일 경로를 반드시 입력해야 합니다.${C_RESET}"
    elif [ ! -f "$INPUT_FILE" ]; then
        echo -e "${C_RED}오류: '$INPUT_FILE' 파일을 찾을 수 없습니다. 경로를 확인해주세요.${C_RESET}"
    elif [ ! -s "$INPUT_FILE" ]; then
        echo -e "${C_RED}오류: '$INPUT_FILE' 파일이 비어있습니다. 내용을 채워주세요.${C_RESET}"
    else
        break
    fi
done

# --- 2단계: 프로젝트 이름 (출력 폴더) ---
while true; do
    read -p "2. 결과물을 저장할 폴더명을 입력하세요 (예: results/realistic_animals): " OUTPUT_DIR
    if [ -z "$OUTPUT_DIR" ]; then
        echo -e "${C_RED}오류: 폴더명을 반드시 입력해야 합니다.${C_RESET}"
    else
        # 폴더 생성 시도 및 권한 확인
        mkdir -p "$OUTPUT_DIR" &>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${C_RED}오류: '$OUTPUT_DIR' 폴더를 생성할 수 없습니다. 쓰기 권한을 확인해주세요.${C_RESET}"
        else
            echo -e "${C_GREEN}이미지는 '$OUTPUT_DIR' 폴더에 저장됩니다.${C_RESET}"
            break
        fi
    fi
done

# --- 3단계: 이미지 포맷 선택 ---
IMAGE_FORMAT="png" # 기본값
while true; do
    read -p "3. 이미지 포맷을 선택하세요 (1: png, 2: jpeg) [기본: 1]: " FORMAT_CHOICE
    FORMAT_CHOICE=${FORMAT_CHOICE:-1} # 사용자가 그냥 엔터치면 기본값 1
    case $FORMAT_CHOICE in
        1) IMAGE_FORMAT="png"; break;;
        2) IMAGE_FORMAT="jpeg"; break;;
        *) echo -e "${C_RED}오류: 1 또는 2를 입력하세요.${C_RESET}";;
    esac
done

# --- 3.1단계: 이미지 크기 선택 ---
WIDTH=512 # 기본값
HEIGHT=512 # 기본값
while true; do
    read -p "3.1. 이미지 크기를 선택하세요 (1: 256x256, 2: 512x512, 3: 1024x1024) [기본: 2]: " SIZE_CHOICE
    SIZE_CHOICE=${SIZE_CHOICE:-2}
    case $SIZE_CHOICE in
        1) WIDTH=256; HEIGHT=256; break;;
        2) WIDTH=512; HEIGHT=512; break;;
        3) WIDTH=1024; HEIGHT=1024; break;;
        *) echo -e "${C_RED}오류: 1, 2, 3 중에서 선택하세요.${C_RESET}";;
    esac
done
echo -e "${C_GREEN}이미지 크기: ${WIDTH}x${HEIGHT}${C_RESET}"

# --- 4단계: 프롬프트 템플릿 입력 ---
while true; do
    read -p "4. 프롬프트 템플릿을 입력하세요 ('{id}' 포함 필수): " PROMPT_TEMPLATE
    if [[ "$PROMPT_TEMPLATE" != *"{id}"* ]]; then
        echo -e "${C_RED}오류: 템플릿에 키워드를 대체할 '{id}'가 반드시 포함되어야 합니다.${C_RESET}"
        echo -e "${C_YELLOW}예시: a photorealistic image of a {id}, 8k, high quality${C_RESET}"
    else
        break
    fi
done

# --- 5단계: 모델 선택 (고급 옵션) ---
MODEL_ID="runwayml/stable-diffusion-v1-5" # 기본 모델
MODEL_MAP=(
    "runwayml/stable-diffusion-v1-5;기본 안정적인 모델 (SD 1.5)"
    "stabilityai/stable-diffusion-2-1;SD 1.5보다 개선된 모델 (SD 2.1)"
    "SG161222/Realistic_Vision_V5.1_noVAE;실사 느낌의 고품질 모델"
    "dreamlike-art/dreamlike-photoreal-2.0;사진처럼 사실적인 모델"
)

echo -e "\n${C_CYAN}5. 사용할 AI 모델을 선택하세요. (숫자만 입력)${C_RESET}"
for i in "${!MODEL_MAP[@]}"; do
    # ;를 기준으로 모델 ID와 설명을 분리
    IFS=';' read -r id desc <<< "${MODEL_MAP[$i]}"
    echo "$((i+1))). ${desc} (${C_YELLOW}${id}${C_RESET})"
done

while true; do
    read -p "모델 번호를 선택하세요 [기본: 1]: " MODEL_CHOICE
    MODEL_CHOICE=${MODEL_CHOICE:-1}
    if [[ "$MODEL_CHOICE" =~ ^[0-9]+$ ]] && [ "$MODEL_CHOICE" -ge 1 ] && [ "$MODEL_CHOICE" -le "${#MODEL_MAP[@]}" ]; then
        IFS=';' read -r MODEL_ID _ <<< "${MODEL_MAP[$((MODEL_CHOICE-1))]}"
        break
    else
        echo -e "${C_RED}오류: 1부터 ${#MODEL_MAP[@]} 사이의 숫자를 입력해주세요.${C_RESET}"
    fi
done
echo -e "${C_GREEN}선택된 모델: ${MODEL_ID}${C_RESET}"

# --- 최종 확인 및 실행 ---
echo -e "\n${C_YELLOW}=============== 설정 확인 ===============${C_RESET}"
echo -e "  - 키워드 파일: ${C_GREEN}${INPUT_FILE}${C_RESET}"
echo -e "  - 출력 폴더:    ${C_GREEN}${OUTPUT_DIR}${C_RESET}"
echo -e "  - 이미지 포맷:  ${C_GREEN}${IMAGE_FORMAT}${C_RESET}"
echo -e "  - 이미지 크기:  ${C_GREEN}${WIDTH}x${HEIGHT}${C_RESET}"
echo -e "  - 프롬프트:      ${C_GREEN}${PROMPT_TEMPLATE}${C_RESET}"
echo -e "  - AI 모델:       ${C_GREEN}${MODEL_ID}${C_RESET}"
echo -e "${C_YELLOW}========================================${C_RESET}"

read -p "설정이 올바르다면, 엔터 키를 눌러 이미지 생성을 시작하세요..."

# --- Python 엔진 실행 ---
python3 generator.py \
    --input_file "$INPUT_FILE" \
    --output_dir "$OUTPUT_DIR" \
    --format "$IMAGE_FORMAT" \
    --prompt_template "$PROMPT_TEMPLATE" \
    --model_id "$MODEL_ID" \
    --width "$WIDTH" \
    --height "$HEIGHT"

if [ $? -eq 0 ]; then
    echo -e "\n${C_GREEN}✨ 모든 작업이 성공적으로 완료되었습니다! '$OUTPUT_DIR' 폴더를 확인하세요.${C_RESET}"
else
    echo -e "\n${C_RED}🔥 작업 중 오류가 발생했습니다. 터미널 로그를 확인해주세요.${C_RESET}"
fi
