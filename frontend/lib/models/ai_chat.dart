class AIChatMessage {
  final int id;
  final int userId;
  final String role;
  final String content;
  final int tokens;
  final String threadId;
  final DateTime createdAt;

  AIChatMessage({
    required this.id,
    required this.userId,
    required this.role,
    required this.content,
    this.tokens = 0,
    required this.threadId,
    required this.createdAt,
  });

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      id: json['message_id'] ?? json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? '',
      tokens: json['tokens'] ?? 0,
      threadId: json['thread_id'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class AIChatThread {
  final int id;
  final int userId;
  final String title;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  AIChatThread({
    required this.id,
    required this.userId,
    this.title = '',
    this.messageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AIChatThread.fromJson(Map<String, dynamic> json) {
    return AIChatThread(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      messageCount: json['message_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class AIChatRequest {
  final int userId;
  final List<Map<String, String>> messages;
  final String? threadId;

  AIChatRequest({
    required this.userId,
    required this.messages,
    this.threadId,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'messages': messages,
      if (threadId != null) 'thread_id': threadId,
    };
  }
}
