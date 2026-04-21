import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../screens/login_screen.dart';
import 'records_screen.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';
import '../services/ai_service.dart';

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
            // AI 今日简报卡（最新最重要的）
            _DailyBriefCard(userId: user.id, onChatTap: () {
              final homeState = context.findAncestorStateOfType<_HomeScreenState>();
              homeState?.setState(() {
                homeState._selectedIndex = 2; // AI tab（记录/AI/我的 中 AI 是 index 2）
              });
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    '当前体重',
                    '${(user.currentWeight ?? 0).toStringAsFixed(1)} kg',
                    Icons.monitor_weight,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    '目标体重',
                    '${(user.targetWeight ?? 0).toStringAsFixed(1)} kg',
                    Icons.flag,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'BMI',
                    (user.bmi ?? 0).toStringAsFixed(1),
                    Icons.analytics,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    '已减',
                    '${(user.weightLoss ?? 0).abs().toStringAsFixed(1)} kg',
                    Icons.trending_down,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '快捷操作',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    context,
                    '记录饮食',
                    Icons.restaurant,
                    Colors.orange,
                    () {
                      context.findAncestorStateOfType<_HomeScreenState>()
                          ?.jumpToRecords(0);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    context,
                    '记录运动',
                    Icons.directions_run,
                    Colors.red,
                    () {
                      context.findAncestorStateOfType<_HomeScreenState>()
                          ?.jumpToRecords(1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    context,
                    '记录体重',
                    Icons.monitor_weight,
                    Colors.blue,
                    () {
                      context.findAncestorStateOfType<_HomeScreenState>()
                          ?.jumpToRecords(2);
                    },
                  ),
                ),
              ],
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

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
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
                Text(
                  _data!['brief'].toString(),
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.5),
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
