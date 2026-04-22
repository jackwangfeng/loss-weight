import '../l10n/generated/app_localizations.dart';

String mealTypeLabel(AppLocalizations l, String mealType) {
  switch (mealType) {
    case 'breakfast': return l.mealBreakfast;
    case 'lunch':     return l.mealLunch;
    case 'dinner':    return l.mealDinner;
    case 'snack':     return l.mealSnack;
    default:          return l.mealOther;
  }
}

String intensityLabel(AppLocalizations l, String intensity) {
  switch (intensity) {
    case 'low':    return l.intensityLight;
    case 'medium': return l.intensityModerate;
    case 'high':   return l.intensityHard;
    default:       return '';
  }
}

String genderLabel(AppLocalizations l, String? gender) {
  switch (gender) {
    case 'male':   return l.sexMale;
    case 'female': return l.sexFemale;
    case 'other':  return l.sexOther;
    default:       return '—';
  }
}

String activityLevelLabel(AppLocalizations l, int level) {
  switch (level) {
    case 1: return l.activitySedentary;
    case 2: return l.activityLight;
    case 3: return l.activityModerate;
    case 4: return l.activityHigh;
    case 5: return l.activityVeryHigh;
    default: return '—';
  }
}
