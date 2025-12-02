import 'package:shared_preferences/shared_preferences.dart';

/// Actionable preference options that influence suggestions based on context
class PreferenceOption {
  final String id;
  final String label;
  final String description;
  final PreferenceCategory category;
  /// Rooms where this preference is most relevant
  final List<String> relevantRooms;
  /// Time buckets when this preference applies: morning, afternoon, evening, night
  final List<String> relevantTimes;
  /// The action label to add to suggestions (maps to ActionService)
  final String actionLabel;

  const PreferenceOption({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
    required this.relevantRooms,
    required this.relevantTimes,
    required this.actionLabel,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'relevantRooms': relevantRooms,
    'relevantTimes': relevantTimes,
    'actionLabel': actionLabel,
  };
}

enum PreferenceCategory {
  fitness,
  wellness,
  productivity,
  entertainment,
  cooking,
}

/// List of actionable preferences with context awareness
const List<PreferenceOption> predefinedPreferences = [
  // Fitness
  PreferenceOption(
    id: 'morning_exercise',
    label: 'Morning Exercise',
    description: 'Get workout suggestions in the morning',
    category: PreferenceCategory.fitness,
    relevantRooms: ['Living Room', 'Bedroom', 'Gym'],
    relevantTimes: ['morning'],
    actionLabel: 'Morning workout video',
  ),
  PreferenceOption(
    id: 'evening_workout',
    label: 'Evening Workout',
    description: 'Exercise reminders in the evening',
    category: PreferenceCategory.fitness,
    relevantRooms: ['Living Room', 'Bedroom', 'Gym'],
    relevantTimes: ['evening'],
    actionLabel: 'Evening workout video',
  ),
  PreferenceOption(
    id: 'desk_stretches',
    label: 'Desk Stretches',
    description: 'Stretch reminders while working',
    category: PreferenceCategory.fitness,
    relevantRooms: ['Office'],
    relevantTimes: ['morning', 'afternoon'],
    actionLabel: 'Quick stretches',
  ),

  // Wellness
  PreferenceOption(
    id: 'morning_meditation',
    label: 'Morning Meditation',
    description: 'Start your day with mindfulness',
    category: PreferenceCategory.wellness,
    relevantRooms: ['Bedroom', 'Living Room'],
    relevantTimes: ['morning'],
    actionLabel: 'Morning meditation',
  ),
  PreferenceOption(
    id: 'evening_meditation',
    label: 'Evening Wind-down',
    description: 'Relaxation before bed',
    category: PreferenceCategory.wellness,
    relevantRooms: ['Bedroom', 'Living Room'],
    relevantTimes: ['evening', 'night'],
    actionLabel: 'Evening meditation',
  ),
  PreferenceOption(
    id: 'sleep_sounds',
    label: 'Sleep Sounds',
    description: 'Ambient sounds for better sleep',
    category: PreferenceCategory.wellness,
    relevantRooms: ['Bedroom'],
    relevantTimes: ['night'],
    actionLabel: 'Play sleep sounds',
  ),
  PreferenceOption(
    id: 'evening_journaling',
    label: 'Evening Journaling',
    description: 'Reflect on your day with journaling prompts',
    category: PreferenceCategory.wellness,
    relevantRooms: ['Bedroom'],
    relevantTimes: ['evening'],
    actionLabel: 'Open journaling',
  ),

  // Productivity
  PreferenceOption(
    id: 'focus_music',
    label: 'Focus Music',
    description: 'Concentration music while working',
    category: PreferenceCategory.productivity,
    relevantRooms: ['Office'],
    relevantTimes: ['morning', 'afternoon'],
    actionLabel: 'Play focus music',
  ),
  PreferenceOption(
    id: 'morning_news',
    label: 'Morning News',
    description: 'Catch up on news in the morning',
    category: PreferenceCategory.productivity,
    relevantRooms: ['Kitchen', 'Living Room', 'Dining Room'],
    relevantTimes: ['morning'],
    actionLabel: 'Play morning news',
  ),
  PreferenceOption(
    id: 'calendar_check',
    label: 'Calendar Review',
    description: 'Check your schedule in the morning',
    category: PreferenceCategory.productivity,
    relevantRooms: ['Bedroom', 'Office', 'Kitchen'],
    relevantTimes: ['morning'],
    actionLabel: 'Check calendar',
  ),
  PreferenceOption(
    id: 'task_review',
    label: 'Task Review',
    description: 'Review tasks during work hours',
    category: PreferenceCategory.productivity,
    relevantRooms: ['Office'],
    relevantTimes: ['morning', 'afternoon', 'evening'],
    actionLabel: 'Check tasks',
  ),

  // Entertainment
  PreferenceOption(
    id: 'relaxing_music',
    label: 'Relaxing Music',
    description: 'Unwind with calming music',
    category: PreferenceCategory.entertainment,
    relevantRooms: ['Living Room', 'Bedroom', 'Bathroom'],
    relevantTimes: ['evening', 'night'],
    actionLabel: 'Play relaxing music',
  ),
  PreferenceOption(
    id: 'workout_music',
    label: 'Workout Music',
    description: 'Energizing music for exercise',
    category: PreferenceCategory.entertainment,
    relevantRooms: ['Gym', 'Living Room'],
    relevantTimes: ['morning', 'afternoon', 'evening'],
    actionLabel: 'Play workout music',
  ),

  // Cooking
  PreferenceOption(
    id: 'cooking_recipes',
    label: 'Recipe Ideas',
    description: 'Get recipe suggestions while cooking',
    category: PreferenceCategory.cooking,
    relevantRooms: ['Kitchen'],
    relevantTimes: ['morning', 'afternoon', 'evening'],
    actionLabel: 'Check recipes',
  ),
  PreferenceOption(
    id: 'cooking_music',
    label: 'Cooking Playlist',
    description: 'Music while preparing meals',
    category: PreferenceCategory.cooking,
    relevantRooms: ['Kitchen'],
    relevantTimes: ['morning', 'afternoon', 'evening'],
    actionLabel: 'Play cooking playlist',
  ),
  PreferenceOption(
    id: 'cooking_timer',
    label: 'Cooking Timers',
    description: 'Quick timer access in kitchen',
    category: PreferenceCategory.cooking,
    relevantRooms: ['Kitchen'],
    relevantTimes: ['morning', 'afternoon', 'evening'],
    actionLabel: 'Set timer 15min',
  ),
];

/// Manages user preferences persistence
class UserPrefsManager {
  // Use different keys to avoid conflicts
  static const _enabledIdsKey = 'enabled_pref_ids';
  static const _customPrefsKey = 'custom_user_prefs';
  static const _formattedPrefsKey = 'user_prefs'; // For API consumption

  /// Load enabled preference IDs
  static Future<Set<String>> loadEnabledPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_enabledIdsKey);
      return list?.toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Load custom preferences
  static Future<List<String>> loadCustomPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString(_customPrefsKey);
      if (custom != null && custom.isNotEmpty) {
        return custom.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Save enabled preference IDs
  static Future<void> saveEnabledPrefs(Set<String> enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_enabledIdsKey, enabled.toList());
      // Also save formatted list for API
      await _saveFormattedPrefs(prefs, enabled);
    } catch (_) {
      // Ignore errors
    }
  }

  /// Save custom preferences
  static Future<void> saveCustomPrefs(List<String> custom) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customPrefsKey, custom.join(','));
      // Update formatted prefs
      final enabled = (prefs.getStringList(_enabledIdsKey) ?? []).toSet();
      await _saveFormattedPrefs(prefs, enabled, custom);
    } catch (_) {
      // Ignore errors
    }
  }

  /// Save formatted preferences list for API consumption
  /// This saves the full preference data as JSON for the backend
  static Future<void> _saveFormattedPrefs(
    SharedPreferences prefs,
    Set<String> enabled, [
    List<String>? custom,
  ]) async {
    final formatted = <String>[];

    // Add enabled predefined preferences by ID (backend will look these up)
    for (final pref in predefinedPreferences) {
      if (enabled.contains(pref.id)) {
        formatted.add(pref.id);
      }
    }

    // Add custom preferences
    if (custom != null) {
      formatted.addAll(custom.map((c) => 'custom:$c'));
    } else {
      final existingCustom = prefs.getString(_customPrefsKey);
      if (existingCustom != null && existingCustom.isNotEmpty) {
        formatted.addAll(
          existingCustom.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).map((c) => 'custom:$c'),
        );
      }
    }

    await prefs.setStringList(_formattedPrefsKey, formatted);
  }

  /// Get all preferences as a formatted list for the API
  static Future<List<String>> getFormattedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_formattedPrefsKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Get the full preference objects for enabled preferences
  static Future<List<PreferenceOption>> getEnabledPreferenceObjects() async {
    final enabledIds = await loadEnabledPrefs();
    return predefinedPreferences.where((p) => enabledIds.contains(p.id)).toList();
  }
}
