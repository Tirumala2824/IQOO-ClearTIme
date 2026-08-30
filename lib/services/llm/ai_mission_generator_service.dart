import 'dart:convert';
import 'dart:math';
import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/models/child_profile_model.dart';
import '../../data/models/usage_models.dart';

class GeneratedMissionIdea {
  final String title;
  final String description;
  final int targetMinutes;
  final String? suggestedReward;
  final String category;

  const GeneratedMissionIdea({
    required this.title,
    required this.description,
    required this.targetMinutes,
    this.suggestedReward,
    this.category = 'Offline Balance',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'targetMinutes': targetMinutes,
        'suggestedReward': suggestedReward,
        'category': category,
      };

  factory GeneratedMissionIdea.fromJson(Map<String, dynamic> json) {
    return GeneratedMissionIdea(
      title: json['title'] as String? ?? 'Mindful Offline Activity',
      description: json['description'] as String? ??
          'Spend some screen-free creative or outdoor time.',
      targetMinutes: (json['targetMinutes'] as num?)?.toInt() ?? 30,
      suggestedReward: json['suggestedReward'] as String?,
      category: json['category'] as String? ?? 'Offline Balance',
    );
  }
}

class AiMissionGeneratorService {
  final LocalLLMProvider _llmProvider;

  const AiMissionGeneratorService({
    required LocalLLMProvider llmProvider,
  }) : _llmProvider = llmProvider;

  static const List<GeneratedMissionIdea> _fallbackIdeas = [
    GeneratedMissionIdea(
      title: 'LEGO / Craft Castle Challenge',
      description: 'Build a fortress or creative structure using blocks, clay, or paper without checking screens.',
      targetMinutes: 30,
      suggestedReward: '15 mins bonus weekend playtime',
      category: 'Creativity',
    ),
    GeneratedMissionIdea(
      title: 'Outdoor Adventure & Bike Sprint',
      description: 'Go outside for a walk, bicycle ride, or outdoor sport in the fresh air.',
      targetMinutes: 45,
      suggestedReward: 'Pick tonight\'s family dinner or snack',
      category: 'Outdoor & Health',
    ),
    GeneratedMissionIdea(
      title: 'Book & Comic Reading Haven',
      description: 'Read 20 pages of your favorite book, graphic novel, or comic.',
      targetMinutes: 25,
      suggestedReward: 'New sticker pack or bedtime story pass',
      category: 'Focus & Learning',
    ),
    GeneratedMissionIdea(
      title: 'Kitchen Master Helper',
      description: 'Help prepare a fresh fruit salad or evening family snack in the kitchen.',
      targetMinutes: 20,
      suggestedReward: 'First scoop of ice cream / dessert',
      category: 'Family & Chores',
    ),
    GeneratedMissionIdea(
      title: 'Origami & Drawing Quest',
      description: 'Draw a comic superhero or fold 3 origami animals from scrap paper.',
      targetMinutes: 25,
      suggestedReward: 'Display artwork on family showcase',
      category: 'Creativity',
    ),
  ];

  /// Generates a list of tailored mission ideas for a parent to assign.
  Future<List<GeneratedMissionIdea>> generateMissionsForParent({
    required ChildProfile child,
    UsageSummary? usage,
    int count = 3,
  }) async {
    final nickname = child.nickname.isNotEmpty ? child.nickname : 'your child';
    final ageStr = child.age != null ? 'aged ${child.age}' : '';
    final screenMins = usage?.totalMinutes ?? 0;
    final focusMins = usage?.focusMinutes ?? 0;

    final prompt = StringBuffer();
    prompt.writeln('You are an intelligent, encouraging AI Parenting Assistant.');
    prompt.writeln('Generate $count creative, screen-free offline activity missions for $nickname ($ageStr).');
    prompt.writeln('Context: Today $nickname had $screenMins minutes of screen time with $focusMins minutes focus.');
    prompt.writeln('Categories could include: Creativity, Outdoor/Sport, Focus/Reading, Chores/Help, Mindfulness.');
    prompt.writeln('Respond ONLY with a JSON array of objects with keys: "title", "description", "targetMinutes" (int 15-60), "suggestedReward" (string), "category" (string).');
    prompt.writeln('Example JSON format:');
    prompt.writeln('[{"title":"Build a LEGO Castle","description":"Construct a tower with blocks.","targetMinutes":30,"suggestedReward":"Special snack","category":"Creativity"}]');

    try {
      final isAvailable = await _llmProvider.isAvailable();
      if (!isAvailable) {
        return _getRandomFallbacks(count);
      }

      final rawResponse = await _llmProvider.generate(prompt: prompt.toString());
      final parsed = _extractJsonArray(rawResponse);
      if (parsed.isNotEmpty) {
        return parsed.map((item) => GeneratedMissionIdea.fromJson(item)).toList();
      }
    } catch (_) {}

    return _getRandomFallbacks(count);
  }

  /// Generates a single personalized mission for a child on-demand driven by Android usage stats.
  Future<GeneratedMissionIdea> generateMissionForChild({
    required String childNickname,
    UsageSummary? usage,
    String? requestTheme,
  }) async {
    final screenMins = usage?.totalMinutes ?? 0;
    final focusMins = usage?.focusMinutes ?? 0;
    final topCats = usage?.categories.map((c) => '${c.category} (${c.totalMinutes}m)').join(', ') ?? '';

    final prompt = StringBuffer();
    prompt.writeln('You are ClearTime AI Buddy, an encouraging on-device buddy for $childNickname.');
    prompt.writeln('Create one fun, exciting screen-free offline challenge mission designed to counterbalance today\'s screen time.');
    if (requestTheme != null && requestTheme.isNotEmpty) {
      prompt.writeln('Requested Theme or User Context: $requestTheme');
    }
    prompt.writeln('Today\'s Screen Time: $screenMins min (Focus: $focusMins min).');
    if (topCats.isNotEmpty) {
      prompt.writeln('Today\'s Top App Categories: $topCats');
    }
    prompt.writeln('Respond ONLY with a valid JSON object with keys: "title", "description", "targetMinutes" (int between 15 and 45), "suggestedReward" (string), "category" (e.g. Outdoor, Creativity, Health, Focus, Family).');
    prompt.writeln('Example: {"title": "Backyard Obstacle Dash", "description": "Set up a 3-station obstacle course outside and complete 5 laps.", "targetMinutes": 20, "suggestedReward": "15 min bonus playtime", "category": "Outdoor & Health"}');

    try {
      final isAvailable = await _llmProvider.isAvailable();
      if (!isAvailable) {
        return _getRandomFallbacks(1).first;
      }

      final rawResponse = await _llmProvider.generate(prompt: prompt.toString());
      final parsed = _extractJsonObject(rawResponse);
      if (parsed != null) {
        return GeneratedMissionIdea.fromJson(parsed);
      }
    } catch (_) {}

    return _getRandomFallbacks(1).first;
  }

  List<GeneratedMissionIdea> _getRandomFallbacks(int count) {
    final list = List<GeneratedMissionIdea>.from(_fallbackIdeas);
    list.shuffle(Random());
    return list.take(count).toList();
  }

  List<Map<String, dynamic>> _extractJsonArray(String raw) {
    try {
      final start = raw.indexOf('[');
      final end = raw.lastIndexOf(']');
      if (start != -1 && end != -1 && end > start) {
        final jsonString = raw.substring(start, end + 1);
        final decoded = jsonDecode(jsonString);
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic>? _extractJsonObject(String raw) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonString = raw.substring(start, end + 1);
        final decoded = jsonDecode(jsonString);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }
}
