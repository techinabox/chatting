-- 1. Add unread_count to room_participants
ALTER TABLE public.room_participants
ADD COLUMN IF NOT EXISTS unread_count INT DEFAULT 0;

-- 2. Create a trigger function to increment unread_count
CREATE OR REPLACE FUNCTION increment_unread_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.room_participants
    SET unread_count = unread_count + 1
    WHERE room_id = NEW.room_id AND user_id != NEW.sender_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create the trigger on the messages table
DROP TRIGGER IF EXISTS on_message_insert ON public.messages;
CREATE TRIGGER on_message_insert
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION increment_unread_count();

-- 4. Create an RPC function to easily reset unread_count
CREATE OR REPLACE FUNCTION public.reset_unread_count(p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.room_participants
    SET unread_count = 0
    WHERE room_id = p_room_id AND user_id = auth.uid();
END;
$$;
