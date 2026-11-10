DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications"
ON public.notifications FOR DELETE TO authenticated
USING (recipient_id = auth.uid());

GRANT DELETE ON public.notifications TO authenticated;
