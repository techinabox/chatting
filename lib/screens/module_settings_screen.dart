import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeral_chat/models/chat_module_config.dart';
import 'package:ephemeral_chat/providers/module_providers.dart';

class ModuleSettingsScreen extends ConsumerWidget {
  const ModuleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(chatModuleConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('모듈 디자인 설정 (미리보기)')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            '채팅 모듈을 연동할 때 제공할 수 있는 미리보기 테마 세트입니다.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Kakao Style Theme'),
            subtitle: const Text('노란색/흰색 말풍선, 하늘색 배경'),
            leading: _buildColorPreview(
              ChatModuleConfig.kakao().backgroundColor,
            ),
            onTap: () {
              ref.read(chatModuleConfigProvider.notifier).state =
                  ChatModuleConfig.kakao();
            },
            trailing: _buildCheck(config, ChatModuleConfig.kakao()),
          ),
          const Divider(),
          ListTile(
            title: const Text('Line Style Theme'),
            subtitle: const Text('연두색/흰색 말풍선, 회색 배경'),
            leading: _buildColorPreview(
              ChatModuleConfig.line().backgroundColor,
            ),
            onTap: () {
              ref.read(chatModuleConfigProvider.notifier).state =
                  ChatModuleConfig.line();
            },
            trailing: _buildCheck(config, ChatModuleConfig.line()),
          ),
          const Divider(),
          ListTile(
            title: const Text('Dark Mode Theme'),
            subtitle: const Text('어두운 회색 말풍선, 검은색 배경'),
            leading: _buildColorPreview(
              ChatModuleConfig.dark().backgroundColor,
            ),
            onTap: () {
              ref.read(chatModuleConfigProvider.notifier).state =
                  ChatModuleConfig.dark();
            },
            trailing: _buildCheck(config, ChatModuleConfig.dark()),
          ),
          const Divider(),
          ListTile(
            title: const Text('Neon Silence Theme'),
            subtitle: const Text('네온 퍼플 말풍선, 퓨어 블랙 배경 (사이버펑크)'),
            leading: _buildColorPreview(
              ChatModuleConfig.neonSilence().sendButtonColor,
            ),
            onTap: () {
              ref.read(chatModuleConfigProvider.notifier).state =
                  ChatModuleConfig.neonSilence();
            },
            trailing: _buildCheck(config, ChatModuleConfig.neonSilence()),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildColorPreview(Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
    );
  }

  Widget? _buildCheck(ChatModuleConfig current, ChatModuleConfig target) {
    if (current.themeName == target.themeName) {
      return const Icon(Icons.check, color: Colors.blue);
    }
    return null;
  }
}
