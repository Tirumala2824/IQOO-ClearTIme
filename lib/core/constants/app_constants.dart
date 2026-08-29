class AppConstants {
  AppConstants._();

  static const String appName = 'ClearTime';
  static const String appTagline =
      'Mindful screen habits for flourishing families';

  // Scheme & Deep Links
  static const String appScheme = 'cleartime';
  static const String authCallbackHost = 'auth-callback';
  static const String inviteHost = 'invite';
  static const String authRedirectUrl = 'cleartime://auth-callback';

  // Invitation configuration
  static const int invitationCodeLength = 8;
  static const Duration invitationExpiry = Duration(hours: 48);

  // Timeouts
  static const Duration defaultTimeout = Duration(seconds: 15);
}
