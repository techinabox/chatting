import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ephemeral_chat/repositories/room_repository.dart';
import 'package:ephemeral_chat/repositories/message_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return RoomRepository(client: client);
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MessageRepository(client: client);
});

final messagesStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, roomId) {
      final supabase = ref.watch(supabaseClientProvider);
      return supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .map(
            (messages) => messages
                .where(
                  (m) =>
                      !(m['content']?.toString().startsWith('WEBRTC_SIGNAL:') ??
                          false),
                )
                .toList(),
          );
    });

final roomStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, roomId) {
      final supabase = ref.watch(supabaseClientProvider);
      return supabase
          .from('rooms')
          .stream(primaryKey: ['id'])
          .eq('id', roomId)
          .map((events) => events.isEmpty ? null : events.first);
    });

final roomParticipantStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, roomId) {
      final supabase = ref.watch(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return Stream.value(null);

      return supabase
          .from('room_participants')
          .stream(primaryKey: ['room_id', 'user_id'])
          .eq('room_id', roomId)
          .map((events) {
            final filtered = events
                .where((e) => e['user_id'] == userId)
                .toList();
            return filtered.isEmpty ? null : filtered.first;
          });
    });

final allRoomParticipantsStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, roomId) {
      final supabase = ref.watch(supabaseClientProvider);
      return supabase
          .from('room_participants')
          .stream(primaryKey: ['room_id', 'user_id'])
          .eq('room_id', roomId);
    });

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final myRoomsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) {
  ref.watch(authStateProvider); // Rebuild when auth state changes
  final repo = ref.watch(roomRepositoryProvider);
  return repo.getMyRoomsStream();
});

final roomPresenceProvider =
    StateProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
      return [];
    });
