# API 服务 (Services)

> Flutter 网络请求服务

---

## 📁 目录结构

```
services/
├── README.md                 # 本文档
├── api_service.dart          # API 客户端基类
├── user_service.dart         # 用户服务
├── food_service.dart         # 饮食服务
├── weight_service.dart       # 体重服务
└── ai_service.dart           # AI 服务
```

---

## 📋 服务说明

### 1. API 客户端基类

**文件：** `api_service.dart`

**功能：**
- HTTP 请求封装
- Token 管理
- 错误处理
- 请求拦截

**示例：**
```dart
import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio;
  String? _token;

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // 统一错误处理
        return handler.next(error);
      },
    ));
  }

  void setToken(String token) {
    _token = token;
  }

  Future<Response> get(String path) async {
    return await _dio.get(path);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
}
```

---

### 2. 用户服务

**文件：** `user_service.dart`

**功能：**
- 创建用户档案
- 获取用户信息
- 更新用户信息

**示例：**
```dart
import '../models/user.dart';
import 'api_service.dart';

class UserService {
  final ApiService _apiService;

  UserService(this._apiService);

  Future<User> createProfile(Map<String, dynamic> profile) async {
    final response = await _apiService.post('/users/profile', data: profile);
    return User.fromJson(response.data['data']);
  }

  Future<User> getProfile() async {
    final response = await _apiService.get('/users/profile');
    return User.fromJson(response.data['data']);
  }

  Future<User> updateProfile(Map<String, dynamic> profile) async {
    final response = await _apiService.put('/users/profile', data: profile);
    return User.fromJson(response.data['data']);
  }
}
```

---

### 3. 饮食服务

**文件：** `food_service.dart`

**功能：**
- 拍照识别食物
- 添加饮食记录
- 获取今日饮食
- 更新/删除记录

**示例：**
```dart
import 'dart:io';
import '../models/food_record.dart';
import 'api_service.dart';

class FoodService {
  final ApiService _apiService;

  FoodService(this._apiService);

  Future<List<FoodItem>> recognizeFood(File image) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path),
    });

    final response = await _apiService.post('/food/recognize', data: formData);
    return (response.data['data']['foods'] as List)
        .map((item) => FoodItem.fromJson(item))
        .toList();
  }

  Future<FoodRecord> addRecord(FoodRecord record) async {
    final response = await _apiService.post('/food/records', data: record.toJson());
    return FoodRecord.fromJson(response.data['data']);
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    final response = await _apiService.get('/food/records/today');
    return response.data['data'];
  }
}
```

---

### 4. 体重服务

**文件：** `weight_service.dart`

**功能：**
- 记录体重
- 获取体重曲线
- 更新/删除记录

---

### 5. AI 服务

**文件：** `ai_service.dart`

**功能：**
- 获取 AI 鼓励
- AI 对话

---

## 🎯 使用示例

```dart
// 初始化服务
final apiService = ApiService();
final userService = UserService(apiService);
final foodService = FoodService(apiService);

// 创建用户
final user = await userService.createProfile({
  'nickname': '小明',
  'gender': 'male',
  'age': 28,
  'height': 175,
  'current_weight': 75.0,
  'target_weight': 65.0,
});

// 保存 Token
apiService.setToken(user.token);

// 拍照识别
final image = await ImagePicker().pickImage();
final foods = await foodService.recognizeFood(image);

// 添加记录
await foodService.addRecord(FoodRecord(
  foodName: foods.first.foodName,
  calories: foods.first.calories,
  mealType: 'lunch',
));
```

---

## 🔗 相关链接

- [数据模型](../models/README.md)
- [页面组件](../screens/README.md)
- [前端首页](../../README.md)
- [项目首页](../../../README.md)

---

**最后更新：** 2026-04-06
