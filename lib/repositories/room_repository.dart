import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/invite_code_generator.dart';

class RoomRepository {
  final SupabaseClient _client;

  RoomRepository({required this._client});

  Future<void> _ensureAuth() async {
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
  }

  Future<Map<String, String>> createRoom(
    String name,
    String deletePermission,
    String participantName,
    String participantEmoji, {
    String? participantAvatarUrl,
  }) async {
    await _ensureAuth();
    final userId = _client.auth.currentUser!.id;

    // Create room
    final room = await _client
        .from('rooms')
        .insert({'creator_id': userId, 'delete_permission': deletePermission})
        .select()
        .single();

    final roomId = room['id'] as String;

    // Generate invite code
    final code = InviteCodeGenerator.generateSecureCode(24);
    await _client.from('invite_codes').insert({
      'code': code,
      'room_id': roomId,
    });

    // Automatically join the room as creator
    await _client.from('room_participants').insert({
      'room_id': roomId,
      'user_id': userId,
      'room_name': name,
      'participant_name': participantName,
      'participant_emoji': participantEmoji,
      'participant_avatar_url': participantAvatarUrl,
    });

    return {'roomId': roomId, 'code': code};
  }

  Future<String> joinRoom(
    String code,
    String name,
    String participantName,
    String participantEmoji, {
    String? participantAvatarUrl,
  }) async {
    await _ensureAuth();
    final response = await _client.rpc(
      'join_room',
      params: {
        'invite_code': code,
        'p_room_name': name,
        'p_participant_name': participantName,
        'p_participant_emoji': participantEmoji,
        'p_participant_avatar_url': participantAvatarUrl,
      },
    );
    return response as String;
  }

  Future<String?> getInviteCode(String roomId) async {
    await _ensureAuth();
    final response = await _client
        .from('invite_codes')
        .select('code')
        .eq('room_id', roomId)
        .maybeSingle();
    return response?['code'] as String?;
  }

  Stream<List<Map<String, dynamic>>> getMyRoomsStream() {
    if (_client.auth.currentSession == null) return Stream.value([]);
    final userId = _client.auth.currentUser!.id;
    return _client
        .from('room_participants')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('user_id', userId)
        .asyncMap((participants) async {
          if (participants.isEmpty) return [];
          final roomIds = participants.map((p) => p['room_id']).toList();
          final roomsResponse = await _client
              .from('rooms')
              .select()
              .inFilter('id', roomIds)
              .order('created_at', ascending: false);

          final latestMessagesFutures = roomIds.map(
            (id) => _client
                .from('messages')
                .select('content, media_url, created_at')
                .eq('room_id', id)
                .not('content', 'like', 'WEBRTC_SIGNAL:%')
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle(),
          );
          final latestMessagesList = await Future.wait(latestMessagesFutures);
          final latestMessages = Map.fromIterables(roomIds, latestMessagesList);

          // Fetch all participants to find the creator's profile
          final allParticipantsResponse = await _client
              .from('room_participants')
              .select(
                'room_id, user_id, participant_emoji, participant_avatar_url',
              )
              .inFilter('room_id', roomIds);

          final creatorParticipants = (allParticipantsResponse as List)
              .fold<Map<String, Map<String, dynamic>>>({}, (map, p) {
                final roomId = p['room_id'] as String;
                final participantUserId = p['user_id'] as String;
                // Find the corresponding room to check creator_id
                final room = roomsResponse.firstWhere(
                  (r) => r['id'] == roomId,
                  orElse: () => <String, dynamic>{},
                );
                if (room.isNotEmpty &&
                    room['creator_id'] == participantUserId) {
                  map[roomId] = p as Map<String, dynamic>;
                }
                return map;
              });

          return roomsResponse.map((room) {
            final participant = participants.firstWhere(
              (p) => p['room_id'] == room['id'],
            );
            final creator = creatorParticipants[room['id']];
            return {
              ...room,
              'name': participant['room_name'] ?? 'Chat Room',
              'unread_count': participant['unread_count'] ?? 0,
              'is_favorite': participant['is_favorite'] ?? false,
              'latest_message': latestMessages[room['id']],
              'other_emoji':
                  creator?['participant_emoji'] ??
                  participant['participant_emoji'],
              'other_avatar_url':
                  creator?['participant_avatar_url'] ??
                  participant['participant_avatar_url'],
            };
          }).toList();
        });
  }

  Future<void> leaveRoom(String roomId) async {
    await _ensureAuth();
    final userId = _client.auth.currentUser!.id;
    final senderName = 'Guest-${userId.substring(0, 4)}';

    // Fetch messages to delete their media
    final messages = await _client
        .from('messages')
        .select('media_url')
        .eq('room_id', roomId)
        .eq('sender_name', senderName);
    for (final message in messages) {
      if (message['media_url'] != null) {
        final urls = message['media_url'].toString().split(',');
        for (final url in urls) {
          if (url.isNotEmpty) {
            final path = url.split('public/chat_media/').last;
            await _client.storage.from('chat_media').remove([path]);
          }
        }
      }
    }

    // Delete messages
    await _client
        .from('messages')
        .delete()
        .eq('room_id', roomId)
        .eq('sender_name', senderName);

    // Delete from participants
    await _client
        .from('room_participants')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<void> closeRoom(String roomId) async {
    await _ensureAuth();
    final userId = _client.auth.currentUser!.id;

    // Check if creator
    final room = await _client
        .from('rooms')
        .select('creator_id')
        .eq('id', roomId)
        .single();
    if (room['creator_id'] != userId) {
      throw Exception('Only the creator can close the room.');
    }

    // Delete all media in the room
    final messages = await _client
        .from('messages')
        .select('media_url')
        .eq('room_id', roomId);
    for (final message in messages) {
      if (message['media_url'] != null) {
        final urls = message['media_url'].toString().split(',');
        for (final url in urls) {
          if (url.isNotEmpty) {
            final path = url.split('public/chat_media/').last;
            await _client.storage.from('chat_media').remove([path]);
          }
        }
      }
    }

    // Delete room (cascades participants and messages in DB)
    await _client.from('rooms').delete().eq('id', roomId);
  }

  Future<void> updateRoomName(String roomId, String newName) async {
    await _ensureAuth();
    final userId = _client.auth.currentUser!.id;

    await _client
        .from('room_participants')
        .update({'room_name': newName})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<void> updateGlobalProfile(
    String newName,
    String newEmoji, {
    String? newAvatarUrl,
  }) async {
    await _ensureAuth();
    final userId = _client.auth.currentUser!.id;

    // Update in all rooms
    await _client
        .from('room_participants')
        .update({
          'participant_name': newName,
          'participant_emoji': newEmoji,
          'participant_avatar_url': newAvatarUrl,
        })
        .eq('user_id', userId);
  }

  Future<void> resetUnreadCount(String roomId) async {
    await _ensureAuth();
    try {
      await _client.rpc('reset_unread_count', params: {'p_room_id': roomId});
    } catch (e) {
      print('Failed to reset unread count: $e');
    }
  }

  Future<void> toggleFavorite(String roomId, bool isFavorite) async {
    await _ensureAuth();
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('room_participants')
        .update({'is_favorite': isFavorite})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }
}
