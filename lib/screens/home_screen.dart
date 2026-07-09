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
import 'package:google_fonts/google_fonts.dart';

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
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Google Ad (Web Placeholder)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            fontSize: 14,
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
                'Share this secret keyword with your friend.\\nIt is valid for 10 minutes and can be used once.',
                style: TextStyle(
                  color: isNeon ? themeConfig.homeSubtextColor : null,
                ),
                textAlign: TextAlign.center,
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
    final isNeon = themeConfig.themeName == 'neon_silence';

    return Scaffold(
      backgroundColor: themeConfig.homeBackgroundColor,
      appBar: AppBar(
        backgroundColor: themeConfig.homeBackgroundColor,
        elevation: 0,
        title: isNeon 
            ? RichText(
                text: TextSpan(
                  style: GoogleFonts.hankenGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    letterSpacing: -1,
                  ),
                  children: [
                    const TextSpan(text: 'Fade', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'Chat', style: TextStyle(color: themeConfig.sendButtonColor)),
                  ],
                ),
              )
            : Text(
                'FadeChat',
                style: GoogleFonts.hankenGrotesk(
                  color: themeConfig.homeTextColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  letterSpacing: -1,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_comment_outlined,
              color: isNeon ? Colors.white54 : themeConfig.homeTextColor,
            ),
            tooltip: 'Create Room',
            onPressed: () => _createRoom(context, ref),
          ),
          IconButton(
            icon: Icon(
              Icons.person_add_outlined,
              color: isNeon ? Colors.white54 : themeConfig.homeTextColor,
            ),
            tooltip: 'Join Room',
            onPressed: () => _showJoinRoomDialog(context),
          ),
        ],
      ),
      body: roomsAsync.when(
        data: (asyncRooms) {
          final allRooms = asyncRooms.toList();

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
                    Icons.chat_bubble_outline,
                    size: 60,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active chats.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredRooms.length + 3, // 3 extra for chips, search, ad
            itemBuilder: (context, index) {
              if (index == 0) {
                // Filter Chips
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            ref.read(homeFilterProvider.notifier).state = '전체',
                        child: _buildChip(
                          '전체',
                          isSelected: currentFilter == '전체',
                          isNeon: isNeon,
                          themeConfig: themeConfig,
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
                          isNeon: isNeon,
                          themeConfig: themeConfig,
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (index == 1) {
                // Search Bar
                if (isNeon) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, color: Colors.grey),
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                );
              }
              if (index == 2) {
                // Ad Banner
                return const AdBannerWidget();
              }

              // Chat Item
              final room = filteredRooms[index - 3];
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
                      Stack(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isNeon ? const Color(0xFF2A2A2A) : Colors.grey.shade300,
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
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: isNeon ? Colors.white : Colors.black54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          if (isNeon && hasUnread)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF03DAC6),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: themeConfig.homeBackgroundColor, width: 2),
                                ),
                              ),
                            ),
                        ],
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
                                      color: isNeon ? Colors.white : themeConfig.homeTextColor,
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
                              color: isNeon ? Colors.grey.shade500 : themeConfig.homeSubtextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (hasUnread)
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: isNeon ? const Color(0xFF03DAC6) : AppColors.kakaoHomeBadge,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: TextStyle(
                                  color: isNeon ? Colors.black : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
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
      bottomNavigationBar: isNeon ? Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF131313),
          selectedItemColor: themeConfig.sendButtonColor,
          unselectedItemColor: Colors.grey.shade600,
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
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.star_border),
              activeIcon: _buildGlowingIcon(Icons.star, themeConfig.sendButtonColor),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_outline),
              activeIcon: _buildGlowingIcon(Icons.chat_bubble, themeConfig.sendButtonColor),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.more_horiz),
              activeIcon: _buildGlowingIcon(Icons.more_horiz, themeConfig.sendButtonColor),
              label: 'Settings',
            ),
          ],
        ),
      ) : BottomNavigationBar(
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

  Widget _buildGlowingIcon(IconData iconData, Color color) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  Widget _buildChip(String label, {bool isSelected = false, int? badgeCount, bool isNeon = false, dynamic themeConfig}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isNeon 
            ? (isSelected ? Colors.white : const Color(0xFF131313))
            : (isSelected ? Colors.black87 : AppColors.kakaoHomeChipBackground),
        border: (isSelected || isNeon)
            ? Border.all(color: isNeon && !isSelected ? Colors.white12 : Colors.transparent)
            : Border.all(color: AppColors.kakaoHomeChipBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isNeon 
                  ? (isSelected ? Colors.black : Colors.white70)
                  : (isSelected ? Colors.white : AppColors.kakaoHomeText),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          if (badgeCount != null) ...[
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isNeon ? const Color(0xFF03DAC6) : AppColors.kakaoHomeBadge,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: TextStyle(
                  color: isNeon ? Colors.black : Colors.white,
                  fontSize: 10,
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

    return Dialog(
      backgroundColor: isNeon ? const Color(0xFF131313) : Colors.white,
      shape: isNeon
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: themeConfig.sendButtonColor.withOpacity(0.4),
                width: 1,
              ),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNeon) ...[
                Text(
                  'ENTER CODE TO JOIN IN',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                const Text(
                  'Join Room',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _codeController,
                obscureText: false, // show the passphrase clearly
                style: TextStyle(
                  color: isNeon ? themeConfig.sendButtonColor : Colors.black,
                  fontSize: isNeon ? 24 : 16,
                  letterSpacing: isNeon ? 2.0 : null,
                  fontWeight: isNeon ? FontWeight.bold : null,
                ),
                textAlign: isNeon ? TextAlign.center : TextAlign.start,
                decoration: isNeon
                    ? InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: themeConfig.sendButtonColor.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: themeConfig.sendButtonColor.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: themeConfig.sendButtonColor, width: 2),
                        ),
                      )
                    : const InputDecoration(
                        labelText: 'Invite Code',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                      ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an invite code';
                  }
                  if (value.length < 8) {
                    return 'Code must be at least 8 characters';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(value)) {
                    return 'Code must contain only letters, numbers, and hyphens';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (isNeon)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, color: themeConfig.homeSubtextColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Alert: End-to-End Encrypted',
                      style: TextStyle(
                        color: themeConfig.homeSubtextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              
              // We hide Name and Emoji settings in Neon mode for a cleaner look, use defaults
              if (!isNeon) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'My Room Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name for the room';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _participantNameController,
                  decoration: const InputDecoration(
                    labelText: 'Chatter ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                ),
              ],
              
              if (!isNeon) const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isNeon)
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  if (isNeon)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: themeConfig.homeSubtextColor.withOpacity(0.3)),
                          foregroundColor: themeConfig.homeSubtextColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('CANCEL'),
                      ),
                    ),
                  if (isNeon) const SizedBox(width: 12),
                  if (isNeon)
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: themeConfig.sendButtonColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text('JOIN IN', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Join Room'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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

    return Dialog(
      backgroundColor: isNeon ? const Color(0xFF131313) : Colors.white,
      shape: isNeon
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: themeConfig.sendButtonColor.withOpacity(0.4),
                width: 1,
              ),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNeon) ...[
                  Text(
                    'CREATE NEW ROOM',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  const Text(
                    'Create Room',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(
                    color: isNeon ? Colors.white : Colors.black,
                  ),
                  decoration: isNeon
                      ? InputDecoration(
                          labelText: 'Room Name',
                          labelStyle: TextStyle(color: themeConfig.homeSubtextColor),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: themeConfig.sendButtonColor.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: themeConfig.sendButtonColor.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: themeConfig.sendButtonColor, width: 2),
                          ),
                        )
                      : const InputDecoration(
                          labelText: 'Room Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
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
                  dropdownColor: isNeon ? const Color(0xFF1E1E1E) : null,
                  style: TextStyle(
                    color: isNeon ? Colors.white : Colors.black,
                  ),
                  decoration: isNeon
                      ? InputDecoration(
                          labelText: 'Delete Permission',
                          labelStyle: TextStyle(color: themeConfig.homeSubtextColor),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: themeConfig.sendButtonColor.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: themeConfig.sendButtonColor.withOpacity(0.3)),
                          ),
                        )
                      : const InputDecoration(
                          labelText: 'Delete Permission',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.delete_sweep),
                        ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('모두 허용 (Allow All)', style: TextStyle(color: isNeon ? Colors.white : Colors.black)),
                    ),
                    DropdownMenuItem(
                      value: 'own',
                      child: Text('본인 메시지만 지우기 (Own Only)', style: TextStyle(color: isNeon ? Colors.white : Colors.black)),
                    ),
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('모든 메시지 지울수 없음 (None)', style: TextStyle(color: isNeon ? Colors.white : Colors.black)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _deletePermission = value);
                  },
                ),
                
                // Hide Profile settings in Neon for simplicity, or just show them if needed. 
                // We'll hide them to match minimalist look.
                if (!isNeon) ...[
                  const SizedBox(height: 24),
                  const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _participantNameController,
                    decoration: const InputDecoration(
                      labelText: 'Chatter ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                ],
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isNeon)
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    if (isNeon)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: themeConfig.homeSubtextColor.withOpacity(0.3)),
                            foregroundColor: themeConfig.homeSubtextColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('CANCEL'),
                        ),
                      ),
                    if (isNeon) const SizedBox(width: 12),
                    if (isNeon)
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: themeConfig.sendButtonColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Create'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
