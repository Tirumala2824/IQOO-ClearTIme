/// Retention configuration defining how long granular raw usage and daily aggregates
/// are kept securely on the local device.
class RetentionConfig {
  /// Maximum number of days to keep granular raw usage session records on-device.
  /// Records older than this are automatically deleted during retention cleanup.
  final int rawUsageRetentionDays;

  /// Maximum number of days to keep daily aggregates.
  final int aggregateRetentionDays;

  /// Maximum number of reflections to keep locally.
  final int maxReflectionsStored;

  const RetentionConfig({
    this.rawUsageRetentionDays = 30,
    this.aggregateRetentionDays = 90,
    this.maxReflectionsStored = 365,
  });

  static const RetentionConfig standard = RetentionConfig();
}
