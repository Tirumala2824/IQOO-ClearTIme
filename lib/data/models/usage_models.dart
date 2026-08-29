/// Represents a single application usage session or record captured locally on device.
class UsageRecord {
  final String id;
  final String packageName;
  final String appName;
  final String category;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;

  const UsageRecord({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
  });

  int get durationMinutes => (durationSeconds / 60).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'packageName': packageName,
        'appName': appName,
        'category': category,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationSeconds': durationSeconds,
      };

  factory UsageRecord.fromJson(Map<String, dynamic> json) => UsageRecord(
        id: json['id'] as String,
        packageName: json['packageName'] as String,
        appName: json['appName'] as String,
        category: json['category'] as String? ?? 'General',
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        durationSeconds: (json['durationSeconds'] as num).toInt(),
      );
}

/// Aggregated usage summary for a day.
class DailyUsage {
  final DateTime date;
  final int totalMinutes;
  final int focusMinutes;
  final int unlockCount;
  final Map<String, int> categoryMinutes; // Category -> total minutes
  final List<AppUsageSummary> topApps;

  const DailyUsage({
    required this.date,
    required this.totalMinutes,
    this.focusMinutes = 0,
    this.unlockCount = 0,
    this.categoryMinutes = const {},
    this.topApps = const [],
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'totalMinutes': totalMinutes,
        'focusMinutes': focusMinutes,
        'unlockCount': unlockCount,
        'categoryMinutes': categoryMinutes,
        'topApps': topApps.map((a) => a.toJson()).toList(),
      };

  factory DailyUsage.fromJson(Map<String, dynamic> json) => DailyUsage(
        date: DateTime.parse(json['date'] as String),
        totalMinutes: (json['totalMinutes'] as num).toInt(),
        focusMinutes: (json['focusMinutes'] as num? ?? 0).toInt(),
        unlockCount: (json['unlockCount'] as num? ?? 0).toInt(),
        categoryMinutes: Map<String, int>.from(json['categoryMinutes'] as Map? ?? {}),
        topApps: (json['topApps'] as List<dynamic>? ?? [])
            .map((e) => AppUsageSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Summary of an individual app's usage.
class AppUsageSummary {
  final String packageName;
  final String appName;
  final String category;
  final int durationMinutes;
  final int launchCount;

  const AppUsageSummary({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.durationMinutes,
    this.launchCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'category': category,
        'durationMinutes': durationMinutes,
        'launchCount': launchCount,
      };

  factory AppUsageSummary.fromJson(Map<String, dynamic> json) =>
      AppUsageSummary(
        packageName: json['packageName'] as String,
        appName: json['appName'] as String,
        category: json['category'] as String? ?? 'General',
        durationMinutes: (json['durationMinutes'] as num).toInt(),
        launchCount: (json['launchCount'] as num? ?? 0).toInt(),
      );
}

/// Category usage distribution.
class CategoryUsage {
  final String category;
  final int totalMinutes;
  final double percentage;
  final int appCount;

  const CategoryUsage({
    required this.category,
    required this.totalMinutes,
    required this.percentage,
    this.appCount = 1,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'totalMinutes': totalMinutes,
        'percentage': percentage,
        'appCount': appCount,
      };

  factory CategoryUsage.fromJson(Map<String, dynamic> json) => CategoryUsage(
        category: json['category'] as String,
        totalMinutes: (json['totalMinutes'] as num).toInt(),
        percentage: (json['percentage'] as num).toDouble(),
        appCount: (json['appCount'] as num? ?? 1).toInt(),
      );
}

/// Entry in the usage timeline.
class UsageTimelineEntry {
  final String packageName;
  final String appName;
  final String category;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;

  const UsageTimelineEntry({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'category': category,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationMinutes': durationMinutes,
      };

  factory UsageTimelineEntry.fromJson(Map<String, dynamic> json) =>
      UsageTimelineEntry(
        packageName: json['packageName'] as String,
        appName: json['appName'] as String,
        category: json['category'] as String? ?? 'General',
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        durationMinutes: (json['durationMinutes'] as num).toInt(),
      );
}

/// Dedicated focus session record.
class FocusSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int targetMinutes;
  final int actualMinutes;
  final bool isCompleted;
  final String title;
  final String category;

  const FocusSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.targetMinutes,
    required this.actualMinutes,
    required this.isCompleted,
    this.title = 'Focus Session',
    this.category = 'Learning',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'targetMinutes': targetMinutes,
        'actualMinutes': actualMinutes,
        'isCompleted': isCompleted,
        'title': title,
        'category': category,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        targetMinutes: (json['targetMinutes'] as num).toInt(),
        actualMinutes: (json['actualMinutes'] as num).toInt(),
        isCompleted: json['isCompleted'] as bool? ?? false,
        title: json['title'] as String? ?? 'Focus Session',
        category: json['category'] as String? ?? 'Learning',
      );
}

/// High-level today usage summary for the child dashboard.
class UsageSummary {
  final int totalMinutes;
  final int focusMinutes;
  final int breakCount;
  final int screenUnlockCount;
  final double changePercentageFromYesterday;
  final List<CategoryUsage> categories;
  final List<AppUsageSummary> topApps;

  const UsageSummary({
    required this.totalMinutes,
    required this.focusMinutes,
    required this.breakCount,
    this.screenUnlockCount = 0,
    this.changePercentageFromYesterday = 0.0,
    this.categories = const [],
    this.topApps = const [],
  });

  String get formattedTotalTime {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedFocusTime {
    final hours = focusMinutes ~/ 60;
    final minutes = focusMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Map<String, dynamic> toJson() => {
        'totalMinutes': totalMinutes,
        'focusMinutes': focusMinutes,
        'breakCount': breakCount,
        'screenUnlockCount': screenUnlockCount,
        'changePercentageFromYesterday': changePercentageFromYesterday,
        'categories': categories.map((c) => c.toJson()).toList(),
        'topApps': topApps.map((a) => a.toJson()).toList(),
      };

  factory UsageSummary.fromJson(Map<String, dynamic> json) => UsageSummary(
        totalMinutes: (json['totalMinutes'] as num).toInt(),
        focusMinutes: (json['focusMinutes'] as num? ?? 0).toInt(),
        breakCount: (json['breakCount'] as num? ?? 0).toInt(),
        screenUnlockCount: (json['screenUnlockCount'] as num? ?? 0).toInt(),
        changePercentageFromYesterday:
            (json['changePercentageFromYesterday'] as num? ?? 0.0).toDouble(),
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((c) => CategoryUsage.fromJson(c as Map<String, dynamic>))
            .toList(),
        topApps: (json['topApps'] as List<dynamic>? ?? [])
            .map((a) => AppUsageSummary.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

/// Stored daily aggregate in local database for fast retrieval and retention management.
class DailyAggregate {
  final String dateString; // YYYY-MM-DD
  final int totalMinutes;
  final int focusMinutes;
  final int breakCount;
  final int unlockCount;
  final Map<String, int> categoryMinutes;
  final DateTime calculatedAt;

  const DailyAggregate({
    required this.dateString,
    required this.totalMinutes,
    required this.focusMinutes,
    required this.breakCount,
    required this.unlockCount,
    required this.categoryMinutes,
    required this.calculatedAt,
  });

  DateTime get date => DateTime.tryParse(dateString) ?? calculatedAt;

  Map<String, dynamic> toJson() => {
        'dateString': dateString,
        'totalMinutes': totalMinutes,
        'focusMinutes': focusMinutes,
        'breakCount': breakCount,
        'unlockCount': unlockCount,
        'categoryMinutes': categoryMinutes,
        'calculatedAt': calculatedAt.toIso8601String(),
      };

  factory DailyAggregate.fromJson(Map<String, dynamic> json) => DailyAggregate(
        dateString: json['dateString'] as String,
        totalMinutes: (json['totalMinutes'] as num).toInt(),
        focusMinutes: (json['focusMinutes'] as num? ?? 0).toInt(),
        breakCount: (json['breakCount'] as num? ?? 0).toInt(),
        unlockCount: (json['unlockCount'] as num? ?? 0).toInt(),
        categoryMinutes:
            Map<String, int>.from(json['categoryMinutes'] as Map? ?? {}),
        calculatedAt: DateTime.parse(json['calculatedAt'] as String),
      );
}
