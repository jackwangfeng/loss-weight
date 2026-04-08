#!/bin/bash

# API 接口测试运行脚本
# 用于测试减肥 AI 助理后端 API

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
BASE_URL="${TEST_BASE_URL:-http://localhost:8000/v1}"
TOKEN=""
USER_ID=""

echo "========================================"
echo "🚀 减肥 AI 助理 - API 接口测试"
echo "========================================"
echo ""
echo -e "${BLUE}测试配置:${NC}"
echo "  Base URL: $BASE_URL"
echo "  超时时间：30s"
echo ""

# 辅助函数：打印测试结果
print_result() {
    local test_name=$1
    local status=$2
    local message=$3
    
    if [ "$status" == "PASS" ]; then
        echo -e "[${GREEN}✅ PASS${NC}] $test_name: $message"
    else
        echo -e "[${RED}❌ FAIL${NC}] $test_name: $message"
    fi
}

# 辅助函数：发送 HTTP 请求
http_post() {
    local endpoint=$1
    local data=$2
    local token=$3
    
    if [ -n "$token" ]; then
        curl -s -X POST "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -d "$data"
    else
        curl -s -X POST "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data"
    fi
}

http_get() {
    local endpoint=$1
    local token=$2
    
    if [ -n "$token" ]; then
        curl -s -X GET "$BASE_URL$endpoint" \
            -H "Authorization: Bearer $token"
    else
        curl -s -X GET "$BASE_URL$endpoint"
    fi
}

http_put() {
    local endpoint=$1
    local data=$2
    local token=$3
    
    curl -s -X PUT "$BASE_URL$endpoint" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d "$data"
}

http_delete() {
    local endpoint=$1
    local token=$2
    
    curl -s -X DELETE "$BASE_URL$endpoint" \
        -H "Authorization: Bearer $token"
}

# ============ 1. 用户模块测试 ============
echo -e "${YELLOW}📋 测试用户模块${NC}"
echo "----------------------------------------"

# 1.1 创建用户档案
echo "1.1 创建用户档案..."
CREATE_USER_DATA='{
    "openid": "test_openid_'"$(date +%s)"'",
    "nickname": "测试用户",
    "gender": "male",
    "height": 175,
    "current_weight": 75.0,
    "target_weight": 65.0,
    "activity_level": 2
}'

RESPONSE=$(http_post "/users/profile" "$CREATE_USER_DATA" "")
USER_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
    print_result "创建用户档案" "PASS" "UserID=$USER_ID"
else
    print_result "创建用户档案" "FAIL"
    echo "响应：$RESPONSE"
    exit 1
fi

# 等待一下
sleep 1

# 1.2 获取用户档案
echo "1.2 获取用户档案..."
RESPONSE=$(http_get "/users/profile/$USER_ID" "")
STATUS_CODE=$(echo "$RESPONSE" | jq -r '.id // empty')

if [ -n "$STATUS_CODE" ] && [ "$STATUS_CODE" != "null" ]; then
    print_result "获取用户档案" "PASS"
else
    print_result "获取用户档案" "FAIL"
    echo "响应：$RESPONSE"
fi

# 1.3 更新用户档案
echo "1.3 更新用户档案..."
UPDATE_DATA='{
    "current_weight": 74.5
}'

RESPONSE=$(http_put "/users/profile/$USER_ID" "$UPDATE_DATA" "")
UPDATED_WEIGHT=$(echo "$RESPONSE" | jq -r '.current_weight // empty')

if [ -n "$UPDATED_WEIGHT" ]; then
    print_result "更新用户档案" "PASS" "Weight=$UPDATED_WEIGHT"
else
    print_result "更新用户档案" "FAIL"
    echo "响应：$RESPONSE"
fi

echo ""

# ============ 2. 饮食模块测试 ============
echo -e "${YELLOW}🍽️  测试饮食模块${NC}"
echo "----------------------------------------"

# 2.1 添加饮食记录
echo "2.1 添加饮食记录..."
FOOD_RECORD_DATA='{
    "user_id": '"$USER_ID"',
    "food_name": "宫保鸡丁",
    "calories": 520,
    "protein": 25,
    "fat": 30,
    "carbohydrates": 15,
    "meal_type": "lunch"
}'

RESPONSE=$(http_post "/food/record" "$FOOD_RECORD_DATA" "")
FOOD_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

if [ -n "$FOOD_ID" ] && [ "$FOOD_ID" != "null" ]; then
    print_result "添加饮食记录" "PASS" "FoodID=$FOOD_ID"
else
    print_result "添加饮食记录" "FAIL"
    echo "响应：$RESPONSE"
fi

# 2.2 获取食物记录列表
echo "2.2 获取食物记录列表..."
RESPONSE=$(http_get "/food/records?user_id=$USER_ID" "")
COUNT=$(echo "$RESPONSE" | jq -r '.count // empty')

if [ -n "$COUNT" ]; then
    print_result "获取食物记录列表" "PASS" "Count=$COUNT"
else
    print_result "获取食物记录列表" "FAIL"
    echo "响应：$RESPONSE"
fi

# 2.3 获取每日营养汇总
echo "2.3 获取每日营养汇总..."
RESPONSE=$(http_get "/food/daily-summary?user_id=$USER_ID" "")
TOTAL_CALORIES=$(echo "$RESPONSE" | jq -r '.total_calories // empty')

if [ -n "$TOTAL_CALORIES" ]; then
    print_result "获取每日营养汇总" "PASS" "Calories=$TOTAL_CALORIES"
else
    print_result "获取每日营养汇总" "FAIL"
    echo "响应：$RESPONSE"
fi

echo ""

# ============ 3. 体重模块测试 ============
echo -e "${YELLOW}⚖️  测试体重模块${NC}"
echo "----------------------------------------"

# 3.1 记录体重
echo "3.1 记录体重..."
WEIGHT_RECORD_DATA='{
    "user_id": '"$USER_ID"',
    "weight": 74.5,
    "body_fat": 22,
    "muscle": 55,
    "bmi": 24.3
}'

RESPONSE=$(http_post "/weight/record" "$WEIGHT_RECORD_DATA" "")
WEIGHT_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

if [ -n "$WEIGHT_ID" ] && [ "$WEIGHT_ID" != "null" ]; then
    print_result "记录体重" "PASS" "WeightID=$WEIGHT_ID"
else
    print_result "记录体重" "FAIL"
    echo "响应：$RESPONSE"
fi

# 3.2 获取体重记录列表
echo "3.2 获取体重记录列表..."
RESPONSE=$(http_get "/weight/records?user_id=$USER_ID" "")
COUNT=$(echo "$RESPONSE" | jq -r '.count // empty')

if [ -n "$COUNT" ]; then
    print_result "获取体重记录列表" "PASS" "Count=$COUNT"
else
    print_result "获取体重记录列表" "FAIL"
    echo "响应：$RESPONSE"
fi

# 3.3 获取体重趋势
echo "3.3 获取体重趋势..."
RESPONSE=$(http_get "/weight/trend?user_id=$USER_ID&days=30" "")
TREND_COUNT=$(echo "$RESPONSE" | jq -r '.count // empty')

if [ -n "$TREND_COUNT" ]; then
    print_result "获取体重趋势" "PASS" "Count=$TREND_COUNT"
else
    print_result "获取体重趋势" "FAIL"
    echo "响应：$RESPONSE"
fi

echo ""

# ============ 4. AI 模块测试 ============
echo -e "${YELLOW}🤖 测试 AI 模块${NC}"
echo "----------------------------------------"

# 4.1 获取 AI 鼓励
echo "4.1 获取 AI 鼓励..."
ENCOURAGEMENT_DATA='{
    "user_id": '"$USER_ID"',
    "current_weight": 74.5,
    "target_weight": 65,
    "weight_loss": 0.5,
    "days_active": 7
}'

RESPONSE=$(http_post "/ai/encouragement" "$ENCOURAGEMENT_DATA" "")
MESSAGE=$(echo "$RESPONSE" | jq -r '.message // empty')

if [ -n "$MESSAGE" ]; then
    print_result "获取 AI 鼓励" "PASS"
else
    print_result "获取 AI 鼓励" "FAIL"
    echo "响应：$RESPONSE"
fi

# 4.2 AI 聊天
echo "4.2 AI 聊天..."
CHAT_DATA='{
    "user_id": '"$USER_ID"',
    "messages": [
        {"role": "user", "content": "如何控制晚餐热量？"}
    ]
}'

RESPONSE=$(http_post "/ai/chat" "$CHAT_DATA" "")
CHAT_MESSAGE=$(echo "$RESPONSE" | jq -r '.content // empty')

if [ -n "$CHAT_MESSAGE" ]; then
    print_result "AI 聊天" "PASS"
else
    print_result "AI 聊天" "FAIL"
    echo "响应：$RESPONSE"
fi

echo ""

# ============ 测试总结 ============
echo "========================================"
echo -e "${GREEN}✅ 所有测试完成！${NC}"
echo "========================================"
echo ""
echo "测试数据："
echo "  UserID: $USER_ID"
echo ""
