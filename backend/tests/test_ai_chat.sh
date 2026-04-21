#!/bin/bash

echo "=== 测试 AI 聊天功能 ==="
echo ""

# 1. 登录获取 token
echo "1. 登录获取 token..."
LOGIN_RESULT=$(curl -s -X POST http://localhost:8000/v1/auth/sms/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","code":"123456"}')

TOKEN=$(echo $LOGIN_RESULT | jq -r '.token')
USER_ID=$(echo $LOGIN_RESULT | jq -r '.user_id')

echo "Token: $TOKEN"
echo "User ID: $USER_ID"
echo ""

# 2. 创建聊天线程
echo "2. 创建聊天线程..."
THREAD_RESULT=$(curl -s -X POST "http://localhost:8000/v1/ai/chat/thread?user_id=$USER_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"测试对话"}')

THREAD_ID=$(echo $THREAD_RESULT | jq -r '.id')
echo "Thread ID: $THREAD_ID"
echo ""

# 3. 发送聊天消息
echo "3. 发送聊天消息..."
CHAT_RESULT=$(curl -s -X POST http://localhost:8000/v1/ai/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"user_id\": $USER_ID,
    \"message\": \"你好，我想减肥\",
    \"thread_id\": \"$THREAD_ID\"
  }")

echo "Chat Response:"
echo $CHAT_RESULT | jq .
echo ""

# 4. 获取聊天历史
echo "4. 获取聊天历史..."
HISTORY_RESULT=$(curl -s -X GET "http://localhost:8000/v1/ai/chat/history?user_id=$USER_ID&thread_id=$THREAD_ID" \
  -H "Authorization: Bearer $TOKEN")

echo "History Response:"
echo $HISTORY_RESULT | jq .
echo ""

# 5. 获取用户线程列表
echo "5. 获取用户线程列表..."
THREADS_RESULT=$(curl -s -X GET "http://localhost:8000/v1/ai/chat/threads?user_id=$USER_ID" \
  -H "Authorization: Bearer $TOKEN")

echo "Threads Response:"
echo $THREADS_RESULT | jq .
echo ""

echo "=== 测试完成 ==="
