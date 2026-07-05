# fadechat Design System

This document outlines the design metadata, layout strategies, and styling guidelines for the **fadechat** app. It is designed to work in conjunction with Stitch.

## 1. Theme Strategy
- **Base Theme**: The application's theme extends `ThemeData.dark()`.
- **Colors & Typography**: All UI components and screens generated from Stitch should reference and extend properties from `ThemeData.dark()`. Do not use hardcoded colors unless specifically defined as part of the theme extension.
- **Goal**: Maintain a consistent, immersive dark mode experience suitable for a modern chatting application.

## 2. State Management
- **Library**: `flutter_riverpod`
- **Guidelines**:
  - Follow the existing project setup for state management.
  - UI components should be mostly stateless, relying on Riverpod `ConsumerWidget` or `ConsumerStatefulWidget` to read and watch states.
  - Keep business logic separated from the design and UI layers.

## 3. Stitch Integration
- Design files, layouts, and assets generated via Stitch should be placed within the `lib/design/` folder.
- Ensure all generated Flutter code complies with the theme extensions and Riverpod state management patterns outlined above.

---
*Ready for Stitch design metadata injection.*
