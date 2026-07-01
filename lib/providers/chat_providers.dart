import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeral_chat/repositories/room_repository.dart';
import 'package:ephemeral_chat/repositories/message_repository.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository();
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});
