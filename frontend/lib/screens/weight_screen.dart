import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/user_provider.dart';
import '../services/weight_service.dart';
import '../models/weight_record.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({Key? key}) : super(key: key);

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final WeightService _weightService = WeightService();
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
      appBar: AppBar(
        title: const Text('体重记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
          ),
        ],
      ),
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

  void _showAddWeightDialog() {
    final formKey = GlobalKey<FormState>();
    double weight = 0;
    double bodyFat = 0;
    double muscle = 0;
    double water = 0;
    String note = '';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加体重记录'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
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
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  if (userProvider.currentUser != null) {
                    await _weightService.createRecord(
                      userId: userProvider.currentUser!.id,
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
                        const SnackBar(content: Text('添加成功')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('添加失败：$e')),
                    );
                  }
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
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
