import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';

typedef OnSignalingData = void Function(Map<String, dynamic> data);

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isRemoteDescriptionSet = false;
  final List<RTCIceCandidate> _remoteCandidatesQueue = [];

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
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:global.stun.twilio.com:3478'},
      {'urls': 'stun:stun.relay.metered.ca:80'},
      {
        'urls': 'turn:global.relay.metered.ca:80',
        'username': 'e6d79f87993e547822a8e38f',
        'credential': '8hcmkqMZctdoqSfV',
      },
      {
        'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
        'username': 'e6d79f87993e547822a8e38f',
        'credential': '8hcmkqMZctdoqSfV',
      },
      {
        'urls': 'turn:global.relay.metered.ca:443',
        'username': 'e6d79f87993e547822a8e38f',
        'credential': '8hcmkqMZctdoqSfV',
      },
      {
        'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
        'username': 'e6d79f87993e547822a8e38f',
        'credential': '8hcmkqMZctdoqSfV',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all',
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
      print('WebRTCService.init Warning: $e. Proceeding as receive-only.');
      _localStream = null;
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
        },
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
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    } else {
      // If no local media (e.g. no hardware), explicitly add transceivers
      // to ensure we can still receive remote media and gather ICE candidates.
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      if (isVideoEnabled) {
        await _peerConnection!.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );
      }
    }
  }

  Future<void> createOffer() async {
    if (_peerConnection == null) return;
    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(offer);

    onSignalingData({'type': 'call-offer', 'sdp': offer.sdp});
  }

  Future<void> handleOffer(String sdp) async {
    if (_peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    onSignalingData({'type': 'call-answer', 'sdp': answer.sdp});
    _isRemoteDescriptionSet = true;
    for (var candidate in _remoteCandidatesQueue) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('WebRTCService Error adding queued candidate (Offer): $e');
      }
    }
    _remoteCandidatesQueue.clear();
  }

  Future<void> handleAnswer(String sdp) async {
    if (_peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'answer'),
    );
    _isRemoteDescriptionSet = true;
    for (var candidate in _remoteCandidatesQueue) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('WebRTCService Error adding queued candidate (Answer): $e');
      }
    }
    _remoteCandidatesQueue.clear();
  }

  Future<void> handleIceCandidate(Map<String, dynamic> candidateMap) async {
    if (_peerConnection == null) return;
    RTCIceCandidate candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    if (!_isRemoteDescriptionSet) {
      _remoteCandidatesQueue.add(candidate);
    } else {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('WebRTCService Error adding candidate (Live): $e');
      }
    }
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
    _isRemoteDescriptionSet = false;
    _remoteCandidatesQueue.clear();
  }
}
