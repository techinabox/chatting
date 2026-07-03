import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';

typedef OnSignalingData = void Function(Map<String, dynamic> data);

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isRemoteDescriptionSet = false;

  bool get isRemoteDescriptionSet => _isRemoteDescriptionSet;

  final OnSignalingData onSignalingData;
  final VoidCallback onRemoteStreamAdded;
  final Function(String, String) onConnectionStateChange;
  final VoidCallback onConnectionClosed;
  final VoidCallback onLocalIceCandidate;

  WebRTCService({
    required this.onSignalingData,
    required this.onRemoteStreamAdded,
    required this.onConnectionStateChange,
    required this.onConnectionClosed,
    required this.onLocalIceCandidate,
  });

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'url': 'stun:stun.l.google.com:19302',
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302'
        ],
      },
      {
        'url': 'turn:openrelay.metered.ca:443?transport=tcp',
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:443',
          'turn:openrelay.metered.ca:443?transport=tcp'
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> init(bool isVideoEnabled) async {
    try {
      print('WebRTCService.init: Requesting media (video: $isVideoEnabled)');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideoEnabled,
      });
      print('WebRTCService.init: Media stream acquired: ${_localStream?.id}');
    } catch (e) {
      print('WebRTCService.init Error: $e');
      rethrow;
    }

    _peerConnection = await createPeerConnection(_iceServers);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      onLocalIceCandidate();
      onSignalingData({
        'type': 'ice-candidate',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStreamAdded();
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      onConnectionStateChange(
        _peerConnection!.iceConnectionState?.name ?? 'unknown',
        state.name,
      );
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        onConnectionClosed();
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      onConnectionStateChange(
        state.name,
        _peerConnection!.connectionState?.name ?? 'unknown',
      );
    };

    // Add local tracks to peer connection
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
  }

  Future<void> createOffer() async {
    if (_peerConnection == null) return;
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    onSignalingData({
      'type': 'call-offer',
      'sdp': offer.sdp,
    });
  }

  Future<void> handleOffer(String sdp) async {
    if (_peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    onSignalingData({
      'type': 'call-answer',
      'sdp': answer.sdp,
    });
    _isRemoteDescriptionSet = true;
  }

  Future<void> handleAnswer(String sdp) async {
    if (_peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'answer'),
    );
    _isRemoteDescriptionSet = true;
  }

  Future<void> handleIceCandidate(Map<String, dynamic> candidateMap) async {
    if (_peerConnection == null) return;
    RTCIceCandidate candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
  }

  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final track = audioTracks[0];
        track.enabled = !track.enabled;
      }
    }
  }

  void toggleVideo() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final track = videoTracks[0];
        track.enabled = !track.enabled;
      }
    }
  }

  Future<void> dispose() async {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream!.dispose();
      _localStream = null;
    }
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
    _remoteStream = null;
  }
}
