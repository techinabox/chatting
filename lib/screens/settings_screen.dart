import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeral_chat/providers/settings_provider.dart';
import 'package:ephemeral_chat/providers/chat_providers.dart';
import 'package:ephemeral_chat/providers/module_providers.dart';
import 'package:ephemeral_chat/screens/module_settings_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

const List<String> animalEmojis = [
  '🐶',
  '🐱',
  '🐭',
  '🐹',
  '🐰',
  '🦊',
  '🐻',
  '🐼',
  '🐨',
  '🐯',
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late String _selectedEmoji;
  String? _avatarUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final currentName = ref.read(defaultParticipantNameProvider);
    final currentEmoji = ref.read(defaultParticipantEmojiProvider);
    _avatarUrl = ref.read(defaultParticipantAvatarProvider);
    _nameController = TextEditingController(text: currentName);
    _selectedEmoji = currentEmoji;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();

    if (!mounted) return;

    final croppedBytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final cropController = CropController();
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Crop Profile Image',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Crop(
                    image: bytes,
                    controller: cropController,
                    onCropped: (result) {
                      if (result is CropSuccess) {
                        Navigator.of(context).pop(result.croppedImage);
                      } else {
                        Navigator.of(context).pop(null);
                      }
                    },
                    aspectRatio: 1 / 1,
                    withCircleUi: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => cropController.crop(),
                      child: const Text('Crop & Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (croppedBytes == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final pathStr = pickedFile.path;
      final ext = pathStr.contains('.') ? pathStr.split('.').last : 'png';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';

      if (Supabase.instance.client.auth.currentSession == null) {
        await Supabase.instance.client.auth.signInAnonymously();
      }

      final userId = Supabase.instance.client.auth.currentUser!.id;
      final path = '$userId/$fileName';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(path, croppedBytes);
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      setState(() {
        _avatarUrl = publicUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _saveSettings() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref
        .read(settingsServiceProvider)
        .setDefaultParticipant(name, _selectedEmoji, avatarUrl: _avatarUrl);
    ref.read(defaultParticipantNameProvider.notifier).state = name;
    ref.read(defaultParticipantEmojiProvider.notifier).state = _selectedEmoji;
    ref.read(defaultParticipantAvatarProvider.notifier).state = _avatarUrl;

    try {
      if (Supabase.instance.client.auth.currentSession != null) {
        await ref
            .read(roomRepositoryProvider)
            .updateGlobalProfile(
              name,
              _selectedEmoji,
              newAvatarUrl: _avatarUrl,
            );
      }
    } catch (e) {
      print('Failed to update global profile: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(chatModuleConfigProvider);
    final isNeon = themeConfig.themeName == 'neon_silence';

    return Scaffold(
      backgroundColor: themeConfig.homeBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Global Settings',
          style: TextStyle(color: themeConfig.homeTextColor),
        ),
        backgroundColor: themeConfig.homeBackgroundColor,
        iconTheme: IconThemeData(color: themeConfig.homeTextColor),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? Text(
                            _selectedEmoji,
                            style: const TextStyle(fontSize: 40),
                          )
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(child: CircularProgressIndicator()),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploading ? null : _pickAndCropImage,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Default Chatter ID',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeConfig.homeTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: TextStyle(color: themeConfig.homeTextColor),
                decoration: InputDecoration(
                  hintText: 'Enter your default name',
                  hintStyle: TextStyle(color: themeConfig.homeSubtextColor),
                  border: isNeon
                      ? OutlineInputBorder(
                          borderSide: BorderSide(
                            color: themeConfig.sendButtonColor,
                          ),
                        )
                      : const OutlineInputBorder(),
                  enabledBorder: isNeon
                      ? OutlineInputBorder(
                          borderSide: BorderSide(
                            color: themeConfig.sendButtonColor.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        )
                      : null,
                  prefixIcon: Icon(
                    Icons.person,
                    color: themeConfig.homeSubtextColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Default Animal Emoji (Fallback)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeConfig.homeTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: animalEmojis.map((emoji) {
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEmoji = emoji;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isNeon
                                  ? themeConfig.sendButtonColor.withValues(
                                      alpha: 0.2,
                                    )
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? (isNeon
                                    ? themeConfig.sendButtonColor
                                    : Theme.of(context).colorScheme.primary)
                              : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: isNeon
                      ? FilledButton.styleFrom(
                          backgroundColor: themeConfig.sendButtonColor,
                          foregroundColor: themeConfig.backgroundColor,
                        )
                      : null,
                  onPressed: _saveSettings,
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      'Save Settings',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.color_lens,
                  color: themeConfig.homeTextColor,
                ),
                title: Text(
                  '모듈 디자인 설정 (미리보기)',
                  style: TextStyle(color: themeConfig.homeTextColor),
                ),
                subtitle: Text(
                  '채팅앱 테마 커스터마이징',
                  style: TextStyle(color: themeConfig.homeSubtextColor),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: themeConfig.homeTextColor,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ModuleSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
