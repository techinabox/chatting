-- Copy and paste this into your Supabase SQL Editor and click "Run"

CREATE OR REPLACE FUNCTION join_room(
    invite_code text,
    p_room_name text,
    p_participant_name text,
    p_participant_emoji text,
    p_participant_avatar_url text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
    target_room_id uuid;
    code_created_at timestamptz;
BEGIN
    -- 1. Find the invite code and its creation time
    SELECT room_id, created_at INTO target_room_id, code_created_at
    FROM invite_codes 
    WHERE code = invite_code;

    IF target_room_id IS NULL THEN
        RAISE EXCEPTION 'Invalid invite code.';
    END IF;

    -- 2. Check if the code has expired (10 minutes)
    IF now() - code_created_at > interval '10 minutes' THEN
        -- Optionally delete the expired code
        DELETE FROM invite_codes WHERE code = invite_code;
        RAISE EXCEPTION 'Invite code has expired (valid for 10 minutes).';
    END IF;

    -- 3. Insert the user into room_participants
    INSERT INTO room_participants (
        room_id, 
        user_id, 
        room_name, 
        participant_name, 
        participant_emoji,
        participant_avatar_url
    ) VALUES (
        target_room_id, 
        auth.uid(), 
        p_room_name, 
        p_participant_name, 
        p_participant_emoji,
        p_participant_avatar_url
    );
    
    -- 4. Delete the invite code so it can only be used ONCE
    DELETE FROM invite_codes WHERE code = invite_code;

    RETURN target_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
