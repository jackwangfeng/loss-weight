# Frontend · Flutter

> Flutter 3.38 跨端应用（iOS / Android / Web）。日常开发和 E2E 测试以 **Web 模式**为主。

---

## 🚀 启动

```bash
cd frontend
flutter pub get
```

### 方式 A：Web（推荐，和后端联调最省事）

```bash
# 构建 release（~20s，tree-shake + minify）
flutter build web --release

# serve build/web/
node tests/static_server.js              # 零依赖 Node 服务器，默认 :8888
# 或：PORT=9000 node tests/static_server.js
```

浏览器开 `http://localhost:8888`。

> **不用 `flutter run -d web-server`。** 它的 DDC 热重载产物在 headless 浏览器里不稳，E2E 测试会挂。

### 方式 B：Chrome 热重载（改 UI 时）

```bash
flutter run -d chrome
```

### 方式 C：移动真机/模拟器

```bash
flutter run                              # 自动挑设备
flutter devices                          # 列出可用设备
```

### 配置后端地址

默认读取 `http://localhost:8000/v1`。如果后端在别处，改 `lib/services/api_service.dart` 里的 `_baseUrl`。

---

## 📁 代码结构

```
lib/
├─ main.dart                   # 入口：Web 端强制开 Semantics（给 Playwright 用）
├─ providers/
│  ├─ auth_provider.dart       # 登录态
│  └─ user_provider.dart       # 用户档案
├─ models/
│  ├─ user_profile.dart
│  ├─ food_record.dart         # 含 portion / unit
│  ├─ exercise_record.dart     # type / duration / intensity / calories / distance
│  ├─ weight_record.dart
│  └─ ai_chat.dart
├─ services/                   # Dio HTTP 客户端封装
│  ├─ api_service.dart
│  ├─ auth_service.dart
│  ├─ user_service.dart
│  ├─ food_service.dart
│  ├─ weight_service.dart
│  ├─ exercise_service.dart
│  └─ ai_service.dart          # chat / recognize / estimate-* / parse-weight / daily-brief
├─ screens/
│  ├─ home_screen.dart         # 底部导航 + DashboardScreen（今日 AI 简报卡）
│  ├─ records_screen.dart      # 饮食/运动/体重 内部 TabBar 壳
│  ├─ food_screen.dart         # 今日热量 + 按日分组 + AI 输入 + 拍照 + 常吃快选
│  ├─ exercise_screen.dart     # 今日消耗 + 按日分组 + AI 输入 + 常做快选
│  ├─ weight_screen.dart       # 历史 + 趋势图 + AI 输入
│  ├─ ai_screen.dart           # 聊天 + 空 thread 自动显示 AI 简报
│  ├─ profile_screen.dart      # 资料展示 + 编辑 sheet（8 字段）
│  └─ login_screen.dart        # 手机验证码登录
└─ widgets/
   └─ voice_input_button.dart  # 可复用语音输入按钮（iOS/Android/Web 三端）

test/                          # flutter test（widget test，当前空）
tests/                         # Playwright E2E（不是 flutter test）
```

---

## 🧭 底部导航

```
首页   记录   AI   我的
  •     ↓
      饮食 | 运动 | 体重   ← records_screen.dart 里的 TabBar
```

首页（Dashboard）顶部有 **AI 今日简报卡**，拉 `/v1/ai/daily-brief`，显示目标/吃/烧/剩余额度 + AI 一段话点评。

---

## ✍️ 3 个记录的输入方式

饮食 / 运动 / 体重每个都支持：

| 方式 | 示例 | 触发的 AI 接口 |
|---|---|---|
| 手动填 | 分字段输入 | — |
| **AI 文本** | `一碗米饭 200g` / `跑步 5 公里 30 分钟` / `68.5kg 早` | `/estimate-nutrition` / `/estimate-exercise` / `/parse-weight` |
| **语音** | 点话筒说话 | 转写后自动走上面的 AI 文本流程 |
| **拍照识别**（仅饮食）| 上传食物图片 | `/recognize`（Gemini Vision, inline_data + base64）|
| **常吃快选** | 最近 14 天高频项 | 点 chip → 自动走 AI 文本 |

语音按钮代码在 `lib/widgets/voice_input_button.dart`：iOS 用 SFSpeechRecognizer / Android SpeechRecognizer / Chrome 用浏览器 SpeechRecognition API。Firefox 默认不支持，会降级为灰态。

---

## 🧪 E2E 测试

详见 [tests/README.md](tests/README.md)。一句话：

```bash
cd frontend && ./run_e2e_tests.sh       # build + serve + 跑 Playwright
./run_e2e_tests.sh --skip-build         # 跳过 build（只改测试时）
./run_e2e_tests.sh --headed             # 可视化
```

当前 **26/26** 通过，约 50s。

---

## 📦 发布构建

### Android

```bash
flutter build apk --release             # 直装 APK
flutter build appbundle --release       # Google Play 用
```

### iOS

```bash
flutter build ios --release
```

### Web

```bash
flutter build web --release             # 输出 build/web/
```

---

## 🧩 关键依赖

见 `pubspec.yaml`。核心：

- `provider` · 状态管理
- `dio` · HTTP
- `image_picker` · 拍照/相册
- `speech_to_text` · 语音输入
- `fl_chart` · 体重趋势图
- `hive` / `shared_preferences` · 本地存储
- `go_router` · 路由（还没大规模用）

---

## ⚠️ 常见问题

**连不上后端**：确认 `api_service.dart` 里 `_baseUrl` 对应后端实际地址。移动模拟器有特殊性：Android 模拟器用 `http://10.0.2.2:8000/v1`，iOS 模拟器用 `http://localhost:8000/v1`。

**`flutter pub get` 卡住**：如果网络要代理，先 `source /usr/local/proxy1.sh`；或者用清华镜像：`export PUB_HOSTED_URL=https://pub-mirror.tuna.tsinghua.edu.cn`。

**Web 端语音按钮是灰的**：Firefox 默认不支持 Web Speech API，用 Chrome/Edge。

**Web 端浏览器缓存旧版本**：改完代码 `flutter build web --release` 后，浏览器 Ctrl-Shift-R 硬刷新，清掉 service worker 缓存。

---

## 🔗 相关

- [项目总览](../README.md)
- [后端 README](../backend/README.md)
- [E2E 测试](tests/README.md)
