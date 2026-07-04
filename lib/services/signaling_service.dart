import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

typedef OnSignalingMessage = void Function(Map<String, dynamic> payload);

class SignalingService {
  final String roomId;
  final String userId;
  final String tabId = DateTime.now().millisecondsSinceEpoch.toString();
  final OnSignalingMessage onMessage;
  RealtimeChannel? _channel;

  SignalingService({
    required this.roomId,
    required this.userId,
    required this.onMessage,
  });

  void connect() {
    final supabase = Supabase.instance.client;
    _channel = supabase.channel('room_${roomId}_signaling');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final content = newRecord['content']?.toString() ?? '';

            if (content.startsWith('WEBRTC_SIGNAL:')) {
              try {
                final jsonStr = content.substring('WEBRTC_SIGNAL:'.length);
                final data = jsonDecode(jsonStr);
                debugPrint('SignalingService: Received signal: $data');

                if (data['tab_id'] != tabId) {
                  final targetUserId = data['target_user_id'];
                  final senderId = data['sender_id'];
                  if (targetUserId != null &&
                      targetUserId != userId &&
                      senderId != userId) {
                    debugPrint(
                      'SignalingService: Ignored signal meant for $targetUserId',
                    );
                    return;
                  }
                  onMessage(data);
                } else {
                  debugPrint('SignalingService: Ignored own message');
                }
              } catch (e) {
                debugPrint('SignalingService parse error: $e');
              }
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Signaling channel status: $status, error: $error');
        });
  }

  Future<void> send(Map<String, dynamic> data, {String? targetUserId}) async {
    if (_channel == null) {
      debugPrint('SignalingService: Channel is null, cannot send!');
      return;
    }

    final payload = {
      'sender_id': userId,
      'tab_id': tabId,
      'target_user_id': ?targetUserId,
      ...data,
    };

    debugPrint('SignalingService: Sending broadcast message: $payload');
    try {
      await Supabase.instance.client.from('messages').insert({
        'room_id': roomId,
        'sender_id': userId,
        'sender_name': 'System',
        'sender_emoji': '🤖',
        'content': 'WEBRTC_SIGNAL:${jsonEncode(payload)}',
      });
      debugPrint('SignalingService: Sent successfully via DB');
    } catch (e) {
      debugPrint('SignalingService: Send error $e');
    }
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
