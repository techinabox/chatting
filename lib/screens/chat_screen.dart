import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ephemeral_chat/providers/chat_providers.dart';
import 'package:ephemeral_chat/providers/settings_provider.dart';
import 'package:ephemeral_chat/repositories/message_repository.dart';
import 'package:ephemeral_chat/theme/app_colors.dart';
import 'package:ephemeral_chat/providers/call_provider.dart';
import 'package:ephemeral_chat/screens/call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  
  const ChatScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Reset unread count when opening the room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomRepositoryProvider).resetUnreadCount(widget.roomId);
      ref.read(callProvider.notifier).initSignaling(widget.roomId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
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
      final participant = ref.read(roomParticipantStreamProvider(widget.roomId)).value;
      final fallbackName = ref.read(defaultParticipantNameProvider);
      final fallbackEmoji = ref.read(defaultParticipantEmojiProvider);
      final fallbackAvatarUrl = ref.read(defaultParticipantAvatarProvider);
      
      final senderName = participant?['participant_name']?.toString() ?? fallbackName;
      final senderEmoji = participant?['participant_emoji']?.toString() ?? fallbackEmoji;
      final senderAvatarUrl = participant?['participant_avatar_url']?.toString() ?? fallbackAvatarUrl;

      String? mediaUrl;
      final repo = ref.read(messageRepositoryProvider);
      
      if (images.isNotEmpty) {
        final urls = await Future.wait(images.map((img) => repo.uploadMedia(widget.roomId, img)));
        mediaUrl = urls.join(',');
      }

      await repo.sendMessage(
        roomId: widget.roomId, 
        senderName: senderName,
        senderEmoji: senderEmoji,
        senderAvatarUrl: senderAvatarUrl,
        content: text.isNotEmpty ? text : null, 
        mediaUrl: mediaUrl
      );
      
      _messageController.clear();
      setState(() {
        _selectedImages.clear();
      });
    } catch (e, stack) {
      print('Message send error: $e');
      print(stack);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
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
                  child: InteractiveViewer(
                    child: Image.network(imageUrl),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: \$e')));
      }
    }
  }

  void _confirmCloseRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Room'),
        content: const Text('Are you sure you want to close this room? This will permanently delete the room and all messages for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to close room: \$e')));
      }
    }
  }

  void _confirmLeaveRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Room'),
        content: const Text('Are you sure you want to leave this room? All your messages and media will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to leave room: $e')));
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
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading ? null : () async {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      await ref.read(roomRepositoryProvider).updateRoomName(widget.roomId, newName);
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      setState(() => isLoading = false);
                    }
                  },
                  child: isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
      final code = await ref.read(roomRepositoryProvider).getInviteCode(widget.roomId);
      if (code != null && mounted) {
        await Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied to clipboard')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code not found')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get invite code: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for incoming calls
    ref.listen<CallStateData>(callProvider, (previous, next) {
      if (previous?.state != CallState.ringing && next.state == CallState.ringing) {
        // Show incoming call dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Incoming Call'),
            content: Text(next.isVideoEnabled ? 'Incoming Video Call...' : 'Incoming Voice Call...'),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(callProvider.notifier).endCall();
                  Navigator.of(context).pop();
                },
                child: const Text('Decline', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(callProvider.notifier).answerCall();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallScreen()));
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
    final participantAsync = ref.watch(roomParticipantStreamProvider(widget.roomId));
    final allParticipantsAsync = ref.watch(allRoomParticipantsStreamProvider(widget.roomId));
    final fallbackName = ref.watch(defaultParticipantNameProvider);
    final fallbackEmoji = ref.watch(defaultParticipantEmojiProvider);
    final fallbackAvatarUrl = ref.watch(defaultParticipantAvatarProvider);

    return Scaffold(
      backgroundColor: AppColors.kakaoBackground,
      appBar: AppBar(
        title: participantAsync.when(
          data: (participant) => Text(participant?['room_name']?.toString() ?? 'Chat Room'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Chat Room'),
        ),
        actions: roomAsync.when(
          data: (room) {
            if (room == null) return [];
            final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
            final isCreator = room['creator_id'] == userId;
            final currentName = participantAsync.value?['room_name']?.toString() ?? '';

            final actions = <Widget>[
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                tooltip: 'Voice Call',
                onPressed: () async {
                  try {
                    await ref.read(callProvider.notifier).makeCall(widget.roomId, false);
                    if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallScreen()));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Call failed (Check your Mic/Cam hardware): $e'), duration: const Duration(seconds: 5)));
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.videocam, color: Colors.green),
                tooltip: 'Video Call',
                onPressed: () async {
                  try {
                    await ref.read(callProvider.notifier).makeCall(widget.roomId, true);
                    if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallScreen()));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Video Call failed (Check your Mic/Cam hardware): $e'), duration: const Duration(seconds: 5)));
                  }
                },
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
          error: (_, __) => [],
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
                    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
                    final currentSenderName = userId != null ? 'Guest-${userId.substring(0, 4)}' : '';
                    final isMe = (message['sender_name'] == fallbackName && message['sender_emoji'] == fallbackEmoji) || (message['sender_id'] != null && message['sender_id'] == userId);
                    
                    String? otherAvatarUrl = message['sender_avatar_url']?.toString();
                    String otherEmoji = message['sender_emoji']?.toString() ?? '🐶';
                    
                    if (!isMe && allParticipantsAsync.value != null) {
                      try {
                        final p = allParticipantsAsync.value!.firstWhere((p) => p['participant_name'] == message['sender_name'] && p['participant_emoji'] == message['sender_emoji']);
                        otherAvatarUrl = p['participant_avatar_url']?.toString() ?? otherAvatarUrl;
                        otherEmoji = p['participant_emoji']?.toString() ?? otherEmoji;
                      } catch (_) {
                        // ignore if not found
                      }
                    }
                    
                    final displayAvatarUrl = isMe ? fallbackAvatarUrl : otherAvatarUrl;
                    final displayEmoji = isMe ? fallbackEmoji : otherEmoji;
                    
                    final room = roomAsync.value;
                    final permission = room?['delete_permission'] as String? ?? 'all';
                    final isCreator = room?['creator_id'] == userId;
                    final canDeleteMessage = isCreator || permission == 'all' || (permission == 'own' && isMe);
                    
                    final content = message['content']?.toString();
                    final mediaUrl = message['media_url']?.toString();
                    
                    final bubbleContent = Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.kakaoMyBubble : AppColors.kakaoOtherBubble,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (content != null && content.isNotEmpty) 
                            Text(content, style: const TextStyle(fontSize: 15, color: AppColors.kakaoText, height: 1.3)),
                          if (mediaUrl != null && mediaUrl.isNotEmpty) 
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: mediaUrl.split(',').where((u) => u.isNotEmpty).map((url) => Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showImagePreview(context, url),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(url, height: 200, fit: BoxFit.cover),
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
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.delete, color: Colors.white),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Delete Image'),
                                                  content: const Text('Are you sure you want to delete this image?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                                    TextButton(
                                                      onPressed: () => Navigator.of(context).pop(true),
                                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm != true) return;
                                              try {
                                                await ref.read(messageRepositoryProvider).removeMediaUrl(message['id'].toString(), url);
                                              } catch (e) {
                                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                )).toList(),
                              ),
                            ),
                        ],
                      ),
                    );

                    final bubbleRow = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.8),
                            backgroundImage: displayAvatarUrl != null ? NetworkImage(displayAvatarUrl) : null,
                            radius: 20,
                            child: displayAvatarUrl == null ? Text(displayEmoji, style: const TextStyle(fontSize: 24)) : null,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                                  child: Text(
                                    message['sender_name']?.toString() ?? 'Unknown', 
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.kakaoNameText)
                                  ),
                                ),
                              bubbleContent,
                            ]
                          )
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.8),
                            backgroundImage: displayAvatarUrl != null ? NetworkImage(displayAvatarUrl) : null,
                            radius: 20,
                            child: displayAvatarUrl == null ? Text(displayEmoji, style: const TextStyle(fontSize: 24)) : null,
                          ),
                        ],
                      ]
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (canDeleteMessage && isMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 4, bottom: 8),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.black38, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDeleteMessage(message['id'].toString()),
                              ),
                            ),
                          Flexible(child: bubbleRow),
                          if (canDeleteMessage && !isMe)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.black38, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDeleteMessage(message['id'].toString()),
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
              color: AppColors.kakaoInputBackground,
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
                                    border: Border.all(color: Colors.grey.withOpacity(0.5)),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(image.path, fit: BoxFit.cover),
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
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.close, color: Colors.white),
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
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_box_outlined, color: Colors.grey, size: 30),
                          onPressed: _isSending ? null : _pickImage,
                        ),
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 120),
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(color: AppColors.kakaoText),
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              onSubmitted: _isSending ? null : (_) => _sendMessage(),
                              decoration: const InputDecoration(
                                hintText: '메시지를 입력하세요',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0, right: 4.0),
                          child: _isSending 
                              ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.kakaoSendButton,
                                    foregroundColor: AppColors.kakaoText,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    minimumSize: const Size(64, 40),
                                  ),
                                  onPressed: _sendMessage,
                                  child: const Text('전송', style: TextStyle(fontWeight: FontWeight.bold)),
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
