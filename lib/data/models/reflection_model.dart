enum ReflectionMood {
  productive,
  relaxing,
  distracting,
  mixed,
}

extension ReflectionMoodExtension on ReflectionMood {
  String get label {
    switch (this) {
      case ReflectionMood.productive:
        return 'Productive';
      case ReflectionMood.relaxing:
        return 'Relaxing';
      case ReflectionMood.distracting:
        return 'Distracting';
      case ReflectionMood.mixed:
        return 'Mixed';
    }
  }

  String get emoji {
    switch (this) {
      case ReflectionMood.productive:
        return '🚀';
      case ReflectionMood.relaxing:
        return '🌿';
      case ReflectionMood.distracting:
        return '🌀';
      case ReflectionMood.mixed:
        return '⚖️';
    }
  }
}

class DailyReflection {
  final String id;
  final DateTime date;
  final ReflectionMood mood;
  final String? notes;
  final DateTime createdAt;

  const DailyReflection({
    required this.id,
    required this.date,
    required this.mood,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'mood': mood.name,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DailyReflection.fromJson(Map<String, dynamic> json) =>
      DailyReflection(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        mood: ReflectionMood.values.firstWhere(
          (m) => m.name == json['mood'],
          orElse: () => ReflectionMood.productive,
        ),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
