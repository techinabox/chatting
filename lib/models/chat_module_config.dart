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

  const ChatModuleConfig({
    required this.backgroundColor,
    required this.myBubbleColor,
    required this.otherBubbleColor,
    required this.textColor,
    required this.nameTextColor,
    required this.dateTextColor,
    required this.dateBackground,
    required this.inputBackground,
    required this.sendButtonColor,
  });

  // Default Kakao Style Theme
  factory ChatModuleConfig.kakao() {
    return const ChatModuleConfig(
      backgroundColor: Color(0xFF9BBBD4),
      myBubbleColor: Color(0xFFFEE500),
      otherBubbleColor: Colors.white,
      textColor: Colors.black87,
      nameTextColor: Colors.black87,
      dateTextColor: Colors.white,
      dateBackground: Color(0x66000000),
      inputBackground: Colors.white,
      sendButtonColor: Color(0xFFFEE500),
    );
  }

  // Example Line Style Theme
  factory ChatModuleConfig.line() {
    return const ChatModuleConfig(
      backgroundColor: Color(0xFF708090),
      myBubbleColor: Color(0xFF85E249),
      otherBubbleColor: Colors.white,
      textColor: Colors.black87,
      nameTextColor: Colors.white,
      dateTextColor: Colors.white,
      dateBackground: Color(0x66000000),
      inputBackground: Colors.white,
      sendButtonColor: Color(0xFF85E249),
    );
  }

  // Example Dark Mode Theme
  factory ChatModuleConfig.dark() {
    return const ChatModuleConfig(
      backgroundColor: Color(0xFF1E1E1E),
      myBubbleColor: Color(0xFF3B3B3B),
      otherBubbleColor: Color(0xFF2C2C2C),
      textColor: Colors.white,
      nameTextColor: Colors.white70,
      dateTextColor: Colors.white54,
      dateBackground: Color(0x33000000),
      inputBackground: Color(0xFF2C2C2C),
      sendButtonColor: Color(0xFF5A5A5A),
    );
  }
}
