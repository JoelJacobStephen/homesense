import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Method channel for native Android clock intents
const MethodChannel _systemChannel = MethodChannel('com.homesense/system');

/// Service to handle quick action execution
/// Maps action labels to actual system actions (browser, apps, etc.)
class ActionService {
  /// Execute a quick action by its label
  /// Returns true if action was handled, false otherwise
  static Future<bool> executeAction(String actionLabel) async {
    final label = actionLabel.toLowerCase();

    // ========== WORKOUT & EXERCISE ACTIONS (YouTube) ==========
    if (_matchesAny(label, ['morning workout video', 'morning workout'])) {
      return _openYouTube(searchQuery: '10 minute morning workout routine');
    }
    if (_matchesAny(label, ['evening workout video', 'evening workout'])) {
      return _openYouTube(searchQuery: '20 minute evening workout home');
    }
    if (_matchesAny(label, ['workout video', 'check workout'])) {
      return _openYouTube(searchQuery: 'quick workout routine');
    }

    // ========== MEDITATION & WELLNESS ACTIONS (YouTube) ==========
    if (_matchesAny(label, ['morning meditation'])) {
      return _openYouTube(searchQuery: '10 minute morning meditation guided');
    }
    if (_matchesAny(label, ['evening meditation'])) {
      return _openYouTube(searchQuery: '10 minute evening relaxation meditation');
    }
    if (_matchesAny(label, ['meditation', 'quick meditation'])) {
      return _openYouTube(searchQuery: '5 minute guided meditation');
    }
    if (_matchesAny(label, ['stretches', 'quick stretches', 'stretch', 'desk stretches'])) {
      return _openYouTube(searchQuery: '5 minute desk stretches office');
    }

    // ========== BROWSER SEARCH ACTIONS ==========
    if (_matchesAny(label, ['recipe', 'recipes', 'check recipes'])) {
      return _searchGoogle('quick easy recipes');
    }
    if (_matchesAny(label, ['news', 'morning news', 'play news', 'play morning news'])) {
      return _searchGoogle('latest news today');
    }
    if (_matchesAny(label, ['weather', 'check weather'])) {
      return _searchGoogle('weather today');
    }
    if (_matchesAny(label, ['read book'])) {
      return _openUrl('https://play.google.com/store/apps/details?id=com.google.android.apps.books');
    }
    if (_matchesAny(label, ['trending movies', 'top movies', 'popular movies'])) {
      return _openUrl('https://www.imdb.com/chart/moviemeter/');
    }
    if (_matchesAny(label, ['journaling', 'open journaling', 'journal', 'evening journal'])) {
      return _openJournaling();
    }
    if (_matchesAny(label, ['shopping list', 'add to shopping'])) {
      return _openUrl('https://shoppinglist.google.com/');
    }

    // ========== APP LAUNCH ACTIONS ==========
    if (_matchesAny(label, ['calendar', 'check calendar', 'tomorrow\'s calendar'])) {
      return _openCalendar();
    }
    if (_matchesAny(label, ['timer', 'set timer', 'timer 3min', 'timer 5min', 'timer 10min', 'timer 15min', 'timer 30min', 'timer 45min'])) {
      return _openTimer(label);
    }
    if (_matchesAny(label, ['alarm', 'set alarm'])) {
      return _openClock();
    }
    if (_matchesAny(label, [
      'music',
      'play music',
      'spotify',
      'focus music',
      'play focus music',
      'morning playlist',
      'play morning playlist',
      'cooking playlist',
      'play cooking playlist',
      'sleep sounds',
      'play sleep sounds',
      'relaxing music',
      'play relaxing music',
      'workout music',
      'play workout music'
    ])) {
      return _openSpotify(label);
    }
    if (_matchesAny(label, ['tv', 'watch tv'])) {
      return _openYouTube();
    }

    // ========== DEVICE CONTROL ACTIONS (show instructions) ==========
    if (_matchesAny(label, ['lights', 'dim lights', 'turn off lights', 'turn on lights'])) {
      // These would integrate with smart home APIs
      return false; // Not directly actionable
    }
    if (_matchesAny(label, ['blinds', 'open blinds'])) {
      return false; // Would need smart home integration
    }
    if (_matchesAny(label, ['coffee', 'coffee maker', 'start coffee maker'])) {
      return false; // Would need smart home integration
    }
    if (_matchesAny(label, ['focus mode', 'focus mode on', 'do not disturb'])) {
      return _openSettings();
    }
    if (_matchesAny(label, ['night mode', 'activate night mode'])) {
      return _openSettings();
    }

    // ========== TASK/TODO ACTIONS ==========
    if (_matchesAny(label, ['tasks', 'check tasks', 'task list'])) {
      return _openUrl('https://tasks.google.com/');
    }
    if (_matchesAny(label, ['reminder', 'set reminder'])) {
      return _openGoogleAssistant();
    }
    if (_matchesAny(label, ['morning routine'])) {
      return _openGoogleAssistant();
    }
    if (_matchesAny(label, ['take break', 'stretch reminder'])) {
      return _openYouTube(searchQuery: 'quick desk stretches');
    }
    if (_matchesAny(label, ['close work apps', 'out-of-office'])) {
      return false; // Would need specific app integrations
    }

    // Default: Try a Google search with the action label
    return _searchGoogle(actionLabel);
  }

  /// Check if label matches any of the patterns
  static bool _matchesAny(String label, List<String> patterns) {
    for (final pattern in patterns) {
      if (label.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Get the action type for UI display purposes
  static ActionType getActionType(String actionLabel) {
    final label = actionLabel.toLowerCase();

    // Video content (YouTube)
    if (_matchesAny(label, [
      'workout video', 'morning workout', 'evening workout',
      'meditation', 'stretches', 'stretch',
      'tv', 'youtube', 'watch'
    ])) {
      return ActionType.video;
    }
    // Music should be checked before browser
    if (_matchesAny(label, ['music', 'spotify', 'playlist', 'sleep sounds'])) {
      return ActionType.music;
    }
    if (_matchesAny(label, [
      'recipe', 'news', 'weather', 'read book',
      'shopping', 'trending movies', 'journaling', 'journal'
    ])) {
      return ActionType.browser;
    }
    if (_matchesAny(label, ['calendar', 'check calendar'])) {
      return ActionType.calendar;
    }
    if (_matchesAny(label, ['timer', 'alarm', 'clock'])) {
      return ActionType.clock;
    }
    if (_matchesAny(label, ['tasks', 'check tasks', 'reminder'])) {
      return ActionType.tasks;
    }
    if (_matchesAny(label, [
      'lights', 'blinds', 'coffee', 'focus mode', 'night mode',
      'do not disturb', 'close work', 'out-of-office'
    ])) {
      return ActionType.smartHome;
    }

    return ActionType.browser; // Default to browser search
  }

  // ========== PRIVATE HELPER METHODS ==========

  static Future<bool> _searchGoogle(String query) async {
    final encoded = Uri.encodeComponent(query);
    final url = 'https://www.google.com/search?q=$encoded';
    return _openUrl(url);
  }

  static Future<bool> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      // Don't check canLaunchUrl - just try to launch directly
      // canLaunchUrl often returns false on Android 11+ even when it can launch
      final result = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return result;
    } catch (e) {
      print('Error opening URL: $e');
      return false;
    }
  }

  /// Try to launch URL, return false on failure (don't throw)
  static Future<bool> _tryLaunchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _openCalendar() async {
    if (kIsWeb) return _openUrl('https://calendar.google.com/');
    
    if (Platform.isAndroid) {
      // Try to open Google Calendar app directly via package
      // Using the proper Android intent URL format
      final calendarIntent = Uri.parse(
        'intent://calendar.google.com/#Intent;'
        'scheme=https;'
        'package=com.google.android.calendar;'
        'end'
      );
      try {
        if (await launchUrl(calendarIntent, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
      
      // Fallback: Open web calendar (will open in browser or prompt to open app)
      return _openUrl('https://calendar.google.com/');
    } else if (Platform.isIOS) {
      if (await _tryLaunchUrl('calshow://')) return true;
      return _openUrl('https://calendar.google.com/');
    }
    
    return _openUrl('https://calendar.google.com/');
  }

  static Future<bool> _openTimer(String label) async {
    // Extract duration if mentioned
    int durationSeconds = 60; // Default 1 minute
    final match = RegExp(r'(\d+)\s*min').firstMatch(label);
    if (match != null) {
      durationSeconds = int.parse(match.group(1)!) * 60;
    }

    if (kIsWeb) {
      final query = 'timer+${durationSeconds ~/ 60}+minutes';
      return _openUrl('https://www.google.com/search?q=$query');
    }
    
    if (Platform.isAndroid) {
      // Use native method channel for reliable clock app opening
      try {
        final result = await _systemChannel.invokeMethod('openTimer', {
          'duration': durationSeconds,
        });
        if (result == true) return true;
      } catch (e) {
        print('Native timer error: $e');
      }
      
      // Fallback to Google search for timer
      final query = 'timer+${durationSeconds ~/ 60}+minutes';
      return _openUrl('https://www.google.com/search?q=$query');
    } else if (Platform.isIOS) {
      if (await _tryLaunchUrl('clock-timer://')) return true;
      if (await _tryLaunchUrl('clock://')) return true;
      return _openUrl('https://www.google.com/search?q=timer');
    }
    
    return false;
  }

  static Future<bool> _openClock() async {
    if (kIsWeb) return _openUrl('https://www.google.com/search?q=set+alarm');
    
    if (Platform.isAndroid) {
      // Use native method channel for reliable clock app opening
      try {
        final result = await _systemChannel.invokeMethod('openAlarm');
        if (result == true) return true;
      } catch (e) {
        print('Native alarm error: $e');
      }
      
      // Fallback to Google search
      return _openUrl('https://www.google.com/search?q=set+alarm');
    } else if (Platform.isIOS) {
      if (await _tryLaunchUrl('clock-alarm://')) return true;
      if (await _tryLaunchUrl('clock://')) return true;
    }
    
    return _openUrl('https://www.google.com/search?q=set+alarm');
  }

  static Future<bool> _openSpotify(String label) async {
    // Build a search query based on the action
    String searchQuery = 'music';
    if (label.contains('focus')) {
      searchQuery = 'focus music';
    } else if (label.contains('morning')) {
      searchQuery = 'morning playlist';
    } else if (label.contains('cooking')) {
      searchQuery = 'cooking playlist';
    } else if (label.contains('sleep')) {
      searchQuery = 'sleep sounds';
    } else if (label.contains('relaxing')) {
      searchQuery = 'relaxing music';
    } else if (label.contains('workout')) {
      searchQuery = 'workout music';
    }

    if (kIsWeb) {
      return _openUrl('https://open.spotify.com/search/${Uri.encodeComponent(searchQuery)}');
    }

    if (Platform.isAndroid) {
      // Try Spotify app with search using intent
      final spotifyIntent = Uri.parse(
        'intent://search/${Uri.encodeComponent(searchQuery)}#Intent;'
        'scheme=spotify;'
        'package=com.spotify.music;'
        'end'
      );
      try {
        if (await launchUrl(spotifyIntent, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
      
      // Try direct Spotify URI
      if (await _tryLaunchUrl('spotify:search:${Uri.encodeComponent(searchQuery)}')) return true;
    }
    
    // Fallback to web Spotify
    return _openUrl('https://open.spotify.com/search/${Uri.encodeComponent(searchQuery)}');
  }

  static Future<bool> _openYouTube({String? searchQuery}) async {
    final webUrl = searchQuery != null
        ? 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(searchQuery)}'
        : 'https://www.youtube.com/';
    
    if (kIsWeb) return _openUrl(webUrl);
    
    if (Platform.isAndroid) {
      // Try YouTube app via intent
      final ytIntent = searchQuery != null
          ? Uri.parse(
              'intent://www.youtube.com/results?search_query=${Uri.encodeComponent(searchQuery)}#Intent;'
              'scheme=https;'
              'package=com.google.android.youtube;'
              'end'
            )
          : Uri.parse(
              'intent://www.youtube.com/#Intent;'
              'scheme=https;'
              'package=com.google.android.youtube;'
              'end'
            );
      try {
        if (await launchUrl(ytIntent, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
    }
    
    // Fallback to web URL (will open in browser or YouTube app)
    return _openUrl(webUrl);
  }

  static Future<bool> _openSettings() async {
    if (kIsWeb) return false;
    
    if (Platform.isAndroid) {
      final settingsIntent = Uri.parse(
        'intent://#Intent;'
        'action=android.settings.SETTINGS;'
        'end'
      );
      try {
        return await launchUrl(settingsIntent, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    } else if (Platform.isIOS) {
      return _tryLaunchUrl('app-settings://');
    }
    
    return false;
  }

  static Future<bool> _openGoogleAssistant() async {
    if (kIsWeb) return _openUrl('https://assistant.google.com/');
    
    if (Platform.isAndroid) {
      // Try Google Assistant via intent
      final assistantIntent = Uri.parse(
        'intent://#Intent;'
        'action=android.intent.action.VOICE_ASSIST;'
        'end'
      );
      try {
        if (await launchUrl(assistantIntent, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
      
      // Try Google app
      if (await _tryLaunchUrl('googleassistant://')) return true;
    } else if (Platform.isIOS) {
      if (await _tryLaunchUrl('shortcuts://')) return true;
    }
    
    return _openUrl('https://assistant.google.com/');
  }

  static Future<bool> _openJournaling() async {
    if (kIsWeb) return _openUrl('https://www.penzu.com/');
    
    if (Platform.isAndroid) {
      // List of notes/journaling apps to try in order
      final appsToTry = [
        'com.google.android.keep',        // Google Keep
        'com.samsung.android.app.notes',  // Samsung Notes
        'com.microsoft.office.onenote',   // OneNote
        'com.evernote',                   // Evernote
        'com.dayoneapp.dayone',           // Day One
      ];
      
      for (final packageName in appsToTry) {
        try {
          final result = await _systemChannel.invokeMethod('launchApp', {
            'package': packageName,
          });
          if (result == true) {
            print('Successfully launched: $packageName');
            return true;
          }
        } catch (e) {
          print('Failed to launch $packageName: $e');
        }
      }
      
      // Fallback to web journaling
      return _openUrl('https://www.penzu.com/');
    } else if (Platform.isIOS) {
      // Try Day One journaling app
      if (await _tryLaunchUrl('dayone://')) return true;
      // Try Apple Notes
      if (await _tryLaunchUrl('mobilenotes://')) return true;
    }
    
    // Fallback to a web-based journaling platform
    return _openUrl('https://www.penzu.com/');
  }
}

/// Type of action for UI icon selection
enum ActionType {
  browser,
  calendar,
  clock,
  music,
  video,
  tasks,
  smartHome,
}
