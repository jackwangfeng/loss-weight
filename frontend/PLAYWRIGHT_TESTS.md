# Playwright 测试使用指南

## 📦 已创建的文件

```
frontend/
├── tests/
│   ├── e2e.test.js          # 完整的 E2E 测试套件
│   ├── demo.test.js         # 快速演示脚本
│   ├── package.json         # Node.js 依赖配置
│   └── README.md            # 详细文档
├── playwright.config.js     # Playwright 配置文件
└── run_e2e_tests.sh         # 测试运行脚本
```

## 🚀 快速开始

### 1. 安装依赖

```bash
cd frontend

# 方法一：使用脚本安装（推荐）
./run_e2e_tests.sh --install

# 方法二：手动安装
cd tests
npm install
cd ..
npx playwright install chromium
```

### 2. 启动服务

```bash
# 终端 1: 启动后端
cd backend
make local

# 终端 2: 启动前端
cd frontend
flutter run -d web-server --web-port=8888
```

### 3. 运行测试

```bash
# 运行完整测试套件
./run_e2e_tests.sh

# 或运行演示脚本
node tests/demo.test.js
```

## 📋 测试命令

### 完整测试套件

```bash
# 正常运行（无头模式）
./run_e2e_tests.sh

# 显示浏览器界面
./run_e2e_tests.sh --headed

# 调试模式
./run_e2e_tests.sh --debug

# 运行并查看报告
./run_e2e_tests.sh --report
```

### 演示脚本

```bash
# 运行演示（无头模式）
node tests/demo.test.js

# 显示浏览器运行演示
HEADED=1 node tests/demo.test.js
```

### 使用 npx

```bash
# 运行所有测试
npx playwright test tests/e2e.test.js

# 运行特定测试
npx playwright test tests/e2e.test.js --grep "登录"

# 指定浏览器
npx playwright test tests/e2e.test.js --project chromium

# 显示浏览器
npx playwright test tests/e2e.test.js --headed
```

## ✅ 测试覆盖的功能

### 1. 登录流程
- 访问首页
- 手机号验证码登录
- 登录成功跳转

### 2. 首页功能
- 用户数据概览
- 底部导航栏
- 快捷操作

### 3. 饮食记录
- 添加记录
- 显示列表
- 餐次分类

### 4. 体重记录
- 添加记录
- 显示列表
- 趋势图表
- 统计信息

### 5. AI 聊天
- 发送消息
- 新建对话
- 聊天记录

### 6. 个人中心
- 用户信息
- 退出登录

### 7. 响应式
- 移动端适配
- 平板端适配

## 📊 测试报告

### HTML 报告

```bash
# 查看报告
npx playwright show-report

# 或手动打开浏览器
# file:///path/to/frontend/playwright-report/index.html
```

### JSON 结果

测试完成后会生成 `test-results.json` 文件，包含所有测试结果的详细信息。

### 截图和视频

测试失败时会自动保存：
- 失败截图：`test-results/`
- 执行视频：`test-results/`

## ⚙️ 配置选项

### 环境变量

```bash
# 指定前端地址
BASE_URL=http://localhost:8888 ./run_e2e_tests.sh

# 指定后端地址
API_URL=http://localhost:8000 ./run_e2e_tests.sh
```

### playwright.config.js

```javascript
module.exports = {
  timeout: 30000,              // 超时时间
  retries: 0,                  // 重试次数
  workers: 1,                  // 并行数
  
  use: {
    baseURL: 'http://localhost:8888',
    headless: true,            // 无头模式
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  
  reporter: [
    ['html'],
    ['list'],
    ['json'],
  ],
};
```

## 🔧 常见问题

### 问题 1: 前端服务未运行

```bash
# 启动前端
cd frontend
flutter run -d web-server --web-port=8888
```

### 问题 2: 后端服务未运行

```bash
# 启动后端
cd backend
make local
```

### 问题 3: Playwright 未安装

```bash
# 安装 Playwright
./run_e2e_tests.sh --install
```

### 问题 4: 测试超时

```bash
# 增加超时时间
npx playwright test tests/e2e.test.js --timeout=60000
```

## 📝 自定义测试

### 添加新测试

在 `tests/e2e.test.js` 中添加：

```javascript
test.describe('新功能测试', () => {
  test('应该能够做某事', async ({ page }) => {
    // 你的测试代码
  });
});
```

### 使用 Page Object 模式

创建 `tests/pages/home.page.js`:

```javascript
class HomePage {
  constructor(page) {
    this.page = page;
  }

  async goto() {
    await this.page.goto(BASE_URL);
  }

  async clickLoginButton() {
    await this.page.click('text=开始使用');
  }
}

module.exports = HomePage;
```

## 🎯 最佳实践

1. **保持测试独立** - 每个测试应该能够独立运行
2. **使用稳定的选择器** - 优先使用文本或 data-testid
3. **添加适当等待** - 使用 `waitForSelector` 而非固定等待
4. **测试关键路径** - 优先测试核心功能
5. **定期运行测试** - 集成到 CI/CD 流程中

## 📚 更多资源

- [Playwright 官方文档](https://playwright.dev/)
- [测试最佳实践](https://playwright.dev/docs/best-practices)
- [API 参考](https://playwright.dev/docs/api/class-playwright)
