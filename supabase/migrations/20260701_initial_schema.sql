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
CREATE POLICY "Allow all operations on rooms" ON public.rooms FOR ALL USING (true);
CREATE POLICY "Allow all operations on invite_codes" ON public.invite_codes FOR ALL USING (true);
CREATE POLICY "Allow all operations on messages" ON public.messages FOR ALL USING (true);
CREATE POLICY "Allow all operations on chat_media" ON storage.objects FOR ALL USING (bucket_id = 'chat_media');

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
