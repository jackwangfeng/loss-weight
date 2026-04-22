import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'RecompDaily'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your daily recomp coach'**
  String get appTagline;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get navLog;

  /// No description provided for @navCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get navCoach;

  /// No description provided for @navMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get navMe;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get actionEdit;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @actionSignInSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign in / Sign up'**
  String get actionSignInSignUp;

  /// No description provided for @actionGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get actionGetStarted;

  /// No description provided for @actionSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get actionSendCode;

  /// No description provided for @actionResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend {seconds}s'**
  String actionResendCode(int seconds);

  /// No description provided for @actionAskCoach.
  ///
  /// In en, this message translates to:
  /// **'Ask coach'**
  String get actionAskCoach;

  /// No description provided for @actionEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get actionEstimate;

  /// No description provided for @actionLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get actionLog;

  /// No description provided for @actionTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get actionTakePhoto;

  /// No description provided for @actionChooseFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get actionChooseFromLibrary;

  /// No description provided for @actionRecognizeFromPhoto.
  ///
  /// In en, this message translates to:
  /// **'Recognize from photo'**
  String get actionRecognizeFromPhoto;

  /// No description provided for @actionLogFoodFromPhoto.
  ///
  /// In en, this message translates to:
  /// **'Log food from photo'**
  String get actionLogFoodFromPhoto;

  /// No description provided for @toastSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get toastSignedOut;

  /// No description provided for @toastSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get toastSignedIn;

  /// No description provided for @toastWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get toastWelcomeBack;

  /// No description provided for @toastCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent'**
  String get toastCodeSent;

  /// No description provided for @toastProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get toastProfileUpdated;

  /// No description provided for @toastLogged.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get toastLogged;

  /// No description provided for @toastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get toastUpdated;

  /// No description provided for @toastPleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first'**
  String get toastPleaseSignIn;

  /// No description provided for @toastUploadNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Image upload not configured yet'**
  String get toastUploadNotConfigured;

  /// No description provided for @errorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String errorLoadFailed(String error);

  /// No description provided for @errorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String errorSaveFailed(String error);

  /// No description provided for @errorDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String errorDeleteFailed(String error);

  /// No description provided for @errorSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed: {error}'**
  String errorSendFailed(String error);

  /// No description provided for @errorSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed: {error}'**
  String errorSignInFailed(String error);

  /// No description provided for @errorEstimateFailed.
  ///
  /// In en, this message translates to:
  /// **'Estimate failed: {error}'**
  String errorEstimateFailed(String error);

  /// No description provided for @errorPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Pick failed: {error}'**
  String errorPickFailed(String error);

  /// No description provided for @errorRecognitionFailed.
  ///
  /// In en, this message translates to:
  /// **'Recognition failed: {error}'**
  String errorRecognitionFailed(String error);

  /// No description provided for @errorCouldNotLoadUser.
  ///
  /// In en, this message translates to:
  /// **'Could not load user'**
  String get errorCouldNotLoadUser;

  /// No description provided for @errorCouldNotLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Could not load messages: {error}'**
  String errorCouldNotLoadMessages(String error);

  /// No description provided for @errorCouldNotCreateConversation.
  ///
  /// In en, this message translates to:
  /// **'Could not create conversation: {error}'**
  String errorCouldNotCreateConversation(String error);

  /// No description provided for @errorCouldNotOpenConversation.
  ///
  /// In en, this message translates to:
  /// **'Could not open conversation'**
  String get errorCouldNotOpenConversation;

  /// No description provided for @authPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get authPhoneLabel;

  /// No description provided for @authPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'11-digit phone'**
  String get authPhoneHint;

  /// No description provided for @authPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone required'**
  String get authPhoneRequired;

  /// No description provided for @authPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get authPhoneInvalid;

  /// No description provided for @authCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get authCodeLabel;

  /// No description provided for @authCodeHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get authCodeHint;

  /// No description provided for @authCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Code required'**
  String get authCodeRequired;

  /// No description provided for @authCodeWrongLength.
  ///
  /// In en, this message translates to:
  /// **'Code must be 6 digits'**
  String get authCodeWrongLength;

  /// No description provided for @authTerms.
  ///
  /// In en, this message translates to:
  /// **'By signing in you agree to the Terms & Privacy Policy.'**
  String get authTerms;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authOrDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOrDivider;

  /// No description provided for @errorGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed: {error}'**
  String errorGoogleSignInFailed(String error);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get profileNotSignedIn;

  /// No description provided for @profileNoNickname.
  ///
  /// In en, this message translates to:
  /// **'No nickname'**
  String get profileNoNickname;

  /// No description provided for @profileHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get profileHeight;

  /// No description provided for @profileSex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get profileSex;

  /// No description provided for @profileBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get profileBirthday;

  /// No description provided for @profileActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get profileActivity;

  /// No description provided for @profileDailyCalorieTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily calorie target'**
  String get profileDailyCalorieTarget;

  /// No description provided for @profileWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get profileWeight;

  /// No description provided for @profileTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get profileTarget;

  /// No description provided for @profileBmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get profileBmi;

  /// No description provided for @profileNickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get profileNickname;

  /// No description provided for @profileHeightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get profileHeightCm;

  /// No description provided for @profileWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get profileWeightKg;

  /// No description provided for @profileTargetKg.
  ///
  /// In en, this message translates to:
  /// **'Target (kg)'**
  String get profileTargetKg;

  /// No description provided for @profileActivityLevel.
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get profileActivityLevel;

  /// No description provided for @profileDailyCalorieTargetKcal.
  ///
  /// In en, this message translates to:
  /// **'Daily calorie target (kcal)'**
  String get profileDailyCalorieTargetKcal;

  /// No description provided for @profileTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Rule of thumb: BMR × activity × cut factor (~0.8)'**
  String get profileTargetHint;

  /// No description provided for @profileMacroSection.
  ///
  /// In en, this message translates to:
  /// **'Macro targets'**
  String get profileMacroSection;

  /// No description provided for @profileMacroHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to auto-derive from body weight (protein = weight × 1.8, fat = weight × 0.8).'**
  String get profileMacroHint;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sexOther;

  /// No description provided for @activitySedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get activitySedentary;

  /// No description provided for @activityLight.
  ///
  /// In en, this message translates to:
  /// **'Light (1-2x / week)'**
  String get activityLight;

  /// No description provided for @activityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate (3-4x / week)'**
  String get activityModerate;

  /// No description provided for @activityHigh.
  ///
  /// In en, this message translates to:
  /// **'High (5-6x / week)'**
  String get activityHigh;

  /// No description provided for @activityVeryHigh.
  ///
  /// In en, this message translates to:
  /// **'Very high (daily)'**
  String get activityVeryHigh;

  /// No description provided for @homeTodaySection.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeTodaySection;

  /// No description provided for @homeRecentSection.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeRecentSection;

  /// No description provided for @homeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet. Start in the Log tab.'**
  String get homeEmpty;

  /// No description provided for @homeFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String homeFailedToLoad(String error);

  /// No description provided for @homeBudgetTarget.
  ///
  /// In en, this message translates to:
  /// **'TARGET'**
  String get homeBudgetTarget;

  /// No description provided for @homeBudgetIn.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get homeBudgetIn;

  /// No description provided for @homeBudgetOut.
  ///
  /// In en, this message translates to:
  /// **'OUT'**
  String get homeBudgetOut;

  /// No description provided for @homeBudgetLeft.
  ///
  /// In en, this message translates to:
  /// **'{value} left'**
  String homeBudgetLeft(String value);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String timeMinutesAgo(int n);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String timeDaysAgo(int n);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// No description provided for @timeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get timeToday;

  /// No description provided for @timeYesterdayCap.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterdayCap;

  /// No description provided for @logFoodTab.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get logFoodTab;

  /// No description provided for @logTrainingTab.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get logTrainingTab;

  /// No description provided for @logWeightTab.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get logWeightTab;

  /// No description provided for @foodTitle.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get foodTitle;

  /// No description provided for @foodEmpty.
  ///
  /// In en, this message translates to:
  /// **'No food logged yet. Tap + to start.'**
  String get foodEmpty;

  /// No description provided for @foodLogSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Log food'**
  String get foodLogSheetTitle;

  /// No description provided for @foodEditSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get foodEditSheetTitle;

  /// No description provided for @foodSectionAiEstimate.
  ///
  /// In en, this message translates to:
  /// **'AI ESTIMATE'**
  String get foodSectionAiEstimate;

  /// No description provided for @foodSectionFrequent.
  ///
  /// In en, this message translates to:
  /// **'FREQUENT'**
  String get foodSectionFrequent;

  /// No description provided for @foodSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get foodSectionDetails;

  /// No description provided for @foodAiHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 200g grilled chicken, 1 cup rice'**
  String get foodAiHint;

  /// No description provided for @foodAiEmptyWarn.
  ///
  /// In en, this message translates to:
  /// **'Describe what you ate first, e.g. \"200g grilled chicken\"'**
  String get foodAiEmptyWarn;

  /// No description provided for @foodName.
  ///
  /// In en, this message translates to:
  /// **'Food name *'**
  String get foodName;

  /// No description provided for @foodCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories (kcal) *'**
  String get foodCalories;

  /// No description provided for @foodPortion.
  ///
  /// In en, this message translates to:
  /// **'Portion'**
  String get foodPortion;

  /// No description provided for @foodUnitGram.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get foodUnitGram;

  /// No description provided for @foodUnitMl.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get foodUnitMl;

  /// No description provided for @foodUnitServing.
  ///
  /// In en, this message translates to:
  /// **'serving'**
  String get foodUnitServing;

  /// No description provided for @foodUnitPiece.
  ///
  /// In en, this message translates to:
  /// **'piece'**
  String get foodUnitPiece;

  /// No description provided for @foodMeal.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get foodMeal;

  /// No description provided for @foodMacrosOptional.
  ///
  /// In en, this message translates to:
  /// **'Macros (optional)'**
  String get foodMacrosOptional;

  /// No description provided for @foodProteinG.
  ///
  /// In en, this message translates to:
  /// **'Protein (g)'**
  String get foodProteinG;

  /// No description provided for @foodCarbsG.
  ///
  /// In en, this message translates to:
  /// **'Carbs (g)'**
  String get foodCarbsG;

  /// No description provided for @foodFatG.
  ///
  /// In en, this message translates to:
  /// **'Fat (g)'**
  String get foodFatG;

  /// No description provided for @foodTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get foodTodayLabel;

  /// No description provided for @foodMealCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 meal} other{{n} meals}}'**
  String foodMealCount(int n);

  /// No description provided for @foodMacroProtein.
  ///
  /// In en, this message translates to:
  /// **'PROTEIN'**
  String get foodMacroProtein;

  /// No description provided for @foodMacroCarbs.
  ///
  /// In en, this message translates to:
  /// **'CARBS'**
  String get foodMacroCarbs;

  /// No description provided for @foodMacroFat.
  ///
  /// In en, this message translates to:
  /// **'FAT'**
  String get foodMacroFat;

  /// No description provided for @foodMacroCal.
  ///
  /// In en, this message translates to:
  /// **'CAL'**
  String get foodMacroCal;

  /// No description provided for @foodMacroProteinFull.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get foodMacroProteinFull;

  /// No description provided for @foodMacroCarbsFull.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get foodMacroCarbsFull;

  /// No description provided for @foodMacroFatFull.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get foodMacroFatFull;

  /// No description provided for @foodMacroCalFull.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get foodMacroCalFull;

  /// No description provided for @macroValueOfTarget.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} g'**
  String macroValueOfTarget(String current, String target);

  /// No description provided for @macroCalValueOfTarget.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} kcal'**
  String macroCalValueOfTarget(String current, String target);

  /// No description provided for @macroHintNeedProtein.
  ///
  /// In en, this message translates to:
  /// **'Need {grams} g protein to hit target'**
  String macroHintNeedProtein(String grams);

  /// No description provided for @macroHintCalOver.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal over target'**
  String macroHintCalOver(String kcal);

  /// No description provided for @macroHintOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track — finish strong'**
  String get macroHintOnTrack;

  /// No description provided for @macroHintCalLeft.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal left in budget'**
  String macroHintCalLeft(String kcal);

  /// No description provided for @foodDayCalories.
  ///
  /// In en, this message translates to:
  /// **'{value} kcal'**
  String foodDayCalories(String value);

  /// No description provided for @foodNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a food name'**
  String get foodNameRequired;

  /// No description provided for @foodCaloriesRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter calories'**
  String get foodCaloriesRequired;

  /// No description provided for @foodDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get foodDeleteTitle;

  /// No description provided for @foodBudgetUnder.
  ///
  /// In en, this message translates to:
  /// **'Eaten {eaten} kcal · {remaining} left'**
  String foodBudgetUnder(String eaten, String remaining);

  /// No description provided for @foodBudgetOver.
  ///
  /// In en, this message translates to:
  /// **'Eaten {eaten} kcal · {over} over'**
  String foodBudgetOver(String eaten, String over);

  /// No description provided for @mealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealDinner;

  /// No description provided for @mealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// No description provided for @mealOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get mealOther;

  /// No description provided for @trainingTitle.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get trainingTitle;

  /// No description provided for @trainingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No training logged yet. Tap + to start.'**
  String get trainingEmpty;

  /// No description provided for @trainingLogSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Log training'**
  String get trainingLogSheetTitle;

  /// No description provided for @trainingEditSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit training'**
  String get trainingEditSheetTitle;

  /// No description provided for @trainingType.
  ///
  /// In en, this message translates to:
  /// **'Activity *'**
  String get trainingType;

  /// No description provided for @trainingTypeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. bench press, running, HIIT'**
  String get trainingTypeHint;

  /// No description provided for @trainingDurationMin.
  ///
  /// In en, this message translates to:
  /// **'Duration (min) *'**
  String get trainingDurationMin;

  /// No description provided for @trainingCaloriesBurned.
  ///
  /// In en, this message translates to:
  /// **'Calories burned'**
  String get trainingCaloriesBurned;

  /// No description provided for @trainingIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get trainingIntensity;

  /// No description provided for @trainingDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'Distance (km)'**
  String get trainingDistanceKm;

  /// No description provided for @trainingNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get trainingNotes;

  /// No description provided for @trainingAiHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. bench press 4x8 @ 80kg; ran 5k in 25min'**
  String get trainingAiHint;

  /// No description provided for @trainingAiEmptyWarn.
  ///
  /// In en, this message translates to:
  /// **'Describe the workout first, e.g. \"ran 5k in 25min\"'**
  String get trainingAiEmptyWarn;

  /// No description provided for @trainingSectionFrequent.
  ///
  /// In en, this message translates to:
  /// **'FREQUENT'**
  String get trainingSectionFrequent;

  /// No description provided for @trainingTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get trainingTodayLabel;

  /// No description provided for @trainingSessionCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 session} other{{n} sessions}}'**
  String trainingSessionCount(int n);

  /// No description provided for @trainingDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String trainingDurationMinutes(int n);

  /// No description provided for @trainingTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the activity'**
  String get trainingTypeRequired;

  /// No description provided for @trainingDurationRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a duration'**
  String get trainingDurationRequired;

  /// No description provided for @trainingDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this session?'**
  String get trainingDeleteTitle;

  /// No description provided for @trainingBurnedToast.
  ///
  /// In en, this message translates to:
  /// **'Burned {calories} kcal · {minutes} min today'**
  String trainingBurnedToast(String calories, int minutes);

  /// No description provided for @intensityLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get intensityLight;

  /// No description provided for @intensityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get intensityModerate;

  /// No description provided for @intensityHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get intensityHard;

  /// No description provided for @weightTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightTitle;

  /// No description provided for @weightEmpty.
  ///
  /// In en, this message translates to:
  /// **'No weigh-ins yet. Tap + to start.'**
  String get weightEmpty;

  /// No description provided for @weightLogSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Log weigh-in'**
  String get weightLogSheetTitle;

  /// No description provided for @weightEditSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit weigh-in'**
  String get weightEditSheetTitle;

  /// No description provided for @weightValueKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg) *'**
  String get weightValueKg;

  /// No description provided for @weightNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get weightNote;

  /// No description provided for @weightValueRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a weight'**
  String get weightValueRequired;

  /// No description provided for @weightDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this weigh-in?'**
  String get weightDeleteTitle;

  /// No description provided for @weightWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Weigh-in'**
  String get weightWeighIn;

  /// No description provided for @weightTrendSection.
  ///
  /// In en, this message translates to:
  /// **'Weight trend'**
  String get weightTrendSection;

  /// No description provided for @weightHistorySection.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get weightHistorySection;

  /// No description provided for @weightStatLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get weightStatLow;

  /// No description provided for @weightStatHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get weightStatHigh;

  /// No description provided for @weightStatChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get weightStatChange;

  /// No description provided for @weightBodyFatPct.
  ///
  /// In en, this message translates to:
  /// **'Body fat (%)'**
  String get weightBodyFatPct;

  /// No description provided for @weightMuscleKg.
  ///
  /// In en, this message translates to:
  /// **'Muscle (kg)'**
  String get weightMuscleKg;

  /// No description provided for @weightWaterPct.
  ///
  /// In en, this message translates to:
  /// **'Water (%)'**
  String get weightWaterPct;

  /// No description provided for @weightMoreLabel.
  ///
  /// In en, this message translates to:
  /// **'More (body fat / muscle / water / note, optional)'**
  String get weightMoreLabel;

  /// No description provided for @weightMeasuredOn.
  ///
  /// In en, this message translates to:
  /// **'Measured on {date}'**
  String weightMeasuredOn(String date);

  /// No description provided for @weightAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add weigh-in'**
  String get weightAddDialogTitle;

  /// No description provided for @weightAiHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 68.5kg morning, 67 bf22%'**
  String get weightAiHint;

  /// No description provided for @weightAiEmptyWarn.
  ///
  /// In en, this message translates to:
  /// **'Type anything, e.g. \"68.5kg morning\", \"67 bf22\"'**
  String get weightAiEmptyWarn;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionParse.
  ///
  /// In en, this message translates to:
  /// **'Parse'**
  String get actionParse;

  /// No description provided for @errorParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Parse failed: {error}'**
  String errorParseFailed(String error);

  /// No description provided for @coachTitle.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coachTitle;

  /// No description provided for @coachEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start talking to your coach'**
  String get coachEmptyTitle;

  /// No description provided for @coachEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask about macros, training, or what to eat next.'**
  String get coachEmptySubtitle;

  /// No description provided for @coachInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message your coach...'**
  String get coachInputHint;

  /// No description provided for @sheetCtxEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get sheetCtxEstimate;

  /// No description provided for @sheetTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day} {hour}:{minute}'**
  String sheetTimeFormat(int month, int day, String hour, String minute);

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get voiceListening;

  /// No description provided for @voiceNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input not available'**
  String get voiceNotAvailable;

  /// No description provided for @voicePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get voicePermissionDenied;

  /// No description provided for @voiceTapToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap to speak'**
  String get voiceTapToSpeak;

  /// No description provided for @voiceTapToStop.
  ///
  /// In en, this message translates to:
  /// **'Tap to stop'**
  String get voiceTapToStop;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Controls both the UI and your AI coach\'s reply language.'**
  String get settingsLanguageDescription;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageChinese;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
