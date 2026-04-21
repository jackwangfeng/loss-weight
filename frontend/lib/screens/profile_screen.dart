import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../models/user_profile.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final isLoggedIn = authProvider.isLoggedIn;
    final user = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: '退出登录',
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  userProvider.clearUser();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已退出登录')),
                  );
                }
              },
            ),
        ],
      ),
      body: !isLoggedIn ? _buildLoggedOut(context) : _buildProfile(context, user),
    );
  }

  Widget _buildLoggedOut(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text('未登录', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('欢迎回来！')),
                  );
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('登录/注册'),
            ),
          ],
        ),
      );

  Widget _buildProfile(BuildContext context, UserProfile? user) {
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
              _InfoTile(label: '身高', value: user == null || user.height <= 0 ? '—' : '${user.height.toStringAsFixed(0)} cm'),
              _divider(),
              _InfoTile(label: '性别', value: _genderLabel(user?.gender)),
              _divider(),
              _InfoTile(label: '生日', value: user?.birthday == null
                  ? '—'
                  : '${user!.birthday!.year}-${user.birthday!.month.toString().padLeft(2, '0')}-${user.birthday!.day.toString().padLeft(2, '0')}'),
              _divider(),
              _InfoTile(label: '活动水平', value: _activityLabel(user?.activityLevel ?? 1)),
              _divider(),
              _InfoTile(label: '每日目标热量', value: user == null || user.targetCalorie <= 0
                  ? '—'
                  : '${user.targetCalorie.toStringAsFixed(0)} kcal'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: user == null ? null : () => _openEdit(context, user),
            icon: const Icon(Icons.edit),
            label: const Text('编辑资料'),
          ),
        ),
      ],
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  String _genderLabel(String? g) {
    switch (g) {
      case 'male':   return '男';
      case 'female': return '女';
      case 'other':  return '其他';
      default:       return '—';
    }
  }

  String _activityLabel(int lvl) {
    switch (lvl) {
      case 1: return '久坐（几乎不运动）';
      case 2: return '轻度（每周 1-2 次）';
      case 3: return '中度（每周 3-4 次）';
      case 4: return '高度（每周 5-6 次）';
      case 5: return '极高（每天训练）';
      default: return '—';
    }
  }

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
    final authProvider = context.watch<AuthProvider>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.green[100],
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 32,
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              (user?.nickname.trim().isNotEmpty ?? false) ? user!.nickname : '未设置昵称',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text('ID: ${authProvider.userId ?? '-'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
    final u = user;
    String kg(double v) => v <= 0 ? '—' : '${v.toStringAsFixed(1)}';
    final bmi = u == null || u.bmi <= 0 ? '—' : u.bmi.toStringAsFixed(1);
    return Row(
      children: [
        Expanded(child: _statCard('当前体重', u == null ? '—' : kg(u.currentWeight), 'kg')),
        const SizedBox(width: 8),
        Expanded(child: _statCard('目标体重', u == null ? '—' : kg(u.targetWeight), 'kg')),
        const SizedBox(width: 8),
        Expanded(child: _statCard('BMI', bmi, '')),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              RichText(text: TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 20, color: Colors.black87, fontWeight: FontWeight.w600,
                ),
                children: [
                  if (unit.isNotEmpty)
                    TextSpan(text: ' $unit',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              )),
            ],
          ),
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        trailing: Text(value,
            style: const TextStyle(color: Colors.black87, fontSize: 15)),
      );
}

// ============================================================================
//  编辑资料 BottomSheet
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
  late String _gender;
  DateTime? _birthday;
  late int _activityLevel;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final u = widget.initial;
    _nick = TextEditingController(text: u.nickname);
    _height = TextEditingController(text: u.height > 0 ? u.height.toStringAsFixed(0) : '');
    _curWeight = TextEditingController(text: u.currentWeight > 0 ? u.currentWeight.toStringAsFixed(1) : '');
    _tgtWeight = TextEditingController(text: u.targetWeight > 0 ? u.targetWeight.toStringAsFixed(1) : '');
    _tgtCal = TextEditingController(text: u.targetCalorie > 0 ? u.targetCalorie.toStringAsFixed(0) : '');
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
    super.dispose();
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
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('资料已更新')),
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
    final decimalKb = const TextInputType.numberWithOptions(decimal: true);

    return [
      Row(
        children: [
          const Text('编辑资料',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      const SizedBox(height: 8),

      TextField(controller: _nick, decoration: deco('昵称')),
      const SizedBox(height: 12),

      Row(
        children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: deco('性别'),
            items: const [
              DropdownMenuItem(value: 'male',   child: Text('男')),
              DropdownMenuItem(value: 'female', child: Text('女')),
              DropdownMenuItem(value: 'other',  child: Text('其他')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'male'),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            onPressed: _pickBirthday,
            icon: const Icon(Icons.cake_outlined),
            label: Text(_birthday == null
                ? '选生日'
                : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, "0")}-${_birthday!.day.toString().padLeft(2, "0")}'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
        ],
      ),
      const SizedBox(height: 12),

      TextField(
        controller: _height,
        decoration: deco('身高 (cm)'),
        keyboardType: decimalKb,
        inputFormatters: numFmt,
      ),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: TextField(
          controller: _curWeight,
          decoration: deco('当前体重 (kg)'),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
        const SizedBox(width: 12),
        Expanded(child: TextField(
          controller: _tgtWeight,
          decoration: deco('目标体重 (kg)'),
          keyboardType: decimalKb,
          inputFormatters: numFmt,
        )),
      ]),
      const SizedBox(height: 12),

      DropdownButtonFormField<int>(
        initialValue: _activityLevel,
        decoration: deco('活动水平'),
        items: const [
          DropdownMenuItem(value: 1, child: Text('久坐（几乎不运动）')),
          DropdownMenuItem(value: 2, child: Text('轻度（每周 1-2 次）')),
          DropdownMenuItem(value: 3, child: Text('中度（每周 3-4 次）')),
          DropdownMenuItem(value: 4, child: Text('高度（每周 5-6 次）')),
          DropdownMenuItem(value: 5, child: Text('极高（每天训练）')),
        ],
        onChanged: (v) => setState(() => _activityLevel = v ?? 1),
      ),
      const SizedBox(height: 12),

      TextField(
        controller: _tgtCal,
        decoration: deco('每日目标热量 (kcal)'),
        keyboardType: decimalKb,
        inputFormatters: numFmt,
      ),
      const SizedBox(height: 8),
      Text('建议：BMR × 活动系数 × 减脂系数（0.8 左右）',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ];
  }
}
