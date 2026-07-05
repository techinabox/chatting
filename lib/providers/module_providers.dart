import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeral_chat/models/chat_module_config.dart';

// Provides the current active chat module theme configuration
final chatModuleConfigProvider = StateProvider<ChatModuleConfig>((ref) {
  // Default to Neon Silence Style
  return ChatModuleConfig.neonSilence();
});
