import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/user_provider.dart';
import '../services/weight_service.dart';
import '../services/ai_service.dart';
import '../models/weight_record.dart';
import '../widgets/voice_input_button.dart';

class WeightScreen extends StatefulWidget {
  final bool showAppBar;
  const WeightScreen({Key? key, this.showAppBar = true}) : super(key: key);

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final WeightService _weightService = WeightService();
  final AIService _aiService = AIService();
  List<WeightRecord> _records = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先登录')),
          );
        }
        return;
      }
      _records = await _weightService.getRecords(
        userId: userProvider.currentUser!.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：$e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('体重记录'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadRecords,
                ),
              ],
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monitor_weight, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 24),
                      Text(
                        '暂无体重记录',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddWeightDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('添加记录'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecords,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // 体重趋势图表
                        _buildTrendChart(),
                        // 记录列表
                        _buildRecordsList(),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'weight_fab',
        onPressed: () => _showAddWeightDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_records.length < 2) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '体重趋势',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _records.length) {
                            final record = _records[index];
                            return Text(
                              '${record.measuredAt.month}/${record.measuredAt.day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _records.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.weight,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 统计信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  '最低',
                  '${_records.map((r) => r.weight).reduce((a, b) => a < b ? a : b).toStringAsFixed(1)} kg',
                  Icons.arrow_downward,
                  Colors.green,
                ),
                _buildStatItem(
                  '最高',
                  '${_records.map((r) => r.weight).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} kg',
                  Icons.arrow_upward,
                  Colors.red,
                ),
                _buildStatItem(
                  '变化',
                  '${(_records.last.weight - _records.first.weight).toStringAsFixed(1)} kg',
                  _records.last.weight < _records.first.weight
                      ? Icons.trending_down
                      : Icons.trending_up,
                  _records.last.weight < _records.first.weight
                      ? Colors.green
                      : Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecordsList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '历史记录',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _records.length,
            itemBuilder: (context, index) {
              final record = _records[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Icon(Icons.monitor_weight, color: Colors.blue[800]),
                  ),
                  title: Text('${record.weight.toStringAsFixed(1)} kg'),
                  subtitle: Text(
                    '${record.measuredAt.year}-${record.measuredAt.month.toString().padLeft(2, '0')}-${record.measuredAt.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: record.note.isNotEmpty
                      ? Text(
                          record.note,
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      : null,
                  onTap: () => _showEditWeightDialog(record),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddWeightDialog() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddWeightSheet(
        userId: user.id,
        weightService: _weightService,
        aiService: _aiService,
      ),
    );
    if (created == true) _loadRecords();
  }

  void _showEditWeightDialog(WeightRecord record) {
    final formKey = GlobalKey<FormState>();
    double weight = record.weight;
    double bodyFat = record.bodyFat;
    double muscle = record.muscle;
    double water = record.water;
    String note = record.note;
    DateTime selectedDate = record.measuredAt;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑体重记录'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: weight.toString(),
                  decoration: const InputDecoration(
                    labelText: '体重 (kg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monitor_weight),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入体重';
                    }
                    return null;
                  },
                  onSaved: (value) => weight = double.parse(value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: bodyFat.toString(),
                  decoration: const InputDecoration(
                    labelText: '体脂率 (%)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pie_chart),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSaved: (value) => bodyFat = double.parse(value ?? '0'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: muscle.toString(),
                  decoration: const InputDecoration(
                    labelText: '肌肉量 (kg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fitness_center),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSaved: (value) => muscle = double.parse(value ?? '0'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: water.toString(),
                  decoration: const InputDecoration(
                    labelText: '水分 (%)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.water),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSaved: (value) => water = double.parse(value ?? '0'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: note,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                  onSaved: (value) => note = value ?? '',
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('测量日期'),
                  subtitle: Text(
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();

                try {
                  await _weightService.updateRecord(
                    id: record.id,
                    weight: weight,
                    bodyFat: bodyFat,
                    muscle: muscle,
                    water: water,
                    note: note,
                    measuredAt: selectedDate,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _loadRecords();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('更新成功')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('更新失败：$e')),
                    );
                  }
                }
              }
            },
            child: const Text('更新'),
          ),
          IconButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认删除'),
                  content: const Text('确定要删除这条记录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                try {
                  await _weightService.deleteRecord(record.id);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadRecords();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('删除成功')),
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
            },
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  添加体重 BottomSheet（支持 AI 文本解析）
// ============================================================================

class _AddWeightSheet extends StatefulWidget {
  final int userId;
  final WeightService weightService;
  final AIService aiService;
  const _AddWeightSheet({
    required this.userId,
    required this.weightService,
    required this.aiService,
  });

  @override
  State<_AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends State<_AddWeightSheet> {
  final _descCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();
  final _muscleCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _measuredAt = DateTime.now();
  bool _aiLoading = false;
  bool _submitting = false;
  bool _showMore = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _weightCtrl.dispose();
    _bodyFatCtrl.dispose();
    _muscleCtrl.dispose();
    _waterCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> r) {
    setState(() {
      final w = (r['weight'] as num?)?.toDouble() ?? 0;
      if (w > 0) _weightCtrl.text = w.toStringAsFixed(1);
      final bf = (r['body_fat'] as num?)?.toDouble() ?? 0;
      if (bf > 0) _bodyFatCtrl.text = bf.toStringAsFixed(1);
      final m = (r['muscle'] as num?)?.toDouble() ?? 0;
      if (m > 0) _muscleCtrl.text = m.toStringAsFixed(1);
      final wt = (r['water'] as num?)?.toDouble() ?? 0;
      if (wt > 0) _waterCtrl.text = wt.toStringAsFixed(1);
      final note = (r['note'] ?? '').toString();
      if (note.isNotEmpty) _noteCtrl.text = note;
      if (bf + m + wt > 0 || note.isNotEmpty) _showMore = true;
    });
  }

  Future<void> _aiParse() async {
    final text = _descCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('随便写，比如 "68.5kg 早"、"67 体脂22"')),
      );
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final r = await widget.aiService.parseWeight(text: text);
      _apply(r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _measuredAt = d);
  }

  Future<void> _submit() async {
    final w = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    if (w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入体重（或让 AI 帮你解析）')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.weightService.createRecord(
        userId: widget.userId,
        weight: w,
        bodyFat: double.tryParse(_bodyFatCtrl.text.trim()) ?? 0,
        muscle: double.tryParse(_muscleCtrl.text.trim()) ?? 0,
        water: double.tryParse(_waterCtrl.text.trim()) ?? 0,
        note: _noteCtrl.text.trim(),
        measuredAt: _measuredAt,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('体重已记录')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final decimalKb = const TextInputType.numberWithOptions(decimal: true);

    return [
      Row(children: [
        const Text('添加体重记录',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
            hintText: '例：68.5kg 早、67 体脂22%',
            filled: true, fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _aiParse(),
        )),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: _aiLoading ? null : _aiParse,
          child: _aiLoading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('解析'),
        ),
        VoiceInputButton(
          targetController: _descCtrl,
          onFinalized: _aiParse,
        ),
      ]),

      const SizedBox(height: 20),
      Text('详细信息',
          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(
        controller: _weightCtrl,
        decoration: deco('体重 (kg) *'),
        keyboardType: decimalKb,
        inputFormatters: numFmt,
      ),
      const SizedBox(height: 12),

      OutlinedButton.icon(
        onPressed: _pickDate,
        icon: const Icon(Icons.calendar_today),
        label: Text('测量日期：${_measuredAt.year}-'
            '${_measuredAt.month.toString().padLeft(2, "0")}-'
            '${_measuredAt.day.toString().padLeft(2, "0")}'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      const SizedBox(height: 12),

      InkWell(
        onTap: () => setState(() => _showMore = !_showMore),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(_showMore ? Icons.expand_less : Icons.expand_more,
                  size: 20, color: Colors.grey[700]),
              const SizedBox(width: 4),
              Text('更多（体脂 / 肌肉 / 水分 / 备注，可选）',
                  style: TextStyle(color: Colors.grey[700])),
            ],
          ),
        ),
      ),
      if (_showMore) ...[
        Row(children: [
          Expanded(child: TextField(
            controller: _bodyFatCtrl,
            decoration: deco('体脂率 (%)'),
            keyboardType: decimalKb,
            inputFormatters: numFmt,
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _muscleCtrl,
            decoration: deco('肌肉 (kg)'),
            keyboardType: decimalKb,
            inputFormatters: numFmt,
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _waterCtrl,
            decoration: deco('水分 (%)'),
            keyboardType: decimalKb,
            inputFormatters: numFmt,
          )),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: deco('备注'),
        ),
      ],
    ];
  }
}
