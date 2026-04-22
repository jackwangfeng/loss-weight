import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/generated/app_localizations.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.toastPleaseSignIn)),
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
          SnackBar(content: Text(l10n.errorLoadFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.weightTitle),
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
                      Icon(Icons.monitor_weight,
                          size: 80, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 24),
                      Text(
                        l10n.weightEmpty,
                        style: TextStyle(
                          fontSize: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddWeightDialog(),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.actionAdd),
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
                        _buildTrendChart(l10n),
                        _buildRecordsList(l10n),
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

  Widget _buildTrendChart(AppLocalizations l10n) {
    if (_records.length < 2) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final lineColor = scheme.primary;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.weightTrendSection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.outlineVariant,
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 10, color: scheme.onSurfaceVariant),
                        ),
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
                              style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant),
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
                      color: lineColor,
                      barWidth: 2.5,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  l10n.weightStatLow,
                  '${_records.map((r) => r.weight).reduce((a, b) => a < b ? a : b).toStringAsFixed(1)} kg',
                  Icons.arrow_downward,
                  const Color(0xFF64B871),
                ),
                _buildStatItem(
                  l10n.weightStatHigh,
                  '${_records.map((r) => r.weight).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} kg',
                  Icons.arrow_upward,
                  scheme.error,
                ),
                _buildStatItem(
                  l10n.weightStatChange,
                  '${(_records.last.weight - _records.first.weight).toStringAsFixed(1)} kg',
                  _records.last.weight < _records.first.weight
                      ? Icons.trending_down
                      : Icons.trending_up,
                  _records.last.weight < _records.first.weight
                      ? const Color(0xFF64B871)
                      : const Color(0xFFE38B2A),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildRecordsList(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.weightHistorySection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _records.length,
            itemBuilder: (context, index) {
              final record = _records[index];
              return Dismissible(
                key: ValueKey('weight-${record.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmAndDelete(record),
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
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF5B9BD5).withValues(alpha: 0.18),
                      child: const Icon(Icons.monitor_weight,
                          color: Color(0xFF5B9BD5)),
                    ),
                    title: Text('${record.weight.toStringAsFixed(1)} kg'),
                    subtitle: Text(
                      '${record.measuredAt.year}-${record.measuredAt.month.toString().padLeft(2, '0')}-${record.measuredAt.day.toString().padLeft(2, '0')}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    trailing: record.note.isNotEmpty
                        ? Text(
                            record.note,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          )
                        : null,
                    onTap: () => _showEditWeightDialog(record),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddWeightDialog() async {
    final l10n = AppLocalizations.of(context);
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.toastPleaseSignIn)),
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

  Future<void> _showEditWeightDialog(WeightRecord record) async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddWeightSheet(
        userId: user.id,
        weightService: _weightService,
        aiService: _aiService,
        prefill: record,
      ),
    );
    if (updated == true) _loadRecords();
  }

  Future<bool> _confirmAndDelete(WeightRecord r) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.weightDeleteTitle),
        content: Text('${r.weight.toStringAsFixed(1)} kg · '
            '${r.measuredAt.year}-${r.measuredAt.month.toString().padLeft(2, "0")}-${r.measuredAt.day.toString().padLeft(2, "0")}'),
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
      await _weightService.deleteRecord(r.id);
      await _loadRecords();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorDeleteFailed(e.toString()))),
        );
      }
      return false;
    }
  }
}

// ============================================================================
//  Add/Edit BottomSheet
// ============================================================================

class _AddWeightSheet extends StatefulWidget {
  final int userId;
  final WeightService weightService;
  final AIService aiService;
  final WeightRecord? prefill;
  const _AddWeightSheet({
    required this.userId,
    required this.weightService,
    required this.aiService,
    this.prefill,
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
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _weightCtrl.text = p.weight.toStringAsFixed(1);
      if (p.bodyFat > 0) _bodyFatCtrl.text = p.bodyFat.toStringAsFixed(1);
      if (p.muscle > 0) _muscleCtrl.text = p.muscle.toStringAsFixed(1);
      if (p.water > 0) _waterCtrl.text = p.water.toStringAsFixed(1);
      _noteCtrl.text = p.note;
      _measuredAt = p.measuredAt;
      if (p.bodyFat > 0 || p.muscle > 0 || p.water > 0 || p.note.isNotEmpty) {
        _showMore = true;
      }
    }
  }

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
    final l10n = AppLocalizations.of(context);
    final text = _descCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.weightAiEmptyWarn)),
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
          SnackBar(content: Text(l10n.errorParseFailed(e.toString()))),
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
    final l10n = AppLocalizations.of(context);
    final w = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    if (w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.weightValueRequired)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final bodyFat = double.tryParse(_bodyFatCtrl.text.trim()) ?? 0;
      final muscle = double.tryParse(_muscleCtrl.text.trim()) ?? 0;
      final water = double.tryParse(_waterCtrl.text.trim()) ?? 0;
      final note = _noteCtrl.text.trim();

      if (widget.prefill != null) {
        await widget.weightService.updateRecord(
          id: widget.prefill!.id,
          weight: w,
          bodyFat: bodyFat,
          muscle: muscle,
          water: water,
          note: note,
          measuredAt: _measuredAt,
        );
      } else {
        await widget.weightService.createRecord(
          userId: widget.userId,
          weight: w,
          bodyFat: bodyFat,
          muscle: muscle,
          water: water,
          note: note,
          measuredAt: _measuredAt,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.prefill == null ? l10n.toastLogged : l10n.toastUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSaveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
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
    final scheme = Theme.of(context).colorScheme;
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final decimalKb = const TextInputType.numberWithOptions(decimal: true);

    return [
      Row(children: [
        Text(widget.prefill == null ? l10n.weightLogSheetTitle : l10n.weightEditSheetTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ]),
      const SizedBox(height: 8),

      _sectionTitle(l10n.foodSectionAiEstimate, scheme),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: TextField(
          controller: _descCtrl,
          decoration: InputDecoration(
            hintText: l10n.weightAiHint,
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
              : Text(l10n.actionParse),
        ),
        VoiceInputButton(
          targetController: _descCtrl,
          onFinalized: _aiParse,
        ),
      ]),

      const SizedBox(height: 20),
      _sectionTitle(l10n.foodSectionDetails, scheme),
      const SizedBox(height: 4),
      TextField(
        controller: _weightCtrl,
        decoration: deco(l10n.weightValueKg),
        keyboardType: decimalKb,
        inputFormatters: numFmt,
      ),
      const SizedBox(height: 12),

      OutlinedButton.icon(
        onPressed: _pickDate,
        icon: const Icon(Icons.calendar_today),
        label: Text(l10n.weightMeasuredOn(
            '${_measuredAt.year}-${_measuredAt.month.toString().padLeft(2, "0")}-${_measuredAt.day.toString().padLeft(2, "0")}')),
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
                  size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(l10n.weightMoreLabel,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
      if (_showMore) ...[
        Row(children: [
          Expanded(child: TextField(
            controller: _bodyFatCtrl,
            decoration: deco(l10n.weightBodyFatPct),
            keyboardType: decimalKb,
            inputFormatters: numFmt,
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _muscleCtrl,
            decoration: deco(l10n.weightMuscleKg),
            keyboardType: decimalKb,
            inputFormatters: numFmt,
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _waterCtrl,
            decoration: deco(l10n.weightWaterPct),
            keyboardType: decimalKb,
            inputFormatters: numFmt,
          )),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: deco(l10n.weightNote),
        ),
      ],
    ];
  }

  Widget _sectionTitle(String t, ColorScheme scheme) => Text(t,
      style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600));
}
