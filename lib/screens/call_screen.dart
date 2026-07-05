import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:ephemeral_chat/providers/call_provider.dart';
import 'package:ephemeral_chat/providers/module_providers.dart';
import 'dart:ui';

class CallScreen extends ConsumerStatefulWidget {
  final String remoteUserName;
  final String? remoteAvatarUrl;

  const CallScreen({
    super.key,
    required this.remoteUserName,
    this.remoteAvatarUrl,
  });

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
                      color: const Color(0xFF131313),
                      gradient: RadialGradient(
                        colors: [
                          themeConfig.sendButtonColor.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                        radius: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

            // Top Left Back Button
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white54,
                    size: 20,
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
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFB388FF).withValues(alpha: 0.3),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB388FF).withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                        image: DecorationImage(
                          image: widget.remoteAvatarUrl != null
                              ? NetworkImage(widget.remoteAvatarUrl!)
                              : const NetworkImage('https://i.pravatar.cc/300?img=5') as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                    widget.remoteUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFB388FF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'CALLING...',
                            style: TextStyle(
                              color: Color(0xFFB388FF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
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
              bottom: 48,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  GestureDetector(
                    onTap: () => ref.read(callProvider.notifier).toggleMute(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_off_outlined,
                        color: Colors.white54,
                        size: 28,
                      ),
                    ),
                  ),
                  // End Call
                  GestureDetector(
                    onTap: () => ref.read(callProvider.notifier).endCall(),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB3B3),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB3B3).withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Color(0xFF8B0000),
                        size: 36,
                      ),
                    ),
                  ),
                  // Video
                  GestureDetector(
                    onTap: () => ref.read(callProvider.notifier).toggleVideo(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam_outlined,
                        color: Colors.white54,
                        size: 28,
                      ),
                    ),
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
