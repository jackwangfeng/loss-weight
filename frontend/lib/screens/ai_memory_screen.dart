import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/ai_service.dart';
import '../models/user_fact.dart';

/// "AI 眼中的我"
/// 展示 user_facts 表里的长期记忆事实。分类显示，可删除。
/// 删除后 AI 下一次聊天就不会再引用这条事实。
class AIMemoryScreen extends StatefulWidget {
  const AIMemoryScreen({Key? key}) : super(key: key);

  @override
  State<AIMemoryScreen> createState() => _AIMemoryScreenState();
}

class _AIMemoryScreenState extends State<AIMemoryScreen> {
  final AIService _ai = AIService();
  List<UserFact> _facts = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      setState(() => _error = '请先登录');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _facts = await _ai.listUserFacts(userId: user.id);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(UserFact f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('忘掉这条？'),
        content: Text('AI 将不再记得：\n\n"${f.fact}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('忘掉'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _ai.deleteUserFact(f.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从 AI 记忆中移除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
    }
  }

  Map<String, List<UserFact>> _groupByCategory() {
    final map = <String, List<UserFact>>{};
    for (final f in _facts) {
      map.putIfAbsent(f.category, () => []).add(f);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 眼中的我'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading && _facts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _facts.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(onRefresh: _load, child: _buildList()),
    );
  }

  Widget _buildEmpty() => ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.auto_awesome, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'AI 还没记住什么。\n多和 AI 聊聊你的偏好、约束、目标，\n它会慢慢积累关于你的"事实"。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], height: 1.6),
              ),
            ),
          ),
        ],
      );

  Widget _buildList() {
    final groups = _groupByCategory();
    final order = ['goal', 'constraint', 'preference', 'routine', 'history'];
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '这些是 AI 从你们的对话中抽取出来的事实，它会在每次聊天中参考。你可以随时让它忘掉某条。',
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
          ),
        ),
        for (final cat in keys) _buildGroup(cat, groups[cat]!),
      ],
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'goal':       return Colors.blue;
      case 'constraint': return Colors.red;
      case 'preference': return Colors.orange;
      case 'routine':    return Colors.green;
      case 'history':    return Colors.purple;
      default:           return Colors.grey;
    }
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'goal':       return Icons.flag;
      case 'constraint': return Icons.block;
      case 'preference': return Icons.favorite;
      case 'routine':    return Icons.repeat;
      case 'history':    return Icons.history;
      default:           return Icons.label;
    }
  }

  String _catLabel(String cat) {
    switch (cat) {
      case 'goal':       return '目标';
      case 'constraint': return '约束';
      case 'preference': return '偏好';
      case 'routine':    return '习惯';
      case 'history':    return '经历';
      default:           return cat;
    }
  }

  Widget _buildGroup(String cat, List<UserFact> facts) {
    final color = _catColor(cat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(
            children: [
              Icon(_catIcon(cat), size: 16, color: color),
              const SizedBox(width: 6),
              Text(_catLabel(cat),
                  style: TextStyle(
                      fontSize: 14, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text('· ${facts.length}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
        for (final f in facts)
          Dismissible(
            key: ValueKey('fact-${f.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              await _confirmDelete(f);
              return false; // 让 _load 来刷新列表，不做本地移除
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(f.fact, style: const TextStyle(fontSize: 15)),
                subtitle: Text(
                  '置信度 ${(f.confidence * 100).toStringAsFixed(0)}% · ${_relative(f.updatedAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.grey[500],
                  onPressed: () => _confirmDelete(f),
                  tooltip: '忘掉',
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${d.month}/${d.day}';
  }
}
