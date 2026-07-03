import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeral_chat/providers/chat_providers.dart';
import 'package:ephemeral_chat/providers/settings_provider.dart';
import 'package:ephemeral_chat/screens/chat_screen.dart';
import 'package:ephemeral_chat/screens/settings_screen.dart';
import '../theme/app_colors.dart';

final homeFilterProvider = StateProvider<String>((ref) => '전체');

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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

  void _showCreatedRoomDialog(BuildContext context, String roomId, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Room Created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share this invite code with others:'),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId)));
              },
              child: const Text('Enter Chat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myRoomsAsync = ref.watch(myRoomsProvider);
    final currentFilter = ref.watch(homeFilterProvider);
    
    return Scaffold(
      backgroundColor: AppColors.kakaoHomeBackground,
      appBar: AppBar(
        backgroundColor: AppColors.kakaoHomeAppBar,
        elevation: 0,
        title: const Text('채팅', style: TextStyle(color: AppColors.kakaoHomeText, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.kakaoHomeText), onPressed: () {}),
          IconButton(icon: const Icon(Icons.add_comment_outlined, color: AppColors.kakaoHomeText), tooltip: 'Create Room', onPressed: () => _createRoom(context, ref)),
          IconButton(icon: const Icon(Icons.group_add_outlined, color: AppColors.kakaoHomeText), tooltip: 'Join Room', onPressed: () => _showJoinRoomDialog(context)),
        ],
      ),
      body: myRoomsAsync.when(
        data: (rooms) {
          final unreadTotalCount = rooms.fold<int>(0, (sum, r) => sum + (r['unread_count'] as int? ?? 0));
          final filteredRooms = currentFilter == '안읽음' 
              ? rooms.where((room) => (room['unread_count'] as int? ?? 0) > 0).toList() 
              : rooms;

          return ListView.builder(
            itemCount: filteredRooms.length + 2, // 2 extra for chips and ad
            itemBuilder: (context, index) {
              if (index == 0) {
                // Filter Chips
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => ref.read(homeFilterProvider.notifier).state = '전체',
                        child: _buildChip('전체', isSelected: currentFilter == '전체'),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ref.read(homeFilterProvider.notifier).state = '안읽음',
                        child: _buildChip('안읽음', badgeCount: unreadTotalCount > 0 ? unreadTotalCount : null, isSelected: currentFilter == '안읽음'),
                      ),
                    ],
                  ),
                );
              }
              if (index == 1) {
                // Ad Banner
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.kakaoHomeAdBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('오늘의 카카오가 궁금하다면?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.kakaoHomeText, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('카카오소식 보러가기', style: TextStyle(color: AppColors.kakaoHomeSubText, fontSize: 13)),
                        ],
                      ),
                      Row(
                        children: const [
                          Text('🍈', style: TextStyle(fontSize: 20)),
                          Text('📣', style: TextStyle(fontSize: 20)),
                          Text('📅', style: TextStyle(fontSize: 20)),
                        ],
                      ),
                    ],
                  ),
                );
              }

              // Chat Item
              final room = filteredRooms[index - 2];
              final roomId = room['id'].toString();
              final roomName = room['name']?.toString() ?? 'Unnamed Room';
              
              // Actual unread count from DB
              final unreadCount = room['unread_count'] as int? ?? 0;
              final hasUnread = unreadCount > 0;
              final randomCount = (roomId.hashCode % 10) + 1; // Keeping dummy participant count for UI
              
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId)));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            roomName.characters.first,
                            style: const TextStyle(fontSize: 20, color: Colors.black54, fontWeight: FontWeight.bold),
                          ),
                        ),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.kakaoHomeText),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$randomCount',
                                  style: const TextStyle(color: AppColors.kakaoHomeSubText, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${roomId.substring(0, 8)}...',
                              style: const TextStyle(color: AppColors.kakaoHomeSubText, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Trailing (Time & Badge)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('오후 3:30', style: TextStyle(color: AppColors.kakaoHomeSubText, fontSize: 12)),
                          const SizedBox(height: 6),
                          if (hasUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.kakaoHomeBadge,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
        currentIndex: 1, // Chat is selected
        onTap: (index) {
          if (index == 3) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.star_border), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
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
        border: isSelected ? null : Border.all(color: AppColors.kakaoHomeChipBorder),
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
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, height: 1.0),
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
        final roomId = await ref.read(roomRepositoryProvider).joinRoom(
          _codeController.text.trim(), 
          _nameController.text.trim(),
          _participantNameController.text.trim(),
          _selectedEmoji,
        );
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to join room: $e')));
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
    return AlertDialog(
      title: const Text('Join Room'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Invite Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter an invite code';
                  if (value.length < 8) return 'Code must be at least 8 characters';
                  if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) return 'Code must be alphanumeric';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'My Room Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a name for the room';
                  return null;
                },
              ),
              const Divider(height: 32),
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
              const SizedBox(height: 16),
              const Text('Animal Emoji', style: TextStyle(fontSize: 12)),
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
                        color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                        border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
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
        final result = await ref.read(roomRepositoryProvider).createRoom(
          _nameController.text.trim(), 
          _deletePermission,
          _participantNameController.text.trim(),
          _selectedEmoji,
        );
        if (mounted) {
          Navigator.of(context).pop({...result, 'name': _nameController.text.trim()});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create room: $e')));
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
    return AlertDialog(
      title: const Text('Create Room'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a room name';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _deletePermission,
                decoration: const InputDecoration(
                  labelText: 'Delete Permission',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.delete_sweep),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('모두 허용 (Allow All)')),
                  DropdownMenuItem(value: 'own', child: Text('본인 메시지만 지우기 (Own Only)')),
                  DropdownMenuItem(value: 'none', child: Text('모든 메시지 지울수 없음 (None)')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _deletePermission = value);
                },
              ),
              const Divider(height: 32),
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
              const SizedBox(height: 16),
              const Text('Animal Emoji', style: TextStyle(fontSize: 12)),
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
                        color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                        border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
              : const Text('Create'),
        ),
      ],
    );
  }
}
