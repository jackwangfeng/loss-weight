#!/bin/bash

echo "========================================"
echo "  后端 API 接口测试"
echo "========================================"
echo ""

BASE_URL="http://localhost:8000/v1"
TOKEN=""
USER_ID=""

# 1. 测试健康检查
echo "=== 1. 健康检查 ==="
curl -s http://localhost:8000/health | jq .
echo ""

# 2. 测试发送短信验证码
echo "=== 2. 发送短信验证码 ==="
RESULT=$(curl -s -X POST $BASE_URL/auth/sms/send \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","purpose":"login"}')
echo $RESULT | jq .
echo ""

# 3. 测试手机号登录
echo "=== 3. 手机号登录 ==="
LOGIN_RESULT=$(curl -s -X POST $BASE_URL/auth/sms/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","code":"123456"}')
echo $LOGIN_RESULT | jq .

TOKEN=$(echo $LOGIN_RESULT | jq -r '.token')
USER_ID=$(echo $LOGIN_RESULT | jq -r '.user_id')
echo "Token: $TOKEN"
echo "User ID: $USER_ID"
echo ""

# 4. 测试获取当前用户信息
echo "=== 4. 获取当前用户信息 ==="
curl -s -X GET $BASE_URL/auth/me \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

# 5. 测试创建用户档案
echo "=== 5. 创建用户档案 ==="
PROFILE_RESULT=$(curl -s -X POST $BASE_URL/users/profile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "nickname": "测试用户",
    "gender": "male",
    "height": 175,
    "current_weight": 75.0,
    "target_weight": 65.0
  }')
echo $PROFILE_RESULT | jq .
echo ""

# 6. 测试获取用户档案
echo "=== 6. 获取用户档案 ==="
curl -s -X GET $BASE_URL/users/profile/$USER_ID \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

# 7. 测试添加饮食记录
echo "=== 7. 添加饮食记录 ==="
FOOD_RESULT=$(curl -s -X POST $BASE_URL/food/record \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "user_id": '"$USER_ID"',
    "food_name": "宫保鸡丁",
    "calories": 520,
    "protein": 25,
    "carbs": 15,
    "fat": 30,
    "portion": 200,
    "unit": "g",
    "meal_type": "lunch",
    "recorded_at": "2026-04-08T12:00:00Z"
  }')
echo $FOOD_RESULT | jq .
FOOD_ID=$(echo $FOOD_RESULT | jq -r '.id // .record_id // .data.id // empty')
echo "Food Record ID: $FOOD_ID"
echo ""

# 8. 测试获取饮食记录列表
echo "=== 8. 获取饮食记录列表 ==="
curl -s -X GET "$BASE_URL/food/records?user_id=$USER_ID" \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

# 9. 测试获取每日饮食汇总
echo "=== 9. 获取每日饮食汇总 ==="
curl -s -X GET "$BASE_URL/food/daily-summary?user_id=$USER_ID&date=2026-04-08" \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

# 10. 测试添加体重记录
echo "=== 10. 添加体重记录 ==="
WEIGHT_RESULT=$(curl -s -X POST $BASE_URL/weight/record \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "user_id": '"$USER_ID"',
    "weight": 74.5,
    "note": "晨重",
    "measured_at": "2026-04-08T08:00:00Z"
  }')
echo $WEIGHT_RESULT | jq .
WEIGHT_ID=$(echo $WEIGHT_RESULT | jq -r '.id // .record_id // .data.id // empty')
echo "Weight Record ID: $WEIGHT_ID"
echo ""

# 11. 测试获取体重记录列表
echo "=== 11. 获取体重记录列表 ==="
curl -s -X GET "$BASE_URL/weight/records?user_id=$USER_ID" \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

# 12. 测试获取体重趋势
echo "=== 12. 获取体重趋势 ==="
curl -s -X GET "$BASE_URL/weight/trend?user_id=$USER_ID&days=30" \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

# 13. 测试 AI 聊天
echo "=== 13. AI 聊天 ==="
CHAT_RESULT=$(curl -s -X POST $BASE_URL/ai/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "user_id": '"$USER_ID"',
    "messages": [{"role": "user", "content": "你好，我想减肥"}]
  }')
echo $CHAT_RESULT | jq .
echo ""

# 14. 测试获取 AI 鼓励
echo "=== 14. 获取 AI 鼓励 ==="
curl -s -X POST $BASE_URL/ai/encouragement \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "user_id": '"$USER_ID"',
    "current_weight": 75.0,
    "target_weight": 65.0,
    "weight_loss": 0,
    "days_active": 7
  }' | jq .
echo ""

# 15. 测试创建聊天线程
echo "=== 15. 创建聊天线程 ==="
THREAD_RESULT=$(curl -s -X POST "$BASE_URL/ai/chat/thread?user_id=$USER_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title": "测试对话"}')
echo $THREAD_RESULT | jq .
THREAD_ID=$(echo $THREAD_RESULT | jq -r '.id // .thread_id // .data.id // empty')
echo "Thread ID: $THREAD_ID"
echo ""

# 16. 测试获取聊天线程列表
echo "=== 16. 获取聊天线程列表 ==="
curl -s -X GET "$BASE_URL/ai/chat/threads?user_id=$USER_ID" \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

# 17. 测试获取聊天历史
if [ -n "$THREAD_ID" ] && [ "$THREAD_ID" != "null" ]; then
  echo "=== 17. 获取聊天历史 ==="
  curl -s -X GET "$BASE_URL/ai/chat/history?user_id=$USER_ID&thread_id=$THREAD_ID" \
    -H "Authorization: Bearer $TOKEN" | jq .
  echo ""
fi

# 18. 测试删除饮食记录
if [ -n "$FOOD_ID" ] && [ "$FOOD_ID" != "null" ]; then
  echo "=== 18. 删除饮食记录 ==="
  curl -s -X DELETE "$BASE_URL/food/record/$FOOD_ID" \
    -H "Authorization: Bearer $TOKEN" | jq .
  echo ""
fi

# 19. 测试删除体重记录
if [ -n "$WEIGHT_ID" ] && [ "$WEIGHT_ID" != "null" ]; then
  echo "=== 19. 删除体重记录 ==="
  curl -s -X DELETE "$BASE_URL/weight/record/$WEIGHT_ID" \
    -H "Authorization: Bearer $TOKEN" | jq .
  echo ""
fi

# 20. 测试退出登录
echo "=== 20. 退出登录 ==="
curl -s -X POST $BASE_URL/auth/logout \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

echo "========================================"
echo "  ✅ 所有 API 测试完成！"
echo "========================================"
