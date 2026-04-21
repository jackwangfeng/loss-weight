import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_chat.dart';
import '../models/user_fact.dart';
import 'api_service.dart';
import 'sse_client.dart';

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

  /// 流式 AI 聊天。Stream 里每一项是一帧 {delta?, done?, message_id?, error?}。
  /// Stream 结束时（done=true）可以从最后一帧拿 message_id。
  ///
  /// 实现：Web 走原生 fetch（fetch_client），其他平台走 http.Client。
  /// Dio 在 Web 会 buffer 整个响应，无法真流式，故此处不使用 Dio。
  Stream<Map<String, dynamic>> chatStream({
    required int userId,
    required String message,
    String? threadId,
  }) async* {
    final client = createStreamingClient();
    try {
      final uri = Uri.parse('${_apiService.baseUrl}/ai/chat/stream');
      final req = http.Request('POST', uri);
      req.headers['Content-Type'] = 'application/json';
      req.headers['Accept'] = 'text/event-stream';
      if (_apiService.token != null) {
        req.headers['Authorization'] = 'Bearer ${_apiService.token}';
      }
      req.body = json.encode({
        'user_id': userId,
        'messages': [
          {'role': 'user', 'content': message},
        ],
        if (threadId != null) 'thread_id': threadId,
      });

      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        final body = await resp.stream.bytesToString();
        throw Exception('AI stream HTTP ${resp.statusCode}: $body');
      }

      // SSE 逐行解析：每帧 `data: {...}\n\n`
      String buffer = '';
      await for (final bytes in resp.stream) {
        buffer += utf8.decode(bytes, allowMalformed: true);
        while (true) {
          final idx = buffer.indexOf('\n\n');
          if (idx < 0) break;
          final raw = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);
          for (final line in raw.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final data = line.substring(6);
            if (data.isEmpty) continue;
            try {
              yield json.decode(data) as Map<String, dynamic>;
            } catch (_) {
              // 忽略坏帧
            }
          }
        }
      }
    } finally {
      client.close();
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

  /// 重命名对话线程
  Future<void> renameThread(int id, String title) async {
    await _apiService.put('/ai/chat/thread/$id', {'title': title});
  }

  /// 删除对话线程（连同其所有消息）
  Future<void> deleteThread(int id) async {
    await _apiService.delete('/ai/chat/thread/$id');
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

  /// 文本估算运动消耗（例："跑步 5 公里 30 分钟"、"瑜伽一小时"）
  /// 返回：{type, duration_min, intensity, calories_burned, distance, confidence}
  Future<Map<String, dynamic>> estimateExercise({required String text}) async {
    final response = await _apiService.post('/ai/estimate-exercise', {
      'text': text,
    });
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('运动消耗估算失败');
    }
  }

  /// 解析体重自然文本（例："68.5kg"、"体脂 22%"、"今天早 67.8"）
  /// 返回：{weight, body_fat, muscle, water, note, confidence}
  Future<Map<String, dynamic>> parseWeight({required String text}) async {
    final response = await _apiService.post('/ai/parse-weight', {
      'text': text,
    });
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('体重解析失败');
    }
  }

  /// 列出用户长期记忆事实
  Future<List<UserFact>> listUserFacts({required int userId}) async {
    final response = await _apiService.get(
      '/ai/facts',
      queryParameters: {'user_id': userId.toString()},
    );
    final list = (response.data['facts'] as List? ?? []);
    return list.map((e) => UserFact.fromJson(e)).toList();
  }

  /// 删除某条长期记忆
  Future<void> deleteUserFact(int id) async {
    await _apiService.delete('/ai/facts/$id');
  }

  /// 今日 AI 简报：用于首页顶部卡片
  /// 返回：{target_calories, calories_eaten, calories_burned, calories_remaining,
  ///        meals_logged, exercises_logged, brief}
  Future<Map<String, dynamic>> getDailyBrief({required int userId}) async {
    final response = await _apiService.post('/ai/daily-brief', {
      'user_id': userId,
    });
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('获取简报失败');
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
