import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
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
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (!authProvider.isLoggedIn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.toastPleaseSignIn)),
          );
        }
        return;
      }

      if (userProvider.currentUser == null && authProvider.userId != null) {
        await userProvider.loadUser(authProvider.userId!);
      }

      final userId = userProvider.currentUser?.id ?? authProvider.userId;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorCouldNotLoadUser)),
          );
        }
        return;
      }

      // Single continuous conversation: pick the most recent thread with
      // messages, otherwise the latest thread, otherwise create one.
      final threads = await _aiService.getUserThreads(userId);
      if (threads.isNotEmpty) {
        final withMsg = threads.where((t) => t.messageCount > 0).toList();
        _currentThread = withMsg.isNotEmpty ? withMsg.first : threads.first;
        await _loadMessages();
      } else {
        await _createNewThread();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorLoadFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages() async {
    if (_currentThread == null) return;
    final l10n = AppLocalizations.of(context);

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

        if (messages.isEmpty) {
          _injectGreeting(userProvider.currentUser!.id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorCouldNotLoadMessages(e.toString()))),
        );
      }
    }
  }

  Future<void> _injectGreeting(int userId) async {
    try {
      final brief = await _aiService.getDailyBrief(
        userId: userId,
        locale: effectiveAiLocale(context),
      );
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
      // Brief failures shouldn't block chat; stay silent.
    }
  }

  Future<void> _createNewThread() async {
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text(l10n.errorCouldNotCreateConversation(e.toString()))),
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
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.toastPleaseSignIn)),
        );
      }
      return;
    }

    if (_currentThread == null) {
      await _loadOrCreateThread();
    }

    if (_currentThread == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorCouldNotOpenConversation)),
        );
      }
      return;
    }

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
        locale: effectiveAiLocale(context),
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
              _isTyping = false;
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
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.removeWhere((m) => m.id == streamingId);
          _messages.removeWhere((m) => m.id == localUserMsg.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSendFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.actionTakePhoto),
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
              title: Text(l10n.actionChooseFromLibrary),
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).toastUploadNotConfigured)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.coachTitle),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.smart_toy,
                                  size: 80, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 24),
                              Text(
                                l10n.coachEmptyTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.coachEmptySubtitle,
                                style: TextStyle(color: scheme.onSurfaceVariant),
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
                _buildInputArea(l10n),
              ],
            ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.surfaceContainerHighest,
            child: Icon(Icons.smart_toy, color: scheme.onSurface, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: scheme.onSurfaceVariant,
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
              decoration: BoxDecoration(
                color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isUser ? scheme.primary : scheme.surfaceContainerHighest;
    final textColor = isUser ? scheme.onPrimary : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: scheme.surfaceContainerHighest,
              child: Icon(Icons.smart_toy, color: scheme.onSurface, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: TextStyle(color: textColor, fontSize: 15),
                    )
                  : MarkdownBody(
                      data: message.content,
                      softLineBreak: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: textColor, fontSize: 15, height: 1.5),
                        strong: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                        listBullet: TextStyle(color: textColor, fontSize: 15),
                        code: TextStyle(
                          color: scheme.primary,
                          backgroundColor: scheme.surfaceContainer,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: scheme.surfaceContainer,
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

  Widget _buildInputArea(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt),
              tooltip: l10n.actionLogFoodFromPhoto,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: l10n.coachInputHint,
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
              backgroundColor: scheme.primary,
              child: IconButton(
                onPressed: _sendMessage,
                icon: Icon(Icons.send, color: scheme.onPrimary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
