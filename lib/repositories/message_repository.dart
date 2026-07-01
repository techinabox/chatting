import 'package:supabase_flutter/supabase_flutter.dart';

class MessageRepository {
  final SupabaseClient _client;

  MessageRepository({required SupabaseClient client}) : _client = client;

  Future<void> sendMessage() async {
    // Stub implementation
  }
}
