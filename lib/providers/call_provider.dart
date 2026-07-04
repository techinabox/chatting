import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:ephemeral_chat/services/webrtc_service.dart';
import 'package:ephemeral_chat/services/signaling_service.dart';

enum CallState { idle, calling, ringing, inCall }

class CallStateData {
  final CallState state;
  final String? callerId;
  final String? peerUserId;
  final bool isVideoEnabled;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final String iceState;
  final String connState;
  final int localIceCount;
  final int remoteIceCount;

  CallStateData({
    this.state = CallState.idle,
    this.callerId,
    this.peerUserId,
    this.isVideoEnabled = false,
    this.localStream,
    this.remoteStream,
    this.iceState = 'new',
    this.connState = 'new',
    this.localIceCount = 0,
    this.remoteIceCount = 0,
  });

  CallStateData copyWith({
    CallState? state,
    String? callerId,
    String? peerUserId,
    bool? isVideoEnabled,
    MediaStream? localStream,
    MediaStream? remoteStream,
    String? iceState,
    String? connState,
    int? localIceCount,
    int? remoteIceCount,
  }) {
    return CallStateData(
      state: state ?? this.state,
      callerId: callerId ?? this.callerId,
      peerUserId: peerUserId ?? this.peerUserId,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      iceState: iceState ?? this.iceState,
      connState: connState ?? this.connState,
      localIceCount: localIceCount ?? this.localIceCount,
      remoteIceCount: remoteIceCount ?? this.remoteIceCount,
    );
  }
}

class CallProvider extends StateNotifier<CallStateData> {
  SignalingService? _signalingService;
  WebRTCService? _webrtcService;
  String? _latestOffer;
  final List<Map<String, dynamic>> _queuedCandidates = [];
  bool _isCaller = false;
  bool _wasConnected = false;

  CallProvider() : super(CallStateData());

  Future<void> _sendCallSystemMessage(String content) async {
    final roomId = _signalingService?.roomId;
    if (roomId == null) return;

    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      final participant = await Supabase.instance.client
          .from('room_participants')
          .select('participant_name, participant_emoji')
          .eq('room_id', roomId)
          .eq('user_id', userId)
          .maybeSingle();

      final senderName = participant?['participant_name'] ?? 'System';
      final senderEmoji = participant?['participant_emoji'] ?? '📞';

      await Supabase.instance.client.from('messages').insert({
        'room_id': roomId,
        'sender_id': userId,
        'sender_name': senderName,
        'sender_emoji': senderEmoji,
        'content': content,
      });
    } catch (e) {
      print('Failed to send call system message: $e');
    }
  }

  void initSignaling(String roomId) {
    if (_signalingService != null && _signalingService!.roomId == roomId) {
      return;
    }

    _signalingService?.dispose();
    final userId = Supabase.instance.client.auth.currentUser!.id;
    _signalingService = SignalingService(
      roomId: roomId,
      userId: userId,
      onMessage: _handleSignalingMessage,
    );
    _signalingService!.connect();
  }

  void _handleSignalingMessage(Map<String, dynamic> data) async {
    final type = data['type'];
    final senderId = data['sender_id'];

    if (type == 'call-offer') {
      if (state.state == CallState.idle) {
        _latestOffer = data['sdp'];
        state = state.copyWith(
          state: CallState.ringing,
          callerId: senderId,
          peerUserId: senderId,
          isVideoEnabled: data['isVideo'] ?? false,
        );
      }
    } else if (type == 'call-answer') {
      if (state.state == CallState.calling) {
        _webrtcService?.handleAnswer(data['sdp']).then((_) {
          _flushQueuedCandidates();
        });
        state = state.copyWith(state: CallState.inCall);
      }
    } else if (type == 'ice-candidate') {
      state = state.copyWith(remoteIceCount: state.remoteIceCount + 1);
      if (_webrtcService != null && _webrtcService!.isRemoteDescriptionSet) {
        _webrtcService?.handleIceCandidate(data['candidate']);
      } else {
        _queuedCandidates.add(data['candidate']);
      }
    } else if (type == 'call-end') {
      endCall(sendSignal: false, reason: data['reason']);
    }
  }

  Future<void> makeCall(
    String roomId,
    bool isVideo, [
    String? targetUserId,
  ]) async {
    print(
      'CallProvider.makeCall: starting (isVideo: $isVideo, targetUserId: $targetUserId)',
    );

    initSignaling(roomId);
    if (_signalingService == null) {
      throw Exception(
        "SignalingService is null even after init! User might not be logged in.",
      );
    }

    state = state.copyWith(
      state: CallState.calling,
      isVideoEnabled: isVideo,
      peerUserId: targetUserId,
    );

    _isCaller = true;
    _wasConnected = false;
    await _sendCallSystemMessage(isVideo ? '📹 영상 통화 시작' : '📞 음성 통화 시작');

    _webrtcService = WebRTCService(
      onSignalingData: (data) {
        final payload = Map<String, dynamic>.from(data);
        if (payload['type'] == 'call-offer') {
          payload['isVideo'] = isVideo;
        }
        print('CallProvider: Sending signaling data: ${payload['type']}');
        _signalingService?.send(payload, targetUserId: state.peerUserId);
      },
      onRemoteStreamAdded: () {
        state = state.copyWith(remoteStream: _webrtcService!.remoteStream);
      },
      onConnectionStateChange: (String ice, String conn) {
        state = state.copyWith(iceState: ice, connState: conn);
        if (conn == 'connected' || ice == 'connected') {
          _wasConnected = true;
        }
      },
      onConnectionClosed: () {
        endCall(sendSignal: false);
      },
      onLocalIceCandidate: () {
        state = state.copyWith(localIceCount: state.localIceCount + 1);
      },
    );

    print('CallProvider.makeCall: init WebRTCService...');
    await _webrtcService!.init(isVideo);
    print('CallProvider.makeCall: init complete, saving localStream.');
    state = state.copyWith(localStream: _webrtcService!.localStream);

    print('CallProvider.makeCall: creating offer...');
    await _webrtcService!.createOffer();
    print('CallProvider.makeCall: offer created.');
  }

  Future<void> answerCall() async {
    if (_latestOffer == null) return;

    final isVideo = state.isVideoEnabled;
    state = state.copyWith(state: CallState.inCall);

    _isCaller = false;
    _wasConnected = false;

    _webrtcService = WebRTCService(
      onSignalingData: (data) {
        _signalingService?.send(data, targetUserId: state.peerUserId);
      },
      onRemoteStreamAdded: () {
        state = state.copyWith(remoteStream: _webrtcService!.remoteStream);
      },
      onConnectionStateChange: (String ice, String conn) {
        state = state.copyWith(iceState: ice, connState: conn);
        if (conn == 'connected' || ice == 'connected') {
          _wasConnected = true;
        }
      },
      onConnectionClosed: () {
        endCall(sendSignal: false);
      },
      onLocalIceCandidate: () {
        state = state.copyWith(localIceCount: state.localIceCount + 1);
      },
    );

    await _webrtcService!.init(isVideo);
    state = state.copyWith(localStream: _webrtcService!.localStream);

    await _webrtcService!.handleOffer(_latestOffer!);
    _latestOffer = null;

    _flushQueuedCandidates();
  }

  void _flushQueuedCandidates() {
    for (var candidate in _queuedCandidates) {
      _webrtcService?.handleIceCandidate(candidate);
    }
    _queuedCandidates.clear();
  }

  Future<void> endCall({bool sendSignal = true, String? reason}) async {
    if (state.state == CallState.idle) return; // Already ended

    final bool wasActuallyConnected =
        _wasConnected || state.state == CallState.inCall;

    if (sendSignal) {
      _signalingService?.send({
        'type': 'call-end',
        'reason': ?reason,
      }, targetUserId: state.peerUserId);
    }

    if (_isCaller) {
      final isVideo = state.isVideoEnabled;
      if (wasActuallyConnected) {
        await _sendCallSystemMessage(isVideo ? '📹 영상 통화 종료' : '📞 음성 통화 종료');
      } else if (reason == 'declined') {
        await _sendCallSystemMessage('❌ 통화가 거절되었습니다.');
      }
    }

    _isCaller = false;
    _wasConnected = false;

    await _webrtcService?.dispose();
    _webrtcService = null;
    _latestOffer = null;
    _queuedCandidates.clear();

    state = CallStateData(state: CallState.idle);
  }

  void toggleMute() {
    _webrtcService?.toggleMute();
  }

  void toggleVideo() {
    _webrtcService?.toggleVideo();
  }

  @override
  void dispose() {
    endCall(sendSignal: false);
    _signalingService?.dispose();
    super.dispose();
  }
}

final callProvider = StateNotifierProvider<CallProvider, CallStateData>((ref) {
  return CallProvider();
});
