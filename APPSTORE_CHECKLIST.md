# iOS App Store 提交清单

> 给 RecompDaily 首次上架 iOS 用的 working checklist。按优先级排，逐项勾完
> 再点提交。写于 2026-04-22，基于当时 App Store 政策；每次提交前扫一眼
> Apple 最新的 [Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)。

---

## 🔴 不做就拒审（hard blockers）

### 账户与登录
- [ ] **Sign in with Apple**（SIWA）—— Apple 硬规：有任何第三方登录（Google / Facebook）就必须同时提供 SIWA。现在只有 Google → 直接拒
  - 代码：加 `sign_in_with_apple` package + SIWA 按钮
  - 后端：新增 `/v1/auth/apple` 端点验 Apple ID token
  - Model：`UserAccount` 加 `AppleSub *string uniqueIndex`
  - Apple Developer Console 开启 Sign in with Apple capability
- [ ] **账号删除**（in-app）—— 2022 起 Apple 硬规：允许注册就必须允许**应用内一键删除账号**，不是"联系客服"
  - Profile 页加"Delete account"按钮 → 二次确认 → 后端 `/v1/auth/me` DELETE → 清所有用户数据
- [ ] **iOS Google OAuth Client** —— Web 的 client ID 在 iOS 不工作，要单独在 Google Cloud Console 建 iOS 类型
  - 把 Reversed Client ID 写到 `ios/Runner/Info.plist` 的 URL Schemes

### 后端部署（最常被独立开发者忽略的致命盲点）
- [ ] **后端必须公网可访问 + HTTPS** —— 审核员在美国测 app，**不能打 localhost**。没有生产后端 = 审核时 app 连不上 = 拒
- [ ] 推荐方案：**Fly.io + Neon Postgres**
  - Fly.io 全球 edge、对 Go 友好、用现有 `Dockerfile` 就能 deploy，~$5-15/mo
  - Neon 免费层 Postgres + pgvector，合适 MVP
  - 域名：用 Fly 子域就行，后面想换自己的域再换
- [ ] 次选：Railway（最省事但不全球）/ 自己 VPS（要学 ops）
- [ ] **避雷**：Render（免费层 15 分钟不活跃休眠，冷启动 30s 体验差）；Cloudflare Workers（Go 要 WASM，别折腾）

### 法律与合规
- [ ] **Privacy Policy 公开 URL**（必需）
  - 模板生成：[termly.io](https://termly.io) / [pocketmall.io/privacy-policy-generator](https://)
  - 托管：Fly 后端 serve 一个 `/privacy` 静态页即可
- [ ] **Terms of Service URL**（订阅 app 强推荐）
- [ ] **Export Compliance**：`ITSAppUsesNonExemptEncryption = false` 写到 `Info.plist`（标准 HTTPS 不是非豁免加密）

### 权限字符串（Info.plist）
- [ ] `NSCameraUsageDescription` —— "Log food and track physique progress."
- [ ] `NSPhotoLibraryUsageDescription` —— "Pick food photos from your library."
- [ ] `NSMicrophoneUsageDescription` —— "Voice-log food, training, and weight."
- [ ] `NSSpeechRecognitionUsageDescription` —— "Turn your voice into logged entries."
- [ ] 如果存 physique 进相册：`NSPhotoLibraryAddUsageDescription`

### AI 特有（Apple 对 AI app 审查加严）
- [ ] **AI 内容举报 / 屏蔽机制**（2024+ 硬要求）
  - Chat 消息长按 → "Report this reply"
  - 后端记录 report，后台可见
- [ ] **AI 非医疗建议 disclaimer** —— 首次进 Coach tab / Daily brief 弹一次"AI suggestions are not medical advice. Consult a doctor for diet / training decisions."
- [ ] **年龄分级选 17+** —— AI chat 能产生"不可预测内容"，App Store Connect 问卷里 "Unrestricted Web Access" 选 Yes，自动 17+。12+ 会被拒
- [ ] **Description 里明确写** "Powered by Gemini AI. Not medical advice." —— Apple 对 health + AI 组合审查极严，不写容易触发医学专家审查流（再等 2-4 周）

### 付费（如果要订阅收费）
- [ ] **必须用 IAP 不能用 Stripe** —— Apple 对数字订阅抽 30%（Small Business Program $1M/年以下 15%）。external subscription 直接拒
- [ ] RevenueCat + StoreKit 集成
- [ ] App Store Connect 建 subscription product（`cutbro_monthly` $12.99 / `cutbro_annual` $69.99——iOS 定价要比 web 高以抵手续费）
- [ ] **如果 MVP 免费上架**：可以跳过 IAP，但计划未来收费的话要在描述里模糊提 "Pro features coming"，别打用户措手不及

---

## 🟡 强烈推荐（不做会反复返工）

| 项 | 原因 |
|----|------|
| **TestFlight 内测**（3-5 朋友装一周）| 发现 iOS 特有 bug（键盘遮挡、安全区、字体渲染）。省 1-2 轮拒审 |
| **Crash reporting**（[Sentry](https://sentry.io) 免费层 / Firebase Crashlytics）| 上线后 crash 你**看不到** = 用户静默流失 |
| **App Preview 视频**（15-30 秒）| 商店页转化率 +30-40%。QuickTime 录屏 + iMovie 剪 1 小时 |
| **审核员 demo 凭证**（App Review Information 填）| SMS 账号美国审核员用不了，准备一个测试 Google 账号 + 提示"Tap the Coach tab to start chatting" |
| **审核员 note** | 给 Apple 审核员写一段 app 特色说明 + 引导操作路径 |

---

## 🟢 App Store Connect 元数据素材

### 必填
- [ ] **Apple Developer Program** 账号（$99/年，身份验证 1-3 天）
- [ ] **App 图标** 1024×1024 PNG master，不透明，无圆角（Apple 自动加）
- [ ] **Launch Screen** Xcode Storyboard，黑底 + 品牌 logo
- [ ] **App 名**：`RecompDaily`
- [ ] **Subtitle**（30 字符内）：建议 `AI recomp coach that remembers`
- [ ] **Keywords**（100 字符内逗号分隔）：建议 `recomp,macro,protein,cutting,fat loss,fitness,lift,gym,weightlifting`
- [ ] **描述**（4000 字符内，**前 3 行最关键**，搜索结果只显示前 3 行）
- [ ] **Primary 分类**：Health & Fitness
- [ ] **Screenshots**（每个尺寸至少 3 张，推荐 5-10 张）
  - 6.7"（iPhone 15 Pro Max）—— 强制
  - 6.5"（iPhone 8 Plus 兼容）—— 强制
  - iPad（如果支持 iPad）
- [ ] **Support URL** —— 一个页面 or mailto: 都行
- [ ] **Marketing URL**（选填）
- [ ] **Age Rating 问卷**（20 题左右）
- [ ] **App Privacy 问卷** —— 声明收集什么数据：Google 登录 → 收集 email + name、身高体重等 Health data、AI chat 内容

### 选填但重要
- [ ] **中文本地化元数据** —— 如果勾了 `zh-Hans` 作为支持语言，要单独填中文的 App 名 / 描述 / 关键词。要么勾掉只英文上架

---

## ⚫ 具体代码改动 TODO

```
ios/Runner/Info.plist
  + NSCameraUsageDescription
  + NSPhotoLibraryUsageDescription
  + NSMicrophoneUsageDescription
  + NSSpeechRecognitionUsageDescription
  + ITSAppUsesNonExemptEncryption = false
  + CFBundleURLTypes（Google iOS Reversed URL Scheme）
  + CFBundleDisplayName = RecompDaily

ios/Runner/AppDelegate.swift
  + Google Sign-In URL handler

ios/ 项目层
  + App 图标（Assets.xcassets）
  + Launch Screen storyboard 更新

pubspec.yaml
  + sign_in_with_apple: ^6.x

lib/providers/auth_provider.dart
  + signInWithApple 方法（拿 identityToken）

lib/screens/login_screen.dart
  + SIWA 按钮（Apple HIG：黑底白字，放 Google 上方）

lib/screens/profile_screen.dart
  + Delete Account 按钮 + 二次确认 dialog

backend/internal/handlers/auth_handler.go
  + AppleLogin（类似 GoogleLogin）
  + DeleteAccount

backend/internal/services/auth_service.go
  + AppleLogin：用 github.com/Timothylock/go-signin-with-apple
    或自己实现 Apple public key 验证

backend/internal/models/auth.go
  + UserAccount: AppleSub *string uniqueIndex

backend/internal/database/database.go
  + AutoMigrate adds apple_sub column automatically

（AI disclaimer + report 机制）
lib/screens/ai_screen.dart
  + 首次进入弹 disclaimer dialog（shared_prefs 记住已看过）
  + 消息长按菜单加 Report
```

---

## 📅 现实时间线

| 阶段 | 时长 |
|------|------|
| 后端部署（Fly.io + Neon）| 2-3 天 |
| iOS Google OAuth + SIWA + Info.plist 权限 | 2 天 |
| 账号删除按钮 + 后端 endpoint | 半天 |
| AI content disclaimer + report UX | 1 天 |
| IAP + RevenueCat（如果要订阅）| 3-5 天 |
| Privacy Policy + Terms URL 托管 | 半天 |
| App 图标 + 启动图 + screenshots | 1-2 天 |
| Crash reporting 接入（Sentry）| 半天 |
| TestFlight 内测 + 修 iOS bug | 3-5 天 |
| App Store Connect 元数据 + 问卷 | 1 天 |
| 提交审核 + 可能返工 | 1-3 天审核 + 1-2 轮 |

**最乐观 2-3 周，现实 4-6 周。**

---

## 🎯 推荐优先级

**第一刀**：**部署后端**（Fly.io + Neon）—— 这也是 web 版上线前置条件，两边都需要，ROI 最高

**第二刀**：**Sign in with Apple** —— 硬规，早做早踏实

**第三刀**：**Privacy Policy URL + Terms** —— 半天搞定，是其他所有东西的前置

**第四刀**：**账号删除 + AI disclaimer + content moderation** —— 一天搞定所有合规细节

**第五刀**：**IAP + RevenueCat**（决定收费了再做）

**第六刀**：**TestFlight 内测 + 修 iOS bug** —— 真机跑起来了才知道 Flutter web → iOS 的 gap 有多大

**最后**：**App Store Connect 元数据 + 提交**

---

## ❓ 现在你要先回答的几个问题

1. **Apple Developer 账号** —— 开了吗？没开就先开，要 1-3 天
2. **上架模式** —— 免费 / 免费 + IAP / 付费下载？决定是否先接 RevenueCat
3. **域名** —— 定了吗？Privacy Policy / Terms 要托管在公开 URL
4. **目标地区** —— US / Global / 含中国？中国 App Store 要 ICP 备案 + 特殊审核
5. **Mac + Xcode** —— 有吗？改代码我能做，真机或模拟器跑只能你做

答完这 5 个问题再定真实 submission plan。
