.PHONY: help local test build clean run-local run-prod

# 默认目标
help:
	@echo "可用命令:"
	@echo "  make local    - 本地开发模式（测试模式，跳过验证码校验）"
	@echo "  make test     - 运行测试"
	@echo "  make build    - 编译生产版本"
	@echo "  make clean    - 清理构建文件"
	@echo "  make run      - 运行（默认本地模式）"

# 本地开发模式（测试模式）
local:
	@echo "🚀 启动本地开发服务器（测试模式）..."
	@echo "⚠️  注意：当前为测试模式，跳过验证码校验"
	@SKIP_SMS_VERIFY=true go run cmd/server/main.go -config config.test.yaml

# 运行测试
test:
	@echo "🧪 运行测试..."
	@cd tests && ./run_api_tests.sh

# 编译生产版本
build:
	@echo "🔨 编译生产版本..."
	@go build -o server cmd/server/main.go
	@echo "✅ 编译完成：./server"

# 清理构建文件
clean:
	@echo "🧹 清理构建文件..."
	@rm -f server main
	@echo "✅ 清理完成"

# 运行（默认本地模式）
run: local

# 生产模式（需要配置真实短信服务）
run-prod:
	@echo "🚀 启动生产服务器..."
	@echo "⚠️  注意：生产模式需要配置真实的短信服务"
	@./server -config config.yaml
