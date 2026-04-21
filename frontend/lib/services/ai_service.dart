import '../models/ai_chat.dart';
import 'api_service.dart';

class AIService {
  final ApiService _apiService = ApiService();

  /// AI 聊天
  Future<AIChatMessage> chat({
    required int userId,
    required String message,
    String? threadId,
  }) async {
    final response = await _apiService.post('/ai/chat', {
      'user_id': userId,
      'messages': [
        {'role': 'user', 'content': message},
      ],
      if (threadId != null) 'thread_id': threadId,
    });

    if (response.statusCode == 200) {
      return AIChatMessage.fromJson(response.data);
    } else {
      throw Exception('AI 聊天失败');
    }
  }

  /// 获取聊天记录
  Future<List<AIChatMessage>> getChatHistory({
    required int userId,
    required String threadId,
    int limit = 50,
  }) async {
    final response = await _apiService.get(
      '/ai/chat/history',
      queryParameters: {
        'user_id': userId.toString(),
        'thread_id': threadId,
        'limit': limit.toString(),
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      List messagesList = data['messages'] ?? [];
      return messagesList.map((m) => AIChatMessage.fromJson(m)).toList();
    } else {
      throw Exception('获取聊天记录失败');
    }
  }

  /// 创建对话线程
  Future<AIChatThread> createThread({
    required int userId,
    String title = '新对话',
  }) async {
    final response = await _apiService.post(
      '/ai/chat/thread?user_id=$userId',
      {'title': title},
    );

    if (response.statusCode == 201) {
      return AIChatThread.fromJson(response.data);
    } else {
      throw Exception('创建对话失败');
    }
  }

  /// 获取用户对话列表
  Future<List<AIChatThread>> getUserThreads(int userId) async {
    final response = await _apiService.get(
      '/ai/chat/threads',
      queryParameters: {
        'user_id': userId.toString(),
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      List threadsList = data['threads'] ?? [];
      return threadsList.map((t) => AIChatThread.fromJson(t)).toList();
    } else {
      throw Exception('获取对话列表失败');
    }
  }

  /// 食物图片识别（image_url 支持 data: URL 或 http(s) URL）
  /// 返回：{food_name, calories, protein, carbohydrates, fat, fiber, confidence}
  Future<Map<String, dynamic>> recognizeFood({
    required String imageUrl,
  }) async {
    final response = await _apiService.post('/ai/recognize', {
      'image_url': imageUrl,
    });

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('食物识别失败');
    }
  }

  /// 文本估算营养素（例："一碗米饭 200g"、"宫保鸡丁一份"）
  /// 返回：{food_name, calories, protein, carbohydrates, fat, fiber, confidence}
  Future<Map<String, dynamic>> estimateNutrition({required String text}) async {
    final response = await _apiService.post('/ai/estimate-nutrition', {
      'text': text,
    });
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('营养估算失败');
    }
  }

  /// 获取 AI 鼓励
  Future<String> getEncouragement({
    required int userId,
    double? weightChange,
    int? streakDays,
  }) async {
    final response = await _apiService.post('/ai/encouragement', {
      'user_id': userId,
      if (weightChange != null) 'weight_change': weightChange,
      if (streakDays != null) 'streak_days': streakDays,
    });

    if (response.statusCode == 200) {
      final data = response.data;
      return data['message'] ?? '';
    } else {
      throw Exception('获取鼓励信息失败');
    }
  }
}
