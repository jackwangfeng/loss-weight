# Frontend E2E 测试（Playwright）

> 当前 **26/26** 通过，约 50s。

---

## 📁 文件

```
frontend/
├─ run_e2e_tests.sh               # 一键 build + serve + test + cleanup
├─ playwright.config.js           # 配置（testMatch 同时支持 foo.test.js 和 foo_test.js）
└─ tests/
   ├─ static_server.js            # 零依赖 Node 静态服务器（serve build/web）
   ├─ flutter_canvas_test.js      # 12 条：Flutter 渲染检查 + Semantics UI 交互 + 部分 API
   └─ backend_api_test.js         # 14 条：串行走完登录→饮食→体重→AI 的后端主路径
```

其他历史遗留的 `*_test.js` 文件（`interaction_test.js` 等）已不在默认运行集里。

---

## 🚀 一键跑

```bash
cd frontend
./run_e2e_tests.sh                # build + serve + 跑测试 + 清理
./run_e2e_tests.sh --skip-build   # 不动 build/web（只改测试或后端时用）
./run_e2e_tests.sh --headed       # 可视化浏览器
./run_e2e_tests.sh --report       # 跑完打开 HTML 报告
./run_e2e_tests.sh --install      # 安装 @playwright/test + chromium
./run_e2e_tests.sh -- --grep "饮食"   # -- 后面的透传给 npx playwright test
```

### 脚本做了什么

1. 检查后端 `http://localhost:8000/health`（没起就退出并提示）
2. 如无 `--skip-build`：`flutter build web --release`（~20s）
3. 杀掉 8888 上的残留进程，**新起**一个 `node tests/static_server.js`（不复用，避免长跑的进程状态污染）
4. `unset HTTP_PROXY / HTTPS_PROXY / ALL_PROXY`——本机测试不需要代理，`NO_PROXY=localhost` 在某些 Playwright 版本下不可靠
5. `npx playwright test --project=chromium --reporter=list tests/flutter_canvas_test.js tests/backend_api_test.js`
6. `trap EXIT` 回收静态服务器

---

## 📋 用例清单（26 条）

### `backend_api_test.js` · 14 条（`test.describe.serial`）

端到端走通主路径。任何一条挂掉后面都会被标为 "did not run"。

1. `/health` 健康检查
2. `POST /v1/auth/sms/send`
3. `POST /v1/auth/sms/login` → 拿 token + user_id
4. `GET /v1/auth/me`（鉴权）
5. `POST /v1/food/record` 加饮食
6. `GET /v1/food/records`
7. `GET /v1/food/daily-summary`
8. `POST /v1/weight/record`
9. `GET /v1/weight/records`
10. `GET /v1/weight/trend`
11. `POST /v1/ai/encouragement`
12. `POST /v1/ai/chat/thread`
13. `GET /v1/ai/chat/threads`
14. `POST /v1/auth/logout`

### `flutter_canvas_test.js` · 12 条

**Flutter 渲染（3）**

- Flutter Web 应该正确加载（canvas 数量 > 0）
- Canvas 应该可见
- 页面应该包含 `main.dart.js` / `flutter_bootstrap.js`

**Semantics 交互（7）**

- 底部导航应该有 4 个 tab（首页 / 记录 / AI / 我的）
- 点击 AI tab 应该切到 AI 界面
- 点击"记录"后能看到 3 个子 tab（饮食/运动/体重）
- 点击 "记录" → "饮食" 子 tab
- 点击 "记录" → "运动" 子 tab
- 点击 "记录" → "体重" 子 tab
- 点击 "我的"
- 依次切换所有 tab 不崩溃

**后端 API（2）**

- 后端健康检查
- AI 聊天 API

---

## 🧑‍💻 单独跑

```bash
# 只跑后端测试
./run_e2e_tests.sh --skip-build -- tests/backend_api_test.js

# 只跑 UI 测试，且可视化
./run_e2e_tests.sh --skip-build --headed -- tests/flutter_canvas_test.js

# grep 子集
./run_e2e_tests.sh --skip-build -- --grep "AI"
```

---

## 🔧 环境变量

| 变量 | 默认 | 作用 |
|---|---|---|
| `FRONTEND_PORT` | 8888 | 静态服务器端口 |
| `BACKEND_URL` | http://localhost:8000 | 后端地址（健康检查用）|
| `BASE_URL` | http://localhost:8888 | Playwright 的 `use.baseURL` |
| `API_BASE_URL` | http://localhost:8000 | `backend_api_test.js` 打的后端地址 |

---

## ⚠️ 为什么不用 `flutter run -d web-server`

踩过坑，记录下来避免下次再试：

1. DDC 产物（debug + hot-reload bundle）在 headless Chromium 里**不 mount**，测试永远超时
2. DDC 单客户端限制：一个 debug session 只能一个浏览器连接
3. Release 构建 (`flutter build web --release`) 是纯 JS/wasm，headless 里稳得很

所以 E2E 始终走 release + 静态服务器路径。

---

## 🐛 常见报错

### `Error: No tests found`

`playwright.config.js` 的 `testMatch` 要同时认 `foo.test.js` 和 `foo_test.js`（Playwright 默认只认前者）。我们已经在 config 里加了正则：`/.*(_test|\.test|\.spec)\.[cm]?[jt]sx?$/`。

### 测试 1-14 通过，15+ 突然 60s 超时

99% 是 `HTTP_PROXY` 劫持了 `localhost:8888` 的请求。`run_e2e_tests.sh` 启动测试前会 `unset HTTP_PROXY`，但如果你绕过脚本直接 `npx playwright test`，别忘了先：

```bash
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy
```

### 浏览器没安装

```bash
./run_e2e_tests.sh --install
# 或
npx playwright install chromium
```

---

## 📊 报告

```bash
npx playwright show-report           # 打开 HTML 报告
ls test-results/                     # 失败的用例里有截图 + video.webm
```

---

## 🔁 CI 建议

```yaml
# GitHub Actions 伪代码
steps:
  - uses: actions/checkout@v4
  - uses: subosito/flutter-action@v2
    with: { flutter-version: '3.38.x' }
  - name: Install playwright
    run: cd frontend && npx playwright install chromium
  - name: Start backend
    run: cd backend && SKIP_SMS_VERIFY=true go run cmd/server/main.go -config config.test.yaml &
  - name: Wait backend
    run: curl --retry 10 --retry-delay 2 http://localhost:8000/health
  - name: Run E2E
    run: cd frontend && ./run_e2e_tests.sh
    env:
      GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
```

注意：CI 里没 Gemini key 的话 AI 测试的内容断言会挂。要么给 CI 配 key，要么把 AI 部分测试换成只检查 `response.ok()` 而不断言内容。
