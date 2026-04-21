# 页面组件 (Screens)

> Flutter 页面级组件

---

## 📁 目录结构

```
screens/
├── README.md                 # 本文档
├── home_screen.dart          # 首页（今日概览）
├── profile_screen.dart       # 用户档案页
├── food_record_screen.dart   # 饮食记录页
├── weight_screen.dart        # 体重记录页
├── chat_screen.dart          # AI 对话页
└── stats_screen.dart         # 统计页
```

---

## 📱 页面说明

### 1. 首页 (HomeScreen)

**文件：** `home_screen.dart`

**功能：**
- 展示今日热量预算圆环
- 展示饮食列表（早/午/晚/加餐）
- AI 建议卡片
- 体重趋势摘要
- 快捷入口（拍照/体重打卡）

**状态：**
- 用户信息
- 今日饮食汇总
- AI 建议

---

### 2. 用户档案页 (ProfileScreen)

**文件：** `profile_screen.dart`

**功能：**
- 首次启动时填写档案
- 展示当前档案信息
- 编辑档案（可选）

**表单字段：**
- 昵称
- 性别
- 年龄
- 身高
- 当前体重
- 目标体重
- 目标日期（可选）

---

### 3. 饮食记录页 (FoodRecordScreen)

**文件：** `food_record_screen.dart`

**功能：**
- 拍照识别食物
- 搜索食物库
- 手动添加食物
- 选择餐次（早/午/晚/加餐）
- 确认添加

**交互流程：**
```
拍照 → AI 识别 → 显示结果 → 调整份量 → 确认添加
```

---

### 4. 体重记录页 (WeightScreen)

**文件：** `weight_screen.dart`

**功能：**
- 记录今日体重
- 展示体重曲线图
- 展示减重进度
- 历史体重列表

---

### 5. AI 对话页 (ChatScreen)

**文件：** `chat_screen.dart`

**功能：**
- 与 AI 助手聊天
- 消息列表展示
- 输入框
- 发送消息

---

### 6. 统计页 (StatsScreen)

**文件：** `stats_screen.dart`

**功能：**
- 热量摄入趋势图
- 体重变化趋势图
- 饮食分析（蛋白质/脂肪/碳水占比）
- 周/月报

---

## 🎨 页面设计原则

### 1. 简洁优先

```dart
// ✅ 好的设计
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('首页')),
      body: Column(
        children: [
          CalorieRing(),  // 核心功能
          MealList(),     // 重要信息
        ],
      ),
    );
  }
}

// ❌ 不好的设计（过于复杂）
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(  // 过度嵌套
        headerSliverBuilder: ...
        body: CustomScrollView(
          slivers: [
            // 20+ 个组件
          ],
        ),
      ),
    );
  }
}
```

### 2. 状态管理

```dart
// 使用 Provider
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    
    return Scaffold(
      body: userState.isLoading
          ? LoadingWidget()
          : HomeContent(user: userState.user),
    );
  }
}
```

### 3. 错误处理

```dart
class FoodRecordScreen extends StatelessWidget {
  Future<void> _handlePhoto(BuildContext context) async {
    try {
      final image = await ImagePicker().pickImage();
      final foods = await FoodService().recognize(image);
      // 处理结果
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败：$e')),
      );
    }
  }
}
```

---

## 📝 开发示例

### 页面模板

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({Key? key}) : super(key: key);

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  @override
  void initState() {
    super.initState();
    // 初始化逻辑
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('页面标题'),
      ),
      body: _buildBody(),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildBody() {
    return Center(
      child: Text('内容'),
    );
  }

  Widget? _buildFab() {
    return FloatingActionButton(
      onPressed: () {},
      child: const Icon(Icons.add),
    );
  }
}
```

---

## 🔗 相关链接

- [可复用组件](../widgets/README.md)
- [API 服务](../services/README.md)
- [前端首页](../../README.md)
- [项目首页](../../../README.md)

---

**最后更新：** 2026-04-06
