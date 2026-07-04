import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:ephemeral_chat/providers/call_provider.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);

    // Update renderers when streams change
    if (_localRenderer.srcObject != callState.localStream) {
      _localRenderer.srcObject = callState.localStream;
    }
    if (_remoteRenderer.srcObject != callState.remoteStream) {
      _remoteRenderer.srcObject = callState.remoteStream;
    }

    // If call ended, pop screen
    if (callState.state == CallState.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video
            if (callState.remoteStream != null && callState.isVideoEnabled)
              RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else if (callState.isVideoEnabled)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Connecting Video...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              )
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 100, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Voice Call',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ],
                ),
              ),

            // Local Video (PiP)
            if (callState.localStream != null && callState.isVideoEnabled)
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Controls
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // DEBUG INFO
                  Text(
                    'ICE: ${callState.iceState} | Conn: ${callState.connState}',
                    style: const TextStyle(color: Colors.yellow, fontSize: 12),
                  ),
                  Text(
                    'Sent ICE: ${callState.localIceCount} | Rcvd ICE: ${callState.remoteIceCount}',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(
                        heroTag: 'mute',
                        backgroundColor: Colors.white30,
                        onPressed: () {
                          ref.read(callProvider.notifier).toggleMute();
                        },
                        child: const Icon(Icons.mic_off, color: Colors.white),
                      ),
                      FloatingActionButton(
                        heroTag: 'video',
                        backgroundColor: Colors.white30,
                        onPressed: () {
                          ref.read(callProvider.notifier).toggleVideo();
                        },
                        child: const Icon(
                          Icons.videocam_off,
                          color: Colors.white,
                        ),
                      ),
                      FloatingActionButton(
                        heroTag: 'end',
                        backgroundColor: Colors.red,
                        onPressed: () {
                          ref.read(callProvider.notifier).endCall();
                        },
                        child: const Icon(Icons.call_end, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
