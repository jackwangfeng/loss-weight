import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';
import '../models/user_profile.dart';
import '../services/ai_service.dart';
import '../utils/labels.dart';
import '../widgets/voice_input_button.dart';
import 'feedback_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final isLoggedIn = authProvider.isLoggedIn;
    final user = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: l10n.actionSignOut,
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  userProvider.clearUser();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.toastSignedOut)),
                  );
                }
              },
            ),
        ],
      ),
      body: !isLoggedIn ? _buildLoggedOut(context) : _buildProfile(context, user),
    );
  }

  Widget _buildLoggedOut(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 80),
          const SizedBox(height: 24),
          Text(l10n.profileNotSignedIn, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
              if (result == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.toastWelcomeBack)),
                );
              }
            },
            icon: const Icon(Icons.login),
            label: Text(l10n.actionSignInSignUp),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(BuildContext context, UserProfile? user) {
    final l10n = AppLocalizations.of(context);
    final nickname = (user?.nickname ?? '').trim();
    final initial = nickname.isEmpty ? 'U' : nickname.characters.first.toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(user: user, initial: initial),
        const SizedBox(height: 16),
        _StatsRow(user: user),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _InfoTile(label: l10n.profileHeight, value: user == null || user.height <= 0 ? '—' : '${user.height.toStringAsFixed(0)} cm'),
              _divider(),
              _InfoTile(label: l10n.profileSex, value: genderLabel(l10n, user?.gender)),
              _divider(),
              _InfoTile(label: l10n.profileBirthday, value: user?.birthday == null
                  ? '—'
                  : '${user!.birthday!.year}-${user.birthday!.month.toString().padLeft(2, '0')}-${user.birthday!.day.toString().padLeft(2, '0')}'),
              _divider(),
              _InfoTile(label: l10n.profileActivity, value: activityLevelLabel(l10n, user?.activityLevel ?? 1)),
              _divider(),
              _InfoTile(label: l10n.profileDailyCalorieTarget, value: user == null || user.targetCalorie <= 0
                  ? '—'
                  : '${user.targetCalorie.toStringAsFixed(0)} kcal'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(l10n.profileSettings),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: Text(l10n.profileFeedback),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: user == null ? null : () => _openEdit(context, user),
            icon: const Icon(Icons.edit),
            label: Text(l10n.actionEdit),
          ),
        ),
      ],
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Future<void> _openEdit(BuildContext context, UserProfile user) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(initial: user),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UserProfile? user;
  final String initial;
  const _HeaderCard({required this.user, required this.initial});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: scheme.surfaceContainerHighest,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 32,
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              (user?.nickname.trim().isNotEmpty ?? false) ? user!.nickname : l10n.profileNoNickname,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text('ID: ${authProvider.userId ?? '-'}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final UserProfile? user;
  const _StatsRow({required this.user});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final u = user;
    String kg(double v) => v <= 0 ? '—' : v.toStringAsFixed(1);
    final bmi = u == null || u.bmi <= 0 ? '—' : u.bmi.toStringAsFixed(1);
    return Row(
      children: [
        Expanded(child: _statCard(context, l10n.profileWeight, u == null ? '—' : kg(u.currentWeight), 'kg')),
        const SizedBox(width: 8),
        Expanded(child: _statCard(context, l10n.profileTarget, u == null ? '—' : kg(u.targetWeight), 'kg')),
        const SizedBox(width: 8),
        Expanded(child: _statCard(context, l10n.profileBmi, bmi, '')),
      ],
    );
  }

  Widget _statCard(BuildContext ctx, String label, String value, String unit) {
    final scheme = Theme.of(ctx).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 6),
            RichText(text: TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 20, color: scheme.onSurface, fontWeight: FontWeight.w600,
              ),
              children: [
                if (unit.isNotEmpty)
                  TextSpan(text: ' $unit',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            )),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        trailing: Text(value,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 15)),
      );
}

// ============================================================================
//  Edit profile BottomSheet
// ============================================================================

class _EditProfileSheet extends StatefulWidget {
  final UserProfile initial;
  const _EditProfileSheet({required this.initial});
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nick;
  late final TextEditingController _height;
  late final TextEditingController _curWeight;
  late final TextEditingController _tgtWeight;
  late final TextEditingController _tgtCal;
  late final TextEditingController _tgtProtein;
  late final TextEditingController _tgtCarbs;
  late final TextEditingController _tgtFat;
  late String _gender;
  DateTime? _birthday;
  late int _activityLevel;
  bool _submitting = false;

  // AI 一句话入口：跟 quick_setup 一致的 UX，调 /ai/parse-profile
  // 结构化返回 → 覆盖当前**空**的字段（已手动填的不覆盖）。
  final TextEditingController _aiInput = TextEditingController();
  final AIService _ai = AIService();
  bool _aiParsing = false;

  @override
  void initState() {
    super.initState();
    final u = widget.initial;
    _nick = TextEditingController(text: u.nickname);
    _height = TextEditingController(text: u.height > 0 ? u.height.toStringAsFixed(0) : '');
    _curWeight = TextEditingController(text: u.currentWeight > 0 ? u.currentWeight.toStringAsFixed(1) : '');
    _tgtWeight = TextEditingController(text: u.targetWeight > 0 ? u.targetWeight.toStringAsFixed(1) : '');
    _tgtCal = TextEditingController(text: u.targetCalorie > 0 ? u.targetCalorie.toStringAsFixed(0) : '');
    _tgtProtein = TextEditingController(text: u.targetProteinG > 0 ? u.targetProteinG.toStringAsFixed(0) : '');
    _tgtCarbs = TextEditingController(text: u.targetCarbsG > 0 ? u.targetCarbsG.toStringAsFixed(0) : '');
    _tgtFat = TextEditingController(text: u.targetFatG > 0 ? u.targetFatG.toStringAsFixed(0) : '');
    _gender = u.gender.isEmpty ? 'male' : u.gender;
    _birthday = u.birthday;
    _activityLevel = u.activityLevel == 0 ? 1 : u.activityLevel;
  }

  @override
  void dispose() {
    _nick.dispose();
    _height.dispose();
    _curWeight.dispose();
    _tgtWeight.dispose();
    _tgtCal.dispose();
    _tgtProtein.dispose();
    _tgtCarbs.dispose();
    _tgtFat.dispose();
    _aiInput.dispose();
    super.dispose();
  }

  /// 应用 parse-profile / transcribe-and-parse-profile 的结构化结果到表单。
  /// 零值字段（AI 认为没提到的）不覆盖；非零字段一律覆盖。
  void _applyParsed(Map<String, dynamic> res) {
    final g = (res['gender'] as String?) ?? '';
    final age = (res['age'] as num?)?.toInt() ?? 0;
    final h = (res['height'] as num?)?.toDouble() ?? 0;
    final cw = (res['current_weight'] as num?)?.toDouble() ?? 0;
    final tw = (res['target_weight'] as num?)?.toDouble() ?? 0;
    final al = (res['activity_level'] as num?)?.toInt() ?? 0;
    if (!mounted) return;
    setState(() {
      if (g == 'male' || g == 'female') _gender = g;
      if (age > 0) _birthday = DateTime(DateTime.now().year - age, 1, 1);
      if (h > 0) _height.text = h.toStringAsFixed(0);
      if (cw > 0) _curWeight.text = cw.toStringAsFixed(1);
      if (tw > 0) _tgtWeight.text = tw.toStringAsFixed(1);
      if (al >= 1 && al <= 5) _activityLevel = al;
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
    final init = _birthday ?? DateTime(1990, 1, 1);
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _birthday = d);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _submitting = true);
    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.updateUserProfile(
        nickname: _nick.text.trim(),
        gender: _gender,
        birthday: _birthday,
        height: double.tryParse(_height.text.trim()),
        currentWeight: double.tryParse(_curWeight.text.trim()),
        targetWeight: double.tryParse(_tgtWeight.text.trim()),
        activityLevel: _activityLevel,
        targetCalorie: double.tryParse(_tgtCal.text.trim()),
        targetProteinG: double.tryParse(_tgtProtein.text.trim()),
        targetCarbsG: double.tryParse(_tgtCarbs.text.trim()),
        targetFatG: double.tryParse(_tgtFat.text.trim()),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.toastProfileUpdated)),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final decimalKb = const TextInputType.numberWithOptions(decimal: true);

    return [
      Row(
        children: [
          Text(l10n.actionEdit,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      const SizedBox(height: 8),

      // AI 一句话入口——覆盖空字段的性别 / 年龄 / 身高 / 体重 / 活动水平。
      TextField(
        controller: _aiInput,
        maxLines: 2,
        decoration: deco(l10n.quickSetupAiHint),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          VoiceInputButton(
            targetController: _aiInput,
            onProfileParsed: _applyParsed,
            localeId:
                effectiveAiLocale(context) == 'zh' ? 'zh-CN' : 'en-US',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _aiParsing ? null : _aiParse,
              icon: _aiParsing
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(l10n.quickSetupAiParse),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Divider(height: 1),
      const SizedBox(height: 16),

      TextField(controller: _nick, decoration: deco(l10n.profileNickname)),
      const SizedBox(height: 12),

      Row(
        children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: deco(l10n.profileSex),
            items: [
              DropdownMenuItem(value: 'male',   child: Text(l10n.sexMale)),
              DropdownMenuItem(value: 'female', child: Text(l10n.sexFemale)),
              DropdownMenuItem(value: 'other',  child: Text(l10n.sexOther)),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'male'),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            onPressed: _pickBirthday,
            icon: const Icon(Icons.cake_outlined),
            label: Text(_birthday == null
                ? l10n.profileBirthday
                : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, "0")}-${_birthday!.day.toString().padLeft(2, "0")}'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
        ],
      ),
      const SizedBox(height: 12),

      TextField(
        controller: _height,
        decoration: deco(l10n.profileHeightCm),
        keyboardType: decimalKb,
        inputFormatters: numFmt,
      ),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: TextField(
          controller: _curWeight,
          decoration: deco(l10n.profileWeightKg),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
        const SizedBox(width: 12),
        Expanded(child: TextField(
          controller: _tgtWeight,
          decoration: deco(l10n.profileTargetKg),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
      ]),
      const SizedBox(height: 12),

      DropdownButtonFormField<int>(
        initialValue: _activityLevel,
        decoration: deco(l10n.profileActivityLevel),
        items: [
          DropdownMenuItem(value: 1, child: Text(l10n.activitySedentary)),
          DropdownMenuItem(value: 2, child: Text(l10n.activityLight)),
          DropdownMenuItem(value: 3, child: Text(l10n.activityModerate)),
          DropdownMenuItem(value: 4, child: Text(l10n.activityHigh)),
          DropdownMenuItem(value: 5, child: Text(l10n.activityVeryHigh)),
        ],
        onChanged: (v) => setState(() => _activityLevel = v ?? 1),
      ),
      const SizedBox(height: 12),

      TextField(
        controller: _tgtCal,
        decoration: deco(l10n.profileDailyCalorieTargetKcal),
        keyboardType: decimalKb,
        inputFormatters: numFmt,
      ),
      const SizedBox(height: 8),
      Text(l10n.profileTargetHint,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),

      const SizedBox(height: 20),
      Text(
        l10n.profileMacroSection.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(
          controller: _tgtProtein,
          decoration: deco(l10n.foodProteinG),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: _tgtCarbs,
          decoration: deco(l10n.foodCarbsG),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: _tgtFat,
          decoration: deco(l10n.foodFatG),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
      ]),
      const SizedBox(height: 8),
      Text(l10n.profileMacroHint,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ];
  }
}
