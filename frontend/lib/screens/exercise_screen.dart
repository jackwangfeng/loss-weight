import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';
import '../services/exercise_service.dart';
import '../services/ai_service.dart';
import '../models/exercise_record.dart';
import '../utils/labels.dart';
import '../widgets/voice_input_button.dart';

class ExerciseScreen extends StatefulWidget {
  final bool showAppBar;
  const ExerciseScreen({Key? key, this.showAppBar = true}) : super(key: key);
  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final ExerciseService _svc = ExerciseService();
  final AIService _ai = AIService();

  List<ExerciseRecord> _records = [];
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
      final user = context.read<UserProvider>().currentUser;
      if (user != null) {
        _records = await _svc.getRecords(userId: user.id);
      }
    } catch (e) {
      _toast(l10n.errorLoadFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<ExerciseRecord> _today() {
    final now = DateTime.now();
    return _records.where((r) =>
      r.exercisedAt.year == now.year &&
      r.exercisedAt.month == now.month &&
      r.exercisedAt.day == now.day).toList();
  }

  Map<DateTime, List<ExerciseRecord>> _groupByDay() {
    final map = <DateTime, List<ExerciseRecord>>{};
    for (final r in _records) {
      final key = DateTime(r.exercisedAt.year, r.exercisedAt.month, r.exercisedAt.day);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  List<String> _frequentTypes({int limit = 6}) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final counts = <String, int>{};
    for (final r in _records) {
      if (r.exercisedAt.isBefore(cutoff)) continue;
      counts[r.type] = (counts[r.type] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.trainingTitle),
              actions: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ],
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'exercise_fab',
        onPressed: () => _openAddSheet(),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionLog),
      ),
    );
  }

  Widget _buildBody() {
    final today = _today();
    final groups = _groupByDay();
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _TodayCard(records: today),
        const SizedBox(height: 16),
        if (_records.isEmpty) _buildEmpty(context),
        for (final d in days) _DayGroup(
          day: d,
          records: groups[d]!,
          onTap: (r) => _openAddSheet(prefill: r),
          onDelete: _confirmAndDelete,
        ),
      ],
    );
  }

  Future<bool> _confirmAndDelete(ExerciseRecord r) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingDeleteTitle),
        content: Text('${r.type} · ${r.durationMin} min · ${r.caloriesBurned.toStringAsFixed(0)} kcal'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await _svc.deleteRecord(r.id);
      await _load();
      return true;
    } catch (e) {
      _toast(l10n.errorDeleteFailed(e.toString()));
      return false;
    }
  }

  Widget _buildEmpty(BuildContext ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    final l10n = AppLocalizations.of(ctx);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.fitness_center, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(l10n.trainingEmpty,
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _openAddSheet({ExerciseRecord? prefill}) async {
    final l10n = AppLocalizations.of(context);
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return _toast(l10n.toastPleaseSignIn);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddExerciseSheet(
        userId: user.id,
        exerciseService: _svc,
        aiService: _ai,
        frequentTypes: _frequentTypes(),
        prefill: prefill,
      ),
    );
    if (created == true) {
      await _load();
      _showBurnedToast();
    }
  }

  void _showBurnedToast() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final today = _today();
    if (today.isEmpty) return;
    final cal = today.fold<double>(0, (s, r) => s + r.caloriesBurned);
    final minutes = today.fold<int>(0, (s, r) => s + r.durationMin);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.trainingBurnedToast(cal.toStringAsFixed(0), minutes)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ============================================================================
//  Today's burn card
// ============================================================================

class _TodayCard extends StatelessWidget {
  final List<ExerciseRecord> records;
  const _TodayCard({required this.records});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final double cal = records.fold(0.0, (s, r) => s + r.caloriesBurned);
    final int minutes = records.fold(0, (s, r) => s + r.durationMin);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.trainingTodayLabel,
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                Text(l10n.trainingSessionCount(records.length),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(cal.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: scheme.onSurface,
                    )),
                Text(' kcal',
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                const Spacer(),
                Text(l10n.trainingDurationMinutes(minutes),
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  Day group card
// ============================================================================

class _DayGroup extends StatelessWidget {
  final DateTime day;
  final List<ExerciseRecord> records;
  final void Function(ExerciseRecord)? onTap;
  final Future<bool> Function(ExerciseRecord)? onDelete;
  const _DayGroup({
    required this.day,
    required this.records,
    this.onTap,
    this.onDelete,
  });

  String _label(AppLocalizations l10n, DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return l10n.timeToday;
    if (diff == 1) return l10n.timeYesterdayCap;
    if (diff < 7) return l10n.timeDaysAgo(diff);
    return '${d.month}/${d.day}';
  }

  IconData _typeIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('run') || lower.contains('walk') ||
        type.contains('跑') || type.contains('走')) return Icons.directions_run;
    if (lower.contains('swim') || type.contains('游')) return Icons.pool;
    if (lower.contains('cycle') || lower.contains('bike') ||
        type.contains('骑')) return Icons.directions_bike;
    if (lower.contains('yoga') || lower.contains('stretch') ||
        type.contains('瑜伽') || type.contains('拉伸')) return Icons.self_improvement;
    if (lower.contains('lift') || lower.contains('press') ||
        lower.contains('squat') || lower.contains('deadlift') ||
        lower.contains('strength') || type.contains('力量') ||
        type.contains('训练')) return Icons.fitness_center;
    if (lower.contains('tennis') || lower.contains('ball') ||
        type.contains('球')) return Icons.sports_tennis;
    return Icons.sports;
  }

  Color _intensityColor(String intensity) {
    switch (intensity) {
      case 'low':    return const Color(0xFF64B871);
      case 'medium': return const Color(0xFFE38B2A);
      case 'high':   return const Color(0xFFE53935);
      default:       return const Color(0xFF8A8A90);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final total = records.fold<double>(0, (s, r) => s + r.caloriesBurned);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Text(_label(l10n, day),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${total.toStringAsFixed(0)} kcal',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
        for (final r in records)
          Dismissible(
            key: ValueKey('exercise-${r.id}'),
            direction: onDelete == null
                ? DismissDirection.none
                : DismissDirection.endToStart,
            confirmDismiss: onDelete == null ? null : (_) async => await onDelete!(r),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.delete, color: scheme.onError),
            ),
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: onTap == null ? null : () => onTap!(r),
                leading: CircleAvatar(
                  backgroundColor: _intensityColor(r.intensity).withValues(alpha: 0.18),
                  child: Icon(_typeIcon(r.type), color: _intensityColor(r.intensity)),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(r.type, overflow: TextOverflow.ellipsis)),
                    if (r.distance > 0) ...[
                      const SizedBox(width: 6),
                      Text('· ${r.distance.toStringAsFixed(1)} km',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ],
                ),
                subtitle: Text(
                    '${r.durationMin} min · ${r.caloriesBurned.toStringAsFixed(0)} kcal'
                    '${intensityLabel(l10n, r.intensity).isNotEmpty ? "  ${intensityLabel(l10n, r.intensity)}" : ""}'),
                trailing: Text(
                    '${r.exercisedAt.hour.toString().padLeft(2, '0')}:'
                    '${r.exercisedAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
//  Add/Edit BottomSheet
// ============================================================================

class _AddExerciseSheet extends StatefulWidget {
  final int userId;
  final ExerciseService exerciseService;
  final AIService aiService;
  final List<String> frequentTypes;
  final ExerciseRecord? prefill;
  const _AddExerciseSheet({
    required this.userId,
    required this.exerciseService,
    required this.aiService,
    required this.frequentTypes,
    this.prefill,
  });
  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final _descCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _intensity = 'medium';
  DateTime _exercisedAt = DateTime.now();
  bool _submitting = false;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _typeCtrl.text = p.type;
      _durationCtrl.text = p.durationMin.toString();
      if (p.caloriesBurned > 0) _caloriesCtrl.text = p.caloriesBurned.toStringAsFixed(0);
      if (p.distance > 0) _distanceCtrl.text = p.distance.toStringAsFixed(1);
      if (p.intensity.isNotEmpty) _intensity = p.intensity;
      _notesCtrl.text = p.notes;
      _exercisedAt = p.exercisedAt;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _typeCtrl.dispose();
    _durationCtrl.dispose();
    _caloriesCtrl.dispose();
    _distanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _applyEstimate(Map<String, dynamic> r) {
    setState(() {
      if ((r['type'] ?? '').toString().isNotEmpty) _typeCtrl.text = r['type'].toString();
      final dur = (r['duration_min'] as num?)?.toInt() ?? 0;
      if (dur > 0) _durationCtrl.text = dur.toString();
      final cal = (r['calories_burned'] as num?)?.toDouble() ?? 0;
      if (cal > 0) _caloriesCtrl.text = cal.toStringAsFixed(0);
      final dist = (r['distance'] as num?)?.toDouble() ?? 0;
      if (dist > 0) _distanceCtrl.text = dist.toStringAsFixed(1);
      final inten = (r['intensity'] ?? '').toString();
      if (inten.isNotEmpty) _intensity = inten;
    });
  }

  Future<void> _estimate() async {
    final l10n = AppLocalizations.of(context);
    final text = _descCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.trainingAiEmptyWarn)),
      );
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final r = await widget.aiService.estimateExercise(
        text: text,
        locale: effectiveAiLocale(context),
      );
      _applyEstimate(r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorEstimateFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _exercisedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_exercisedAt),
    );
    setState(() {
      _exercisedAt = DateTime(d.year, d.month, d.day,
          t?.hour ?? _exercisedAt.hour, t?.minute ?? _exercisedAt.minute);
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final type = _typeCtrl.text.trim();
    final dur = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    if (type.isEmpty) return _warn(l10n.trainingTypeRequired);
    if (dur <= 0) return _warn(l10n.trainingDurationRequired);

    setState(() => _submitting = true);
    try {
      final cal = double.tryParse(_caloriesCtrl.text.trim()) ?? 0;
      final dist = double.tryParse(_distanceCtrl.text.trim()) ?? 0;
      if (widget.prefill != null) {
        await widget.exerciseService.updateRecord(
          widget.prefill!.id,
          type: type,
          durationMin: dur,
          intensity: _intensity,
          caloriesBurned: cal,
          distance: dist,
          notes: _notesCtrl.text.trim(),
          exercisedAt: _exercisedAt,
        );
      } else {
        await widget.exerciseService.createRecord(
          userId: widget.userId,
          type: type,
          durationMin: dur,
          intensity: _intensity,
          caloriesBurned: cal,
          distance: dist,
          notes: _notesCtrl.text.trim(),
          exercisedAt: _exercisedAt,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.prefill == null ? l10n.toastLogged : l10n.toastUpdated)),
        );
      }
    } catch (e) {
      _warn(l10n.errorSaveFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _warn(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                height: 4, width: 40,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: _buildFields(l10n),
                ),
              ),
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(top: BorderSide(color: scheme.outlineVariant)),
                  ),
                  child: SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(l10n.actionSave),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields(AppLocalizations l10n) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final intFmt = [FilteringTextInputFormatter.digitsOnly];
    final decimalKb = const TextInputType.numberWithOptions(decimal: true);
    const intKb = TextInputType.number;

    return [
      Row(children: [
        Text(widget.prefill == null ? l10n.trainingLogSheetTitle : l10n.trainingEditSheetTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ]),
      const SizedBox(height: 8),

      _sectionTitle(l10n.foodSectionAiEstimate),
      Row(children: [
        Expanded(child: TextField(
          controller: _descCtrl,
          decoration: InputDecoration(
            hintText: l10n.trainingAiHint,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _estimate(),
        )),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: _aiLoading ? null : _estimate,
          child: _aiLoading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.actionEstimate),
        ),
        VoiceInputButton(
          targetController: _descCtrl,
          onFinalized: _estimate,
          localeId: effectiveAiLocale(context) == 'zh' ? 'zh-CN' : 'en-US',
        ),
      ]),

      if (widget.frequentTypes.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle(l10n.trainingSectionFrequent),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in widget.frequentTypes)
              ActionChip(
                label: Text(t),
                onPressed: () {
                  setState(() {
                    _typeCtrl.text = t;
                    _descCtrl.text = t;
                  });
                  _estimate();
                },
              ),
          ],
        ),
      ],

      const SizedBox(height: 20),
      _sectionTitle(l10n.foodSectionDetails),
      const SizedBox(height: 4),
      TextField(
        controller: _typeCtrl,
        decoration: deco(l10n.trainingType).copyWith(hintText: l10n.trainingTypeHint),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(
          controller: _durationCtrl,
          decoration: deco(l10n.trainingDurationMin),
          keyboardType: intKb,
          inputFormatters: intFmt,
        )),
        const SizedBox(width: 12),
        Expanded(child: TextField(
          controller: _caloriesCtrl,
          decoration: deco(l10n.trainingCaloriesBurned),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          initialValue: _intensity,
          decoration: deco(l10n.trainingIntensity),
          items: [
            DropdownMenuItem(value: 'low',    child: Text(l10n.intensityLight)),
            DropdownMenuItem(value: 'medium', child: Text(l10n.intensityModerate)),
            DropdownMenuItem(value: 'high',   child: Text(l10n.intensityHard)),
          ],
          onChanged: (v) => setState(() => _intensity = v ?? 'medium'),
        )),
        const SizedBox(width: 12),
        Expanded(child: TextField(
          controller: _distanceCtrl,
          decoration: deco(l10n.trainingDistanceKm),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
      ]),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pickTime,
        icon: const Icon(Icons.schedule),
        label: Text('${_exercisedAt.month}/${_exercisedAt.day} '
            '${_exercisedAt.hour.toString().padLeft(2, "0")}:'
            '${_exercisedAt.minute.toString().padLeft(2, "0")}'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _notesCtrl,
        decoration: deco(l10n.trainingNotes),
      ),
    ];
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
      );
}
