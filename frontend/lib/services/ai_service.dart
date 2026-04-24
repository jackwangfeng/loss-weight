import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../models/ai_chat.dart';
import '../models/user_fact.dart';
import 'api_service.dart';
import 'sse_client.dart';

class AIService {
  final ApiService _apiService = ApiService();

  /// AI 聊天。`locale` 控制大模型回复语言（'en' / 'zh'）；不传就由后端默认英文。
  Future<AIChatMessage> chat({
    required int userId,
    required String message,
    String? threadId,
    String? locale,
  }) async {
    final response = await _apiService.post('/ai/chat', {
      'user_id': userId,
      'messages': [
        {'role': 'user', 'content': message},
      ],
      if (threadId != null) 'thread_id': threadId,
      if (locale != null) 'locale': locale,
    });

    if (response.statusCode == 200) {
      return AIChatMessage.fromJson(response.data);
    } else {
      throw Exception('AI chat failed');
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
    String? locale,
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
        if (locale != null) 'locale': locale,
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

  /// Fetch thread messages. Pass `sinceId` (the last known server message id)
  /// to receive only the delta — used by the coach tab on focus to stay fresh
  /// without refetching the whole conversation.
  Future<List<AIChatMessage>> getChatHistory({
    required int userId,
    required String threadId,
    int limit = 50,
    int? sinceId,
  }) async {
    final response = await _apiService.get(
      '/ai/chat/history',
      queryParameters: {
        'user_id': userId.toString(),
        'thread_id': threadId,
        'limit': limit.toString(),
        if (sinceId != null && sinceId > 0) 'since_id': sinceId.toString(),
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

  /// Create a new conversation thread. An empty title lets the backend
  /// auto-title from the first user message.
  Future<AIChatThread> createThread({
    required int userId,
    String title = 'New chat',
  }) async {
    final response = await _apiService.post(
      '/ai/chat/thread?user_id=$userId',
      {'title': title},
    );

    if (response.statusCode == 201) {
      return AIChatThread.fromJson(response.data);
    } else {
      throw Exception('Failed to create thread');
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
    String? locale,
  }) async {
    final response = await _apiService.post('/ai/recognize', {
      'image_url': imageUrl,
      if (locale != null) 'locale': locale,
    });

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Food recognition failed');
    }
  }

  /// Text-based nutrition estimate.
  /// Returns: {food_name, calories, protein, carbohydrates, fat, fiber, confidence}
  Future<Map<String, dynamic>> estimateNutrition({
    required String text,
    String? locale,
  }) async {
    final response = await _apiService.post('/ai/estimate-nutrition', {
      'text': text,
      if (locale != null) 'locale': locale,
    });
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Nutrition estimate failed');
    }
  }

  /// Text-based exercise estimate.
  /// Returns: {type, duration_min, intensity, calories_burned, distance, confidence}
  Future<Map<String, dynamic>> estimateExercise({
    required String text,
    String? locale,
  }) async {
    final response = await _apiService.post('/ai/estimate-exercise', {
      'text': text,
      if (locale != null) 'locale': locale,
    });
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Exercise estimate failed');
    }
  }

  /// Parse natural-language weight input.
  /// Returns: {weight, body_fat, muscle, water, note, confidence}
  Future<Map<String, dynamic>> parseWeight({
    required String text,
    String? locale,
  }) async {
    final response = await _apiService.post('/ai/parse-weight', {
      'text': text,
      if (locale != null) 'locale': locale,
    });
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Weight parse failed');
    }
  }

  /// 把一句话（手敲或语音转写）解析成 profile 字段。后端所有字段可选，
  /// 未提及就是零值/空串，前端用零值过滤不覆盖已填字段。
  Future<Map<String, dynamic>> parseProfile({
    required String text,
    String? locale,
  }) async {
    final response = await _apiService.post('/ai/parse-profile', {
      'text': text,
      if (locale != null) 'locale': locale,
    });
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Profile parse failed');
    }
  }

  /// 云端语音转写：音频**原始字节**以 multipart/form-data 上传（省 33%
  /// 字节 vs. base64 + 省客户端 encode CPU）。backend 自己 base64 给
  /// Gemini（内网段无所谓）。mime 常见 `audio/mp4`、`audio/wav`、`audio/ogg`。
  Future<Map<String, dynamic>> transcribe({
    required List<int> audioBytes,
    String mimeType = 'audio/mp4',
    String? locale,
  }) async {
    final form = FormData.fromMap({
      'audio': MultipartFile.fromBytes(audioBytes,
          filename: 'rec.m4a',
          contentType: DioMediaType.parse(mimeType)),
      'mime_type': mimeType,
      if (locale != null) 'locale': locale,
    });
    final response = await _apiService.postFormData('/ai/transcribe', form);
    if (response.statusCode == 200) return response.data;
    throw Exception('Transcribe failed');
  }

  /// 云端语音 → 转写 + profile 结构化（一次 Gemini 调用）。返回的 Map 含
  /// `transcript`（给 UI 复核）+ gender/age/height/current_weight/target_weight/
  /// activity_level/confidence 字段。
  Future<Map<String, dynamic>> transcribeAndParseProfile({
    required List<int> audioBytes,
    String mimeType = 'audio/mp4',
    String? locale,
  }) async {
    final form = FormData.fromMap({
      'audio': MultipartFile.fromBytes(audioBytes,
          filename: 'rec.m4a',
          contentType: DioMediaType.parse(mimeType)),
      'mime_type': mimeType,
      if (locale != null) 'locale': locale,
    });
    final response = await _apiService.postFormData(
        '/ai/transcribe-and-parse-profile', form);
    if (response.statusCode == 200) return response.data;
    throw Exception('Transcribe-and-parse failed');
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
  Future<Map<String, dynamic>> getDailyBrief({
    required int userId,
    String? locale,
  }) async {
    final response = await _apiService.post('/ai/daily-brief', {
      'user_id': userId,
      if (locale != null) 'locale': locale,
    });
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to fetch brief');
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
