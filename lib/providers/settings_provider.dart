import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final defaultParticipantNameProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('default_participant_name') ?? 'Guest';
});

final defaultParticipantEmojiProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('default_participant_emoji') ?? '🐶';
});

final defaultParticipantAvatarProvider = StateProvider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('default_participant_avatar');
});

class SettingsService {
  final SharedPreferences prefs;
  
  SettingsService(this.prefs);

  Future<void> setDefaultParticipant(String name, String emoji, {String? avatarUrl}) async {
    await prefs.setString('default_participant_name', name);
    await prefs.setString('default_participant_emoji', emoji);
    if (avatarUrl != null) {
      await prefs.setString('default_participant_avatar', avatarUrl);
    }
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(sharedPreferencesProvider));
});
