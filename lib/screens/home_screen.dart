import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ephemeral_chat/config/ad_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:ephemeral_chat/providers/chat_providers.dart';
import 'package:ephemeral_chat/providers/settings_provider.dart';
import 'package:ephemeral_chat/screens/chat_screen.dart';
import 'package:ephemeral_chat/screens/settings_screen.dart';
import '../theme/app_colors.dart';
import 'package:ephemeral_chat/providers/module_providers.dart';

String _formatTimestamp(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '';
  try {
    final dt = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = hour < 12 ? '오전' : '오후';
      final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$ampm $formattedHour:$minute';
    } else {
      return '${dt.month}월 ${dt.day}일';
    }
  } catch (e) {
    return '';
  }
}

final homeFilterProvider = StateProvider<String>((ref) => '전체');
final homeTabIndexProvider = StateProvider<int>((ref) => 1);

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  final String _adUnitId = AdConfig.bannerAdUnitId;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb) return;

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.kakaoHomeAdBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Google Ad (Web Placeholder)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.kakaoHomeText,
            fontSize: 16,
          ),
        ),
      );
    }

    if (_isLoaded && _bannerAd != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return const SizedBox(height: 50); // Placeholder while loading
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _showJoinRoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const _JoinRoomDialog();
      },
    );
  }

  Future<void> _createRoom(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CreateRoomDialog(),
    );

    if (result != null && context.mounted) {
      _showCreatedRoomDialog(context, result['roomId']!, result['code']!);
    }
  }

  void _showCreatedRoomDialog(
    BuildContext context,
    String roomId,
    String code,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final themeConfig = ref.read(chatModuleConfigProvider);
        final isNeon = themeConfig.themeName == 'neon_silence';

        return AlertDialog(
          backgroundColor: isNeon ? Colors.black87 : null,
          shape: isNeon
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: themeConfig.sendButtonColor.withValues(alpha: 0.5),
                  ),
                )
              : null,
          title: Text(
            'Room Created',
            style: TextStyle(color: isNeon ? themeConfig.homeTextColor : null),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share this invite code with others:',
                style: TextStyle(
                  color: isNeon ? themeConfig.homeSubtextColor : null,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isNeon ? themeConfig.sendButtonColor : null,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied to clipboard')),
                );
              },
              style: isNeon
                  ? TextButton.styleFrom(
                      foregroundColor: themeConfig.homeSubtextColor,
                    )
                  : null,
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId)),
                );
              },
              style: isNeon
                  ? FilledButton.styleFrom(
                      backgroundColor: themeConfig.sendButtonColor,
                      foregroundColor: themeConfig.backgroundColor,
                    )
                  : null,
              child: const Text('Enter Chat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(myRoomsProvider);
    final currentFilter = ref.watch(homeFilterProvider);
    final tabIndex = ref.watch(homeTabIndexProvider);
    final themeConfig = ref.watch(chatModuleConfigProvider);

    return Scaffold(
      backgroundColor: themeConfig.homeBackgroundColor,
      appBar: AppBar(
        backgroundColor: themeConfig.homeBackgroundColor,
        elevation: 0,
        title: Text(
          tabIndex == 0 ? '즐겨찾기' : '채팅',
          style: TextStyle(
            color: themeConfig.homeTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_comment_outlined,
              color: themeConfig.homeTextColor,
            ),
            tooltip: 'Create Room',
            onPressed: () => _createRoom(context, ref),
          ),
          IconButton(
            icon: Icon(
              Icons.group_add_outlined,
              color: themeConfig.homeTextColor,
            ),
            tooltip: 'Join Room',
            onPressed: () => _showJoinRoomDialog(context),
          ),
        ],
      ),
      body: roomsAsync.when(
        data: (asyncRooms) {
          final allRooms = tabIndex == 0
              ? asyncRooms.where((r) => r['is_favorite'] == true).toList()
              : asyncRooms.toList();

          final unreadTotalCount = allRooms.fold<int>(
            0,
            (sum, r) => sum + (r['unread_count'] as int? ?? 0),
          );
          final filteredRooms = currentFilter == '안읽음'
              ? allRooms
                    .where((room) => (room['unread_count'] as int? ?? 0) > 0)
                    .toList()
              : allRooms;

          if (allRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    tabIndex == 0
                        ? Icons.star_border
                        : Icons.chat_bubble_outline,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tabIndex == 0 ? '즐겨찾기한 채팅방이 없습니다.' : '참여 중인 채팅방이 없습니다.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredRooms.length + 2, // 2 extra for chips and ad
            itemBuilder: (context, index) {
              if (index == 0) {
                // Filter Chips
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            ref.read(homeFilterProvider.notifier).state = '전체',
                        child: _buildChip(
                          '전체',
                          isSelected: currentFilter == '전체',
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            ref.read(homeFilterProvider.notifier).state = '안읽음',
                        child: _buildChip(
                          '안읽음',
                          badgeCount: unreadTotalCount > 0
                              ? unreadTotalCount
                              : null,
                          isSelected: currentFilter == '안읽음',
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (index == 1) {
                // Ad Banner
                return const AdBannerWidget();
              }

              // Chat Item
              final room = filteredRooms[index - 2];
              final roomId = room['id'].toString();
              final roomName = room['name']?.toString() ?? 'Unnamed Room';
              final latestMsg = room['latest_message'] as Map<String, dynamic>?;

              // Actual unread count from DB
              final unreadCount = room['unread_count'] as int? ?? 0;
              final hasUnread = unreadCount > 0;

              final avatarUrl = room['other_avatar_url']?.toString();
              final emoji = room['other_emoji']?.toString();

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(roomId: roomId),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                          image: avatarUrl != null && avatarUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(avatarUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Center(
                                child: Text(
                                  emoji != null && emoji.isNotEmpty
                                      ? emoji
                                      : roomName.characters.first,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    roomName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: themeConfig.homeTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                String subtitleText = '대화 내역이 없습니다.';
                                if (latestMsg != null) {
                                  final content =
                                      latestMsg['content']?.toString() ?? '';
                                  final hasMedia =
                                      latestMsg['media_url'] != null &&
                                      latestMsg['media_url']
                                          .toString()
                                          .isNotEmpty;

                                  if (content.isNotEmpty) {
                                    subtitleText = content;
                                  } else if (hasMedia) {
                                    subtitleText = '(사진/동영상)';
                                  }
                                }
                                return Text(
                                  subtitleText,
                                  style: TextStyle(
                                    color: themeConfig.homeSubtextColor,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Trailing (Time & Badge)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTimestamp(
                              latestMsg?['created_at']?.toString() ??
                                  room['created_at']?.toString(),
                            ),
                            style: TextStyle(
                              color: themeConfig.homeSubtextColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (hasUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: themeConfig.themeName == 'neon_silence'
                                    ? themeConfig.sendButtonColor
                                    : AppColors.kakaoHomeBadge,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: TextStyle(
                                  color: themeConfig.themeName == 'neon_silence'
                                      ? themeConfig.backgroundColor
                                      : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black87,
        unselectedItemColor: Colors.grey.shade400,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: tabIndex,
        onTap: (index) {
          if (index == 0 || index == 1) {
            ref.read(homeTabIndexProvider.notifier).state = index;
          } else if (index == 2) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {bool isSelected = false, int? badgeCount}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.black87 : AppColors.kakaoHomeChipBackground,
        border: isSelected
            ? null
            : Border.all(color: AppColors.kakaoHomeChipBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.kakaoHomeText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          if (badgeCount != null) ...[
            const SizedBox(width: 4),
            Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.kakaoHomeBadge,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JoinRoomDialog extends ConsumerStatefulWidget {
  const _JoinRoomDialog();

  @override
  ConsumerState<_JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends ConsumerState<_JoinRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  late TextEditingController _participantNameController;
  late String _selectedEmoji;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final currentName = ref.read(defaultParticipantNameProvider);
    final currentEmoji = ref.read(defaultParticipantEmojiProvider);
    _participantNameController = TextEditingController(text: currentName);
    _selectedEmoji = currentEmoji;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _participantNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      try {
        final roomId = await ref
            .read(roomRepositoryProvider)
            .joinRoom(
              _codeController.text.trim(),
              _nameController.text.trim(),
              _participantNameController.text.trim(),
              _selectedEmoji,
            );
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to join room: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(chatModuleConfigProvider);
    final isNeon = themeConfig.themeName == 'neon_silence';

    return AlertDialog(
      backgroundColor: isNeon ? Colors.black87 : null,
      shape: isNeon
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: themeConfig.sendButtonColor.withValues(alpha: 0.5),
              ),
            )
          : null,
      title: Text(
        'Join Room',
        style: TextStyle(color: isNeon ? themeConfig.homeTextColor : null),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _codeController,
                style: TextStyle(
                  color: isNeon ? themeConfig.homeTextColor : null,
                ),
                decoration: InputDecoration(
                  labelText: 'Invite Code',
                  labelStyle: TextStyle(
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
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
                    Icons.key,
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an invite code';
                  }
                  if (value.length < 8) {
                    return 'Code must be at least 8 characters';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                    return 'Code must be alphanumeric';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                style: TextStyle(
                  color: isNeon ? themeConfig.homeTextColor : null,
                ),
                decoration: InputDecoration(
                  labelText: 'My Room Name',
                  labelStyle: TextStyle(
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
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
                    Icons.title,
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name for the room';
                  }
                  return null;
                },
              ),
              Divider(
                height: 32,
                color: isNeon
                    ? themeConfig.sendButtonColor.withValues(alpha: 0.3)
                    : null,
              ),
              Text(
                'My Profile',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isNeon ? themeConfig.homeTextColor : null,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _participantNameController,
                style: TextStyle(
                  color: isNeon ? themeConfig.homeTextColor : null,
                ),
                decoration: InputDecoration(
                  labelText: 'Chatter ID',
                  labelStyle: TextStyle(
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
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
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Animal Emoji',
                style: TextStyle(
                  fontSize: 12,
                  color: isNeon ? themeConfig.homeSubtextColor : null,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: animalEmojis.map((emoji) {
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      padding: const EdgeInsets.all(4),
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
                              : (isNeon ? Colors.grey.shade800 : Colors.grey),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: isNeon
              ? TextButton.styleFrom(
                  foregroundColor: themeConfig.homeSubtextColor,
                )
              : null,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          style: isNeon
              ? FilledButton.styleFrom(
                  backgroundColor: themeConfig.sendButtonColor,
                  foregroundColor: themeConfig.backgroundColor,
                )
              : null,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}

class _CreateRoomDialog extends ConsumerStatefulWidget {
  const _CreateRoomDialog();

  @override
  ConsumerState<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends ConsumerState<_CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late TextEditingController _participantNameController;
  late String _selectedEmoji;
  String _deletePermission = 'all';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final currentName = ref.read(defaultParticipantNameProvider);
    final currentEmoji = ref.read(defaultParticipantEmojiProvider);
    _participantNameController = TextEditingController(text: currentName);
    _selectedEmoji = currentEmoji;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _participantNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      try {
        final result = await ref
            .read(roomRepositoryProvider)
            .createRoom(
              _nameController.text.trim(),
              _deletePermission,
              _participantNameController.text.trim(),
              _selectedEmoji,
            );
        if (mounted) {
          Navigator.of(
            context,
          ).pop({...result, 'name': _nameController.text.trim()});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to create room: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(chatModuleConfigProvider);
    final isNeon = themeConfig.themeName == 'neon_silence';

    return AlertDialog(
      backgroundColor: isNeon ? Colors.black87 : null,
      shape: isNeon
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: themeConfig.sendButtonColor.withValues(alpha: 0.5),
              ),
            )
          : null,
      title: Text(
        'Create Room',
        style: TextStyle(color: isNeon ? themeConfig.homeTextColor : null),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                style: TextStyle(
                  color: isNeon ? themeConfig.homeTextColor : null,
                ),
                decoration: InputDecoration(
                  labelText: 'Room Name',
                  labelStyle: TextStyle(
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
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
                    Icons.title,
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a room name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _deletePermission,
                dropdownColor: isNeon ? themeConfig.homeBackgroundColor : null,
                style: TextStyle(
                  color: isNeon ? themeConfig.homeTextColor : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: 'Delete Permission',
                  labelStyle: TextStyle(
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
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
                    Icons.delete_sweep,
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('모두 허용 (Allow All)'),
                  ),
                  DropdownMenuItem(
                    value: 'own',
                    child: Text('본인 메시지만 지우기 (Own Only)'),
                  ),
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('모든 메시지 지울수 없음 (None)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _deletePermission = value);
                },
              ),
              Divider(
                height: 32,
                color: isNeon
                    ? themeConfig.sendButtonColor.withValues(alpha: 0.3)
                    : null,
              ),
              Text(
                'My Profile',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isNeon ? themeConfig.homeTextColor : null,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _participantNameController,
                style: TextStyle(
                  color: isNeon ? themeConfig.homeTextColor : null,
                ),
                decoration: InputDecoration(
                  labelText: 'Chatter ID',
                  labelStyle: TextStyle(
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
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
                    color: isNeon ? themeConfig.homeSubtextColor : null,
                  ),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Animal Emoji',
                style: TextStyle(
                  fontSize: 12,
                  color: isNeon ? themeConfig.homeSubtextColor : null,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: animalEmojis.map((emoji) {
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      padding: const EdgeInsets.all(4),
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
                              : (isNeon ? Colors.grey.shade800 : Colors.grey),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: isNeon
              ? TextButton.styleFrom(
                  foregroundColor: themeConfig.homeSubtextColor,
                )
              : null,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          style: isNeon
              ? FilledButton.styleFrom(
                  backgroundColor: themeConfig.sendButtonColor,
                  foregroundColor: themeConfig.backgroundColor,
                )
              : null,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
