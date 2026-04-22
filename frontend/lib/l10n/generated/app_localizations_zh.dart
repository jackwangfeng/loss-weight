// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'RecompDaily';

  @override
  String get appTagline => '你的每日身体重塑教练';

  @override
  String get navToday => '今日';

  @override
  String get navLog => '记录';

  @override
  String get navCoach => '教练';

  @override
  String get navMe => '我的';

  @override
  String get actionSave => '保存';

  @override
  String get actionCancel => '取消';

  @override
  String get actionDelete => '删除';

  @override
  String get actionEdit => '编辑资料';

  @override
  String get actionSignOut => '退出登录';

  @override
  String get actionSignIn => '登录';

  @override
  String get actionSignInSignUp => '登录 / 注册';

  @override
  String get actionGetStarted => '开始使用';

  @override
  String get actionSendCode => '获取验证码';

  @override
  String actionResendCode(int seconds) {
    return '$seconds 秒后重发';
  }

  @override
  String get actionAskCoach => '问教练';

  @override
  String get actionEstimate => '估算';

  @override
  String get actionLog => '记录';

  @override
  String get actionTakePhoto => '拍照';

  @override
  String get actionChooseFromLibrary => '从相册选';

  @override
  String get actionRecognizeFromPhoto => '拍照识别';

  @override
  String get actionLogFoodFromPhoto => '拍照记录饮食';

  @override
  String get toastSignedOut => '已退出';

  @override
  String get toastSignedIn => '登录成功';

  @override
  String get toastWelcomeBack => '欢迎回来';

  @override
  String get toastCodeSent => '验证码已发送';

  @override
  String get toastProfileUpdated => '资料已更新';

  @override
  String get toastLogged => '已记录';

  @override
  String get toastUpdated => '已更新';

  @override
  String get toastPleaseSignIn => '请先登录';

  @override
  String get toastUploadNotConfigured => '图片上传尚未配置';

  @override
  String errorLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String errorSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String errorDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String errorSendFailed(String error) {
    return '发送失败：$error';
  }

  @override
  String errorSignInFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String errorEstimateFailed(String error) {
    return '估算失败：$error';
  }

  @override
  String errorPickFailed(String error) {
    return '选图失败：$error';
  }

  @override
  String errorRecognitionFailed(String error) {
    return '识别失败：$error';
  }

  @override
  String get errorCouldNotLoadUser => '无法获取用户信息';

  @override
  String errorCouldNotLoadMessages(String error) {
    return '加载消息失败：$error';
  }

  @override
  String errorCouldNotCreateConversation(String error) {
    return '创建对话失败：$error';
  }

  @override
  String get errorCouldNotOpenConversation => '无法打开对话';

  @override
  String get authPhoneLabel => '手机号';

  @override
  String get authPhoneHint => '11 位手机号';

  @override
  String get authPhoneRequired => '请输入手机号';

  @override
  String get authPhoneInvalid => '请输入正确的手机号';

  @override
  String get authCodeLabel => '验证码';

  @override
  String get authCodeHint => '6 位验证码';

  @override
  String get authCodeRequired => '请输入验证码';

  @override
  String get authCodeWrongLength => '验证码需为 6 位';

  @override
  String get authTerms => '登录即表示同意《用户协议》和《隐私政策》。';

  @override
  String get authContinueWithGoogle => '使用 Google 登录';

  @override
  String get authOrDivider => '或';

  @override
  String errorGoogleSignInFailed(String error) {
    return 'Google 登录失败：$error';
  }

  @override
  String get profileTitle => '我的';

  @override
  String get profileNotSignedIn => '未登录';

  @override
  String get profileNoNickname => '未设置昵称';

  @override
  String get profileHeight => '身高';

  @override
  String get profileSex => '性别';

  @override
  String get profileBirthday => '生日';

  @override
  String get profileActivity => '活动水平';

  @override
  String get profileDailyCalorieTarget => '每日目标热量';

  @override
  String get profileWeight => '体重';

  @override
  String get profileTarget => '目标';

  @override
  String get profileBmi => 'BMI';

  @override
  String get profileNickname => '昵称';

  @override
  String get profileHeightCm => '身高 (cm)';

  @override
  String get profileWeightKg => '体重 (kg)';

  @override
  String get profileTargetKg => '目标 (kg)';

  @override
  String get profileActivityLevel => '活动水平';

  @override
  String get profileDailyCalorieTargetKcal => '每日目标热量 (kcal)';

  @override
  String get profileTargetHint => '估算：BMR × 活动系数 × 减脂系数（约 0.8）';

  @override
  String get sexMale => '男';

  @override
  String get sexFemale => '女';

  @override
  String get sexOther => '其他';

  @override
  String get activitySedentary => '久坐';

  @override
  String get activityLight => '轻度（每周 1-2 次）';

  @override
  String get activityModerate => '中度（每周 3-4 次）';

  @override
  String get activityHigh => '高度（每周 5-6 次）';

  @override
  String get activityVeryHigh => '极高（每天训练）';

  @override
  String get homeTodaySection => '今日';

  @override
  String get homeRecentSection => '最近';

  @override
  String get homeEmpty => '还没有记录。去「记录」页开始吧。';

  @override
  String homeFailedToLoad(String error) {
    return '加载失败：$error';
  }

  @override
  String get homeBudgetTarget => '目标';

  @override
  String get homeBudgetIn => '吃';

  @override
  String get homeBudgetOut => '烧';

  @override
  String homeBudgetLeft(String value) {
    return '剩余 $value';
  }

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int n) {
    return '$n 分钟前';
  }

  @override
  String timeDaysAgo(int n) {
    return '$n 天前';
  }

  @override
  String get timeYesterday => '昨天';

  @override
  String get timeToday => '今天';

  @override
  String get timeYesterdayCap => '昨天';

  @override
  String get logFoodTab => '饮食';

  @override
  String get logTrainingTab => '训练';

  @override
  String get logWeightTab => '体重';

  @override
  String get foodTitle => '饮食';

  @override
  String get foodEmpty => '还没有饮食记录。点右下角 + 开始。';

  @override
  String get foodLogSheetTitle => '添加饮食';

  @override
  String get foodEditSheetTitle => '编辑饮食';

  @override
  String get foodSectionAiEstimate => 'AI 估算';

  @override
  String get foodSectionFrequent => '常吃';

  @override
  String get foodSectionDetails => '详细信息';

  @override
  String get foodAiHint => '例：一碗米饭 200g、宫保鸡丁一份';

  @override
  String get foodAiEmptyWarn => '先描述一下吃了啥，例如「一碗米饭 200g」';

  @override
  String get foodName => '食物名 *';

  @override
  String get foodCalories => '热量 (kcal) *';

  @override
  String get foodPortion => '份量';

  @override
  String get foodUnitGram => 'g';

  @override
  String get foodUnitMl => 'ml';

  @override
  String get foodUnitServing => '份';

  @override
  String get foodUnitPiece => '个';

  @override
  String get foodMeal => '餐次';

  @override
  String get foodMacrosOptional => '营养素（可选）';

  @override
  String get foodProteinG => '蛋白 (g)';

  @override
  String get foodCarbsG => '碳水 (g)';

  @override
  String get foodFatG => '脂肪 (g)';

  @override
  String get foodTodayLabel => '今日';

  @override
  String foodMealCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 餐',
      one: '1 餐',
    );
    return '$_temp0';
  }

  @override
  String get foodMacroProtein => '蛋白';

  @override
  String get foodMacroCarbs => '碳水';

  @override
  String get foodMacroFat => '脂肪';

  @override
  String foodDayCalories(String value) {
    return '$value kcal';
  }

  @override
  String get foodNameRequired => '请输入食物名';

  @override
  String get foodCaloriesRequired => '请输入热量';

  @override
  String get foodDeleteTitle => '删除这条记录？';

  @override
  String foodBudgetUnder(String eaten, String remaining) {
    return '今日已吃 $eaten kcal · 剩余 $remaining';
  }

  @override
  String foodBudgetOver(String eaten, String over) {
    return '今日已吃 $eaten kcal · 超出 $over';
  }

  @override
  String get mealBreakfast => '早餐';

  @override
  String get mealLunch => '午餐';

  @override
  String get mealDinner => '晚餐';

  @override
  String get mealSnack => '加餐';

  @override
  String get mealOther => '其他';

  @override
  String get trainingTitle => '训练';

  @override
  String get trainingEmpty => '还没有训练记录。点右下角 + 开始。';

  @override
  String get trainingLogSheetTitle => '添加训练';

  @override
  String get trainingEditSheetTitle => '编辑训练';

  @override
  String get trainingType => '训练类型 *';

  @override
  String get trainingTypeHint => '例：卧推、跑步、HIIT';

  @override
  String get trainingDurationMin => '时长（分钟）*';

  @override
  String get trainingCaloriesBurned => '消耗 (kcal)';

  @override
  String get trainingIntensity => '强度';

  @override
  String get trainingDistanceKm => '距离 (km)';

  @override
  String get trainingNotes => '备注（可选）';

  @override
  String get trainingAiHint => '例：卧推 4×8 @ 80kg；跑 5km 25 分钟';

  @override
  String get trainingAiEmptyWarn => '先描述一下训练，例如「跑 5km 25 分钟」';

  @override
  String get trainingSectionFrequent => '常做';

  @override
  String get trainingTodayLabel => '今日';

  @override
  String trainingSessionCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 次',
      one: '1 次',
    );
    return '$_temp0';
  }

  @override
  String trainingDurationMinutes(int n) {
    return '$n 分钟';
  }

  @override
  String get trainingTypeRequired => '请输入训练类型';

  @override
  String get trainingDurationRequired => '请输入时长';

  @override
  String get trainingDeleteTitle => '删除这次训练？';

  @override
  String trainingBurnedToast(String calories, int minutes) {
    return '今日消耗 $calories kcal · $minutes 分钟';
  }

  @override
  String get intensityLight => '轻度';

  @override
  String get intensityModerate => '中等';

  @override
  String get intensityHard => '高强度';

  @override
  String get weightTitle => '体重';

  @override
  String get weightEmpty => '还没有称重记录。点右下角 + 开始。';

  @override
  String get weightLogSheetTitle => '添加称重';

  @override
  String get weightEditSheetTitle => '编辑称重';

  @override
  String get weightValueKg => '体重 (kg) *';

  @override
  String get weightNote => '备注（可选）';

  @override
  String get weightValueRequired => '请输入体重';

  @override
  String get weightDeleteTitle => '删除这条称重？';

  @override
  String get weightWeighIn => '称重';

  @override
  String get weightTrendSection => '体重趋势';

  @override
  String get weightHistorySection => '历史记录';

  @override
  String get weightStatLow => '最低';

  @override
  String get weightStatHigh => '最高';

  @override
  String get weightStatChange => '变化';

  @override
  String get weightBodyFatPct => '体脂率 (%)';

  @override
  String get weightMuscleKg => '肌肉 (kg)';

  @override
  String get weightWaterPct => '水分 (%)';

  @override
  String get weightMoreLabel => '更多（体脂 / 肌肉 / 水分 / 备注，可选）';

  @override
  String weightMeasuredOn(String date) {
    return '测量日期：$date';
  }

  @override
  String get weightAddDialogTitle => '添加称重';

  @override
  String get weightAiHint => '随便写，例如「68.5kg 早」「67 体脂 22」';

  @override
  String get weightAiEmptyWarn => '随便写，例如「68.5kg 早」「67 体脂 22」';

  @override
  String get actionAdd => '添加';

  @override
  String get actionParse => '解析';

  @override
  String errorParseFailed(String error) {
    return '解析失败：$error';
  }

  @override
  String get coachTitle => '教练';

  @override
  String get coachEmptyTitle => '开始跟教练聊聊';

  @override
  String get coachEmptySubtitle => '问 macros、训练，或者下一餐吃什么。';

  @override
  String get coachInputHint => '给教练发消息…';

  @override
  String get sheetCtxEstimate => '估算';

  @override
  String sheetTimeFormat(int month, int day, String hour, String minute) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get voiceListening => '正在听…';

  @override
  String get voiceNotAvailable => '当前环境不支持语音输入';

  @override
  String get voicePermissionDenied => '麦克风权限被拒';

  @override
  String get voiceTapToSpeak => '点击语音输入';

  @override
  String get voiceTapToStop => '点击停止';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageDescription => '同时控制界面语言和 AI 教练的回复语言。';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get profileSettings => '设置';
}
