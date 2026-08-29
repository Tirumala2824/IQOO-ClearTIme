class Validators {
  Validators._();

  /// Validates international or local phone numbers (E.164 or digits).
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final clean = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final phoneRegex = RegExp(r'^\+?[1-9]\d{7,14}$');
    if (!phoneRegex.hasMatch(clean)) {
      return 'Enter a valid phone number (e.g. +1234567890)';
    }
    return null;
  }

  /// Validates OTP code (typically 6 digits).
  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Verification code is required';
    }
    final clean = value.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(clean)) {
      return 'Verification code must be 6 digits';
    }
    return null;
  }

  /// Validates family name.
  static String? validateFamilyName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Family name cannot be empty';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Family name must be at least 2 characters';
    }
    if (trimmed.length > 50) {
      return 'Family name cannot exceed 50 characters';
    }
    return null;
  }

  /// Validates child nickname.
  static String? validateChildNickname(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nickname is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Nickname must be at least 2 characters';
    }
    if (trimmed.length > 30) {
      return 'Nickname cannot exceed 30 characters';
    }
    return null;
  }

  /// Validates child age (optional or 3-18).
  static String? validateChildAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // optional
    }
    final age = int.tryParse(value.trim());
    if (age == null || age < 1 || age > 21) {
      return 'Enter a realistic age between 1 and 21';
    }
    return null;
  }

  /// Validates invitation code (8 alphanumeric characters).
  static String? validateInvitationCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Invitation code is required';
    }
    final clean = value.trim().toUpperCase();
    if (clean.length != 8) {
      return 'Invitation code must be 8 characters';
    }
    if (!RegExp(r'^[A-Z0-9]{8}$').hasMatch(clean)) {
      return 'Invalid invitation code format';
    }
    return null;
  }

  /// Validates report title.
  static String? validateReportTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Report title is required';
    }
    if (value.trim().length > 60) {
      return 'Title cannot exceed 60 characters';
    }
    return null;
  }

  /// Validates trigger threshold in minutes.
  static String? validateThresholdMinutes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Threshold minutes required';
    }
    final mins = int.tryParse(value.trim());
    if (mins == null || mins < 5 || mins > 1440) {
      return 'Threshold must be between 5 and 1440 minutes';
    }
    return null;
  }
}
