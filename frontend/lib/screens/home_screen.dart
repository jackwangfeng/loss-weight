import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../screens/login_screen.dart';
import 'records_screen.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';
import '../services/ai_service.dart';
import '../services/food_service.dart';
import '../services/exercise_service.dart';
import '../services/weight_service.dart';
import '../models/food_record.dart';
import '../models/exercise_record.dart';
import '../models/weight_record.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // 记录 tab 里的内部 tab 索引（0=饮食 1=运动 2=体重）
  int _recordsTab = 0;

  /// 外部快捷动作调用：切到"记录"，并预选内部子 tab
  void jumpToRecords(int subTab) {
    setState(() {
      _selectedIndex = 1;
      _recordsTab = subTab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        final isLoggedIn = authProvider.isLoggedIn;
        final user = userProvider.currentUser;

        return Scaffold(
          // 记录页带内部 TabBar：initialTab 用 key 触发，每次想直达某一 tab
          // 就换 key
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              DashboardScreen(user: user, isLoggedIn: isLoggedIn),
              RecordsScreen(key: ValueKey('records-$_recordsTab'), initialTab: _recordsTab),
              const AIScreen(),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.edit_note_outlined),
                selectedIcon: Icon(Icons.edit_note),
                label: '记录',
              ),
              NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.smart_toy),
                label: 'AI',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outlined),
                selectedIcon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashboardScreen extends StatelessWidget {
  final dynamic user;
  final bool isLoggedIn;

  const DashboardScreen({
    Key? key,
    required this.user,
    required this.isLoggedIn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (!isLoggedIn) {
      return _buildLoginView(context);
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('减肥 AI 助理'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (authProvider.isLoggedIn && authProvider.userId != null) {
                  userProvider.loadUser(authProvider.userId!);
                }
              },
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.userId != null) {
          await userProvider.loadUser(authProvider.userId!);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI 今日简报卡
            _DailyBriefCard(userId: user.id, onChatTap: () {
              final homeState = context.findAncestorStateOfType<_HomeScreenState>();
              homeState?.setState(() {
                homeState._selectedIndex = 2;
              });
            }),
            const SizedBox(height: 16),
            // 最近记录时间轴
            _RecentTimeline(
              userId: user.id,
              onTap: (kind) {
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                homeState?.jumpToRecords(kind);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('减肥 AI 助理'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 100, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              '减肥 AI 助理',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '轻松减肥，AI 陪你',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );

                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('欢迎回来！')),
                  );
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('开始使用'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ============================================================================
//  AI 今日简报卡片
//  进入首页异步拉一次；剩余额度、建议一段 AI 生成的点评
// ============================================================================

class _DailyBriefCard extends StatefulWidget {
  final int userId;
  final VoidCallback onChatTap;
  const _DailyBriefCard({required this.userId, required this.onChatTap});
  @override
  State<_DailyBriefCard> createState() => _DailyBriefCardState();
}

class _DailyBriefCardState extends State<_DailyBriefCard> {
  final AIService _ai = AIService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _data = await _ai.getDailyBrief(userId: widget.userId);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: Colors.green[800]),
                const SizedBox(width: 6),
                Text('今日 AI 简报',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[900],
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _loading ? null : _load,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading && _data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text('加载失败：$_error',
                  style: const TextStyle(color: Colors.red))
            else if (_data != null) ...[
              _buildBudgetRow(),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress(),
                  minHeight: 6,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation(_progressColor()),
                ),
              ),
              if ((_data!['brief'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 14),
                MarkdownBody(
                  data: _data!['brief'].toString(),
                  softLineBreak: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        fontSize: 14, color: Colors.black87, height: 1.5),
                    strong: const TextStyle(
                        fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                    blockSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: widget.onChatTap,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('跟 AI 聊聊'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  double _progress() {
    final tgt = (_data?['target_calories'] as num?)?.toDouble() ?? 0;
    final eaten = (_data?['calories_eaten'] as num?)?.toDouble() ?? 0;
    final burned = (_data?['calories_burned'] as num?)?.toDouble() ?? 0;
    final net = eaten - burned;
    if (tgt <= 0) return 0;
    return (net / tgt).clamp(0.0, 1.2).toDouble();
  }

  Color _progressColor() {
    final tgt = (_data?['target_calories'] as num?)?.toDouble() ?? 0;
    final eaten = (_data?['calories_eaten'] as num?)?.toDouble() ?? 0;
    final burned = (_data?['calories_burned'] as num?)?.toDouble() ?? 0;
    return (eaten - burned) > tgt ? Colors.red : Colors.green;
  }

  Widget _buildBudgetRow() {
    final tgt = (_data?['target_calories'] as num?)?.toDouble() ?? 0;
    final eaten = (_data?['calories_eaten'] as num?)?.toDouble() ?? 0;
    final burned = (_data?['calories_burned'] as num?)?.toDouble() ?? 0;
    final remaining = (_data?['calories_remaining'] as num?)?.toDouble() ?? 0;
    return Row(
      children: [
        _pill('目标', tgt),
        _arrow(),
        _pill('吃', eaten),
        _arrow(),
        _pill('烧', burned),
        const Spacer(),
        Text('剩余 ${remaining.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 13,
                color: remaining < 0 ? Colors.red : Colors.green[900],
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _pill(String label, double value) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value.toStringAsFixed(0),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _arrow() => const Padding(
        padding: EdgeInsets.only(right: 6, top: 10),
        child: Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
      );
}

// ============================================================================
//  最近记录时间轴
//  把 food / exercise / weight 三路合并按时间排序，只显示最近 N 条。
//  点击某条跳到对应 tab。
// ============================================================================

class _RecentTimeline extends StatefulWidget {
  final int userId;
  /// kind: 0=饮食 1=运动 2=体重
  final void Function(int kind) onTap;
  const _RecentTimeline({required this.userId, required this.onTap});
  @override
  State<_RecentTimeline> createState() => _RecentTimelineState();
}

class _TimelineItem {
  final DateTime at;
  final int kind;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  _TimelineItem({
    required this.at,
    required this.kind,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _RecentTimelineState extends State<_RecentTimeline> {
  final _foodSvc = FoodService();
  final _exerciseSvc = ExerciseService();
  final _weightSvc = WeightService();
  List<_TimelineItem> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _foodSvc.getRecords(userId: widget.userId),
        _exerciseSvc.getRecords(userId: widget.userId),
        _weightSvc.getRecords(userId: widget.userId),
      ]);
      final items = <_TimelineItem>[];
      for (final r in (results[0] as List<FoodRecord>)) {
        items.add(_TimelineItem(
          at: r.eatenAt,
          kind: 0,
          icon: Icons.restaurant,
          color: Colors.orange,
          title: r.foodName,
          subtitle: '${r.calories.toStringAsFixed(0)} kcal · ${r.mealTypeLabel}',
        ));
      }
      for (final r in (results[1] as List<ExerciseRecord>)) {
        items.add(_TimelineItem(
          at: r.exercisedAt,
          kind: 1,
          icon: Icons.directions_run,
          color: Colors.red,
          title: r.type,
          subtitle: '${r.durationMin} 分钟 · ${r.caloriesBurned.toStringAsFixed(0)} kcal',
        ));
      }
      for (final r in (results[2] as List<WeightRecord>)) {
        items.add(_TimelineItem(
          at: r.measuredAt,
          kind: 2,
          icon: Icons.monitor_weight,
          color: Colors.blue,
          title: '${r.weight.toStringAsFixed(1)} kg',
          subtitle: r.note.isEmpty ? '称重' : '称重 · ${r.note}',
        ));
      }
      items.sort((a, b) => b.at.compareTo(a.at));
      _items = items.take(6).toList();
    } catch (_) {
      // 静默，首页不应弹红 toast 吓人
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _relative(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24 && now.day == d.day) {
      return '今天 ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
    }
    if (diff.inDays == 1 ||
        (diff.inHours < 48 && now.day - d.day == 1)) {
      return '昨天 ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
    }
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                  Text('最近记录',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _loading ? null : _load,
                  ),
                ],
              ),
            ),
            if (_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('还没有记录，去 "记录" 页开始吧',
                      style: TextStyle(color: Colors.grey[600])),
                ),
              )
            else
              for (final item in _items)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: item.color.withValues(alpha: 0.15),
                    child: Icon(item.icon, size: 16, color: item.color),
                  ),
                  title: Text(item.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(item.subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(_relative(item.at),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  onTap: () => widget.onTap(item.kind),
                ),
          ],
        ),
      ),
    );
  }
}
