class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String otpVerify = '/otp-verify';
  static const String onboarding = '/onboarding';

  // Parent routes
  static const String parent = '/parent';
  static const String parentChildren = '/parent/children';
  static const String parentTasks = '/parent/tasks';
  static const String parentReports = '/parent/reports';
  static const String parentReportDetail = '/parent/reports/detail';
  static const String parentReportCompare = '/parent/reports/compare';
  static const String parentTriggers = '/parent/triggers';
  static const String parentAi = '/parent/ai';
  static const String parentSettings = '/parent/settings';
  static const String parentInviteChild = '/parent/children/invite';

  // Local AI Control Center routes (Parent & Shared)
  static const String localAiSettings = '/parent/settings/ai';
  static const String modelManager = '/parent/settings/ai/models';
  static const String promptManager = '/parent/settings/ai/prompts';
  static const String promptEditor = '/parent/settings/ai/prompts/edit';
  static const String promptComparison = '/parent/settings/ai/prompts/compare';
  static const String aiDiagnostics = '/parent/settings/ai/diagnostics';
  static const String parentPrivacyCenter = '/parent/settings/privacy';

  // Child routes
  static const String child = '/child';
  static const String childInsights = '/child/insights';
  static const String childMissions = '/child/missions';
  static const String childGoals = '/child/goals';
  static const String childProgress = '/child/progress';
  static const String childAi = '/child/ai';
  static const String childSettings = '/child/settings';
  static const String childJoinFamily = '/child/join';
  static const String childAiSettings = '/child/settings/ai';
  static const String childModelManager = '/child/settings/ai/models';
  static const String childPromptManager = '/child/settings/ai/prompts';
  static const String childAiDiagnostics = '/child/settings/ai/diagnostics';
  static const String childPrivacyCenter = '/child/settings/privacy';
  static const String usageAccessSetup = '/usage-access-setup';
}
