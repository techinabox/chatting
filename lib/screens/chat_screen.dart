import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ephemeral_chat/providers/chat_providers.dart';
import 'package:ephemeral_chat/providers/settings_provider.dart';
import 'package:ephemeral_chat/providers/call_provider.dart';
import 'package:ephemeral_chat/screens/call_screen.dart';
import 'package:ephemeral_chat/providers/module_providers.dart';
import 'package:ephemeral_chat/widgets/watermark_overlay.dart';
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

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;

  const ChatScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _isSending = false;
  RealtimeChannel? _presenceChannel;

  @override
  void initState() {
    super.initState();
    // Reset unread count when opening the room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomRepositoryProvider).resetUnreadCount(widget.roomId);
      ref.read(callProvider.notifier).initSignaling(widget.roomId);
      _initPresence();
    });
  }

  void _initPresence() {
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _presenceChannel = supabase.channel('presence_room_${widget.roomId}');
    _presenceChannel!.onPresenceSync((_) {
      final state = _presenceChannel!.presenceState();
      final onlineUsers = <Map<String, dynamic>>[];
      for (var singleState in state) {
        for (var presence in singleState.presences) {
          if (presence.payload['user_id'] != null) {
            final payload = Map<String, dynamic>.from(presence.payload);
            onlineUsers.add(payload);
          }
        }
      }
      final uniqueUsersMap = <String, Map<String, dynamic>>{};
      for (var user in onlineUsers) {
        uniqueUsersMap[user['user_id']] = user;
      }
      ref.read(roomPresenceProvider(widget.roomId).notifier).state =
          uniqueUsersMap.values.toList();
    });

    _presenceChannel!.subscribe((status, [error]) async {
      print('Presence subscribe status: $status');
      if (status == RealtimeSubscribeStatus.subscribed ||
          status.toString().toLowerCase().contains('subscribed')) {
        final fallbackName = ref.read(defaultParticipantNameProvider);
        final fallbackEmoji = ref.read(defaultParticipantEmojiProvider);
        final fallbackAvatarUrl = ref.read(defaultParticipantAvatarProvider);

        await _presenceChannel!.track({
          'user_id': userId,
          'participant_name': fallbackName,
          'participant_emoji': fallbackEmoji,
          'participant_avatar_url': fallbackAvatarUrl,
        });
        print('Presence tracking started for $userId');
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    final images = List<XFile>.from(_selectedImages);

    if (text.isEmpty && images.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final participant = ref
          .read(roomParticipantStreamProvider(widget.roomId))
          .value;
      final fallbackName = ref.read(defaultParticipantNameProvider);
      final fallbackEmoji = ref.read(defaultParticipantEmojiProvider);
      final fallbackAvatarUrl = ref.read(defaultParticipantAvatarProvider);

      final senderName =
          participant?['participant_name']?.toString() ?? fallbackName;
      final senderEmoji =
          participant?['participant_emoji']?.toString() ?? fallbackEmoji;
      final senderAvatarUrl =
          participant?['participant_avatar_url']?.toString() ??
          fallbackAvatarUrl;

      String? mediaUrl;
      final repo = ref.read(messageRepositoryProvider);

      if (images.isNotEmpty) {
        final urls = await Future.wait(
          images.map((img) => repo.uploadMedia(widget.roomId, img)),
        );
        mediaUrl = urls.join(',');
      }

      await repo.sendMessage(
        roomId: widget.roomId,
        senderName: senderName,
        senderEmoji: senderEmoji,
        senderAvatarUrl: senderAvatarUrl,
        content: text.isNotEmpty ? text : null,
        mediaUrl: mediaUrl,
      );

      _messageController.clear();
      setState(() {
        _selectedImages.clear();
      });
    } catch (e, stack) {
      print('Message send error: $e');
      print(stack);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Material(
            color: Colors.black87,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(child: Image.network(imageUrl)),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(messageRepositoryProvider).deleteMessage(messageId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  void _confirmCloseRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeConfig = ref.read(chatModuleConfigProvider);
        final isNeon = themeConfig.themeName == 'neon_silence';

        if (isNeon) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1C23), // Darker sleek background
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Color(0xFFB388FF), // Neon Purple
                    size: 48,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'All data will be permanently wiped for\nall parties.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB388FF),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'DESTRUCT ROOM',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white38,
                    ),
                    child: const Text(
                      'ABORT',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return AlertDialog(
          title: const Text('Close Room'),
          content: const Text(
            'Are you sure you want to close this room? This will permanently delete the room and all messages for everyone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Close Room'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await ref.read(roomRepositoryProvider).closeRoom(widget.roomId);
        // We don't pop here, the roomStreamProvider listener will pop when room is null.
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to close room: $e')));
        }
      }
    }
  }

  void _confirmLeaveRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeConfig = ref.read(chatModuleConfigProvider);
        final isNeon = themeConfig.themeName == 'neon_silence';

        if (isNeon) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1C23), // Darker sleek background
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.exit_to_app, // Exit icon for leaving
                    color: Color(0xFFB388FF), // Neon Purple
                    size: 48,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'All your data will be permanently wiped\nfrom this room.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB388FF),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'LEAVE ROOM',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white38,
                    ),
                    child: const Text(
                      'ABORT',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return AlertDialog(
          title: const Text('Leave Room'),
          content: const Text(
            'Are you sure you want to leave this room? All your messages and media will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Leave Room'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await ref.read(roomRepositoryProvider).leaveRoom(widget.roomId);
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to leave room: $e')));
        }
      }
    }
  }

  void _showEditRoomNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Room Name'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final newName = controller.text.trim();
                          if (newName.isEmpty) return;
                          setState(() => isLoading = true);
                          try {
                            await ref
                                .read(roomRepositoryProvider)
                                .updateRoomName(widget.roomId, newName);
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                            setState(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _copyInviteCode() async {
    try {
      final code = await ref
          .read(roomRepositoryProvider)
          .getInviteCode(widget.roomId);
      if (code != null && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('초대 코드'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('아래 코드를 복사하여 친구를 초대하세요:'),
                const SizedBox(height: 16),
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('초대 코드가 복사되었습니다.')),
                  );
                },
                child: const Text('복사하기'),
              ),
            ],
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invite code not found')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get invite code: $e')),
        );
      }
    }
  }

  void _handleCallButton(bool isVideo) async {
    final presenceUsers = ref.read(roomPresenceProvider(widget.roomId));
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final otherOnlineUsers = presenceUsers
        .where((u) => u['user_id'] != userId)
        .toList();

    if (otherOnlineUsers.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('통화 불가'),
          content: const Text('상대방이 채팅방에 입장해야 통화 가능합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    if (otherOnlineUsers.length == 1) {
      final targetUser = otherOnlineUsers.first;
      final name = targetUser['participant_name']?.toString() ?? 'Unknown';
      final avatarUrl = targetUser['participant_avatar_url']?.toString();
      _startCall(isVideo, targetUser['user_id'], name, avatarUrl);
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('통화 대상 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: otherOnlineUsers.length,
              itemBuilder: (context, index) {
                final targetUser = otherOnlineUsers[index];
                final targetUserId = targetUser['user_id'];

                final name =
                    targetUser['participant_name']?.toString() ?? 'Unknown';
                final emoji =
                    targetUser['participant_emoji']?.toString() ?? '👤';
                final avatarUrl = targetUser['participant_avatar_url']
                    ?.toString();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Text(emoji, style: const TextStyle(fontSize: 24))
                        : null,
                  ),
                  title: Text(name),
                  onTap: () {
                    Navigator.of(context).pop();
                    _startCall(isVideo, targetUserId, name, avatarUrl);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startCall(bool isVideo, String targetUserId, String remoteUserName, String? remoteAvatarUrl) async {
    try {
      await ref
          .read(callProvider.notifier)
          .makeCall(widget.roomId, isVideo, targetUserId);
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => CallScreen(
          remoteUserName: remoteUserName,
          remoteAvatarUrl: remoteAvatarUrl,
        )));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Call failed: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final moduleConfig = ref.watch(chatModuleConfigProvider);
    final allParticipantsAsync = ref.watch(
      allRoomParticipantsStreamProvider(widget.roomId),
    );

    // Listen for incoming calls
    ref.listen<CallStateData>(callProvider, (previous, next) {
      if (previous?.state != CallState.ringing &&
          next.state == CallState.ringing) {
        
        String incomingName = 'Unknown';
        String? incomingAvatarUrl;
        if (allParticipantsAsync.value != null) {
           final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
           try {
             final caller = allParticipantsAsync.value!.firstWhere((p) => p['user_id'] != currentUserId);
             incomingName = caller['participant_name']?.toString() ?? 'Unknown';
             incomingAvatarUrl = caller['participant_avatar_url']?.toString();
           } catch (_) {}
        }
        
        // Show incoming call dialog
        final isNeon = moduleConfig.themeName == 'neon_silence';
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: isNeon ? Colors.black87 : Colors.black54,
          builder: (context) {
            final content = next.isVideoEnabled
                ? 'Incoming Video Call...'
                : 'Incoming Voice Call...';

            if (isNeon) {
              return Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: moduleConfig.sendButtonColor.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: moduleConfig.sendButtonColor.withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.call,
                        color: moduleConfig.sendButtonColor,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Incoming Call',
                        style: TextStyle(
                          color: moduleConfig.homeTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        content,
                        style: TextStyle(color: moduleConfig.homeSubtextColor),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.call_end,
                              color: Colors.redAccent,
                              size: 32,
                            ),
                            onPressed: () {
                              ref
                                  .read(callProvider.notifier)
                                  .endCall(reason: 'declined');
                              Navigator.of(context).pop();
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.call,
                              color: Colors.greenAccent,
                              size: 32,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              ref.read(callProvider.notifier).answerCall();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CallScreen(
                                    remoteUserName: incomingName,
                                    remoteAvatarUrl: incomingAvatarUrl,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Incoming Call'),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(callProvider.notifier).endCall(reason: 'declined');
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Decline',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(callProvider.notifier).answerCall();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CallScreen(
                        remoteUserName: incomingName,
                        remoteAvatarUrl: incomingAvatarUrl,
                      )),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Accept'),
                ),
              ],
            );
          },
        );
      }
    });

    // Listen to room stream for realtime kick-out
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      roomStreamProvider(widget.roomId),
      (previous, next) {
        next.when(
          data: (room) {
            if (room == null) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/');
              }
            }
          },
          error: (err, stack) {
            print('Room stream error: $err');
            print('Stack trace: $stack');
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
          loading: () {},
        );
      },
    );

    // Listen to messages stream to reset unread count if we are in the room and a new message arrives
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      messagesStreamProvider(widget.roomId),
      (previous, next) {
        if (next.hasValue && previous?.value?.length != next.value?.length) {
          ref.read(roomRepositoryProvider).resetUnreadCount(widget.roomId);
        }
      },
    );

    final messagesAsync = ref.watch(messagesStreamProvider(widget.roomId));
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final participantAsync = ref.watch(
      roomParticipantStreamProvider(widget.roomId),
    );
    final fallbackName = ref.watch(defaultParticipantNameProvider);
    final fallbackEmoji = ref.watch(defaultParticipantEmojiProvider);
    final fallbackAvatarUrl = ref.watch(defaultParticipantAvatarProvider);

    final presenceUsers = ref.watch(roomPresenceProvider(widget.roomId));
    final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isOtherUserOnline = presenceUsers.any((u) => u['user_id'] != currentUserId);
    final dotColor = isOtherUserOnline ? const Color(0xFF03DAC6) : Colors.redAccent;

    return WatermarkOverlay(
      child: Scaffold(
        backgroundColor: moduleConfig.backgroundColor,
      appBar: AppBar(
        title: participantAsync.when(
          data: (participant) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (moduleConfig.themeName == 'neon_silence')
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor,
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              Text(participant?['room_name']?.toString() ?? 'Chat Room'),
            ],
          ),
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Chat Room'),
        ),
        actions: roomAsync.when(
          data: (room) {
            if (room == null) return [];
            final userId = ref
                .read(supabaseClientProvider)
                .auth
                .currentUser
                ?.id;
            final isCreator = room['creator_id'] == userId;
            final currentName =
                participantAsync.value?['room_name']?.toString() ?? '';
            final isFavorite = participantAsync.value?['is_favorite'] == true;

            final actions = <Widget>[];

            if (moduleConfig.themeName != 'neon_silence') {
              actions.addAll([
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
                  onPressed: () async {
                    try {
                      await ref
                          .read(roomRepositoryProvider)
                          .toggleFavorite(widget.roomId, !isFavorite);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update favorite: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  tooltip: 'Voice Call',
                  onPressed: () => _handleCallButton(false),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.green),
                  tooltip: 'Video Call',
                  onPressed: () => _handleCallButton(true),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Edit Room Name',
                  onPressed: () => _showEditRoomNameDialog(currentName),
                ),
              ]);

              if (isCreator) {
                actions.add(
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.green),
                    tooltip: 'Copy Invite Code',
                    onPressed: () => _copyInviteCode(),
                  ),
                );
              }
            }

            if (isCreator) {
              actions.add(
                IconButton(
                  icon: Icon(Icons.close, color: moduleConfig.themeName == 'neon_silence' ? Colors.white54 : Colors.red),
                  tooltip: 'Close Room',
                  onPressed: () => _confirmCloseRoom(),
                ),
              );
            } else {
              actions.add(
                IconButton(
                  icon: Icon(moduleConfig.themeName == 'neon_silence' ? Icons.close : Icons.exit_to_app, color: moduleConfig.themeName == 'neon_silence' ? Colors.white54 : Colors.orange),
                  tooltip: 'Leave Room',
                  onPressed: () => _confirmLeaveRoom(),
                ),
              );
            }
            return actions;
          },
          loading: () => [],
          error: (_, _) => [],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (asyncMessages) {
                final allMessages = asyncMessages;
                final messages = allMessages.where((m) {
                  final content = m['content']?.toString() ?? '';
                  return !content.startsWith('WEBRTC_SIGNAL:');
                }).toList();

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length + (moduleConfig.themeName == 'neon_silence' ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (moduleConfig.themeName == 'neon_silence' && index == messages.length) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, color: Colors.white38, size: 12),
                              SizedBox(width: 6),
                              Text(
                                'END-TO-END ENCRYPTED SESSION',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final message = messages[index];
                    final userId = ref
                        .read(supabaseClientProvider)
                        .auth
                        .currentUser
                        ?.id;
                    final isMe = message['sender_id'] != null
                        ? message['sender_id'] == userId
                        : (message['sender_name'] == fallbackName &&
                              message['sender_emoji'] == fallbackEmoji);

                    String? otherAvatarUrl = message['sender_avatar_url']
                        ?.toString();
                    String otherEmoji =
                        message['sender_emoji']?.toString() ?? '🐶';

                    if (!isMe && allParticipantsAsync.value != null) {
                      try {
                        final p = allParticipantsAsync.value!.firstWhere(
                          (p) =>
                              p['participant_name'] == message['sender_name'] &&
                              p['participant_emoji'] == message['sender_emoji'],
                        );
                        otherAvatarUrl =
                            p['participant_avatar_url']?.toString() ??
                            otherAvatarUrl;
                        otherEmoji =
                            p['participant_emoji']?.toString() ?? otherEmoji;
                      } catch (_) {
                        // ignore if not found
                      }
                    }

                    final displayAvatarUrl = isMe
                        ? fallbackAvatarUrl
                        : otherAvatarUrl;
                    final displayEmoji = isMe ? fallbackEmoji : otherEmoji;

                    final room = roomAsync.value;
                    final permission =
                        room?['delete_permission'] as String? ?? 'all';
                    final isCreator = room?['creator_id'] == userId;
                    final canDeleteMessage =
                        isCreator ||
                        permission == 'all' ||
                        (permission == 'own' && isMe);

                    final content = message['content']?.toString();
                    final mediaUrl = message['media_url']?.toString();

                    final bubbleContent = Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? moduleConfig.myBubbleColor
                            : moduleConfig.otherBubbleColor,
                        border: isMe && moduleConfig.themeName == 'neon_silence'
                            ? Border.all(color: moduleConfig.sendButtonColor.withValues(alpha: 0.3), width: 1)
                            : null,
                        borderRadius: moduleConfig.themeName == 'neon_silence'
                            ? BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: isMe
                                    ? const Radius.circular(20)
                                    : const Radius.circular(4),
                                bottomRight: isMe
                                    ? const Radius.circular(4)
                                    : const Radius.circular(20),
                              )
                            : BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe
                                    ? const Radius.circular(16)
                                    : const Radius.circular(4),
                                bottomRight: isMe
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                              ),
                        boxShadow: moduleConfig.themeName == 'neon_silence' ? [] : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (content != null && content.isNotEmpty)
                            Text(
                              content,
                              style: TextStyle(
                                fontSize: 15,
                                color: moduleConfig.textColor,
                                height: 1.3,
                              ),
                            ),
                          if (mediaUrl != null && mediaUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: mediaUrl
                                    .split(',')
                                    .where((u) => u.isNotEmpty)
                                    .map(
                                      (url) => Stack(
                                        children: [
                                          GestureDetector(
                                            onTap: () =>
                                                _showImagePreview(context, url),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                url,
                                                height: 200,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          if (canDeleteMessage)
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Material(
                                                color: Colors.black54,
                                                shape: const CircleBorder(),
                                                child: IconButton(
                                                  iconSize: 20,
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32,
                                                      ),
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.white,
                                                  ),
                                                  onPressed: () async {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: const Text(
                                                          'Delete Image',
                                                        ),
                                                        content: const Text(
                                                          'Are you sure you want to delete this image?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  context,
                                                                ).pop(false),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  context,
                                                                ).pop(true),
                                                            style:
                                                                TextButton.styleFrom(
                                                                  foregroundColor:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                            child: const Text(
                                                              'Delete',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm != true) return;
                                                    try {
                                                      await ref
                                                          .read(
                                                            messageRepositoryProvider,
                                                          )
                                                          .removeMediaUrl(
                                                            message['id']
                                                                .toString(),
                                                            url,
                                                          );
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Failed to delete: $e',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    );

                    final bubbleRow = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.8,
                            ),
                            backgroundImage: displayAvatarUrl != null
                                ? NetworkImage(displayAvatarUrl)
                                : null,
                            radius: 20,
                            child: displayAvatarUrl == null
                                ? Text(
                                    displayEmoji,
                                    style: const TextStyle(fontSize: 24),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 4.0,
                                    left: 4.0,
                                  ),
                                  child: Text(
                                    message['sender_name']?.toString() ??
                                        'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: moduleConfig.nameTextColor,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        if (canDeleteMessage && isMe)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: moduleConfig.themeName == 'neon_silence' ? Colors.white38 : Colors.black38,
                                                size: 16,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _confirmDeleteMessage(message['id'].toString()),
                                            ),
                                          ),
                                        Flexible(child: bubbleContent),
                                        if (canDeleteMessage && !isMe)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8.0),
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: moduleConfig.themeName == 'neon_silence' ? Colors.white38 : Colors.black38,
                                                size: 16,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _confirmDeleteMessage(message['id'].toString()),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        right: isMe ? 4.0 : 0,
                                        left: isMe ? 0 : 4.0,
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isMe && moduleConfig.themeName == 'neon_silence') ...[
                                            const Icon(Icons.timer_outlined, color: Colors.white38, size: 10),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            _formatTimestamp(message['created_at']?.toString()),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: moduleConfig.themeName == 'neon_silence' 
                                                  ? Colors.white38 
                                                  : moduleConfig.dateTextColor,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.8,
                            ),
                            backgroundImage: displayAvatarUrl != null
                                ? NetworkImage(displayAvatarUrl)
                                : null,
                            radius: 20,
                            child: displayAvatarUrl == null
                                ? Text(
                                    displayEmoji,
                                    style: const TextStyle(fontSize: 24),
                                  )
                                : null,
                          ),
                        ],
                      ],
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(child: bubbleRow),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          SafeArea(
            child: Container(
              color: moduleConfig.inputBackground,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedImages.isNotEmpty)
                    Container(
                      height: 110,
                      color: Colors.grey.shade100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          final image = _selectedImages[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  height: 94,
                                  width: 94,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.5),
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      image.path,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -10,
                                  top: -10,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      iconSize: 16,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (moduleConfig.themeName == 'neon_silence')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Input row
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.add, color: moduleConfig.sendButtonColor, size: 24),
                                onPressed: _isSending ? null : _pickImage,
                                padding: const EdgeInsets.only(right: 8),
                                constraints: const BoxConstraints(),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: TextStyle(color: moduleConfig.textColor, fontSize: 14),
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  onSubmitted: _isSending ? null : (_) => _sendMessage(),
                                  decoration: InputDecoration(
                                    hintText: 'Transmit message...',
                                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              _isSending
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: Icon(Icons.send, color: moduleConfig.sendButtonColor, size: 20),
                                      onPressed: _sendMessage,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                            ],
                          ),
                          // Divider
                          Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1),
                          // Icons row
                          Builder(
                            builder: (context) {
                              final room = roomAsync.value;
                              final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
                              final isCreator = room?['creator_id'] == userId;
                              final currentName = participantAsync.value?['room_name']?.toString() ?? '';
                              final isFavorite = participantAsync.value?['is_favorite'] == true;
                              
                              String remoteName = '';
                              if (allParticipantsAsync.value != null) {
                                try {
                                  final caller = allParticipantsAsync.value!.firstWhere((p) => p['user_id'] != userId);
                                  remoteName = caller['participant_name']?.toString() ?? '';
                                } catch (_) {}
                              }
                              
                              if (remoteName.isEmpty && messagesAsync.value != null) {
                                try {
                                  final remoteMessage = messagesAsync.value!.firstWhere(
                                    (m) => m['sender_id'] != userId && m['sender_name'] != null && m['sender_name'].toString().isNotEmpty,
                                  );
                                  remoteName = remoteMessage['sender_name'].toString();
                                } catch (_) {}
                              }

                              if (remoteName.isEmpty) remoteName = 'Unknown';

                              return Row(
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      try {
                                        await ref.read(roomRepositoryProvider).toggleFavorite(widget.roomId, !isFavorite);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                                        }
                                      }
                                    },
                                    child: Icon(isFavorite ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
                                  ),
                                  const SizedBox(width: 24),
                                  GestureDetector(
                                    onTap: () => _handleCallButton(false),
                                    child: Icon(Icons.phone_outlined, color: moduleConfig.sendButtonColor, size: 36),
                                  ),
                                  const SizedBox(width: 24),
                                  GestureDetector(
                                    onTap: () => _handleCallButton(true),
                                    child: Icon(Icons.videocam_outlined, color: const Color(0xFF03DAC6), size: 36),
                                  ),
                                  const SizedBox(width: 24),
                                  GestureDetector(
                                    onTap: () => _showEditRoomNameDialog(currentName),
                                    child: const Icon(Icons.edit_outlined, color: Colors.redAccent, size: 36),
                                  ),
                                  const Spacer(),
                                  Text(
                                    remoteName,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.add_box_outlined,
                              color: Colors.grey,
                              size: 30,
                            ),
                            onPressed: _isSending ? null : _pickImage,
                          ),
                          Expanded(
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 120),
                              margin: const EdgeInsets.symmetric(vertical: 6.0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: moduleConfig.inputBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: moduleConfig.themeName == 'neon_silence'
                                    ? Border.all(
                                        color: moduleConfig.sendButtonColor
                                            .withValues(alpha: 0.5),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: TextField(
                                controller: _messageController,
                                style: TextStyle(color: moduleConfig.textColor),
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                onSubmitted: _isSending
                                    ? null
                                    : (_) => _sendMessage(),
                                decoration: const InputDecoration(
                                  hintText: '메시지를 입력하세요',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 6.0,
                              right: 4.0,
                            ),
                            child: _isSending
                                ? const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          moduleConfig.sendButtonColor,
                                      foregroundColor: moduleConfig.textColor,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      minimumSize: const Size(64, 40),
                                    ),
                                    onPressed: _sendMessage,
                                    child: const Text(
                                      '전송',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
