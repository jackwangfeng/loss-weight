import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';
import '../screens/login_screen.dart';
import '../utils/labels.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';
import '../services/ai_service.dart';
import '../services/food_service.dart';
import '../services/exercise_service.dart';
import '../services/weight_service.dart';
import '../models/food_record.dart';
import '../models/exercise_record.dart';
import '../models/weight_record.dart';
import '../widgets/macro_dashboard_card.dart';
import 'quick_setup_sheet.dart';
import 'today_food_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // Key lets us poke AIScreen when the Assistant tab gains focus so it can
  // delta-refresh from the backend instead of showing the stale cached
  // thread that an IndexedStack-mounted screen would otherwise keep.
  final GlobalKey<AIScreenState> _aiKey = GlobalKey<AIScreenState>();

  @override
  void initState() {
    super.initState();
    // If AuthProvider.load() restored a session on cold boot, the
    // UserProvider is still empty — fetch the profile so DashboardScreen
    // doesn't flash the "loading user" placeholder while we wait for the
    // user to tap refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();
      if (auth.isLoggedIn &&
          auth.userId != null &&
          userProvider.currentUser == null &&
          !userProvider.isLoading) {
        userProvider.loadUser(auth.userId!);
      }
    });
  }

  void jumpToCoach() {
    setState(() {
      _selectedIndex = 1;
    });
    _aiKey.currentState?.refreshIfStale();
  }

  void jumpToProfile() {
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
              AIScreen(key: _aiKey),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
              // Assistant tab gaining focus = chance for the thread to have
              // diverged from what we cached. Fire-and-forget; the method
              // is throttled + self-guarded.
              if (index == 1) {
                _aiKey.currentState?.refreshIfStale();
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: l10n.navToday,
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_outlined),
                selectedIcon: const Icon(Icons.chat),
                label: l10n.navAssistant,
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
              _QuickSetupBanner(user: user),
              _DailyBriefCard(
                userId: user.id,
                onChatTap: () {
                  final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                  homeState?.jumpToCoach();
                },
                onProfileTap: () {
                  final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                  homeState?.jumpToProfile();
                },
              ),
              const SizedBox(height: 16),
              _TodayMacroCard(userId: user.id),
              const SizedBox(height: 16),
              _RecentTimeline(userId: user.id),
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
  final VoidCallback onProfileTap;
  const _DailyBriefCard({
    required this.userId,
    required this.onChatTap,
    required this.onProfileTap,
  });
  @override
  State<_DailyBriefCard> createState() => _DailyBriefCardState();
}

class _DailyBriefCardState extends State<_DailyBriefCard> {
  final AIService _ai = AIService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;    // true while a refresh is in flight
  bool _deficitExpanded = false;

  // Stale-while-revalidate: cache the last successful brief per-user; on next
  // mount show the cached copy instantly while the live API recomputes.
  static String _cacheKey(int userId) => 'home.daily_brief.v1.$userId';

  @override
  void initState() {
    super.initState();
    _loadCache().then((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    });
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(widget.userId));
      if (raw == null || !mounted) return;
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        setState(() => _data = parsed);
      }
    } catch (_) {
      // Corrupted cache — ignore; live fetch will still run.
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final live = await _ai.getDailyBrief(
        userId: widget.userId,
        locale: effectiveAiLocale(context),
      );
      if (!mounted) return;
      setState(() => _data = live);
      // Cache AFTER we've committed it to state — stale copy is OK even if
      // the file write fails.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey(widget.userId), jsonEncode(live));
      } catch (_) {}
    } catch (e) {
      // Refresh failed — if we already have cache on screen, keep showing it
      // silently; only bubble up the error when there's nothing to display.
      if (_data == null) _error = e.toString();
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
                // Show a small spinner in-place of the refresh icon while a
                // live refresh is in flight, so the UI makes it clear that
                // cached data is being replaced soon.
                if (_loading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(scheme.onSurfaceVariant),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _load,
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
              const SizedBox(height: 12),
              _buildDeficitSection(l10n),
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

  /// Collapsed-by-default deficit row. Taps toggle an expanded grid with
  /// BMR/TDEE/eaten/deficit. Backend returns tdee=0 when the profile is
  /// missing age/height/sex/activity — in that case we show a one-line CTA
  /// pointing the user to the profile screen instead.
  Widget _buildDeficitSection(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final tdee = (_data?['tdee'] as num?)?.toDouble() ?? 0;
    final bmr = (_data?['bmr'] as num?)?.toDouble() ?? 0;
    final eaten = (_data?['calories_eaten'] as num?)?.toDouble() ?? 0;
    final deficit = (_data?['calories_deficit'] as num?)?.toDouble() ?? 0;

    if (tdee <= 0) {
      return InkWell(
        onTap: widget.onProfileTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l10n.homeDeficitNeedProfile,
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ),
              Icon(Icons.chevron_right,
                  size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    // Color + label rules: deficit > 50 kcal → green (on track), < -50 → red
    // (over), else neutral "maintenance". The 50-kcal band avoids flapping
    // between labels as the day's first meal lands.
    final String label;
    final Color color;
    if (deficit > 50) {
      label = l10n.homeDeficitToday(deficit.toStringAsFixed(0));
      color = Colors.green.shade400;
    } else if (deficit < -50) {
      label = l10n.homeSurplusToday(deficit.toStringAsFixed(0));
      color = scheme.error;
    } else {
      label = l10n.homeDeficitMaintenance;
      color = scheme.onSurface;
    }

    return InkWell(
      onTap: () => setState(() => _deficitExpanded = !_deficitExpanded),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
                Icon(
                  _deficitExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            crossFadeState: _deficitExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                children: [
                  Expanded(child: _metabPill(l10n.homeMetabolismBmr, bmr)),
                  Expanded(child: _metabPill(l10n.homeMetabolismTdee, tdee)),
                  Expanded(
                      child: _metabPill(l10n.homeMetabolismEaten, eaten)),
                  Expanded(
                      child: _metabPill(
                          l10n.homeMetabolismDeficit,
                          deficit,
                          signed: true,
                          color: color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metabPill(String label, double value, {bool signed = false, Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    final text = signed
        ? (value >= 0 ? '+${value.toStringAsFixed(0)}' : value.toStringAsFixed(0))
        : value.toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.8,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(text,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: color ?? scheme.onSurface)),
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
  const _RecentTimeline({required this.userId});
  @override
  State<_RecentTimeline> createState() => _RecentTimelineState();
}

class _TimelineItem {
  final int recordId;
  final DateTime at;
  final int kind; // 0=food, 1=exercise, 2=weight
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  _TimelineItem({
    required this.recordId,
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
          recordId: r.id,
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
          recordId: r.id,
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
          recordId: r.id,
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

  Future<bool> _confirmDismiss(AppLocalizations l10n, _TimelineItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.entryDeleteConfirm(item.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _doDelete(AppLocalizations l10n, _TimelineItem item) async {
    try {
      switch (item.kind) {
        case 0:
          await _foodSvc.deleteRecord(item.recordId);
          break;
        case 1:
          await _exerciseSvc.deleteRecord(item.recordId);
          break;
        case 2:
          await _weightSvc.deleteRecord(item.recordId);
          break;
      }
      if (!mounted) return;
      setState(() {
        _items = _items.where((x) => !(x.kind == item.kind && x.recordId == item.recordId)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorDeleteFailed(e.toString()))),
      );
      // Re-load to recover the row that Dismissible already removed locally.
      _load();
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
                Dismissible(
                  key: ValueKey('tl-${item.kind}-${item.recordId}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: scheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline, color: scheme.onError),
                  ),
                  confirmDismiss: (_) => _confirmDismiss(l10n, item),
                  onDismissed: (_) => _doDelete(l10n, item),
                  // Semantics inside Dismissible — outside, the label gets
                  // dropped (Dismissible owns the parent semantics node).
                  child: Semantics(
                    container: true,
                    label: '${item.title} ${item.subtitle}',
                    child: ListTile(
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
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  Home macro dashboard — loads today's food and hands off to MacroDashboardCard
// ============================================================================

class _TodayMacroCard extends StatefulWidget {
  final int userId;
  const _TodayMacroCard({required this.userId});
  @override
  State<_TodayMacroCard> createState() => _TodayMacroCardState();
}

class _TodayMacroCardState extends State<_TodayMacroCard> {
  final _foodSvc = FoodService();
  List<FoodRecord> _today = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final all = await _foodSvc.getRecords(userId: widget.userId);
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _today = all
            .where((r) =>
                r.eatenAt.year == now.year &&
                r.eatenAt.month == now.month &&
                r.eatenAt.day == now.day)
            .toList();
      });
    } catch (_) {
      // Silent on home — no red toast.
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => TodayFoodListScreen(userId: widget.userId),
          ),
        );
        if (changed == true && mounted) {
          _load();
        }
      },
      child: MacroDashboardCard(todayRecords: _today),
    );
  }
}

// ============================================================================
//  Quick-setup banner — shows at top of dashboard until the user either fills
//  in a minimal profile or explicitly dismisses the prompt.
// ============================================================================

/// "Needs setup" = height or birthday still at factory defaults (0 / null).
/// Those two fields aren't auto-assigned a plausible number by the backend's
/// new-user defaults, so their absence is the cleanest signal that the user
/// never ran the quick setup.
bool _profileNeedsQuickSetup(dynamic user) {
  if (user == null) return false;
  return (user.height ?? 0) <= 0 || user.birthday == null;
}

class _QuickSetupBanner extends StatefulWidget {
  final dynamic user;
  const _QuickSetupBanner({required this.user});

  @override
  State<_QuickSetupBanner> createState() => _QuickSetupBannerState();
}

class _QuickSetupBannerState extends State<_QuickSetupBanner> {
  static const _prefsKey = 'onboarding.quicksetup_dismissed';
  bool? _dismissed; // null until loaded

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _dismissed = prefs.getBool(_prefsKey) ?? false);
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    if (mounted) setState(() => _dismissed = true);
  }

  Future<void> _openSheet() async {
    final saved = await QuickSetupSheet.show(context, widget.user);
    if (saved == true && mounted) {
      // Successful save — hide banner for good (user "finished" setup).
      await _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed == null || _dismissed == true) {
      return const SizedBox.shrink();
    }
    if (!_profileNeedsQuickSetup(widget.user)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _openSheet,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.quickSetupBannerTitle,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.quickSetupBannerHint,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                onPressed: _dismiss,
                tooltip: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
