# 减肥 AI 助理 - E2E 测试文档

## 目录

- [快速开始](#快速开始)
- [安装](#安装)
- [运行测试](#运行测试)
- [测试用例](#测试用例)
- [配置选项](#配置选项)
- [故障排除](#故障排除)

## 快速开始

```bash
# 1. 进入 frontend 目录
cd frontend

# 2. 安装 Playwright
./run_e2e_tests.sh --install

# 3. 确保前端和后端服务都在运行
# 前端：flutter run -d web-server --web-port=8888
# 后端：cd backend && make local

# 4. 运行测试
./run_e2e_tests.sh
```

## 安装

### 方法一：使用安装脚本（推荐）

```bash
./run_e2e_tests.sh --install
```

这会自动安装：
- @playwright/test
- Chromium 浏览器

### 方法二：手动安装

```bash
# 安装 Playwright
npm install -D @playwright/test

# 安装浏览器
npx playwright install chromium
```

## 运行测试

### 基本用法

```bash
# 运行所有测试
./run_e2e_tests.sh

# 显示浏览器界面（非无头模式）
./run_e2e_tests.sh --headed

# 调试模式
./run_e2e_tests.sh --debug

# 运行测试并打开报告
./run_e2e_tests.sh --report
```

### 使用 npx 直接运行

```bash
# 运行所有测试
npx playwright test tests/e2e.test.js

# 运行特定测试
npx playwright test tests/e2e.test.js --grep "登录"

# 在特定浏览器中运行
npx playwright test tests/e2e.test.js --project chromium

# 显示浏览器
npx playwright test tests/e2e.test.js --headed

# 调试模式
npx playwright test tests/e2e.test.js --debug
```

### 环境变量

```bash
# 指定前端服务地址
BASE_URL=http://localhost:8888 ./run_e2e_tests.sh

# 指定后端服务地址
API_URL=http://localhost:8000 ./run_e2e_tests.sh

# 组合使用
BASE_URL=http://localhost:8888 API_URL=http://localhost:8000 ./run_e2e_tests.sh
```

## 测试用例

### 1. 登录流程

- ✅ 访问首页
- ✅ 通过手机号验证码登录
- ✅ 登录成功后返回首页

### 2. 首页功能

- ✅ 显示用户数据概览（体重、BMI 等）
- ✅ 导航到各个页面（饮食、体重、AI、我的）

### 3. 饮食记录功能

- ✅ 添加饮食记录
- ✅ 显示饮食记录列表

### 4. 体重记录功能

- ✅ 添加体重记录
- ✅ 显示体重记录列表
- ✅ 显示体重趋势图表
- ✅ 显示统计信息（最低、最高、变化）

### 5. AI 聊天功能

- ✅ 发送消息给 AI
- ✅ 新建对话
- ✅ 显示聊天记录

### 6. 个人中心功能

- ✅ 显示用户信息
- ✅ 退出登录

### 7. 响应式测试

- ✅ 移动设备尺寸适配（375x667）
- ✅ 平板尺寸适配（768x1024）

## 配置选项

### playwright.config.js 配置

```javascript
module.exports = {
  timeout: 30000,              // 测试超时时间
  expect: { timeout: 5000 },   // 断言超时时间
  retries: 0,                  // 重试次数
  workers: 1,                  // 并行 worker 数量
  
  use: {
    baseURL: 'http://localhost:8888',
    headless: true,            // 无头模式
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    viewport: { width: 1280, height: 720 },
  },
  
  reporter: [
    ['html'],                  // HTML 报告
    ['list'],                  // 列表输出
    ['json'],                  // JSON 结果
  ],
};
```

### 命令行选项

| 选项 | 说明 |
|------|------|
| `--headed` | 显示浏览器界面 |
| `--debug` | 调试模式 |
| `--report` | 运行后打开 HTML 报告 |
| `--install` | 安装 Playwright 和浏览器 |
| `--help` | 显示帮助信息 |

## 输出文件

测试运行后会生成以下文件：

```
frontend/
├── playwright-report/      # HTML 报告
│   └── index.html
├── test-results/           # 截图和视频
│   └── ...
├── test-results.json       # JSON 格式结果
└── blob-report/           # Blob 格式报告
```

### 查看 HTML 报告

```bash
# 方法一：使用脚本自动打开
./run_e2e_tests.sh --report

# 方法二：手动打开
npx playwright show-report

# 方法三：浏览器打开
# file:///path/to/frontend/playwright-report/index.html
```

## 故障排除

### 问题 1: 前端服务未运行

**错误信息：**
```
⚠ 前端服务未运行
```

**解决方案：**
```bash
# 启动前端服务
cd frontend
flutter run -d web-server --web-port=8888
```

### 问题 2: 后端服务未运行

**错误信息：**
```
⚠ 后端服务未运行
```

**解决方案：**
```bash
# 启动后端服务
cd backend
make local
```

### 问题 3: 测试超时

**可能原因：**
- 网络请求慢
- 后端服务响应慢
- 动画效果导致等待时间长

**解决方案：**
```bash
# 增加超时时间
npx playwright test tests/e2e.test.js --timeout=60000

# 或修改 playwright.config.js
module.exports = {
  timeout: 60000,
};
```

### 问题 4: 元素找不到

**可能原因：**
- 页面未完全加载
- 元素 ID 或文本变化
- 需要等待

**解决方案：**
```javascript
// 在测试中添加等待
await page.waitForSelector('text=元素文本');
await page.waitForTimeout(2000); // 等待 2 秒
```

### 问题 5: Playwright 未安装

**错误信息：**
```
Error: Cannot find module '@playwright/test'
```

**解决方案：**
```bash
./run_e2e_tests.sh --install
```

## 持续集成 (CI)

### GitHub Actions 示例

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
    
    - name: Install dependencies
      run: |
        cd frontend
        npm ci
        npx playwright install chromium
    
    - name: Start backend
      run: |
        cd backend
        make local &
    
    - name: Start frontend
      run: |
        cd frontend
        flutter run -d web-server --web-port=8888 &
        sleep 30
    
    - name: Run tests
      run: |
        cd frontend
        npx playwright test
    
    - name: Upload test results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: playwright-report
        path: frontend/playwright-report/
```

## 最佳实践

1. **测试前清理数据**
   - 使用测试专用账号
   - 避免污染生产数据

2. **使用稳定的选择器**
   - 优先使用 `data-testid`
   - 避免使用动态生成的 ID

3. **添加适当的等待**
   - 使用 `waitForSelector` 而不是固定等待
   - 避免使用过长的 `waitForTimeout`

4. **测试关键路径**
   - 登录流程
   - 核心功能（记录饮食、体重）
   - 错误处理

5. **保持测试独立**
   - 每个测试应该独立运行
   - 使用 `beforeEach` 重置状态

## 更多信息

- [Playwright 官方文档](https://playwright.dev/)
- [Playwright Test 文档](https://playwright.dev/docs/test-intro)
- [测试最佳实践](https://playwright.dev/docs/best-practices)
