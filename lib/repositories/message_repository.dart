import 'package:supabase_flutter/supabase_flutter.dart';

class MessageRepository {
  final SupabaseClient _client;

  MessageRepository({required this._client});

  Future<void> sendMessage({
    required String roomId,
    required String senderName,
    required String senderEmoji,
    String? senderAvatarUrl,
    String? content,
    String? mediaUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': user.id,
      'sender_name': senderName,
      'sender_emoji': senderEmoji,
      'sender_avatar_url': senderAvatarUrl,
      'content': content,
      'media_url': mediaUrl,
    });
  }

  Future<String> uploadMedia(String roomId, dynamic xfile) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final bytes = await xfile.readAsBytes();
    final extension = xfile.name.contains('.')
        ? xfile.name.split('.').last
        : 'png';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = '$roomId/$fileName';

    await _client.storage.from('chat_media').uploadBinary(path, bytes);

    return _client.storage.from('chat_media').getPublicUrl(path);
  }

  Future<void> removeMediaUrl(String messageId, String urlToRemove) async {
    print('Attempting to delete image for message: $messageId');
    final response = await _client
        .from('messages')
        .select('content, media_url')
        .eq('id', messageId)
        .maybeSingle();
    print('DB Response: $response');
    if (response == null) return;

    final String? content = response['content']?.toString();
    final String currentMedia = response['media_url']?.toString() ?? '';
    final List<String> urls = currentMedia
        .split(',')
        .where((u) => u.isNotEmpty)
        .toList();

    urls.remove(urlToRemove);

    if (urls.isEmpty && (content == null || content.isEmpty)) {
      await _client.from('messages').delete().eq('id', messageId);
    } else {
      await _client
          .from('messages')
          .update({'media_url': urls.isEmpty ? null : urls.join(',')})
          .eq('id', messageId);
    }
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.from('messages').delete().eq('id', messageId);
  }
}
