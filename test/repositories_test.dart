import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ephemeral_chat/repositories/room_repository.dart';
import 'package:ephemeral_chat/repositories/message_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockClient;

  setUp(() {
    mockClient = MockSupabaseClient();
  });

  group('RoomRepository', () {
    test('should exist and have createRoom and joinRoom methods', () {
      final repository = RoomRepository(client: mockClient);

      expect(repository.createRoom('test', 'owner', 'name', 'emoji'), isA<Future<Map<String, String>>>());
      expect(repository.joinRoom('code', 'room_name', 'name', 'emoji'), isA<Future<String>>());
    });
  });

  group('MessageRepository', () {
    test('should exist and have sendMessage method', () {
      final repository = MessageRepository(client: mockClient);

      expect(repository.sendMessage(roomId: 'room', senderName: 'name', senderEmoji: 'emoji'), isA<Future<void>>());
    });
  });
}
