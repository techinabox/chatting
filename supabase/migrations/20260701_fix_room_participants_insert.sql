CREATE POLICY "Creator can add themselves to participants" ON public.room_participants FOR INSERT WITH CHECK (
    user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.rooms WHERE id = room_id AND creator_id = auth.uid())
);
