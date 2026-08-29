class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String otpVerify = '/otp-verify';
  static const String onboarding = '/onboarding';

  // Parent routes
  static const String parent = '/parent';
  static const String parentChildren = '/parent/children';
  static const String parentReports = '/parent/reports';
  static const String parentTriggers = '/parent/triggers';
  static const String parentAi = '/parent/ai';
  static const String parentSettings = '/parent/settings';
  static const String parentInviteChild = '/parent/children/invite';

  // Child routes
  static const String child = '/child';
  static const String childInsights = '/child/insights';
  static const String childMissions = '/child/missions';
  static const String childGoals = '/child/goals';
  static const String childProgress = '/child/progress';
  static const String childAi = '/child/ai';
  static const String childSettings = '/child/settings';
  static const String childJoinFamily = '/child/join';
}
