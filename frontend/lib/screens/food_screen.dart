import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';
import '../services/food_service.dart';
import '../services/ai_service.dart';
import '../models/food_record.dart';
import '../utils/labels.dart';
import '../widgets/voice_input_button.dart';

class FoodScreen extends StatefulWidget {
  /// When embedded under RecordsScreen's TabBar, pass false to avoid double AppBar.
  final bool showAppBar;
  const FoodScreen({Key? key, this.showAppBar = true}) : super(key: key);

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final FoodService _foodService = FoodService();
  final AIService _aiService = AIService();

  List<FoodRecord> _records = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      final user = context.read<UserProvider>().currentUser;
      if (user != null) {
        _records = await _foodService.getRecords(userId: user.id);
      }
    } catch (e) {
      _toast(l10n.errorLoadFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<FoodRecord> _todayRecords() {
    final now = DateTime.now();
    return _records
        .where((r) => r.eatenAt.year == now.year &&
            r.eatenAt.month == now.month &&
            r.eatenAt.day == now.day)
        .toList();
  }

  Map<DateTime, List<FoodRecord>> _groupByDay() {
    final map = <DateTime, List<FoodRecord>>{};
    for (final r in _records) {
      final key = DateTime(r.eatenAt.year, r.eatenAt.month, r.eatenAt.day);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  List<String> _frequentFoods({int limit = 8}) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final counts = <String, int>{};
    for (final r in _records) {
      if (r.eatenAt.isBefore(cutoff)) continue;
      counts[r.foodName] = (counts[r.foodName] ?? 0) + 1;
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
              title: Text(l10n.foodTitle),
              actions: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRecords),
              ],
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecords,
              child: _buildBody(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'food_fab',
        onPressed: () => _openAddSheet(),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionLog),
      ),
    );
  }

  Widget _buildBody() {
    final todayItems = _todayRecords();
    final groups = _groupByDay();
    final orderedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _TodaySummary(records: todayItems),
        const SizedBox(height: 16),
        if (_records.isEmpty) _buildEmpty(context),
        for (final day in orderedKeys) _DayGroup(
          day: day,
          records: groups[day]!,
          onTap: (r) => _openAddSheet(prefill: r),
          onDelete: _confirmAndDelete,
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    final l10n = AppLocalizations.of(ctx);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.restaurant, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(l10n.foodEmpty, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _openAddSheet({FoodRecord? prefill}) async {
    final l10n = AppLocalizations.of(context);
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      _toast(l10n.toastPleaseSignIn);
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddFoodSheet(
        userId: user.id,
        foodService: _foodService,
        aiService: _aiService,
        frequentFoods: _frequentFoods(),
        prefill: prefill,
      ),
    );
    if (created == true) {
      await _loadRecords();
      _showBudgetToast();
    }
  }

  Future<bool> _confirmAndDelete(FoodRecord r) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.foodDeleteTitle),
        content: Text('${r.foodName} · ${r.calories.toStringAsFixed(0)} kcal'),
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
      await _foodService.deleteRecord(r.id);
      await _loadRecords();
      _showBudgetToast();
      return true;
    } catch (e) {
      _toast(l10n.errorDeleteFailed(e.toString()));
      return false;
    }
  }

  void _showBudgetToast() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final user = context.read<UserProvider>().currentUser;
    if (user == null || user.targetCalorie <= 0) return;
    final today = _todayRecords();
    final eaten = today.fold<double>(0, (s, r) => s + r.calories);
    final remaining = user.targetCalorie - eaten;
    final msg = remaining >= 0
        ? l10n.foodBudgetUnder(eaten.toStringAsFixed(0), remaining.toStringAsFixed(0))
        : l10n.foodBudgetOver(eaten.toStringAsFixed(0), (-remaining).toStringAsFixed(0));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }
}

// ============================================================================
//  Today's calorie summary card
// ============================================================================

class _TodaySummary extends StatelessWidget {
  final List<FoodRecord> records;
  const _TodaySummary({required this.records});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final user = context.watch<UserProvider>().currentUser;
    final double cal = records.fold(0.0, (s, r) => s + r.calories);
    final double protein = records.fold(0.0, (s, r) => s + r.protein);
    final double carbs = records.fold(0.0, (s, r) => s + r.carbohydrates);
    final double fat = records.fold(0.0, (s, r) => s + r.fat);
    final double target = user?.targetCalorie ?? 2000.0;
    final double pct = target > 0 ? (cal / target).clamp(0.0, 1.2) : 0.0;
    final bool over = target > 0 && cal > target;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.foodTodayLabel,
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                Text(l10n.foodMealCount(records.length),
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
                      color: over ? scheme.error : scheme.onSurface,
                    )),
                Text(' / ${target.toStringAsFixed(0)} kcal',
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct > 1.0 ? 1.0 : pct,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(over ? scheme.error : scheme.primary),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _macroBadge(l10n.foodMacroProtein, protein, 'g', const Color(0xFFE38B2A)),
                _macroBadge(l10n.foodMacroCarbs, carbs, 'g', const Color(0xFF5B9BD5)),
                _macroBadge(l10n.foodMacroFat, fat, 'g', const Color(0xFFB18CD9)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroBadge(String label, double v, String unit, Color c) {
    return Column(
      children: [
        Text('${v.toStringAsFixed(0)}$unit',
            style: TextStyle(
                color: c, fontSize: 16, fontWeight: FontWeight.w600,
                letterSpacing: -0.2)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ============================================================================
//  Day group card
// ============================================================================

class _DayGroup extends StatelessWidget {
  final DateTime day;
  final List<FoodRecord> records;
  final void Function(FoodRecord)? onTap;
  final Future<bool> Function(FoodRecord)? onDelete;
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final dayCal = records.fold<double>(0, (s, r) => s + r.calories);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Text(_label(l10n, day),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${dayCal.toStringAsFixed(0)} kcal',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
        for (final r in records)
          Dismissible(
            key: ValueKey('food-${r.id}'),
            direction: onDelete == null
                ? DismissDirection.none
                : DismissDirection.endToStart,
            confirmDismiss: onDelete == null
                ? null
                : (_) async => await onDelete!(r),
            background: _swipeDeleteBg(context),
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _mealColor(r.mealType).withValues(alpha: 0.18),
                  child: Icon(_mealIcon(r.mealType), color: _mealColor(r.mealType)),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(r.foodName,
                        overflow: TextOverflow.ellipsis)),
                    if (r.portionLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('· ${r.portionLabel}',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ],
                ),
                subtitle: Text(
                    '${r.calories.toStringAsFixed(0)} kcal · ${mealTypeLabel(l10n, r.mealType)}'
                    '${r.protein > 0 ? "  P ${r.protein.toStringAsFixed(0)}g" : ""}'),
                trailing: Text(
                    '${r.eatenAt.hour.toString().padLeft(2, '0')}:'
                    '${r.eatenAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                onTap: onTap == null ? null : () => onTap!(r),
              ),
            ),
          ),
      ],
    );
  }

  static Widget _swipeDeleteBg(BuildContext ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.delete, color: scheme.onError),
    );
  }

  static Color _mealColor(String m) {
    switch (m) {
      case 'breakfast': return const Color(0xFFE38B2A);
      case 'lunch':     return const Color(0xFF64B871);
      case 'dinner':    return const Color(0xFF5B9BD5);
      case 'snack':     return const Color(0xFFB18CD9);
      default:          return const Color(0xFF8A8A90);
    }
  }

  static IconData _mealIcon(String m) {
    switch (m) {
      case 'breakfast': return Icons.free_breakfast;
      case 'lunch':     return Icons.lunch_dining;
      case 'dinner':    return Icons.dinner_dining;
      case 'snack':     return Icons.cookie;
      default:          return Icons.restaurant;
    }
  }
}

// ============================================================================
//  Add/Edit BottomSheet
// ============================================================================

class _AddFoodSheet extends StatefulWidget {
  final int userId;
  final FoodService foodService;
  final AIService aiService;
  final List<String> frequentFoods;
  final FoodRecord? prefill;
  const _AddFoodSheet({
    required this.userId,
    required this.foodService,
    required this.aiService,
    required this.frequentFoods,
    this.prefill,
  });

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _descCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _portionCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();

  String _unit = 'g';
  String _mealType = 'breakfast';
  DateTime _eatenAt = DateTime.now();
  bool _submitting = false;
  bool _aiLoading = false;
  bool _showMacros = false;

  static String _defaultMealType(DateTime now) {
    final h = now.hour;
    if (h >= 6 && h < 10) return 'breakfast';
    if (h >= 10 && h < 14) return 'lunch';
    if (h >= 17 && h < 21) return 'dinner';
    return 'snack';
  }

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _nameCtrl.text = p.foodName;
      _caloriesCtrl.text = p.calories.toStringAsFixed(0);
      if (p.portion > 0) _portionCtrl.text = p.portion.toStringAsFixed(0);
      if (p.unit.isNotEmpty) _unit = p.unit;
      _mealType = p.mealType;
      _eatenAt = p.eatenAt;
      if (p.protein > 0) _proteinCtrl.text = p.protein.toStringAsFixed(0);
      if (p.carbohydrates > 0) _carbsCtrl.text = p.carbohydrates.toStringAsFixed(0);
      if (p.fat > 0) _fatCtrl.text = p.fat.toStringAsFixed(0);
      _showMacros = p.protein > 0 || p.carbohydrates > 0 || p.fat > 0;
    } else {
      _mealType = _defaultMealType(_eatenAt);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _nameCtrl.dispose();
    _caloriesCtrl.dispose();
    _portionCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _applyEstimate(Map<String, dynamic> r) {
    setState(() {
      if (_nameCtrl.text.isEmpty && (r['food_name'] ?? '').toString().isNotEmpty) {
        _nameCtrl.text = r['food_name'].toString();
      }
      final cal = (r['calories'] as num?)?.toDouble() ?? 0;
      if (cal > 0) _caloriesCtrl.text = cal.toStringAsFixed(0);
      final p = (r['protein'] as num?)?.toDouble() ?? 0;
      final c = (r['carbohydrates'] as num?)?.toDouble() ?? 0;
      final f = (r['fat'] as num?)?.toDouble() ?? 0;
      if (p > 0) _proteinCtrl.text = p.toStringAsFixed(1);
      if (c > 0) _carbsCtrl.text = c.toStringAsFixed(1);
      if (f > 0) _fatCtrl.text = f.toStringAsFixed(1);
      if (p + c + f > 0) _showMacros = true;
    });
  }

  Future<void> _estimateFromText() async {
    final l10n = AppLocalizations.of(context);
    final text = _descCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.foodAiEmptyWarn)),
      );
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final r = await widget.aiService.estimateNutrition(
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

  Future<void> _pickAndRecognize(ImageSource src) async {
    final l10n = AppLocalizations.of(context);
    final picker = ImagePicker();
    final XFile? img;
    try {
      img = await picker.pickImage(source: src, imageQuality: 75);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorPickFailed(e.toString()))));
      return;
    }
    if (img == null) return;
    setState(() => _aiLoading = true);
    try {
      final bytes = await img.readAsBytes();
      final mime = img.mimeType ?? 'image/jpeg';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      final r = await widget.aiService.recognizeFood(
        imageUrl: dataUrl,
        locale: effectiveAiLocale(context),
      );
      _applyEstimate(r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorRecognitionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _pickImageSource() async {
    final l10n = AppLocalizations.of(context);
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.actionTakePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.actionChooseFromLibrary),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src != null) _pickAndRecognize(src);
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eatenAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eatenAt),
    );
    setState(() {
      _eatenAt = DateTime(date.year, date.month, date.day,
          time?.hour ?? _eatenAt.hour, time?.minute ?? _eatenAt.minute);
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    final cal = double.tryParse(_caloriesCtrl.text.trim()) ?? 0;
    if (name.isEmpty) return _warn(l10n.foodNameRequired);
    if (cal <= 0) return _warn(l10n.foodCaloriesRequired);

    setState(() => _submitting = true);
    try {
      final protein = double.tryParse(_proteinCtrl.text.trim()) ?? 0;
      final carbs = double.tryParse(_carbsCtrl.text.trim()) ?? 0;
      final fat = double.tryParse(_fatCtrl.text.trim()) ?? 0;
      final portion = double.tryParse(_portionCtrl.text.trim()) ?? 0;

      if (widget.prefill != null) {
        await widget.foodService.updateRecord(
          widget.prefill!.id,
          foodName: name,
          calories: cal,
          protein: protein,
          carbohydrates: carbs,
          fat: fat,
          mealType: _mealType,
          eatenAt: _eatenAt,
        );
      } else {
        await widget.foodService.createRecord(
          userId: widget.userId,
          foodName: name,
          calories: cal,
          protein: protein,
          carbohydrates: carbs,
          fat: fat,
          portion: portion,
          unit: _unit,
          mealType: _mealType,
          eatenAt: _eatenAt,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.prefill == null ? l10n.toastLogged : l10n.toastUpdated)));
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
        initialChildSize: 0.9,
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
              _sheetHandle(context),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: _buildSections(l10n),
                ),
              ),
              SafeArea(child: _submitBar(context, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetHandle(BuildContext ctx) => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        height: 4,
        width: 40,
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  List<Widget> _buildSections(AppLocalizations l10n) {
    final freq = widget.frequentFoods;
    return [
      Row(
        children: [
          Text(widget.prefill == null ? l10n.foodLogSheetTitle : l10n.foodEditSheetTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      const SizedBox(height: 8),

      _sectionTitle(l10n.foodSectionAiEstimate),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                hintText: l10n.foodAiHint,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _estimateFromText(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _aiLoading ? null : _estimateFromText,
            child: _aiLoading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.actionEstimate),
          ),
          VoiceInputButton(
            targetController: _descCtrl,
            onFinalized: _estimateFromText,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: l10n.actionRecognizeFromPhoto,
            onPressed: _aiLoading ? null : _pickImageSource,
          ),
        ],
      ),

      if (freq.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle(l10n.foodSectionFrequent),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final f in freq)
              ActionChip(
                label: Text(f),
                onPressed: () {
                  setState(() {
                    _nameCtrl.text = f;
                    _descCtrl.text = f;
                  });
                  _estimateFromText();
                },
              ),
          ],
        ),
      ],

      const SizedBox(height: 20),
      _sectionTitle(l10n.foodSectionDetails),

      TextField(
        controller: _nameCtrl,
        decoration: _deco(label: l10n.foodName),
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _caloriesCtrl,
              decoration: _deco(label: l10n.foodCalories),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _portionCtrl,
              decoration: _deco(label: l10n.foodPortion),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _unit,
            items: [
              DropdownMenuItem(value: 'g',       child: Text(l10n.foodUnitGram)),
              DropdownMenuItem(value: 'ml',      child: Text(l10n.foodUnitMl)),
              DropdownMenuItem(value: 'serving', child: Text(l10n.foodUnitServing)),
              DropdownMenuItem(value: 'piece',   child: Text(l10n.foodUnitPiece)),
            ],
            onChanged: (v) => setState(() => _unit = v ?? 'g'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _mealType,
              decoration: _deco(label: l10n.foodMeal),
              items: [
                DropdownMenuItem(value: 'breakfast', child: Text(l10n.mealBreakfast)),
                DropdownMenuItem(value: 'lunch',     child: Text(l10n.mealLunch)),
                DropdownMenuItem(value: 'dinner',    child: Text(l10n.mealDinner)),
                DropdownMenuItem(value: 'snack',     child: Text(l10n.mealSnack)),
              ],
              onChanged: (v) => setState(() => _mealType = v ?? 'breakfast'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text('${_eatenAt.month}/${_eatenAt.day} '
                  '${_eatenAt.hour.toString().padLeft(2, "0")}:'
                  '${_eatenAt.minute.toString().padLeft(2, "0")}'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      InkWell(
        onTap: () => setState(() => _showMacros = !_showMacros),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(_showMacros ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(l10n.foodMacrosOptional,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
      if (_showMacros) Row(
        children: [
          Expanded(
            child: TextField(
              controller: _proteinCtrl,
              decoration: _deco(label: l10n.foodProteinG),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _carbsCtrl,
              decoration: _deco(label: l10n.foodCarbsG),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _fatCtrl,
              decoration: _deco(label: l10n.foodFatG),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
      ),
    ];
  }

  InputDecoration _deco({required String label}) => InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
      );

  Widget _submitBar(BuildContext ctx, AppLocalizations l10n) {
    final scheme = Theme.of(ctx).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(l10n.actionSave),
        ),
      ),
    );
  }
}
