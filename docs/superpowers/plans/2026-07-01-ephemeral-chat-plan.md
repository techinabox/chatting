# Ephemeral Chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a highly volatile Flutter chat application/module and Supabase backend where users join via unique 20+ char invite codes, and room destruction permanently cascades deletions across messages and media.

**Architecture:** A Flutter frontend utilizing Riverpod for state management and the `supabase_flutter` SDK for database, realtime, and storage. The backend relies completely on Supabase PostgreSQL cascade deletes and edge functions/triggers to wipe media.

**Tech Stack:** Flutter, Supabase (Database, Auth, Storage, Realtime), Riverpod (State).

## Global Constraints

- Flutter version >= 3.22.0
- Supabase Flutter SDK latest version
- Invite codes must be exactly 20 alphanumeric characters minimum
- All data must be permanently unrecoverable upon room destruction

---

### Task 1: Supabase Backend Setup & Database Schema

**Files:**
- Create: `supabase/migrations/20260701_initial_schema.sql`
- Test: `supabase/tests/schema_test.sql`

**Interfaces:**
- Produces: Tables (`rooms`, `invite_codes`, `messages`), RLS policies, Storage bucket (`chat_media`).

- [ ] **Step 1: Write the failing test**

```sql
-- supabase/tests/schema_test.sql
BEGIN;
SELECT plan(1);
-- Test if rooms table exists
SELECT has_table('public', 'rooms', 'rooms table should exist');
SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `supabase test db`
Expected: FAIL (table "rooms" does not exist)

- [ ] **Step 3: Write minimal implementation**

```sql
-- supabase/migrations/20260701_initial_schema.sql
CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.invite_codes (
    code TEXT PRIMARY KEY CHECK (char_length(code) >= 20),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    is_used BOOLEAN DEFAULT false,
    participant_name TEXT
);

CREATE TABLE public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    sender_name TEXT NOT NULL,
    content TEXT,
    media_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invite_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `supabase start && supabase test db`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add supabase
git commit -m "feat: initial supabase schema and tables"
```

---

### Task 2: Flutter Project Scaffold & Supabase Init

**Files:**
- Create: `pubspec.yaml`
- Modify: `lib/main.dart`
- Create: `lib/services/supabase_service.dart`
- Test: `test/supabase_service_test.dart`

**Interfaces:**
- Consumes: Supabase local credentials.
- Produces: `SupabaseService` class that handles client initialization.

- [ ] **Step 1: Write the failing test**

```dart
// test/supabase_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ephemeral_chat/services/supabase_service.dart';

void main() {
  test('SupabaseService initializes successfully', () async {
    final service = SupabaseService();
    expect(service, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/supabase_service_test.dart`
Expected: FAIL (File not found / SupabaseService not defined)

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'YOUR_SUPABASE_URL',
      anonKey: 'YOUR_SUPABASE_ANON_KEY',
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/supabase_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ test/ pubspec.yaml
git commit -m "feat: setup flutter project and supabase service"
```

---

### Task 3: Invite Code Generation Logic

**Files:**
- Create: `lib/utils/invite_code_generator.dart`
- Test: `test/invite_code_generator_test.dart`

**Interfaces:**
- Produces: `String generateSecureCode(int length)`

- [ ] **Step 1: Write the failing test**

```dart
// test/invite_code_generator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ephemeral_chat/utils/invite_code_generator.dart';

void main() {
  test('Generates 20+ char alphanumeric code', () {
    final code = InviteCodeGenerator.generate(20);
    expect(code.length, greaterThanOrEqualTo(20));
    expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(code), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/invite_code_generator_test.dart`
Expected: FAIL (InviteCodeGenerator not defined)

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/utils/invite_code_generator.dart
import 'dart:math';

class InviteCodeGenerator {
  static String generate(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/invite_code_generator_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/utils test/
git commit -m "feat: add secure invite code generator"
```
