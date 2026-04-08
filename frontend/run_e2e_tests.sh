#!/bin/bash

# 减肥 AI 助理 - 前端 E2E 测试运行脚本
# 使用方法:
#   ./run_e2e_tests.sh           # 正常运行测试
#   ./run_e2e_tests.sh --headed  # 显示浏览器界面
#   ./run_e2e_tests.sh --debug   # 调试模式
#   ./run_e2e_tests.sh --help    # 显示帮助

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 帮助信息
show_help() {
    echo "用法：$0 [选项]"
    echo ""
    echo "选项:"
    echo "  --headed      显示浏览器界面（非无头模式）"
    echo "  --debug       调试模式"
    echo "  --report      运行测试后打开报告"
    echo "  --install     安装 Playwright 和浏览器"
    echo "  --help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                    # 正常运行测试"
    echo "  $0 --headed           # 显示浏览器界面"
    echo "  $0 --debug            # 调试模式"
    echo "  $0 --install          # 安装依赖"
    echo ""
}

# 检查 Node.js 是否安装
check_node() {
    if ! command -v node &> /dev/null; then
        echo -e "${RED}错误：未找到 Node.js，请先安装 Node.js${NC}"
        exit 1
    fi
    
    echo "Node.js 版本：$(node -v)"
    echo "npm 版本：$(npm -v)"
}

# 安装 Playwright
install_playwright() {
    echo -e "${YELLOW}正在安装 Playwright...${NC}"
    
    # 检查 package.json 是否存在
    if [ ! -f "package.json" ]; then
        echo -e "${RED}错误：未找到 package.json，请在 frontend 目录下运行此脚本${NC}"
        exit 1
    fi
    
    # 安装 Playwright
    npm install -D @playwright/test
    
    # 安装浏览器
    npx playwright install chromium
    
    echo -e "${GREEN}Playwright 安装完成！${NC}"
}

# 检查前端服务是否运行
check_frontend_server() {
    echo -e "${YELLOW}检查前端服务是否运行...${NC}"
    
    if curl -s http://localhost:8888 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 前端服务正在运行 (http://localhost:8888)${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ 前端服务未运行${NC}"
        echo "请先启动前端服务："
        echo "  cd frontend"
        echo "  flutter run -d web-server --web-port=8888"
        echo ""
        read -p "是否现在启动前端服务？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}正在启动前端服务...${NC}"
            flutter run -d web-server --web-port=8888 &
            sleep 10
        else
            echo -e "${RED}测试无法继续，已退出${NC}"
            exit 1
        fi
    fi
}

# 检查后端服务是否运行
check_backend_server() {
    echo -e "${YELLOW}检查后端服务是否运行...${NC}"
    
    if curl -s http://localhost:8000 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 后端服务正在运行 (http://localhost:8000)${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ 后端服务未运行${NC}"
        echo "提示：后端服务未运行，部分测试可能会失败"
        echo "可以使用 'make local' 启动后端服务："
        echo "  cd backend"
        echo "  make local"
        echo ""
    fi
}

# 运行测试
run_tests() {
    local extra_args="$1"
    
    echo -e "${YELLOW}正在运行 E2E 测试...${NC}"
    echo "基础 URL: ${BASE_URL:-http://localhost:8888}"
    echo "API URL: ${API_URL:-http://localhost:8000}"
    echo ""
    
    # 运行 Playwright 测试
    npx playwright test tests/e2e.test.js $extra_args
    
    local exit_code=$?
    
    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ 所有测试通过！${NC}"
    else
        echo -e "${RED}✗ 部分测试失败${NC}"
    fi
    
    # 显示报告路径
    echo ""
    echo "测试报告已生成："
    echo "  HTML 报告：file://$SCRIPT_DIR/playwright-report/index.html"
    echo "  JSON 结果：$SCRIPT_DIR/test-results.json"
    
    return $exit_code
}

# 主函数
main() {
    echo "======================================"
    echo "  减肥 AI 助理 - E2E 测试"
    echo "======================================"
    echo ""
    
    # 解析参数
    local extra_args=""
    local show_report=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --headed)
                extra_args="--headed"
                shift
                ;;
            --debug)
                extra_args="--debug"
                shift
                ;;
            --report)
                show_report=true
                shift
                ;;
            --install)
                install_playwright
                exit 0
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项：$1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查环境
    check_node
    echo ""
    
    # 检查 Playwright 是否安装
    if ! npm list @playwright/test &> /dev/null; then
        echo -e "${YELLOW}Playwright 未安装，正在安装...${NC}"
        install_playwright
        echo ""
    fi
    
    # 检查服务
    check_frontend_server
    check_backend_server
    echo ""
    
    # 运行测试
    run_tests "$extra_args"
    local test_result=$?
    
    # 打开报告
    if [ "$show_report" = true ]; then
        echo ""
        echo -e "${YELLOW}正在打开测试报告...${NC}"
        if command -v xdg-open &> /dev/null; then
            xdg-open "$SCRIPT_DIR/playwright-report/index.html"
        elif command -v open &> /dev/null; then
            open "$SCRIPT_DIR/playwright-report/index.html"
        else
            echo "请手动打开：file://$SCRIPT_DIR/playwright-report/index.html"
        fi
    fi
    
    exit $test_result
}

# 执行主函数
main "$@"
