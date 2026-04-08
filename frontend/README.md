# 前端开发指南

## 📱 项目概述

减肥 AI 助理 Flutter 应用 - 一款让用户「轻松减肥、量化减肥」的 AI 助理应用

**Slogan：** 「轻松减肥，AI 陪你」

## 🚀 快速开始

### 1. 环境要求

- Flutter 3.x
- Dart 3.x
- Android Studio / VS Code
- Android 模拟器 / iOS 模拟器 / 真机

### 2. 安装依赖

```bash
cd frontend
flutter pub get
```

### 3. 配置 API 地址

编辑 `lib/services/api_service.dart`：

```dart
// Android 模拟器
String _baseUrl = 'http://10.0.2.2:8000/v1';

// iOS 模拟器
String _baseUrl = 'http://localhost:8000/v1';

// 真机（同一局域网）
String _baseUrl = 'http://192.168.x.x:8000/v1';
```

### 4. 启动后端服务

```bash
# 在另一个终端启动后端
cd backend
go run cmd/server/main.go -config config.test.yaml
```

### 5. 运行应用

```bash
# 查看可用设备
flutter devices

# 运行应用
flutter run

# 热重载开发
flutter run --hot
```

## 📁 项目结构

```
lib/
├── main.dart                    # 应用入口
├── models/                      # 数据模型
│   ├── user_profile.dart        # 用户档案
│   ├── food_record.dart         # 食物记录
│   ├── weight_record.dart       # 体重记录
│   └── ai_chat.dart             # AI 聊天
├── services/                    # API 服务
│   ├── api_service.dart         # HTTP 客户端
│   ├── user_service.dart        # 用户 API
│   ├── food_service.dart        # 食物 API
│   ├── weight_service.dart      # 体重 API
│   └── ai_service.dart          # AI API
├── providers/                   # 状态管理
│   └── user_provider.dart       # 用户状态
└── screens/                     # 页面组件
    ├── home_screen.dart         # 主页面
    ├── food_screen.dart         # 饮食记录
    ├── weight_screen.dart       # 体重记录
    ├── ai_screen.dart           # AI 助手
    └── profile_screen.dart      # 个人中心
```

## 🎯 功能模块

### 1. 首页 (Dashboard)
- 用户信息展示
- 体重数据概览（当前体重、目标体重、BMI）
- 快捷操作按钮
- 下拉刷新

### 2. 饮食记录 (Food)
- 查看饮食记录列表
- 添加新的饮食记录
- 显示热量和营养信息
- 按餐次分类（早餐、午餐、晚餐、加餐）

### 3. 体重记录 (Weight)
- 查看体重记录
- 体重趋势图表（待实现）
- 添加体重记录（待实现）

### 4. AI 助手 (AI)
- AI 聊天对话（待实现）
- AI 鼓励（待实现）
- 食物识别（待实现）

### 5. 个人中心 (Profile)
- 用户信息展示
- 编辑个人资料（待实现）
- 设置选项（待实现）

## 🎨 UI 设计

### 主题色
- **主色**：绿色 (#4CAF50) - 健康、活力
- **辅色**：蓝色、橙色、紫色

### 设计风格
- Material Design 3
- 卡片式布局
- 底部导航栏（5 个标签）
- 响应式设计

## 🔧 开发说明

### API 调用示例

```dart
// 用户服务
final userService = UserService();

// 创建用户
final profile = await userService.createProfile(
  openid: 'test_openid',
  nickname: '测试用户',
  currentWeight: 75.0,
  targetWeight: 65.0,
);

// 获取用户
final profile = await userService.getProfile(1);

// 更新用户
await userService.updateProfile(1, currentWeight: 74.5);
```

### 状态管理示例

```dart
// 在 Widget 中使用
final userProvider = Provider.of<UserProvider>(context);
final user = userProvider.currentUser;

// 加载用户数据
await userProvider.loadUser(1);

// 更新用户数据
await userProvider.updateUserProfile(
  currentWeight: 74.5,
);
```

### 食物记录示例

```dart
final foodService = FoodService();

// 创建记录
await foodService.createRecord(
  userId: 1,
  foodName: '苹果',
  calories: 95,
  mealType: 'snack',
);

// 获取列表
final records = await foodService.getRecords(userId: 1);

// 获取每日汇总
final summary = await foodService.getDailySummary(
  userId: 1,
  date: DateTime.now(),
);
```

## 🧪 测试

### 单元测试

```bash
flutter test
```

### 集成测试

```bash
flutter test integration_test/
```

## 📦 构建发布

### Android

```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## ⚠️ 常见问题

### 1. 连接后端失败

**解决**：
- 确保后端服务已启动
- 检查 API 地址配置
- 模拟器使用正确的 IP 地址

### 2. 热重载不生效

**解决**：
- 使用 `flutter run --hot`
- 按 `r` 键触发热重载
- 按 `R` 键触发热重启

### 3. 依赖冲突

**解决**：
```bash
flutter clean
flutter pub get
```

## 📚 相关文档

- [后端 API 文档](../backend/BACKEND_COMPLETE.md)
- [API 测试指南](../backend/QUICK_TEST.md)
- [项目总览](../README.md)

## 🎯 下一步

1. 完善体重记录页面 UI
2. 实现 AI 聊天功能
3. 添加图表展示
4. 实现图片上传功能
5. 添加本地缓存

## 🎉 当前状态

**前端 MVP 版本已完成！**

- ✅ 项目骨架和依赖
- ✅ 完整的 Models 层
- ✅ 完整的 Services 层
- ✅ Provider 状态管理
- ✅ 主页面和导航
- ✅ 饮食记录功能
- ✅ API 对接完成

可以立即运行并测试！
