import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/food_service.dart';
import '../services/ai_service.dart';
import '../models/food_record.dart';

class FoodScreen extends StatefulWidget {
  /// 嵌入到 RecordsScreen 的 TabBar 里时，传 false 避免双 AppBar
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
    setState(() => _isLoading = true);
    try {
      final user = context.read<UserProvider>().currentUser;
      if (user != null) {
        _records = await _foodService.getRecords(userId: user.id);
      }
    } catch (e) {
      _toast('加载失败：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- 数据派生 ----

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

  /// 取最近 14 天内出现最多的食物名，用于"常吃"快选
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
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('饮食记录'),
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
        label: const Text('记录'),
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
        if (_records.isEmpty) _buildEmpty(),
        for (final day in orderedKeys) _DayGroup(
          day: day,
          records: groups[day]!,
          onTap: (r) => _openAddSheet(prefill: r),
        ),
      ],
    );
  }

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.restaurant, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('还没有饮食记录，点右下角开始',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );

  // ---- 添加/编辑底部表单 ----

  Future<void> _openAddSheet({FoodRecord? prefill}) async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      _toast('请先登录');
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

  /// 记录完食物，给个「剩余额度」的及时反馈
  void _showBudgetToast() {
    if (!mounted) return;
    final user = context.read<UserProvider>().currentUser;
    if (user == null || user.targetCalorie <= 0) return;
    final today = _todayRecords();
    final eaten = today.fold<double>(0, (s, r) => s + r.calories);
    final remaining = user.targetCalorie - eaten;
    final msg = remaining >= 0
        ? '今日已吃 ${eaten.toStringAsFixed(0)} kcal，剩余 ${remaining.toStringAsFixed(0)} kcal'
        : '今日已吃 ${eaten.toStringAsFixed(0)} kcal，超出 ${(-remaining).toStringAsFixed(0)} kcal';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }
}

// ============================================================================
//  今日热量汇总卡片
// ============================================================================

class _TodaySummary extends StatelessWidget {
  final List<FoodRecord> records;
  const _TodaySummary({required this.records});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final double cal = records.fold(0.0, (s, r) => s + r.calories);
    final double protein = records.fold(0.0, (s, r) => s + r.protein);
    final double carbs = records.fold(0.0, (s, r) => s + r.carbohydrates);
    final double fat = records.fold(0.0, (s, r) => s + r.fat);
    final double target = user?.targetCalorie ?? 2000.0;
    final double pct = target > 0 ? (cal / target).clamp(0.0, 1.2) : 0.0;
    final bool over = target > 0 && cal > target;
    final Color bar = over ? Colors.red : Colors.green;

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
                const Text('今日热量',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text('${records.length} 餐',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(cal.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: over ? Colors.red : Colors.black87,
                    )),
                Text(' / ${target.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct > 1.0 ? 1.0 : pct,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(bar),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _macroBadge('蛋白', protein, 'g', Colors.orange),
                _macroBadge('碳水', carbs, 'g', Colors.blue),
                _macroBadge('脂肪', fat, 'g', Colors.purple),
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
                color: c, fontSize: 16, fontWeight: FontWeight.w600)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// ============================================================================
//  按天分组的卡片
// ============================================================================

class _DayGroup extends StatelessWidget {
  final DateTime day;
  final List<FoodRecord> records;
  final void Function(FoodRecord)? onTap;
  const _DayGroup(
      {required this.day, required this.records, this.onTap});

  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '$diff 天前';
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final dayCal = records.fold<double>(0, (s, r) => s + r.calories);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Text(_label(day),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${dayCal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
        for (final r in records)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _mealColor(r.mealType),
                child: Icon(_mealIcon(r.mealType), color: Colors.white),
              ),
              title: Row(
                children: [
                  Flexible(child: Text(r.foodName,
                      overflow: TextOverflow.ellipsis)),
                  if (r.portionLabel.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('· ${r.portionLabel}',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13)),
                  ],
                ],
              ),
              subtitle: Text(
                  '${r.calories.toStringAsFixed(0)} kcal · ${r.mealTypeLabel}'
                  '${r.protein > 0 ? "  蛋白${r.protein.toStringAsFixed(0)}g" : ""}'),
              trailing: Text(
                  '${r.eatenAt.hour.toString().padLeft(2, '0')}:'
                  '${r.eatenAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey[600])),
              onTap: onTap == null ? null : () => onTap!(r),
            ),
          ),
      ],
    );
  }

  static Color _mealColor(String m) {
    switch (m) {
      case 'breakfast': return Colors.orange;
      case 'lunch':     return Colors.green;
      case 'dinner':    return Colors.blue;
      case 'snack':     return Colors.purple;
      default:          return Colors.grey;
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
//  添加/编辑 BottomSheet
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
    final text = _descCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先写一下吃了啥，例如 "一碗米饭 200g"')),
      );
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final r = await widget.aiService.estimateNutrition(text: text);
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

  Future<void> _pickAndRecognize(ImageSource src) async {
    final picker = ImagePicker();
    final XFile? img;
    try {
      img = await picker.pickImage(source: src, imageQuality: 75);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选图失败：$e')));
      return;
    }
    if (img == null) return;
    setState(() => _aiLoading = true);
    try {
      final bytes = await img.readAsBytes();
      final mime = img.mimeType ?? 'image/jpeg';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      final r = await widget.aiService.recognizeFood(imageUrl: dataUrl);
      _applyEstimate(r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _pickImageSource() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选'),
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
    final name = _nameCtrl.text.trim();
    final cal = double.tryParse(_caloriesCtrl.text.trim()) ?? 0;
    if (name.isEmpty) return _warn('请输入食物名');
    if (cal <= 0) return _warn('请输入热量');

    setState(() => _submitting = true);
    try {
      await widget.foodService.createRecord(
        userId: widget.userId,
        foodName: name,
        calories: cal,
        protein: double.tryParse(_proteinCtrl.text.trim()) ?? 0,
        carbohydrates: double.tryParse(_carbsCtrl.text.trim()) ?? 0,
        fat: double.tryParse(_fatCtrl.text.trim()) ?? 0,
        portion: double.tryParse(_portionCtrl.text.trim()) ?? 0,
        unit: _unit,
        mealType: _mealType,
        eatenAt: _eatenAt,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('记录成功')));
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
        initialChildSize: 0.9,
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
              _sheetHandle(),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: _buildSections(),
                ),
              ),
              SafeArea(child: _submitBar()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetHandle() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        height: 4,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      );

  List<Widget> _buildSections() {
    final freq = widget.frequentFoods;
    return [
      Row(
        children: [
          const Text('添加饮食记录',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      const SizedBox(height: 8),

      // --- AI 输入区 ---
      _sectionTitle('让 AI 帮你算'),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                hintText: '例：一碗米饭 200g、宫保鸡丁一份',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
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
                : const Text('估算'),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: '拍照识别',
            onPressed: _aiLoading ? null : _pickImageSource,
          ),
        ],
      ),

      // --- 常吃快选 ---
      if (freq.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('常吃'),
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
      _sectionTitle('详细信息'),

      TextField(
        controller: _nameCtrl,
        decoration: _deco(label: '食物名 *'),
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _caloriesCtrl,
              decoration: _deco(label: '热量 (kcal) *'),
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
              decoration: _deco(label: '份量'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _unit,
            items: const [
              DropdownMenuItem(value: 'g',  child: Text('克')),
              DropdownMenuItem(value: 'ml', child: Text('毫升')),
              DropdownMenuItem(value: '份', child: Text('份')),
              DropdownMenuItem(value: '个', child: Text('个')),
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
              decoration: _deco(label: '餐次'),
              items: const [
                DropdownMenuItem(value: 'breakfast', child: Text('早餐')),
                DropdownMenuItem(value: 'lunch',     child: Text('午餐')),
                DropdownMenuItem(value: 'dinner',    child: Text('晚餐')),
                DropdownMenuItem(value: 'snack',     child: Text('加餐')),
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

      // 展开/收起营养素详情
      InkWell(
        onTap: () => setState(() => _showMacros = !_showMacros),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(_showMacros ? Icons.expand_less : Icons.expand_more,
                  size: 20, color: Colors.grey[700]),
              const SizedBox(width: 4),
              Text('营养素（可选）',
                  style: TextStyle(color: Colors.grey[700])),
            ],
          ),
        ),
      ),
      if (_showMacros) Row(
        children: [
          Expanded(
            child: TextField(
              controller: _proteinCtrl,
              decoration: _deco(label: '蛋白(g)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _carbsCtrl,
              decoration: _deco(label: '碳水(g)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _fatCtrl,
              decoration: _deco(label: '脂肪(g)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
      ),
    ];
  }

  InputDecoration _deco({required String label}) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
      );

  Widget _submitBar() => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
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
                : const Text('保存'),
          ),
        ),
      );
}

