import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/exercise_service.dart';
import '../services/ai_service.dart';
import '../models/exercise_record.dart';
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
    setState(() => _loading = true);
    try {
      final user = context.read<UserProvider>().currentUser;
      if (user != null) {
        _records = await _svc.getRecords(userId: user.id);
      }
    } catch (e) {
      _toast('加载失败：$e');
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
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('运动记录'),
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
        label: const Text('记录'),
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
        if (_records.isEmpty) _buildEmpty(),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条运动记录？'),
        content: Text('${r.type} · ${r.durationMin} 分钟 · ${r.caloriesBurned.toStringAsFixed(0)} kcal'),
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
    if (ok != true) return false;
    try {
      await _svc.deleteRecord(r.id);
      await _load();
      return true;
    } catch (e) {
      _toast('删除失败：$e');
      return false;
    }
  }

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.directions_run, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('还没有运动记录，点右下角开始',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );

  Future<void> _openAddSheet({ExerciseRecord? prefill}) async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return _toast('请先登录');
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
    final today = _today();
    if (today.isEmpty) return;
    final cal = today.fold<double>(0, (s, r) => s + r.caloriesBurned);
    final minutes = today.fold<int>(0, (s, r) => s + r.durationMin);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('今日共消耗 ${cal.toStringAsFixed(0)} kcal / $minutes 分钟'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ============================================================================
//  今日消耗卡片
// ============================================================================

class _TodayCard extends StatelessWidget {
  final List<ExerciseRecord> records;
  const _TodayCard({required this.records});
  @override
  Widget build(BuildContext context) {
    final double cal = records.fold(0.0, (s, r) => s + r.caloriesBurned);
    final int minutes = records.fold(0, (s, r) => s + r.durationMin);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('今日消耗',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text('${records.length} 次',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(cal.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    )),
                const Text(' kcal',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const Spacer(),
                Text('$minutes 分钟',
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  按日分组卡片
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

  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '$diff 天前';
    return '${d.month}/${d.day}';
  }

  IconData _typeIcon(String type) {
    if (type.contains('跑') || type.contains('走')) return Icons.directions_run;
    if (type.contains('游')) return Icons.pool;
    if (type.contains('骑')) return Icons.directions_bike;
    if (type.contains('瑜伽') || type.contains('拉伸')) return Icons.self_improvement;
    if (type.contains('力量') || type.contains('训练')) return Icons.fitness_center;
    if (type.contains('球')) return Icons.sports_tennis;
    return Icons.sports;
  }

  Color _intensityColor(String intensity) {
    switch (intensity) {
      case 'low':    return Colors.green;
      case 'medium': return Colors.orange;
      case 'high':   return Colors.red;
      default:       return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = records.fold<double>(0, (s, r) => s + r.caloriesBurned);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Text(_label(day),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${total.toStringAsFixed(0)} kcal',
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
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
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: onTap == null ? null : () => onTap!(r),
                leading: CircleAvatar(
                  backgroundColor: _intensityColor(r.intensity),
                  child: Icon(_typeIcon(r.type), color: Colors.white),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(r.type, overflow: TextOverflow.ellipsis)),
                    if (r.distance > 0) ...[
                      const SizedBox(width: 6),
                      Text('· ${r.distance.toStringAsFixed(1)} km',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ],
                ),
                subtitle: Text(
                    '${r.durationMin} 分钟 · ${r.caloriesBurned.toStringAsFixed(0)} kcal'
                    '${r.intensityLabel.isNotEmpty ? "  ${r.intensityLabel}" : ""}'),
                trailing: Text(
                    '${r.exercisedAt.hour.toString().padLeft(2, '0')}:'
                    '${r.exercisedAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey[600])),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
//  添加运动 BottomSheet
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
    final text = _descCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先描述一下运动，如 "跑步 5 公里 30 分钟"')),
      );
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final r = await widget.aiService.estimateExercise(text: text);
      _applyEstimate(r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('估算失败：$e')),
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
    final type = _typeCtrl.text.trim();
    final dur = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    if (type.isEmpty) return _warn('请输入运动类型');
    if (dur <= 0) return _warn('请输入时长');

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
          SnackBar(content: Text(widget.prefill == null ? '运动记录已保存' : '已更新')),
        );
      }
    } catch (e) {
      _warn('保存失败：$e');
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
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                height: 4, width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: _buildFields(),
                ),
              ),
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('保存'),
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

  List<Widget> _buildFields() {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final intFmt = [FilteringTextInputFormatter.digitsOnly];
    final decimalKb = const TextInputType.numberWithOptions(decimal: true);
    final intKb = TextInputType.number;

    return [
      Row(children: [
        Text(widget.prefill == null ? '添加运动记录' : '编辑运动记录',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ]),
      const SizedBox(height: 8),

      Text('让 AI 帮你算',
          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(
          controller: _descCtrl,
          decoration: InputDecoration(
            hintText: '例：跑步 5 公里 30 分钟',
            filled: true, fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              : const Text('估算'),
        ),
        VoiceInputButton(
          targetController: _descCtrl,
          onFinalized: _estimate,
        ),
      ]),

      if (widget.frequentTypes.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('常做',
            style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
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
      Text('详细信息',
          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(
        controller: _typeCtrl,
        decoration: deco('运动类型 *（跑步/游泳/瑜伽…）'),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(
          controller: _durationCtrl,
          decoration: deco('时长 (分钟) *'),
          keyboardType: intKb,
          inputFormatters: intFmt,
        )),
        const SizedBox(width: 12),
        Expanded(child: TextField(
          controller: _caloriesCtrl,
          decoration: deco('消耗 (kcal)'),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          initialValue: _intensity,
          decoration: deco('强度'),
          items: const [
            DropdownMenuItem(value: 'low',    child: Text('轻度')),
            DropdownMenuItem(value: 'medium', child: Text('中等')),
            DropdownMenuItem(value: 'high',   child: Text('高强度')),
          ],
          onChanged: (v) => setState(() => _intensity = v ?? 'medium'),
        )),
        const SizedBox(width: 12),
        Expanded(child: TextField(
          controller: _distanceCtrl,
          decoration: deco('距离 (km)'),
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
        decoration: deco('备注（可选）'),
      ),
    ];
  }
}
