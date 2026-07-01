BEGIN;
SELECT plan(1);
-- Test if rooms table exists
SELECT has_table('public', 'rooms', 'rooms table should exist');
SELECT * FROM finish();
ROLLBACK;
