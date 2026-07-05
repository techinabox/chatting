import 'package:flutter/material.dart';

class ChatModuleConfig {
  final Color backgroundColor;
  final Color myBubbleColor;
  final Color otherBubbleColor;
  final Color textColor;
  final Color nameTextColor;
  final Color dateTextColor;
  final Color dateBackground;
  final Color inputBackground;
  final Color sendButtonColor;
  final String themeName;
  final Color homeBackgroundColor;
  final Color homeTextColor;
  final Color homeSubtextColor;

  const ChatModuleConfig({
    this.themeName = 'kakao',
    required this.backgroundColor,
    required this.myBubbleColor,
    required this.otherBubbleColor,
    required this.textColor,
    required this.nameTextColor,
    required this.dateTextColor,
    required this.dateBackground,
    required this.inputBackground,
    required this.sendButtonColor,
    required this.homeBackgroundColor,
    required this.homeTextColor,
    required this.homeSubtextColor,
  });

  // Default Kakao Style Theme
  factory ChatModuleConfig.kakao() {
    return const ChatModuleConfig(
      themeName: 'kakao',
      backgroundColor: Color(0xFF9BBBD4),
      myBubbleColor: Color(0xFFFEE500),
      otherBubbleColor: Colors.white,
      textColor: Colors.black87,
      nameTextColor: Colors.black87,
      dateTextColor: Colors.white,
      dateBackground: Color(0x66000000),
      inputBackground: Colors.white,
      sendButtonColor: Color(0xFFFEE500),
      homeBackgroundColor: Color(0xFFFFFFFF),
      homeTextColor: Colors.black87,
      homeSubtextColor: Colors.black54,
    );
  }

  // Example Line Style Theme
  factory ChatModuleConfig.line() {
    return const ChatModuleConfig(
      themeName: 'line',
      backgroundColor: Color(0xFF708090),
      myBubbleColor: Color(0xFF85E249),
      otherBubbleColor: Colors.white,
      textColor: Colors.black87,
      nameTextColor: Colors.white,
      dateTextColor: Colors.white,
      dateBackground: Color(0x66000000),
      inputBackground: Colors.white,
      sendButtonColor: Color(0xFF85E249),
      homeBackgroundColor: Color(0xFFFFFFFF),
      homeTextColor: Colors.black87,
      homeSubtextColor: Colors.black54,
    );
  }

  // Example Dark Mode Theme
  factory ChatModuleConfig.dark() {
    return const ChatModuleConfig(
      themeName: 'dark',
      backgroundColor: Color(0xFF1E1E1E),
      myBubbleColor: Color(0xFF3B3B3B),
      otherBubbleColor: Color(0xFF2C2C2C),
      textColor: Colors.white,
      nameTextColor: Colors.white70,
      dateTextColor: Colors.white54,
      dateBackground: Color(0x33000000),
      inputBackground: Color(0xFF2C2C2C),
      sendButtonColor: Color(0xFF5A5A5A),
      homeBackgroundColor: Color(0xFF1E1E1E),
      homeTextColor: Colors.white,
      homeSubtextColor: Colors.white54,
    );
  }

  // Neon Silence Theme
  factory ChatModuleConfig.neonSilence() {
    return const ChatModuleConfig(
      themeName: 'neon_silence',
      backgroundColor: Color(0xFF000000), // Pure black background
      myBubbleColor: Color(
        0x33BB86FC,
      ), // Glassmorphic sent bubble (20% opacity primary)
      otherBubbleColor: Color(0xFF1E1E1E), // Received bubble solid
      textColor: Colors.white,
      nameTextColor: Color(0xFFE5E2E1), // on-surface
      dateTextColor: Color(0xFFCDC3D4), // on-surface-variant
      dateBackground: Color(0x00000000), // transparent for neon
      inputBackground: Color(0xFF1E1E1E), // surface
      sendButtonColor: Color(0xFFBB86FC), // primary
      homeBackgroundColor: Color(0xFF000000), // Pure black
      homeTextColor: Color(0xFFE5E2E1), // on-surface
      homeSubtextColor: Color(0xFFCDC3D4), // on-surface-variant
    );
  }
}
