-- Re-create the trigger function to ignore WEBRTC_SIGNAL messages
CREATE OR REPLACE FUNCTION increment_unread_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Do not increment unread count for signaling messages
    IF NEW.content LIKE 'WEBRTC_SIGNAL:%' THEN
        RETURN NEW;
    END IF;

    UPDATE public.room_participants
    SET unread_count = unread_count + 1
    WHERE room_id = NEW.room_id AND user_id != NEW.sender_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
