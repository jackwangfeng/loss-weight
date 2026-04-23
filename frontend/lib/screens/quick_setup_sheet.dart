import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/user_profile.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';
import '../services/ai_service.dart';
import '../widgets/voice_input_button.dart';

/// 5 个字段的轻量 onboarding：性别 / 生日 / 身高 / 当前体重 / 目标体重。
/// 目的：让新用户 30 秒内给出一套"够用"的 profile 数据，把默认的 70kg /
/// 65kg / 2000kcal 替换成可信的基线。剩下的高级字段（活动水平、详细宏量
/// 目标等）由 profile_screen 的 _EditProfileSheet 负责。
///
/// 点外面 / 点关闭 → 直接 pop，不保存；点"保存" → 写 DB 后 pop 并返 true
/// 给调用方，调用方负责隐藏触发这个 sheet 的 banner。
class QuickSetupSheet extends StatefulWidget {
  final UserProfile initial;
  const QuickSetupSheet({Key? key, required this.initial}) : super(key: key);

  static Future<bool?> show(BuildContext context, UserProfile initial) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickSetupSheet(initial: initial),
    );
  }

  @override
  State<QuickSetupSheet> createState() => _QuickSetupSheetState();
}

class _QuickSetupSheetState extends State<QuickSetupSheet> {
  late final TextEditingController _height;
  late final TextEditingController _curWeight;
  late final TextEditingController _tgtWeight;
  late String _gender;
  DateTime? _birthday;
  bool _submitting = false;

  // "一句话"AI 入口：文本 + 语音都灌这个 controller，点按钮发给 backend
  // 的 /ai/parse-profile，返回的字段只覆盖当前**未填**的那几个。
  final TextEditingController _aiInput = TextEditingController();
  final AIService _ai = AIService();
  bool _aiParsing = false;

  @override
  void initState() {
    super.initState();
    final u = widget.initial;
    _height = TextEditingController(
        text: u.height > 0 ? u.height.toStringAsFixed(0) : '');
    _curWeight = TextEditingController(
        text: u.currentWeight > 0 ? u.currentWeight.toStringAsFixed(1) : '');
    _tgtWeight = TextEditingController(
        text: u.targetWeight > 0 ? u.targetWeight.toStringAsFixed(1) : '');
    _gender = u.gender.isEmpty ? 'male' : u.gender;
    _birthday = u.birthday;
  }

  @override
  void dispose() {
    _height.dispose();
    _curWeight.dispose();
    _tgtWeight.dispose();
    _aiInput.dispose();
    super.dispose();
  }

  /// 应用 parse-profile / transcribe-and-parse-profile 的结构化结果到表单。
  /// 零值字段（AI 认为没提到的）不覆盖；非零字段一律覆盖默认占位。
  void _applyParsed(Map<String, dynamic> res) {
    final g = (res['gender'] as String?) ?? '';
    final age = (res['age'] as num?)?.toInt() ?? 0;
    final h = (res['height'] as num?)?.toDouble() ?? 0;
    final cw = (res['current_weight'] as num?)?.toDouble() ?? 0;
    final tw = (res['target_weight'] as num?)?.toDouble() ?? 0;
    if (!mounted) return;
    setState(() {
      if (g == 'male' || g == 'female') _gender = g;
      if (age > 0) _birthday = DateTime(DateTime.now().year - age, 1, 1);
      if (h > 0) _height.text = h.toStringAsFixed(0);
      if (cw > 0) _curWeight.text = cw.toStringAsFixed(1);
      if (tw > 0) _tgtWeight.text = tw.toStringAsFixed(1);
    });
  }

  Future<void> _aiParse() async {
    final text = _aiInput.text.trim();
    final l10n = AppLocalizations.of(context);
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quickSetupAiEmpty)),
      );
      return;
    }
    setState(() => _aiParsing = true);
    try {
      final res = await _ai.parseProfile(
        text: text,
        locale: effectiveAiLocale(context),
      );
      if (!mounted) return;
      _applyParsed(res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.quickSetupAiFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _aiParsing = false);
    }
  }

  Future<void> _pickBirthday() async {
    final init = _birthday ?? DateTime(1995, 1, 1);
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _birthday = d);
  }

  Future<void> _save() async {
    setState(() => _submitting = true);
    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.updateUserProfile(
        gender: _gender,
        birthday: _birthday,
        height: double.tryParse(_height.text.trim()),
        currentWeight: double.tryParse(_curWeight.text.trim()),
        targetWeight: double.tryParse(_tgtWeight.text.trim()),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSaveFailed(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                height: 4, width: 40,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.quickSetupTitle,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  l10n.quickSetupSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    // AI 一句话入口
                    TextField(
                      controller: _aiInput,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: l10n.quickSetupAiHint,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        VoiceInputButton(
                          targetController: _aiInput,
                          onProfileParsed: _applyParsed,
                          localeId: effectiveAiLocale(context) == 'zh'
                              ? 'zh-CN' : 'en-US',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _aiParsing ? null : _aiParse,
                            icon: _aiParsing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome, size: 18),
                            label: Text(l10n.quickSetupAiParse),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: scheme.outlineVariant, height: 1),
                    ),
                    _genderRow(l10n, scheme),
                    const SizedBox(height: 12),
                    _birthdayRow(l10n, scheme),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _height,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.profileHeight,
                        suffixText: 'cm',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _curWeight,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.profileWeight,
                        suffixText: 'kg',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tgtWeight,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.profileTarget,
                        suffixText: 'kg',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _submitting ? null : _save,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.quickSetupSave),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genderRow(AppLocalizations l10n, ColorScheme scheme) {
    return Row(
      children: [
        Text(l10n.profileSex,
            style: TextStyle(color: scheme.onSurfaceVariant)),
        const Spacer(),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'male', label: Text(l10n.sexMale)),
            ButtonSegment(value: 'female', label: Text(l10n.sexFemale)),
          ],
          selected: {_gender},
          onSelectionChanged: (s) => setState(() => _gender = s.first),
          showSelectedIcon: false,
        ),
      ],
    );
  }

  Widget _birthdayRow(AppLocalizations l10n, ColorScheme scheme) {
    final label = _birthday == null
        ? '—'
        : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: _pickBirthday,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            Text(l10n.profileBirthday,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const Spacer(),
            Text(label, style: TextStyle(color: scheme.onSurface)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
