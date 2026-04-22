import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';
import '../screens/login_screen.dart';
import '../utils/labels.dart';
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
  int _recordsTab = 0;

  void jumpToRecords(int subTab) {
    setState(() {
      _selectedIndex = 1;
      _recordsTab = subTab;
    });
  }

  void jumpToCoach() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        final isLoggedIn = authProvider.isLoggedIn;
        final user = userProvider.currentUser;

        return Scaffold(
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
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: l10n.navToday,
              ),
              NavigationDestination(
                icon: const Icon(Icons.edit_note_outlined),
                selectedIcon: const Icon(Icons.edit_note),
                label: l10n.navLog,
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_outlined),
                selectedIcon: const Icon(Icons.chat),
                label: l10n.navCoach,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outlined),
                selectedIcon: const Icon(Icons.person),
                label: l10n.navMe,
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
    final l10n = AppLocalizations.of(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (!isLoggedIn) {
      return _buildLoginView(context);
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: RefreshIndicator(
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
              _DailyBriefCard(userId: user.id, onChatTap: () {
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                homeState?.jumpToCoach();
              }),
              const SizedBox(height: 16),
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
      ),
    );
  }

  Widget _buildLoginView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 100, color: scheme.primary),
            const SizedBox(height: 24),
            Text(
              l10n.appTitle,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.appTagline,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
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
                    SnackBar(content: Text(l10n.toastWelcomeBack)),
                  );
                }
              },
              icon: const Icon(Icons.login),
              label: Text(l10n.actionGetStarted),
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
//  Daily AI brief card
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
      _data = await _ai.getDailyBrief(
        userId: widget.userId,
        locale: effectiveAiLocale(context),
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text(l10n.homeTodaySection.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _loading ? null : _load,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading && _data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(l10n.homeFailedToLoad(_error!),
                  style: TextStyle(color: scheme.error))
            else if (_data != null) ...[
              _buildBudgetRow(l10n),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress(),
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(_progressColor(context)),
                ),
              ),
              if ((_data!['brief'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 14),
                MarkdownBody(
                  data: _data!['brief'].toString(),
                  softLineBreak: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                        fontSize: 14, color: scheme.onSurface, height: 1.5),
                    strong: TextStyle(
                        fontSize: 14, color: scheme.onSurface, fontWeight: FontWeight.w600),
                    blockSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: widget.onChatTap,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: Text(l10n.actionAskCoach),
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

  Color _progressColor(BuildContext ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    final tgt = (_data?['target_calories'] as num?)?.toDouble() ?? 0;
    final eaten = (_data?['calories_eaten'] as num?)?.toDouble() ?? 0;
    final burned = (_data?['calories_burned'] as num?)?.toDouble() ?? 0;
    return (eaten - burned) > tgt ? scheme.error : scheme.primary;
  }

  Widget _buildBudgetRow(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final tgt = (_data?['target_calories'] as num?)?.toDouble() ?? 0;
    final eaten = (_data?['calories_eaten'] as num?)?.toDouble() ?? 0;
    final burned = (_data?['calories_burned'] as num?)?.toDouble() ?? 0;
    final remaining = (_data?['calories_remaining'] as num?)?.toDouble() ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _pill(l10n.homeBudgetTarget, tgt),
        _arrow(),
        _pill(l10n.homeBudgetIn, eaten),
        _arrow(),
        _pill(l10n.homeBudgetOut, burned),
        const Spacer(),
        Text(l10n.homeBudgetLeft(remaining.toStringAsFixed(0)),
            style: TextStyle(
                fontSize: 13,
                color: remaining < 0 ? scheme.error : scheme.onSurface,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _pill(String label, double value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.8,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value.toStringAsFixed(0),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3)),
        ],
      ),
    );
  }

  Widget _arrow() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 2),
      child: Icon(Icons.arrow_right_alt, size: 14, color: scheme.onSurfaceVariant),
    );
  }
}

// ============================================================================
//  Recent log timeline
// ============================================================================

class _RecentTimeline extends StatefulWidget {
  final int userId;
  /// kind: 0=food 1=exercise 2=weight
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
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
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
          color: const Color(0xFFE38B2A),
          title: r.foodName,
          subtitle: '${r.calories.toStringAsFixed(0)} kcal · ${mealTypeLabel(l10n, r.mealType)}',
        ));
      }
      for (final r in (results[1] as List<ExerciseRecord>)) {
        items.add(_TimelineItem(
          at: r.exercisedAt,
          kind: 1,
          icon: Icons.fitness_center,
          color: const Color(0xFFE53935),
          title: r.type,
          subtitle: '${r.durationMin} min · ${r.caloriesBurned.toStringAsFixed(0)} kcal',
        ));
      }
      for (final r in (results[2] as List<WeightRecord>)) {
        items.add(_TimelineItem(
          at: r.measuredAt,
          kind: 2,
          icon: Icons.monitor_weight,
          color: const Color(0xFF5B9BD5),
          title: '${r.weight.toStringAsFixed(1)} kg',
          subtitle: r.note.isEmpty ? l10n.weightWeighIn : '${l10n.weightWeighIn} · ${r.note}',
        ));
      }
      items.sort((a, b) => b.at.compareTo(a.at));
      _items = items.take(6).toList();
    } catch (_) {
      // Silent on home.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _relative(AppLocalizations l10n, DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inSeconds < 60) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24 && now.day == d.day) {
      return '${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
    }
    if (diff.inDays == 1 ||
        (diff.inHours < 48 && now.day - d.day == 1)) {
      return l10n.timeYesterday;
    }
    if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.history, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(l10n.homeRecentSection.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4)),
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
                  child: Text(l10n.homeEmpty,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
              )
            else
              for (final item in _items)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: item.color.withValues(alpha: 0.18),
                    child: Icon(item.icon, size: 16, color: item.color),
                  ),
                  title: Text(item.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(item.subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  trailing: Text(_relative(l10n, item.at),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  onTap: () => widget.onTap(item.kind),
                ),
          ],
        ),
      ),
    );
  }
}
