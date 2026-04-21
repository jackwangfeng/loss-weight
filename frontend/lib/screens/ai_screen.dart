import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/ai_service.dart';
import '../models/ai_chat.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({Key? key}) : super(key: key);

  @override
  State<AIScreen> createState() => _AISScreenState();
}

class _AISScreenState extends State<AIScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<AIChatMessage> _messages = [];
  List<AIChatThread> _threads = [];
  AIChatThread? _currentThread;
  bool _isLoading = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadOrCreateThread();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOrCreateThread() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (!authProvider.isLoggedIn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先登录')),
          );
        }
        return;
      }

      // 确保用户信息已加载
      if (userProvider.currentUser == null && authProvider.userId != null) {
        await userProvider.loadUser(authProvider.userId!);
      }

      final userId = userProvider.currentUser?.id ?? authProvider.userId;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取用户信息')),
          );
        }
        return;
      }

      final threads = await _aiService.getUserThreads(userId);
      _threads = threads;
      if (threads.isNotEmpty) {
        _currentThread = threads.first;
        await _loadMessages();
      } else {
        await _createNewThread();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：$e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages() async {
    if (_currentThread == null) return;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.currentUser != null) {
        final messages = await _aiService.getChatHistory(
          userId: userProvider.currentUser!.id,
          threadId: _currentThread!.id.toString(),
        );
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();

        // 空 thread：拿今日简报当作 AI 主动打招呼（不入库，只是展示态）
        if (messages.isEmpty) {
          _injectGreeting(userProvider.currentUser!.id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载消息失败：$e')),
        );
      }
    }
  }

  Future<void> _injectGreeting(int userId) async {
    try {
      final brief = await _aiService.getDailyBrief(userId: userId);
      final text = (brief['brief'] ?? '').toString();
      if (text.isEmpty || !mounted) return;
      setState(() {
        _messages.add(AIChatMessage(
          id: -DateTime.now().millisecondsSinceEpoch,
          userId: userId,
          role: 'assistant',
          content: text,
          threadId: _currentThread?.id.toString() ?? '',
          createdAt: DateTime.now(),
        ));
      });
      _scrollToBottom();
    } catch (_) {
      // 简报失败不影响聊天；静默
    }
  }

  Future<void> _createNewThread() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.currentUser != null) {
        _currentThread = await _aiService.createThread(
          userId: userProvider.currentUser!.id,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建对话失败：$e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      return;
    }

    // 如果没有 thread，先创建一个
    if (_currentThread == null) {
      await _loadOrCreateThread();
    }

    if (_currentThread == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法创建对话')),
        );
      }
      return;
    }

    // 乐观更新：立刻把用户消息加到列表里
    final userId = userProvider.currentUser?.id ?? authProvider.userId;
    if (userId == null) return;
    final localUserMsg = AIChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      userId: userId,
      role: 'user',
      content: message,
      threadId: _currentThread!.id.toString(),
      createdAt: DateTime.now(),
    );
    // 流式占位：assistant 空消息，边收 delta 边替换
    const streamingId = -1;
    final streamingStub = AIChatMessage(
      id: streamingId,
      userId: userId,
      role: 'assistant',
      content: '',
      threadId: _currentThread!.id.toString(),
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages.add(localUserMsg);
      _messages.add(streamingStub);
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    final buf = StringBuffer();
    var firstDelta = true;
    try {
      await for (final chunk in _aiService.chatStream(
        userId: userId,
        message: message,
        threadId: _currentThread!.id.toString(),
      )) {
        final err = chunk['error'] as String?;
        if (err != null && err.isNotEmpty) {
          throw Exception(err);
        }
        final delta = chunk['delta'] as String?;
        if (delta != null && delta.isNotEmpty) {
          buf.write(delta);
          if (!mounted) return;
          setState(() {
            if (firstDelta) {
              _isTyping = false; // 有内容了就不再显示打字圆点
              firstDelta = false;
            }
            final idx = _messages.indexWhere((m) => m.id == streamingId);
            if (idx >= 0) {
              _messages[idx] = AIChatMessage(
                id: streamingId,
                userId: userId,
                role: 'assistant',
                content: buf.toString(),
                threadId: _currentThread!.id.toString(),
                createdAt: _messages[idx].createdAt,
              );
            }
          });
          _scrollToBottom();
        }
        final done = chunk['done'] == true;
        if (done) {
          final mid = (chunk['message_id'] as num?)?.toInt() ?? streamingId;
          if (!mounted) return;
          setState(() {
            _isTyping = false;
            final idx = _messages.indexWhere((m) => m.id == streamingId);
            if (idx >= 0) {
              _messages[idx] = AIChatMessage(
                id: mid,
                userId: userId,
                role: 'assistant',
                content: buf.toString(),
                threadId: _currentThread!.id.toString(),
                createdAt: _messages[idx].createdAt,
              );
            }
          });
          _scrollToBottom();
          // 刷新 drawer 里线程列表（更新标题/时间/消息数）
          _refreshThreads(userId);
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          // 流式失败：把 placeholder 和用户乐观消息都撤回，避免误导
          _messages.removeWhere((m) => m.id == streamingId);
          _messages.removeWhere((m) => m.id == localUserMsg.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(source: ImageSource.camera);
                if (image != null) {
                  _handleImageUpload(File(image.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  _handleImageUpload(File(image.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImageUpload(File imageFile) async {
    // TODO: 上传图片到服务器并获取 URL
    // 这里简化处理，直接提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('食物识别功能需要配置图片上传服务')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentThread?.title.isNotEmpty == true
            ? _currentThread!.title
            : 'AI 助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: _startNewThread,
            tooltip: '新建对话',
          ),
        ],
      ),
      drawer: _buildThreadDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 消息列表
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.smart_toy, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 24),
                              Text(
                                '开始与 AI 聊天吧！',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '我可以帮你：\n• 解答减肥问题\n• 提供饮食建议\n• 给你鼓励和支持',
                                style: TextStyle(color: Colors.grey[500]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isTyping && index == _messages.length) {
                              return _buildTypingIndicator();
                            }
                            final message = _messages[index];
                            return _buildMessageBubble(message);
                          },
                        ),
                ),
                // 输入框
                _buildInputArea(),
              ],
            ),
    );
  }

  Future<void> _startNewThread() async {
    await _createNewThread();
    if (!mounted) return;
    setState(() {
      _messages.clear();
    });
    // 主动 greet + 刷新 thread 列表
    final user = context.read<UserProvider>().currentUser;
    if (user != null) {
      _injectGreeting(user.id);
      _refreshThreads(user.id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已创建新对话')),
      );
    }
  }

  Future<void> _refreshThreads(int userId) async {
    try {
      final threads = await _aiService.getUserThreads(userId);
      if (!mounted) return;
      setState(() => _threads = threads);
    } catch (_) {
      // 静默
    }
  }

  Future<void> _switchThread(AIChatThread t) async {
    if (_currentThread?.id == t.id) {
      Navigator.pop(context); // 关 drawer
      return;
    }
    setState(() {
      _currentThread = t;
      _messages = [];
      _isLoading = true;
    });
    Navigator.pop(context);
    await _loadMessages();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _confirmDeleteThread(AIChatThread t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个对话？'),
        content: Text('"${t.title}" 及其全部消息会被删除，此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _aiService.deleteThread(t.id);
      final user = context.read<UserProvider>().currentUser;
      if (user == null) return;
      final threads = await _aiService.getUserThreads(user.id);
      if (!mounted) return;
      setState(() {
        _threads = threads;
        if (_currentThread?.id == t.id) {
          // 当前选中被删了：切到列表第一个或新建
          if (threads.isNotEmpty) {
            _currentThread = threads.first;
            _messages = [];
            _loadMessages();
          } else {
            _currentThread = null;
            _messages = [];
            _createNewThread().then((_) {
              if (mounted) setState(() {});
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
    }
  }

  Widget _buildThreadDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.forum_outlined, color: Colors.green[800]),
                  const SizedBox(width: 8),
                  const Text('我的对话',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '新建对话',
                    onPressed: () {
                      Navigator.pop(context);
                      _startNewThread();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _threads.isEmpty
                  ? Center(
                      child: Text('还没有对话',
                          style: TextStyle(color: Colors.grey[600])),
                    )
                  : ListView.separated(
                      itemCount: _threads.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (ctx, i) {
                        final t = _threads[i];
                        final isActive = _currentThread?.id == t.id;
                        return ListTile(
                          selected: isActive,
                          selectedTileColor: Colors.green[50],
                          leading: Icon(
                            Icons.chat_bubble_outline,
                            color: isActive ? Colors.green[800] : Colors.grey[600],
                          ),
                          title: Text(
                            t.title.isEmpty ? '新对话' : t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            _threadSubtitle(t),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onPressed: () => _showThreadMenu(t),
                          ),
                          onTap: () => _switchThread(t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _threadSubtitle(AIChatThread t) {
    final d = t.updatedAt;
    final now = DateTime.now();
    final diff = now.difference(d);
    String when;
    if (diff.inMinutes < 60) {
      when = '${diff.inMinutes} 分钟前';
    } else if (diff.inHours < 24 && now.day == d.day) {
      when = '今天 ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
    } else if (diff.inDays < 7) {
      when = '${diff.inDays} 天前';
    } else {
      when = '${d.month}/${d.day}';
    }
    return t.messageCount > 0 ? '$when · ${t.messageCount} 条' : when;
  }

  void _showThreadMenu(AIChatThread t) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名'),
              onTap: () async {
                Navigator.pop(ctx);
                await _renameThread(t);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await _confirmDeleteThread(t);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameThread(AIChatThread t) async {
    final ctrl = TextEditingController(text: t.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '对话名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty || newTitle == t.title) return;
    try {
      await _aiService.renameThread(t.id, newTitle);
      final user = context.read<UserProvider>().currentUser;
      if (user != null) await _refreshThreads(user.id);
      if (!mounted) return;
      if (_currentThread?.id == t.id) {
        // 刷新 AppBar 标题
        setState(() {
          final idx = _threads.indexWhere((x) => x.id == t.id);
          _currentThread = idx >= 0 ? _threads[idx] : _currentThread;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重命名失败：$e')),
        );
      }
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green[100],
            child: Icon(Icons.smart_toy, color: Colors.green[800], size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                _buildDot(1),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.grey[600],
        shape: BoxShape.circle,
      ),
      child: FutureBuilder(
        future: Future.delayed(Duration(milliseconds: index * 150)),
        builder: (context, snapshot) {
          return AnimatedOpacity(
            opacity: snapshot.connectionState == ConnectionState.done ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(AIChatMessage message) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.green[100],
              child: Icon(Icons.smart_toy, color: Colors.green[800], size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? Colors.green : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    )
                  : MarkdownBody(
                      data: message.content,
                      softLineBreak: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
                        strong: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        listBullet: const TextStyle(color: Colors.black87, fontSize: 15),
                        code: TextStyle(
                          color: Colors.deepPurple[900],
                          backgroundColor: Colors.deepPurple[50],
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        blockSpacing: 6,
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt),
              color: Colors.green,
              tooltip: '拍照识别食物',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: '输入消息...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.green,
              child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
