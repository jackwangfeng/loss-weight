import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/food_record.dart';
import '../providers/user_provider.dart';
import '../utils/macros.dart';

/// Home-screen / Food-screen top card. Protein is the hero metric for recomp,
/// calories / carbs / fat sit in a secondary row, and a one-line rule-based
/// hint tells the user what to do next ("need X g protein", "Y kcal over").
///
/// Stateless — takes today's food records as input so both the food screen
/// (already has them loaded) and the home screen (loads its own) can share it.
class MacroDashboardCard extends StatelessWidget {
  /// Today's food records (caller filters to today's date).
  final List<FoodRecord> todayRecords;

  const MacroDashboardCard({Key? key, required this.todayRecords})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final user = context.watch<UserProvider>().currentUser;
    final targets = deriveMacroTargets(user);

    final eatenProtein = todayRecords.fold<double>(0, (s, r) => s + r.protein);
    final eatenCarbs = todayRecords.fold<double>(0, (s, r) => s + r.carbohydrates);
    final eatenFat = todayRecords.fold<double>(0, (s, r) => s + r.fat);
    final eatenCal = todayRecords.fold<double>(0, (s, r) => s + r.calories);

    final hint = computeMacroHint(
      targets: targets,
      eatenProtein: eatenProtein,
      eatenCalorie: eatenCal,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerRow(context, l10n, scheme),
            const SizedBox(height: 14),
            _proteinHero(context, l10n, scheme, eatenProtein, targets.proteinG),
            const SizedBox(height: 18),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 14),
            _secondaryRow(context, l10n, scheme,
                eatenCal: eatenCal,
                eatenCarbs: eatenCarbs,
                eatenFat: eatenFat,
                targets: targets),
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 12),
            _hintRow(context, l10n, scheme, hint),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  //  Header
  // ==========================================================================

  Widget _headerRow(BuildContext ctx, AppLocalizations l10n, ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.foodTodayLabel,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          l10n.foodMealCount(todayRecords.length),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // ==========================================================================
  //  Protein hero — big number + full-width progress bar + %
  // ==========================================================================

  Widget _proteinHero(
    BuildContext ctx,
    AppLocalizations l10n,
    ColorScheme scheme,
    double eaten,
    double target,
  ) {
    final pct = target > 0 ? (eaten / target).clamp(0.0, 1.2) : 0.0;
    final barColor = scheme.primary; // accent red — protein gets brand color
    final pctLabel = target > 0 ? '${(eaten / target * 100).toStringAsFixed(0)}%' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.foodMacroProtein, // "PROTEIN"
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              pctLabel,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              eaten.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: scheme.onSurface,
              ),
            ),
            Text(
              ' / ${target.toStringAsFixed(0)} g',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct > 1.0 ? 1.0 : pct,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  //  Secondary row — 3 small columns (cal / carbs / fat)
  // ==========================================================================

  Widget _secondaryRow(
    BuildContext ctx,
    AppLocalizations l10n,
    ColorScheme scheme, {
    required double eatenCal,
    required double eatenCarbs,
    required double eatenFat,
    required MacroTargets targets,
  }) {
    return Row(
      children: [
        Expanded(
          child: _miniMetric(
            ctx,
            scheme: scheme,
            label: l10n.foodMacroCal,
            current: eatenCal,
            target: targets.calorieKcal,
            unit: 'kcal',
            overIsWarning: true,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _miniMetric(
            ctx,
            scheme: scheme,
            label: l10n.foodMacroCarbs,
            current: eatenCarbs,
            target: targets.carbsG,
            unit: 'g',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _miniMetric(
            ctx,
            scheme: scheme,
            label: l10n.foodMacroFat,
            current: eatenFat,
            target: targets.fatG,
            unit: 'g',
          ),
        ),
      ],
    );
  }

  Widget _miniMetric(
    BuildContext ctx, {
    required ColorScheme scheme,
    required String label,
    required double current,
    required double target,
    required String unit,
    bool overIsWarning = false,
  }) {
    final pct = target > 0 ? (current / target).clamp(0.0, 1.2) : 0.0;
    final over = target > 0 && current > target;
    final numberColor = (over && overIsWarning) ? scheme.error : scheme.onSurface;
    final barColor = (over && overIsWarning) ? scheme.error : scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          current.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: numberColor,
          ),
        ),
        Text(
          '/ ${target.toStringAsFixed(0)} $unit',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct > 1.0 ? 1.0 : pct,
            minHeight: 3,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  //  Hint row — rule-based one-liner
  // ==========================================================================

  Widget _hintRow(
    BuildContext ctx,
    AppLocalizations l10n,
    ColorScheme scheme,
    MacroHint hint,
  ) {
    String text;
    IconData icon;
    Color color;
    switch (hint.kind) {
      case 'needProtein':
        text = l10n.macroHintNeedProtein(hint.amount.toStringAsFixed(0));
        icon = Icons.arrow_upward;
        color = scheme.primary;
        break;
      case 'calOver':
        text = l10n.macroHintCalOver(hint.amount.toStringAsFixed(0));
        icon = Icons.warning_amber_rounded;
        color = scheme.error;
        break;
      case 'onTrack':
        text = l10n.macroHintOnTrack;
        icon = Icons.check_circle_outline;
        color = scheme.primary;
        break;
      case 'calLeft':
      default:
        text = l10n.macroHintCalLeft(hint.amount.toStringAsFixed(0));
        icon = Icons.arrow_forward;
        color = scheme.onSurface;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
