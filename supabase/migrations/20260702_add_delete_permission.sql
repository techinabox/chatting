-- 1. Add delete_permission to rooms
ALTER TABLE public.rooms
ADD COLUMN delete_permission TEXT NOT NULL DEFAULT 'all';

-- 2. Add sender_id to messages
ALTER TABLE public.messages
ADD COLUMN sender_id UUID DEFAULT auth.uid();

-- 3. Drop the old all-encompassing policy for messages
DROP POLICY IF EXISTS "Participants can manage messages" ON public.messages;

-- 4. Create granular RLS policies for messages
CREATE POLICY "Select messages" ON public.messages FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.room_participants WHERE room_id = messages.room_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.rooms WHERE id = messages.room_id AND creator_id = auth.uid())
);

CREATE POLICY "Insert messages" ON public.messages FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.room_participants WHERE room_id = messages.room_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.rooms WHERE id = messages.room_id AND creator_id = auth.uid())
);

CREATE POLICY "Update messages" ON public.messages FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.rooms 
        WHERE id = messages.room_id 
        AND (
            creator_id = auth.uid() 
            OR (
                delete_permission = 'all' 
                AND EXISTS (SELECT 1 FROM public.room_participants WHERE room_id = messages.room_id AND user_id = auth.uid())
            )
            OR (
                delete_permission = 'own' 
                AND messages.sender_id = auth.uid()
                AND EXISTS (SELECT 1 FROM public.room_participants WHERE room_id = messages.room_id AND user_id = auth.uid())
            )
        )
    )
);

CREATE POLICY "Delete messages" ON public.messages FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM public.rooms 
        WHERE id = messages.room_id 
        AND (
            creator_id = auth.uid() 
            OR (
                delete_permission = 'all' 
                AND EXISTS (SELECT 1 FROM public.room_participants WHERE room_id = messages.room_id AND user_id = auth.uid())
            )
            OR (
                delete_permission = 'own' 
                AND messages.sender_id = auth.uid()
                AND EXISTS (SELECT 1 FROM public.room_participants WHERE room_id = messages.room_id AND user_id = auth.uid())
            )
        )
    )
);
