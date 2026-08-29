import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../../core/providers/providers.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../data/models/family_model.dart';
import '../../../data/repositories/family_repository.dart';

class ChildDashboardState {
  final ChildProfile? profile;
  final Family? family;
  final List<Map<String, dynamic>> missions;
  final bool isLoading;
  final String? errorMessage;

  const ChildDashboardState({
    this.profile,
    this.family,
    this.missions = const [
      {
        'id': 'm1',
        'title': 'Mindful Evening Wind-Down',
        'description':
            'Enjoy 30 minutes of screen-free relaxing time before bed.',
        'points': 50,
        'isCompleted': false,
        'category': 'Rest & Recovery',
      },
      {
        'id': 'm2',
        'title': 'Outdoor Sunlight Break',
        'description': 'Spend 20 mindful minutes playing or walking outside.',
        'points': 40,
        'isCompleted': true,
        'category': 'Physical Activity',
      },
      {
        'id': 'm3',
        'title': 'Deep Focus Study Sprint',
        'description': 'Complete a 25-minute undistracted learning session.',
        'points': 60,
        'isCompleted': false,
        'category': 'Focus & Learning',
      },
      {
        'id': 'm4',
        'title': 'Screen-Free Family Meal',
        'description': 'Share a healthy meal and conversation with family.',
        'points': 45,
        'isCompleted': false,
        'category': 'Family Connection',
      },
    ],
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasFamily => family != null;
  int get completedMissionsCount =>
      missions.where((m) => m['isCompleted'] == true).length;
  int get totalPoints => missions
      .where((m) => m['isCompleted'] == true)
      .fold(0, (sum, m) => sum + (m['points'] as int));

  ChildDashboardState copyWith({
    ChildProfile? profile,
    Family? family,
    List<Map<String, dynamic>>? missions,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChildDashboardState(
      profile: profile ?? this.profile,
      family: family ?? this.family,
      missions: missions ?? this.missions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChildDashboardController extends StateNotifier<ChildDashboardState> {
  final FamilyRepository _familyRepository;

  ChildDashboardController(this._familyRepository)
      : super(const ChildDashboardState());

  Future<void> loadDashboard(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _familyRepository.getChildProfileForUser(userId);
      Family? family;
      if (profile != null) {
        family = await _familyRepository.getFamilyForUser(userId);
      }
      state = state.copyWith(
        profile: profile,
        family: family,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void toggleMission(String missionId) {
    final updatedMissions = state.missions.map((m) {
      if (m['id'] == missionId) {
        return {
          ...m,
          'isCompleted': !(m['isCompleted'] as bool),
        };
      }
      return m;
    }).toList();

    state = state.copyWith(missions: updatedMissions);
  }
}

final childDashboardControllerProvider =
    StateNotifierProvider<ChildDashboardController, ChildDashboardState>((ref) {
  final familyRepo = ref.watch(familyRepositoryProvider);
  return ChildDashboardController(familyRepo);
});
