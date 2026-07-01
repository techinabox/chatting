CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.invite_codes (
    code TEXT PRIMARY KEY CHECK (char_length(code) >= 20 AND code ~ '^[a-zA-Z0-9]+$'),
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

-- Storage Bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('chat_media', 'chat_media', false)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE TABLE public.room_participants (
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    PRIMARY KEY (room_id, user_id)
);
ALTER TABLE public.room_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants can view their own mapping" ON public.room_participants FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Creator can manage room" ON public.rooms FOR ALL USING (creator_id = auth.uid());
CREATE POLICY "Participants can view room" ON public.rooms FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.room_participants WHERE room_id = id AND user_id = auth.uid())
);

CREATE POLICY "Creator can manage invite codes" ON public.invite_codes FOR ALL USING (
    EXISTS (SELECT 1 FROM public.rooms WHERE id = room_id AND creator_id = auth.uid())
);
CREATE POLICY "Anyone can read invite codes to join" ON public.invite_codes FOR SELECT USING (true);

CREATE POLICY "Participants can manage messages" ON public.messages FOR ALL USING (
    EXISTS (SELECT 1 FROM public.room_participants WHERE room_id = messages.room_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.rooms WHERE id = messages.room_id AND creator_id = auth.uid())
) WITH CHECK (
    EXISTS (SELECT 1 FROM public.room_participants WHERE room_id = messages.room_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.rooms WHERE id = messages.room_id AND creator_id = auth.uid())
);

CREATE POLICY "Participants can manage chat media" ON storage.objects FOR ALL USING (
    bucket_id = 'chat_media' AND (
        EXISTS (
            SELECT 1 FROM public.room_participants 
            WHERE room_id::text = (string_to_array(name, '/'))[1] 
              AND user_id = auth.uid()
        ) OR
        EXISTS (
            SELECT 1 FROM public.rooms 
            WHERE id::text = (string_to_array(name, '/'))[1] 
              AND creator_id = auth.uid()
        )
    )
);

-- Function to join a room securely using an invite code
CREATE OR REPLACE FUNCTION public.join_room(invite_code text)
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
    
    INSERT INTO public.room_participants (room_id, user_id) 
    VALUES (target_room_id, auth.uid())
    ON CONFLICT DO NOTHING;
    
    UPDATE public.invite_codes SET is_used = true WHERE code = invite_code;
    
    RETURN target_room_id;
END;
$$;
-- Trigger to delete media when room is deleted
CREATE OR REPLACE FUNCTION delete_room_media()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM storage.objects 
  WHERE bucket_id = 'chat_media' 
    AND name LIKE OLD.id::text || '/%';
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_room_delete
AFTER DELETE ON public.rooms
FOR EACH ROW
EXECUTE FUNCTION delete_room_media();
