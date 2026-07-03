-- 1. Add participant_name and participant_emoji to room_participants
ALTER TABLE public.room_participants
ADD COLUMN IF NOT EXISTS participant_name TEXT,
ADD COLUMN IF NOT EXISTS participant_emoji TEXT;

-- 2. Add sender_emoji to messages
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS sender_emoji TEXT;

-- 3. Update join_room RPC to take name and emoji
CREATE OR REPLACE FUNCTION public.join_room(invite_code text, p_room_name text, p_participant_name text, p_participant_emoji text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
    
    INSERT INTO public.room_participants (room_id, user_id, room_name, participant_name, participant_emoji) 
    VALUES (target_room_id, auth.uid(), p_room_name, p_participant_name, p_participant_emoji)
    ON CONFLICT (room_id, user_id) 
    DO UPDATE SET 
        room_name = p_room_name, 
        participant_name = p_participant_name, 
        participant_emoji = p_participant_emoji;
    
    UPDATE public.invite_codes SET is_used = true WHERE code = invite_code;
    
    RETURN target_room_id;
END;
$$;
