import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:ephemeral_chat/providers/call_provider.dart';
import 'package:ephemeral_chat/providers/module_providers.dart';
import 'dart:ui';

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

    final themeConfig = ref.watch(chatModuleConfigProvider);
    final isNeon = themeConfig.themeName == 'neon_silence';

    return Scaffold(
      backgroundColor: isNeon ? Colors.black : Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Blur for Neon Silence
            if (isNeon)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          themeConfig.sendButtonColor.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                        radius: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

            // Remote Video
            if (callState.remoteStream != null && callState.isVideoEnabled)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNeonFAB(
                        heroTag: 'mute',
                        icon: Icons.mic_off,
                        color: isNeon
                            ? themeConfig.sendButtonColor
                            : Colors.white30,
                        onPressed: () =>
                            ref.read(callProvider.notifier).toggleMute(),
                        isNeon: isNeon,
                      ),
                      _buildNeonFAB(
                        heroTag: 'video',
                        icon: Icons.videocam_off,
                        color: isNeon
                            ? themeConfig.sendButtonColor
                            : Colors.white30,
                        onPressed: () =>
                            ref.read(callProvider.notifier).toggleVideo(),
                        isNeon: isNeon,
                      ),
                      _buildNeonFAB(
                        heroTag: 'end',
                        icon: Icons.call_end,
                        color: Colors.redAccent,
                        onPressed: () =>
                            ref.read(callProvider.notifier).endCall(),
                        isNeon: isNeon,
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

  Widget _buildNeonFAB({
    required String heroTag,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required bool isNeon,
  }) {
    return Container(
      decoration: isNeon
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: FloatingActionButton(
        heroTag: heroTag,
        backgroundColor: color.withValues(alpha: isNeon ? 0.8 : 1.0),
        onPressed: onPressed,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
