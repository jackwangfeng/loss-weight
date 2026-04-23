// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RecompDaily';

  @override
  String get appTagline => 'Your daily recomp coach';

  @override
  String get navToday => 'Today';

  @override
  String get navLog => 'Log';

  @override
  String get navCoach => 'Coach';

  @override
  String get navMe => 'Me';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit profile';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignInSignUp => 'Sign in / Sign up';

  @override
  String get actionGetStarted => 'Get started';

  @override
  String get actionSendCode => 'Send code';

  @override
  String actionResendCode(int seconds) {
    return 'Resend ${seconds}s';
  }

  @override
  String get actionAskCoach => 'Ask coach';

  @override
  String get actionEstimate => 'Estimate';

  @override
  String get actionLog => 'Log';

  @override
  String get actionTakePhoto => 'Take photo';

  @override
  String get actionChooseFromLibrary => 'Choose from library';

  @override
  String get actionRecognizeFromPhoto => 'Recognize from photo';

  @override
  String get actionLogFoodFromPhoto => 'Log food from photo';

  @override
  String get toastSignedOut => 'Signed out';

  @override
  String get toastSignedIn => 'Signed in';

  @override
  String get toastWelcomeBack => 'Welcome back';

  @override
  String get toastCodeSent => 'Code sent';

  @override
  String get toastProfileUpdated => 'Profile updated';

  @override
  String get toastLogged => 'Logged';

  @override
  String get toastUpdated => 'Updated';

  @override
  String get toastPleaseSignIn => 'Please sign in first';

  @override
  String get toastUploadNotConfigured => 'Image upload not configured yet';

  @override
  String errorLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String errorSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String errorDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String errorSendFailed(String error) {
    return 'Send failed: $error';
  }

  @override
  String errorSignInFailed(String error) {
    return 'Sign in failed: $error';
  }

  @override
  String errorEstimateFailed(String error) {
    return 'Estimate failed: $error';
  }

  @override
  String errorPickFailed(String error) {
    return 'Pick failed: $error';
  }

  @override
  String errorRecognitionFailed(String error) {
    return 'Recognition failed: $error';
  }

  @override
  String get errorCouldNotLoadUser => 'Could not load user';

  @override
  String errorCouldNotLoadMessages(String error) {
    return 'Could not load messages: $error';
  }

  @override
  String errorCouldNotCreateConversation(String error) {
    return 'Could not create conversation: $error';
  }

  @override
  String get errorCouldNotOpenConversation => 'Could not open conversation';

  @override
  String get authPhoneLabel => 'Phone number';

  @override
  String get authPhoneHint => '11-digit phone';

  @override
  String get authPhoneRequired => 'Phone required';

  @override
  String get authPhoneInvalid => 'Enter a valid phone number';

  @override
  String get authCodeLabel => 'Code';

  @override
  String get authCodeHint => '6-digit code';

  @override
  String get authCodeRequired => 'Code required';

  @override
  String get authCodeWrongLength => 'Code must be 6 digits';

  @override
  String get authTerms =>
      'By signing in you agree to the Terms & Privacy Policy.';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authOrDivider => 'or';

  @override
  String errorGoogleSignInFailed(String error) {
    return 'Google sign-in failed: $error';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileNotSignedIn => 'Not signed in';

  @override
  String get profileNoNickname => 'No nickname';

  @override
  String get profileHeight => 'Height';

  @override
  String get profileSex => 'Sex';

  @override
  String get profileBirthday => 'Birthday';

  @override
  String get profileActivity => 'Activity';

  @override
  String get profileDailyCalorieTarget => 'Daily calorie target';

  @override
  String get profileWeight => 'Weight';

  @override
  String get profileTarget => 'Target';

  @override
  String get profileBmi => 'BMI';

  @override
  String get profileNickname => 'Nickname';

  @override
  String get profileHeightCm => 'Height (cm)';

  @override
  String get profileWeightKg => 'Weight (kg)';

  @override
  String get profileTargetKg => 'Target (kg)';

  @override
  String get profileActivityLevel => 'Activity level';

  @override
  String get profileDailyCalorieTargetKcal => 'Daily calorie target (kcal)';

  @override
  String get profileTargetHint =>
      'Rule of thumb: BMR × activity × cut factor (~0.8)';

  @override
  String get profileMacroSection => 'Macro targets';

  @override
  String get profileMacroHint =>
      'Leave blank to auto-derive from body weight (protein = weight × 1.8, fat = weight × 0.8).';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexOther => 'Other';

  @override
  String get activitySedentary => 'Sedentary';

  @override
  String get activityLight => 'Light (1-2x / week)';

  @override
  String get activityModerate => 'Moderate (3-4x / week)';

  @override
  String get activityHigh => 'High (5-6x / week)';

  @override
  String get activityVeryHigh => 'Very high (daily)';

  @override
  String get homeTodaySection => 'Today';

  @override
  String get homeRecentSection => 'Recent';

  @override
  String get homeEmpty => 'Nothing logged yet. Start in the Log tab.';

  @override
  String homeFailedToLoad(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get homeBudgetTarget => 'TARGET';

  @override
  String get homeBudgetIn => 'IN';

  @override
  String get homeBudgetOut => 'OUT';

  @override
  String homeBudgetLeft(String value) {
    return '$value left';
  }

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int n) {
    return '${n}m ago';
  }

  @override
  String timeDaysAgo(int n) {
    return '${n}d ago';
  }

  @override
  String get timeYesterday => 'yesterday';

  @override
  String get timeToday => 'Today';

  @override
  String get timeYesterdayCap => 'Yesterday';

  @override
  String get logFoodTab => 'Food';

  @override
  String get logTrainingTab => 'Training';

  @override
  String get logWeightTab => 'Weight';

  @override
  String get foodTitle => 'Food';

  @override
  String get foodEmpty => 'No food logged yet. Tap + to start.';

  @override
  String get foodLogSheetTitle => 'Log food';

  @override
  String get foodEditSheetTitle => 'Edit entry';

  @override
  String get foodSectionAiEstimate => 'AI ESTIMATE';

  @override
  String get foodSectionFrequent => 'FREQUENT';

  @override
  String get foodSectionDetails => 'DETAILS';

  @override
  String get foodAiHint => 'e.g. 200g grilled chicken, 1 cup rice';

  @override
  String get foodAiEmptyWarn =>
      'Describe what you ate first, e.g. \"200g grilled chicken\"';

  @override
  String get foodName => 'Food name *';

  @override
  String get foodCalories => 'Calories (kcal) *';

  @override
  String get foodPortion => 'Portion';

  @override
  String get foodUnitGram => 'g';

  @override
  String get foodUnitMl => 'ml';

  @override
  String get foodUnitServing => 'serving';

  @override
  String get foodUnitPiece => 'piece';

  @override
  String get foodMeal => 'Meal';

  @override
  String get foodMacrosOptional => 'Macros (optional)';

  @override
  String get foodProteinG => 'Protein (g)';

  @override
  String get foodCarbsG => 'Carbs (g)';

  @override
  String get foodFatG => 'Fat (g)';

  @override
  String get foodTodayLabel => 'TODAY';

  @override
  String foodMealCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n meals',
      one: '1 meal',
    );
    return '$_temp0';
  }

  @override
  String get foodMacroProtein => 'PROTEIN';

  @override
  String get foodMacroCarbs => 'CARBS';

  @override
  String get foodMacroFat => 'FAT';

  @override
  String get foodMacroCal => 'CAL';

  @override
  String get foodMacroProteinFull => 'Protein';

  @override
  String get foodMacroCarbsFull => 'Carbs';

  @override
  String get foodMacroFatFull => 'Fat';

  @override
  String get foodMacroCalFull => 'Calories';

  @override
  String macroValueOfTarget(String current, String target) {
    return '$current / $target g';
  }

  @override
  String macroCalValueOfTarget(String current, String target) {
    return '$current / $target kcal';
  }

  @override
  String macroHintNeedProtein(String grams) {
    return 'Need $grams g protein to hit target';
  }

  @override
  String macroHintCalOver(String kcal) {
    return '$kcal kcal over target';
  }

  @override
  String get macroHintOnTrack => 'On track — finish strong';

  @override
  String macroHintCalLeft(String kcal) {
    return '$kcal kcal left in budget';
  }

  @override
  String foodDayCalories(String value) {
    return '$value kcal';
  }

  @override
  String get foodNameRequired => 'Enter a food name';

  @override
  String get foodCaloriesRequired => 'Enter calories';

  @override
  String get foodDeleteTitle => 'Delete this entry?';

  @override
  String foodBudgetUnder(String eaten, String remaining) {
    return 'Eaten $eaten kcal · $remaining left';
  }

  @override
  String foodBudgetOver(String eaten, String over) {
    return 'Eaten $eaten kcal · $over over';
  }

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealSnack => 'Snack';

  @override
  String get mealOther => 'Other';

  @override
  String get trainingTitle => 'Training';

  @override
  String get trainingEmpty => 'No training logged yet. Tap + to start.';

  @override
  String get trainingLogSheetTitle => 'Log training';

  @override
  String get trainingEditSheetTitle => 'Edit training';

  @override
  String get trainingType => 'Activity *';

  @override
  String get trainingTypeHint => 'e.g. bench press, running, HIIT';

  @override
  String get trainingDurationMin => 'Duration (min) *';

  @override
  String get trainingCaloriesBurned => 'Calories burned';

  @override
  String get trainingIntensity => 'Intensity';

  @override
  String get trainingDistanceKm => 'Distance (km)';

  @override
  String get trainingNotes => 'Notes (optional)';

  @override
  String get trainingAiHint => 'e.g. bench press 4x8 @ 80kg; ran 5k in 25min';

  @override
  String get trainingAiEmptyWarn =>
      'Describe the workout first, e.g. \"ran 5k in 25min\"';

  @override
  String get trainingSectionFrequent => 'FREQUENT';

  @override
  String get trainingTodayLabel => 'TODAY';

  @override
  String trainingSessionCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String trainingDurationMinutes(int n) {
    return '$n min';
  }

  @override
  String get trainingTypeRequired => 'Enter the activity';

  @override
  String get trainingDurationRequired => 'Enter a duration';

  @override
  String get trainingDeleteTitle => 'Delete this session?';

  @override
  String trainingBurnedToast(String calories, int minutes) {
    return 'Burned $calories kcal · $minutes min today';
  }

  @override
  String get intensityLight => 'Light';

  @override
  String get intensityModerate => 'Moderate';

  @override
  String get intensityHard => 'Hard';

  @override
  String get weightTitle => 'Weight';

  @override
  String get weightEmpty => 'No weigh-ins yet. Tap + to start.';

  @override
  String get weightLogSheetTitle => 'Log weigh-in';

  @override
  String get weightEditSheetTitle => 'Edit weigh-in';

  @override
  String get weightValueKg => 'Weight (kg) *';

  @override
  String get weightNote => 'Note (optional)';

  @override
  String get weightValueRequired => 'Enter a weight';

  @override
  String get weightDeleteTitle => 'Delete this weigh-in?';

  @override
  String get weightWeighIn => 'Weigh-in';

  @override
  String get weightTrendSection => 'Weight trend';

  @override
  String get weightHistorySection => 'History';

  @override
  String get weightStatLow => 'Low';

  @override
  String get weightStatHigh => 'High';

  @override
  String get weightStatChange => 'Change';

  @override
  String get weightBodyFatPct => 'Body fat (%)';

  @override
  String get weightMuscleKg => 'Muscle (kg)';

  @override
  String get weightWaterPct => 'Water (%)';

  @override
  String get weightMoreLabel =>
      'More (body fat / muscle / water / note, optional)';

  @override
  String weightMeasuredOn(String date) {
    return 'Measured on $date';
  }

  @override
  String get weightAddDialogTitle => 'Add weigh-in';

  @override
  String get weightAiHint => 'e.g. 68.5kg morning, 67 bf22%';

  @override
  String get weightAiEmptyWarn =>
      'Type anything, e.g. \"68.5kg morning\", \"67 bf22\"';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionParse => 'Parse';

  @override
  String errorParseFailed(String error) {
    return 'Parse failed: $error';
  }

  @override
  String get coachTitle => 'Coach';

  @override
  String get coachEmptyTitle => 'Start talking to your coach';

  @override
  String get coachEmptySubtitle =>
      'Ask about macros, training, or what to eat next.';

  @override
  String get coachInputHint => 'Message your coach...';

  @override
  String get sheetCtxEstimate => 'Estimate';

  @override
  String sheetTimeFormat(int month, int day, String hour, String minute) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get voiceListening => 'Listening...';

  @override
  String get voiceNotAvailable => 'Voice input not available';

  @override
  String get voicePermissionDenied => 'Microphone permission denied';

  @override
  String get voiceTapToSpeak => 'Tap to speak';

  @override
  String get voiceTapToStop => 'Tap to stop';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageDescription =>
      'Controls both the UI and your AI coach\'s reply language.';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceDescription =>
      'Choose how dark the interface surfaces are.';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeMedium => 'Graphite';

  @override
  String get profileSettings => 'Settings';

  @override
  String get quickSetupBannerTitle => 'Tune your targets for sharper coaching';

  @override
  String get quickSetupBannerHint => '30 seconds';

  @override
  String get quickSetupTitle => 'Quick setup';

  @override
  String get quickSetupSubtitle =>
      'These drive your macro targets and AI advice. Skip anything — you can edit later in Profile.';

  @override
  String get quickSetupSave => 'Save';

  @override
  String get quickSetupAiHint =>
      'Say it in one line (e.g. \'35yo male, 180cm 82kg, want to cut to 75\') — AI fills the fields below';

  @override
  String get quickSetupAiParse => 'Fill with AI';

  @override
  String get quickSetupAiEmpty => 'Type or speak something first.';

  @override
  String get quickSetupAiFailed =>
      'AI didn\'t understand. Try again or fill manually.';
}
