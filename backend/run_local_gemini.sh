#!/bin/bash
# 本地起后端 (Gemini AI 模式)
# - 先 source 代理（访问 Google API 需要）
# - 从 .env 加载 GEMINI_API_KEY 等
# - 跳过短信验证（测试模式）
# - 用 config.gemini.yaml
#
# 用法: ./run_local_gemini.sh

set -e
cd "$(dirname "$0")"

# 代理（Gemini API 走外网必经）
if [ -f /usr/local/proxy1.sh ]; then
    source /usr/local/proxy1.sh
    echo "✓ 代理已加载: $https_proxy"
else
    echo "⚠️  /usr/local/proxy1.sh 不存在，跳过代理加载"
fi

# 加载 .env
if [ -f .env ]; then
    set -a
    . ./.env
    set +a
    echo "✓ .env 已加载"
fi

if [ -z "$GEMINI_API_KEY" ]; then
    echo "❌ 缺少 GEMINI_API_KEY（.env 或环境变量里都没有）"
    exit 1
fi

echo "🚀 启动后端 (Gemini AI + 测试模式)..."
exec env SKIP_SMS_VERIFY=true go run cmd/server/main.go -config config.gemini.yaml
