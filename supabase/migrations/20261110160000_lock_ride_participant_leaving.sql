DROP POLICY IF EXISTS "Users can leave permitted rides" ON public.ride_participants;

CREATE POLICY "Users can leave permitted rides"
ON public.ride_participants FOR DELETE TO authenticated
USING (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.rides
    WHERE rides.id = ride_participants.ride_id
      AND (rides.date + rides.time) AT TIME ZONE 'Europe/Paris' > now() + interval '1 hour'
  )
);
