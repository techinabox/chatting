const { Client } = require('pg');
const client = new Client({ connectionString: 'postgresql://postgres.hkytnedaxvsleychdowg:IKsdKWy1U1PXGjw4@aws-0-us-east-1.pooler.supabase.com:5432/postgres' });

async function run() {
  try {
    await client.connect();

    // 1. Add room_name to room_participants
    await client.query(`ALTER TABLE room_participants ADD COLUMN room_name text;`);
    console.log('Added room_name to room_participants');

    // 2. Drop name from rooms
    await client.query(`ALTER TABLE rooms DROP COLUMN name;`);
    console.log('Dropped name from rooms');

    // 3. Update RLS on room_participants
    await client.query(`
      CREATE POLICY "Users can update their own room participation" 
      ON room_participants FOR UPDATE 
      USING (user_id = auth.uid());
    `);
    console.log('Created UPDATE policy on room_participants');

    // 4. Update join_room RPC
    await client.query(`
      CREATE OR REPLACE FUNCTION public.join_room(invite_code text, p_room_name text DEFAULT 'Chat Room')
      RETURNS uuid
      LANGUAGE plpgsql
      SECURITY DEFINER
      AS $function$
      DECLARE
          target_room_id uuid;
      BEGIN
          SELECT room_id INTO target_room_id FROM public.invite_codes WHERE code = invite_code;
          IF target_room_id IS NULL THEN
              RAISE EXCEPTION 'Invalid invite code';
          END IF;
          
          IF auth.uid() IS NULL THEN
              RAISE EXCEPTION 'Not authenticated';
          END IF;
          
          INSERT INTO public.room_participants (room_id, user_id, room_name) 
          VALUES (target_room_id, auth.uid(), p_room_name)
          ON CONFLICT DO NOTHING;
          
          UPDATE public.invite_codes SET is_used = true WHERE code = invite_code;
          
          RETURN target_room_id;
      END;
      $function$;
    `);
    console.log('Updated join_room RPC');

  } catch (e) {
    console.error('Error:', e);
  } finally {
    await client.end();
  }
}

run();
