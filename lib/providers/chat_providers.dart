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

final messagesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.from('messages').stream(primaryKey: ['id']).eq('room_id', roomId).order('created_at', ascending: true);
});

final roomStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, roomId) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.from('rooms').stream(primaryKey: ['id']).eq('id', roomId).map((events) => events.isEmpty ? null : events.first);
});
