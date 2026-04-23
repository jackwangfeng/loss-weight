import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/user_profile.dart';
import '../providers/user_provider.dart';

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
    super.dispose();
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
