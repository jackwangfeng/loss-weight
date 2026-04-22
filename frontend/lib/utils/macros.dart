import '../models/user_profile.dart';

/// Resolved daily macro targets, in grams (and calories for reference).
class MacroTargets {
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double calorieKcal;
  const MacroTargets({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.calorieKcal,
  });
}

/// Resolve macro targets for a user. Explicit non-zero targets on the profile
/// win; missing fields fall back to a recomp default keyed off body weight:
///
///   protein = weight * 1.8 g       (upper recomp protein target)
///   fat     = weight * 0.8 g       (fat floor to keep hormones sane)
///   carbs   = remaining kcal / 4   (what's left after protein + fat)
///
/// The front-end owns this derivation instead of the backend so a user can
/// change weight and immediately see updated targets without a migration.
MacroTargets deriveMacroTargets(UserProfile? user) {
  const fallbackWeight = 70.0;
  const fallbackCalorie = 2000.0;

  final weight = (user?.currentWeight ?? 0) > 0
      ? user!.currentWeight
      : fallbackWeight;
  final calorie = (user?.targetCalorie ?? 0) > 0
      ? user!.targetCalorie
      : fallbackCalorie;

  final protein = (user?.targetProteinG ?? 0) > 0
      ? user!.targetProteinG
      : weight * 1.8;
  final fat = (user?.targetFatG ?? 0) > 0 ? user!.targetFatG : weight * 0.8;

  double carbs = (user?.targetCarbsG ?? 0) > 0 ? user!.targetCarbsG : 0;
  if (carbs == 0) {
    final remainingKcal = calorie - protein * 4 - fat * 9;
    carbs = remainingKcal > 0 ? remainingKcal / 4 : 0;
  }

  return MacroTargets(
    proteinG: protein,
    carbsG: carbs,
    fatG: fat,
    calorieKcal: calorie,
  );
}

/// Short hint for "what should I do next?" row in the macro dashboard.
/// Rule-based (no LLM) for MVP — faster, cheaper, predictable.
///
/// Returns a hint key + one numeric arg (grams or kcal), rendered via l10n
/// in the UI. We keep the numbers in this layer so the widget stays dumb.
class MacroHint {
  /// One of: 'needProtein' | 'calOver' | 'onTrack' | 'calLeft'.
  final String kind;
  /// The relevant number (g for needProtein, kcal for the rest). 0 for onTrack.
  final double amount;
  const MacroHint(this.kind, this.amount);
}

MacroHint computeMacroHint({
  required MacroTargets targets,
  required double eatenProtein,
  required double eatenCalorie,
}) {
  final proteinPct = targets.proteinG > 0 ? eatenProtein / targets.proteinG : 1.0;
  final calPct = targets.calorieKcal > 0 ? eatenCalorie / targets.calorieKcal : 1.0;

  if (calPct > 1.05) {
    return MacroHint('calOver', eatenCalorie - targets.calorieKcal);
  }
  if (proteinPct < 0.8) {
    final missing = targets.proteinG - eatenProtein;
    return MacroHint('needProtein', missing > 0 ? missing : 0);
  }
  if (proteinPct >= 1.0 && calPct >= 0.95 && calPct <= 1.05) {
    return const MacroHint('onTrack', 0);
  }
  final remaining = targets.calorieKcal - eatenCalorie;
  return MacroHint('calLeft', remaining > 0 ? remaining : 0);
}
