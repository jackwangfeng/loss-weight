#!/bin/bash
#
# 减肥 AI 助理 — 前端 E2E 测试运行脚本
#
# 流程：
#   1. 检查后端 (localhost:8000)
#   2. flutter build web --release    （除非 --skip-build）
#   3. 起 python http.server 在 :8888 serve build/web
#   4. 跑 Playwright 测试
#   5. 退出时自动停掉静态服务器
#
# 用法：
#   ./run_e2e_tests.sh                  默认：构建 + 服务 + 跑全套
#   ./run_e2e_tests.sh --skip-build     跳过 flutter build（build/web 已存在时）
#   ./run_e2e_tests.sh --headed         开可视浏览器
#   ./run_e2e_tests.sh --report         跑完打开 HTML 报告
#   ./run_e2e_tests.sh --install        安装 Playwright 依赖和 Chromium
#   ./run_e2e_tests.sh -- <pw args>     `--` 后面的原样透传给 `npx playwright test`

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

FRONTEND_PORT="${FRONTEND_PORT:-8888}"
BACKEND_URL="${BACKEND_URL:-http://localhost:8000}"
FRONTEND_URL="http://localhost:${FRONTEND_PORT}"
TEST_FILES=(tests/flutter_canvas_test.js tests/backend_api_test.js)

STATIC_SRV_PID=""
STARTED_STATIC_SRV=false

cleanup() {
    if [ "$STARTED_STATIC_SRV" = true ] && [ -n "$STATIC_SRV_PID" ]; then
        echo -e "\n${YELLOW}🧹 关闭静态服务器 (pid=$STATIC_SRV_PID)...${NC}"
        kill "$STATIC_SRV_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

show_help() {
    sed -n '3,19p' "$0" | sed 's/^# \?//'
}

install_playwright() {
    echo -e "${YELLOW}📦 安装 Playwright 依赖...${NC}"
    npm install -D @playwright/test
    npx playwright install chromium
    echo -e "${GREEN}✓ 安装完成${NC}"
}

check_backend() {
    echo -e "${YELLOW}🔍 检查后端 ${BACKEND_URL}/health ...${NC}"
    if curl -sf "${BACKEND_URL}/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 后端活着${NC}"
    else
        echo -e "${RED}✗ 后端未运行${NC}"
        echo "  请先启动：cd backend && SKIP_SMS_VERIFY=true go run cmd/server/main.go -config config.test.yaml"
        exit 1
    fi
}

build_web() {
    if [ ! -f pubspec.yaml ]; then
        echo -e "${RED}✗ 当前目录不是 Flutter 工程${NC}"
        exit 1
    fi
    echo -e "${YELLOW}🔨 flutter build web --release ...${NC}"
    flutter build web --release
    echo -e "${GREEN}✓ 构建完成：build/web/${NC}"
}

ensure_static_server() {
    # 不复用现有 server——长跑后的静态服务器（不论 python/node）会出现
    # 通过浅探活但扛不住真实并发的怪态，之前已踩过好几次。每次都起新的，
    # 启动只要不到 1s，换来稳定性值得。
    existing_pid=$(ss -tlnp 2>/dev/null | awk -v p=":${FRONTEND_PORT}\\b" \
        '$0 ~ p {match($0, /pid=[0-9]+/); if (RLENGTH>0) print substr($0, RSTART+4, RLENGTH-4)}' \
        | head -1)
    if [ -n "$existing_pid" ]; then
        echo -e "${YELLOW}⚠ 端口 ${FRONTEND_PORT} 上有残留进程 (pid=$existing_pid)，结束它...${NC}"
        kill "$existing_pid" 2>/dev/null || true
        sleep 1
        kill -9 "$existing_pid" 2>/dev/null || true
        sleep 1
    fi

    if [ ! -f build/web/index.html ]; then
        echo -e "${RED}✗ 找不到 build/web/index.html，请先 build（去掉 --skip-build）${NC}"
        exit 1
    fi
    echo -e "${YELLOW}🚀 起静态服务器 node tests/static_server.js (port ${FRONTEND_PORT})...${NC}"
    PORT="$FRONTEND_PORT" node tests/static_server.js > /tmp/e2e_static_srv.log 2>&1 &
    STATIC_SRV_PID=$!
    STARTED_STATIC_SRV=true
    # 等待就绪
    for _ in $(seq 1 20); do
        sleep 0.5
        if curl -sf "${FRONTEND_URL}/" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ 静态服务器就绪 (pid=$STATIC_SRV_PID)${NC}"
            return
        fi
    done
    echo -e "${RED}✗ 静态服务器启动超时${NC}"
    tail -20 /tmp/e2e_static_srv.log
    exit 1
}

# --- parse args ---
SKIP_BUILD=false
HEADED=false
SHOW_REPORT=false
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build) SKIP_BUILD=true; shift ;;
        --headed)     HEADED=true; shift ;;
        --report)     SHOW_REPORT=true; shift ;;
        --install)    install_playwright; exit 0 ;;
        --help|-h)    show_help; exit 0 ;;
        --)           shift; EXTRA_ARGS+=("$@"); break ;;
        *)            echo -e "${RED}未知选项: $1${NC}"; show_help; exit 1 ;;
    esac
done

# --- run ---
echo "============================================"
echo "  减肥 AI 助理 — E2E 测试"
echo "============================================"
echo -e "  前端:  ${BLUE}${FRONTEND_URL}${NC}"
echo -e "  后端:  ${BLUE}${BACKEND_URL}${NC}"
echo ""

check_backend

if [ "$SKIP_BUILD" = false ]; then
    build_web
else
    echo -e "${YELLOW}⏭  跳过 flutter build web${NC}"
fi

ensure_static_server

echo ""
# 清掉 HTTP 代理：本机测试不需要代理，留着会让 Chromium 把 localhost 请求
# 发到代理上造成 60s 超时（NO_PROXY=localhost 在某些 Playwright 版本下不可靠）
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy

echo -e "${YELLOW}🧪 跑 Playwright 测试...${NC}"
PW_ARGS=(--project=chromium --reporter=list)
[ "$HEADED" = true ] && PW_ARGS+=(--headed)
if [ ${#EXTRA_ARGS[@]} -eq 0 ]; then
    PW_ARGS+=("${TEST_FILES[@]}")
else
    PW_ARGS+=("${EXTRA_ARGS[@]}")
fi

BASE_URL="${FRONTEND_URL}" API_BASE_URL="${BACKEND_URL}" \
    npx playwright test "${PW_ARGS[@]}"
TEST_EXIT=$?

echo ""
if [ "$SHOW_REPORT" = true ]; then
    echo -e "${YELLOW}📊 打开测试报告...${NC}"
    (command -v xdg-open > /dev/null && xdg-open playwright-report/index.html) \
      || (command -v open > /dev/null && open playwright-report/index.html) \
      || echo "  手动打开: file://${SCRIPT_DIR}/playwright-report/index.html"
fi

exit $TEST_EXIT
