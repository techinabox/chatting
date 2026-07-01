BEGIN;
SELECT plan(30);

-- Tables exist
SELECT has_table('public', 'rooms', 'rooms table should exist');
SELECT has_table('public', 'invite_codes', 'invite_codes table should exist');
SELECT has_table('public', 'messages', 'messages table should exist');

-- Columns in rooms
SELECT has_column('public', 'rooms', 'id', 'rooms should have id');
SELECT has_column('public', 'rooms', 'creator_id', 'rooms should have creator_id');
SELECT has_column('public', 'rooms', 'created_at', 'rooms should have created_at');

-- Columns in invite_codes
SELECT has_column('public', 'invite_codes', 'code', 'invite_codes should have code');
SELECT has_column('public', 'invite_codes', 'room_id', 'invite_codes should have room_id');
SELECT has_column('public', 'invite_codes', 'is_used', 'invite_codes should have is_used');
SELECT has_column('public', 'invite_codes', 'participant_name', 'invite_codes should have participant_name');

-- Columns in messages
SELECT has_column('public', 'messages', 'id', 'messages should have id');
SELECT has_column('public', 'messages', 'room_id', 'messages should have room_id');
SELECT has_column('public', 'messages', 'sender_name', 'messages should have sender_name');
SELECT has_column('public', 'messages', 'content', 'messages should have content');
SELECT has_column('public', 'messages', 'media_url', 'messages should have media_url');
SELECT has_column('public', 'messages', 'created_at', 'messages should have created_at');

-- Primary keys
SELECT has_pk('public', 'rooms', 'rooms should have primary key');
SELECT has_pk('public', 'invite_codes', 'invite_codes should have primary key');
SELECT has_pk('public', 'messages', 'messages should have primary key');

-- Foreign keys
SELECT has_fk('public', 'invite_codes', 'invite_codes should have foreign keys');
SELECT has_fk('public', 'messages', 'messages should have foreign keys');

-- RLS enabled
SELECT table_has_rls('public', 'rooms', 'rooms should have RLS enabled');
SELECT table_has_rls('public', 'invite_codes', 'invite_codes should have RLS enabled');
SELECT table_has_rls('public', 'messages', 'messages should have RLS enabled');

-- Policies exist
SELECT policies_are('public', 'rooms', ARRAY['Allow all operations on rooms'], 'rooms should have appropriate policy');
SELECT policies_are('public', 'invite_codes', ARRAY['Allow all operations on invite_codes'], 'invite_codes should have appropriate policy');
SELECT policies_are('public', 'messages', ARRAY['Allow all operations on messages'], 'messages should have appropriate policy');

-- Trigger & function
SELECT has_trigger('public', 'rooms', 'on_room_delete', 'rooms should have on_room_delete trigger');
SELECT has_function('public', 'delete_room_media', 'delete_room_media function should exist');

-- Storage bucket
SELECT results_eq(
    $$ SELECT id FROM storage.buckets WHERE id = 'chat_media' $$,
    $$ VALUES ('chat_media'::text) $$,
    'chat_media bucket should exist'
);

SELECT * FROM finish();
ROLLBACK;
