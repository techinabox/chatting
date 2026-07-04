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
      builder: (context) => AlertDialog(
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
      ),
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
      builder: (context) => AlertDialog(
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
      ),
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
      _startCall(isVideo, otherOnlineUsers.first['user_id']);
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
                    _startCall(isVideo, targetUserId);
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

  Future<void> _startCall(bool isVideo, String targetUserId) async {
    try {
      await ref
          .read(callProvider.notifier)
          .makeCall(widget.roomId, isVideo, targetUserId);
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CallScreen()));
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
    // Listen for incoming calls
    ref.listen<CallStateData>(callProvider, (previous, next) {
      if (previous?.state != CallState.ringing &&
          next.state == CallState.ringing) {
        // Show incoming call dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Incoming Call'),
            content: Text(
              next.isVideoEnabled
                  ? 'Incoming Video Call...'
                  : 'Incoming Voice Call...',
            ),
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
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const CallScreen()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Accept'),
              ),
            ],
          ),
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
    final allParticipantsAsync = ref.watch(
      allRoomParticipantsStreamProvider(widget.roomId),
    );
    final fallbackName = ref.watch(defaultParticipantNameProvider);
    final fallbackEmoji = ref.watch(defaultParticipantEmojiProvider);
    final fallbackAvatarUrl = ref.watch(defaultParticipantAvatarProvider);
    final moduleConfig = ref.watch(chatModuleConfigProvider);

    return Scaffold(
      backgroundColor: moduleConfig.backgroundColor,
      appBar: AppBar(
        title: participantAsync.when(
          data: (participant) =>
              Text(participant?['room_name']?.toString() ?? 'Chat Room'),
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

            final actions = <Widget>[
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
            ];

            if (isCreator) {
              actions.add(
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.green),
                  tooltip: 'Copy Invite Code',
                  onPressed: () => _copyInviteCode(),
                ),
              );
              actions.add(
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Close Room',
                  onPressed: () => _confirmCloseRoom(),
                ),
              );
            } else {
              actions.add(
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.orange),
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
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
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
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isMe
                              ? const Radius.circular(16)
                              : const Radius.circular(4),
                          bottomRight: isMe
                              ? const Radius.circular(4)
                              : const Radius.circular(16),
                        ),
                        boxShadow: [
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
                            backgroundColor: Colors.white.withValues(alpha: 0.8),
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 4.0,
                                        bottom: 8.0,
                                      ),
                                      child: Text(
                                        _formatTimestamp(
                                          message['created_at']?.toString(),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  Flexible(child: bubbleContent),
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4.0,
                                        bottom: 8.0,
                                      ),
                                      child: Text(
                                        _formatTimestamp(
                                          message['created_at']?.toString(),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
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
                            backgroundColor: Colors.white.withValues(alpha: 0.8),
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
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (canDeleteMessage && isMe)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 4,
                                bottom: 8,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.black38,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDeleteMessage(
                                  message['id'].toString(),
                                ),
                              ),
                            ),
                          Flexible(child: bubbleRow),
                          if (canDeleteMessage && !isMe)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.black38,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDeleteMessage(
                                  message['id'].toString(),
                                ),
                              ),
                            ),
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
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
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
    );
  }
}
