import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/food_record.dart';
import '../services/food_service.dart';
import '../utils/labels.dart';

/// Full list of today's food records with swipe-to-delete + confirm.
///
/// Pushed from MacroDashboardCard tap. Returns `true` from Navigator.pop
/// when at least one record was deleted, so the home screen can refresh
/// its aggregates.
class TodayFoodListScreen extends StatefulWidget {
  final int userId;
  const TodayFoodListScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<TodayFoodListScreen> createState() => _TodayFoodListScreenState();
}

class _TodayFoodListScreenState extends State<TodayFoodListScreen> {
  final _foodSvc = FoodService();
  List<FoodRecord> _items = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _foodSvc.getRecords(userId: widget.userId);
      if (!mounted) return;
      final now = DateTime.now();
      final today = all
          .where((r) =>
              r.eatenAt.year == now.year &&
              r.eatenAt.month == now.month &&
              r.eatenAt.day == now.day)
          .toList()
        ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
      setState(() {
        _items = today;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmDelete(FoodRecord r) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.foodDeleteConfirm(r.foodName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _doDelete(FoodRecord r) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _foodSvc.deleteRecord(r.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((x) => x.id == r.id);
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorDeleteFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty) {
      body = Center(
        child: Text(l10n.todayFoodEmpty,
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    } else {
      body = ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
        itemBuilder: (ctx, i) {
          final r = _items[i];
          return Dismissible(
            key: ValueKey('food-${r.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: scheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Icon(Icons.delete_outline, color: scheme.onError),
            ),
            confirmDismiss: (_) => _confirmDelete(r),
            onDismissed: (_) => _doDelete(r),
            // Semantics label = food name + cals + meal. Needed both for
            // screen readers (Flutter web doesn't auto-derive ListTile labels)
            // and for E2E tests that locate the row by aria-label substring.
            // Must be INSIDE Dismissible — wrapping it outside lets Dismissible
            // merge / drop the label.
            child: Semantics(
              container: true,
              label: '${r.foodName} ${r.calories.toStringAsFixed(0)} kcal ${mealTypeLabel(l10n, r.mealType)}',
              child: ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE38B2A).withValues(alpha: 0.18),
                  child: const Icon(Icons.restaurant,
                      size: 16, color: Color(0xFFE38B2A)),
                ),
                title: Text(r.foodName),
                subtitle: Text(
                  '${r.calories.toStringAsFixed(0)} kcal · ${mealTypeLabel(l10n, r.mealType)}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                trailing: Text(
                  '${r.eatenAt.hour.toString().padLeft(2, '0')}:${r.eatenAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ),
          );
        },
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.todayFoodTitle)),
        body: body,
      ),
    );
  }
}
