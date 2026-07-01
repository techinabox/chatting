# Ephemeral Chat App Design Spec

## 1. Product Overview
A highly secure, highly volatile chat application designed for temporary conversations. The core philosophy is "perfect erasure." When the room creator decides to end the chat, all traces of the conversation—including text messages and media files—are permanently wiped from the database and storage.

- **Primary Clients:** Flutter Mobile App (iOS/Android).
- **Module Support:** Core logic will be structured as an embeddable Flutter package/widget (`SecretChatWidget`) wrapped by a standalone demo app.

## 2. Architecture & Tech Stack
- **Frontend:** Flutter (Dart)
- **Backend:** Supabase (PostgreSQL, Realtime, Storage)
- **State Management:** Riverpod (or Provider) for managing chat states.
- **Media Handling:** `image_picker` for photo/video uploads.

## 3. Core Mechanisms & Workflows

### 3.1. Room Creation & 1:N Invitation
- A "Creator" presses "Create Room".
- The Creator specifies how many participants they want to invite (e.g., 5 people).
- The system generates **1 Master Room ID** and **N Unique Invite Codes** (each 20+ alphanumeric characters).
- The Creator copies and distributes these unique codes manually to each participant.

### 3.2. Participant Join Flow
- Participants must have the app installed.
- Participant opens the app, clicks "Join Chat", and pastes their unique 20+ character code.
- Participant enters a nickname for this session (unless the host enforced specific names).
- The backend validates the code. If the code is valid and unused (or bound to their current session), they enter the room.
- *Security:* Used invite codes are marked as 'active' and bound to the participant to prevent code sharing.

### 3.3. Chat & Media
- Participants can send text, photos, and videos.
- Supabase Realtime broadcasts messages to all participants in the room.

### 3.4. Permanent Destruction (The "Kill Switch")
- Only the Creator has the "Destroy Room" button.
- Upon pressing it, the `rooms` record is deleted.
- **Cascade Deletion:** PostgreSQL cascade deletes all associated `messages` and `participants`.
- **Media Deletion:** A Supabase Edge Function (or Database Webhook) listens to the room deletion event and automatically deletes the corresponding folder in Supabase Storage.
- All connected clients immediately receive a room-closed event and are navigated back to the home screen.

## 4. Database Schema (Supabase)

### 4.1. `rooms` table
- `id`: UUID (Primary Key)
- `creator_id`: UUID (Anonymous Auth ID of the creator)
- `created_at`: Timestamp

### 4.2. `invite_codes` table
- `code`: String (20+ chars, Primary Key)
- `room_id`: UUID (Foreign Key -> rooms.id, Cascade Delete)
- `is_used`: Boolean (Default: false)
- `participant_name`: String (Nullable)

### 4.3. `messages` table
- `id`: UUID (Primary Key)
- `room_id`: UUID (Foreign Key -> rooms.id, Cascade Delete)
- `sender_name`: String
- `content`: Text
- `media_url`: String (Nullable)
- `created_at`: Timestamp

## 5. Security & Row Level Security (RLS)
- **Invite Codes:** Cannot be queried directly. A participant uses an RPC (Remote Procedure Call) or direct specific query to validate the code.
- **Messages:** RLS policies ensure that only users who have successfully validated an active invite code for `room_id` can `SELECT` or `INSERT` messages in that room.
- **Storage:** RLS on the storage bucket restricts uploads and downloads strictly to authenticated session members of that room.
