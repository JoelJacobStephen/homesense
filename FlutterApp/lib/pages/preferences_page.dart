import 'package:flutter/material.dart';
import '../models/user_prefs.dart';

class PreferencesPage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  
  const PreferencesPage({super.key, this.onOpenDrawer});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  Set<String> _enabledPrefs = {};
  Set<String> _initialPrefs = {}; // Track initial state to detect changes
  List<String> _customPrefs = [];
  List<String> _initialCustomPrefs = [];
  final TextEditingController _customController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (_enabledPrefs.length != _initialPrefs.length) return true;
    if (!_enabledPrefs.containsAll(_initialPrefs)) return true;
    if (_customPrefs.length != _initialCustomPrefs.length) return true;
    for (int i = 0; i < _customPrefs.length; i++) {
      if (i >= _initialCustomPrefs.length || _customPrefs[i] != _initialCustomPrefs[i]) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadPrefs() async {
    final enabled = await UserPrefsManager.loadEnabledPrefs();
    final custom = await UserPrefsManager.loadCustomPrefs();
    if (!mounted) return;
    setState(() {
      _enabledPrefs = enabled;
      _initialPrefs = Set.from(enabled);
      _customPrefs = custom;
      _initialCustomPrefs = List.from(custom);
      _loading = false;
    });
  }

  Future<void> _savePrefs() async {
    setState(() => _saving = true);
    await UserPrefsManager.saveEnabledPrefs(_enabledPrefs);
    await UserPrefsManager.saveCustomPrefs(_customPrefs);
    if (!mounted) return;
    setState(() {
      _saving = false;
      // Update initial state to match current state
      _initialPrefs = Set.from(_enabledPrefs);
      _initialCustomPrefs = List.from(_customPrefs);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preferences saved! Your suggestions will now be personalized.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _togglePref(String id) {
    setState(() {
      if (_enabledPrefs.contains(id)) {
        _enabledPrefs.remove(id);
      } else {
        _enabledPrefs.add(id);
      }
    });
  }

  void _addCustomPref() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    if (_customPrefs.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This preference already exists')),
      );
      return;
    }
    setState(() {
      _customPrefs.add(text);
      _customController.clear();
    });
  }

  void _removeCustomPref(String pref) {
    setState(() {
      _customPrefs.remove(pref);
    });
  }

  IconData _getCategoryIcon(PreferenceCategory category) {
    switch (category) {
      case PreferenceCategory.fitness:
        return Icons.fitness_center;
      case PreferenceCategory.wellness:
        return Icons.spa;
      case PreferenceCategory.productivity:
        return Icons.work;
      case PreferenceCategory.entertainment:
        return Icons.music_note;
      case PreferenceCategory.cooking:
        return Icons.restaurant;
    }
  }

  Color _getCategoryColor(PreferenceCategory category) {
    switch (category) {
      case PreferenceCategory.fitness:
        return Colors.orange;
      case PreferenceCategory.wellness:
        return Colors.teal;
      case PreferenceCategory.productivity:
        return Colors.blue;
      case PreferenceCategory.entertainment:
        return Colors.purple;
      case PreferenceCategory.cooking:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: widget.onOpenDrawer != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: widget.onOpenDrawer,
                  tooltip: 'Open menu',
                )
              : null,
          title: const Text('Preferences'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Group preferences by category
    final groupedPrefs = <PreferenceCategory, List<PreferenceOption>>{};
    for (final pref in predefinedPreferences) {
      groupedPrefs.putIfAbsent(pref.category, () => []).add(pref);
    }

    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Open menu',
              )
            : null,
        title: const Text('Preferences'),
        actions: [
          if (_hasChanges)
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _savePrefs,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Suggestions',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select your preferences to get personalized suggestions based on your location and time of day.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Enabled count
          if (_enabledPrefs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_enabledPrefs.length} active',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (_hasChanges) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Unsaved changes',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Predefined preferences by category
          ...groupedPrefs.entries.map((entry) => _buildCategorySection(entry.key, entry.value)),

          // Custom preferences section
          const SizedBox(height: 24),
          Text(
            'Custom Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add custom quick actions (e.g., "Timer 5min", "Jazz music")',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 12),

          // Custom preference input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  decoration: InputDecoration(
                    hintText: 'Enter a quick action...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _addCustomPref(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addCustomPref,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Custom preferences chips
          if (_customPrefs.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _customPrefs.map((pref) {
                return Chip(
                  label: Text(pref),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeCustomPref(pref),
                );
              }).toList(),
            ),

          const SizedBox(height: 100), // Bottom padding for FAB
        ],
      ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _savePrefs,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save Changes'),
            )
          : null,
    );
  }

  Widget _buildCategorySection(PreferenceCategory category, List<PreferenceOption> prefs) {
    final categoryNames = {
      PreferenceCategory.fitness: 'Fitness',
      PreferenceCategory.wellness: 'Wellness',
      PreferenceCategory.productivity: 'Productivity',
      PreferenceCategory.entertainment: 'Entertainment',
      PreferenceCategory.cooking: 'Cooking',
    };

    final color = _getCategoryColor(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(category),
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              categoryNames[category] ?? 'Other',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...prefs.map((pref) => _buildPrefTile(pref, color)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPrefTile(PreferenceOption pref, Color categoryColor) {
    final isEnabled = _enabledPrefs.contains(pref.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isEnabled ? categoryColor.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? categoryColor.withOpacity(0.5) : Colors.grey.shade200,
          width: isEnabled ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => _togglePref(pref.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          pref.label,
          style: TextStyle(
            fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
            color: isEnabled ? _darken(categoryColor, 0.2) : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pref.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                _buildContextChip('${pref.relevantTimes.join(", ")}', Icons.access_time, Colors.blue),
                _buildContextChip('${pref.relevantRooms.length} rooms', Icons.room, Colors.green),
              ],
            ),
          ],
        ),
        trailing: Checkbox(
          value: isEnabled,
          onChanged: (_) => _togglePref(pref.id),
          activeColor: categoryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  /// Darken a color by a factor (0.0 to 1.0)
  Color _darken(Color color, double factor) {
    return Color.fromRGBO(
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
      1,
    );
  }

  Widget _buildContextChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
