-- 1. Create storage bucket for avatars
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for avatars
CREATE POLICY "Avatars are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatars"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (string_to_array(name, '/'))[1]);

CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE
USING (bucket_id = 'avatars' AND auth.uid()::text = (string_to_array(name, '/'))[1]);

CREATE POLICY "Users can delete their own avatars"
ON storage.objects FOR DELETE
USING (bucket_id = 'avatars' AND auth.uid()::text = (string_to_array(name, '/'))[1]);

-- 2. Add avatar_url to room_participants and messages
ALTER TABLE public.room_participants
ADD COLUMN IF NOT EXISTS participant_avatar_url TEXT;

ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS sender_avatar_url TEXT;

-- 3. Update join_room RPC to include avatar_url
DROP FUNCTION IF EXISTS public.join_room(text, text, text, text);

CREATE OR REPLACE FUNCTION public.join_room(
    invite_code text, 
    p_room_name text, 
    p_participant_name text, 
    p_participant_emoji text,
    p_participant_avatar_url text DEFAULT NULL
)
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
    
    INSERT INTO public.room_participants (room_id, user_id, room_name, participant_name, participant_emoji, participant_avatar_url) 
    VALUES (target_room_id, auth.uid(), p_room_name, p_participant_name, p_participant_emoji, p_participant_avatar_url)
    ON CONFLICT (room_id, user_id) 
    DO UPDATE SET 
        room_name = p_room_name, 
        participant_name = p_participant_name, 
        participant_emoji = p_participant_emoji,
        participant_avatar_url = p_participant_avatar_url;
    
    UPDATE public.invite_codes SET is_used = true WHERE code = invite_code;
    
    RETURN target_room_id;
END;
$$;
