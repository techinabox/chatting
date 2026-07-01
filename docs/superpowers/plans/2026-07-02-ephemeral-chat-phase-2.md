# Ephemeral Chat UI & Realtime Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Implement Phase 2: UI Implementation & Realtime Messaging using Riverpod for state management.

---

### Task 1: Dependencies & Repositories Setup

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/repositories/room_repository.dart`
- Create: `lib/repositories/message_repository.dart`
- Create: `lib/providers/chat_providers.dart`
- Test: `test/repositories_test.dart`

**Interfaces:**
- Produces: `RoomRepository` (createRoom, joinRoom) and `MessageRepository` (sendMessage).
- Produces: `flutter_riverpod` and `image_picker` added to dependencies.

- [ ] **Step 1: Write the failing test** (Mock dependencies and verify repository classes exist).
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Write minimal implementation**
  - Add `flutter_riverpod: ^2.5.1` and `image_picker: ^1.1.2` to `pubspec.yaml`.
  - Implement repository stubs.
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 2: HomeScreen Implementation

**Files:**
- Create: `lib/screens/home_screen.dart`
- Modify: `lib/main.dart` (set HomeScreen as default)
- Test: `test/home_screen_test.dart`

**Interfaces:**
- Produces: A screen with "Create Room" and "Join Room" flows.
- Validates that invite code inputs are >= 20 characters.

- [ ] **Step 1: Write the failing test** (Verify input validations and basic rendering).
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Write minimal implementation**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 3: ChatScreen & Realtime Implementation

**Files:**
- Create: `lib/screens/chat_screen.dart`
- Test: `test/chat_screen_test.dart`

**Interfaces:**
- Produces: Chat UI with message stream, text input, and realtime kick-out if room is destroyed.

- [ ] **Step 1: Write the failing test** (Verify UI elements exist).
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Write minimal implementation**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**
