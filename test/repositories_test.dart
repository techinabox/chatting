import 'package:flutter_test/flutter_test.dart';
import 'package:ephemeral_chat/repositories/room_repository.dart';
import 'package:ephemeral_chat/repositories/message_repository.dart';

void main() {
  group('RoomRepository', () {
    test('should exist and have createRoom and joinRoom methods', () {
      final repository = RoomRepository();
      
      expect(repository.createRoom, isNotNull);
      expect(repository.joinRoom, isNotNull);
    });
  });

  group('MessageRepository', () {
    test('should exist and have sendMessage method', () {
      final repository = MessageRepository();
      
      expect(repository.sendMessage, isNotNull);
    });
  });
}
