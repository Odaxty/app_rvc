DROP POLICY IF EXISTS "Creators can update own rides" ON public.rides;
DROP POLICY IF EXISTS "Creators can update permitted rides" ON public.rides;
DROP POLICY IF EXISTS "Creators can delete own rides" ON public.rides;
DROP POLICY IF EXISTS "Admins can update any ride" ON public.rides;
DROP POLICY IF EXISTS "Admins can delete any ride" ON public.rides;
DROP POLICY IF EXISTS "Users can leave own rides" ON public.ride_participants;
DROP POLICY IF EXISTS "Admins can remove any participant" ON public.ride_participants;

CREATE POLICY "Creators can update permitted rides"
ON public.rides FOR UPDATE TO authenticated
USING (
  creator_id = auth.uid()
  AND (
    NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
    OR (date + time) AT TIME ZONE 'Europe/Paris' > now() + interval '1 hour'
  )
)
WITH CHECK (
  creator_id = auth.uid()
  AND (
    NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
    OR (date + time) AT TIME ZONE 'Europe/Paris' > now() + interval '1 hour'
  )
);

CREATE POLICY "Admins can update any unlocked ride"
ON public.rides FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  )
  AND (date + time) AT TIME ZONE 'Europe/Paris' > now() + interval '1 hour'
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  )
  AND (date + time) AT TIME ZONE 'Europe/Paris' > now() + interval '1 hour'
);

CREATE POLICY "Creators can delete rides"
ON public.rides FOR DELETE TO authenticated
USING (
  creator_id = auth.uid()
  AND (
    NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
    OR (date + time) AT TIME ZONE 'Europe/Paris' > now() + interval '1 hour'
  )
);

CREATE POLICY "Admins can delete any unlocked ride"
ON public.rides FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  )
  AND (date + time) AT TIME ZONE 'Europe/Paris' > now() + interval '1 hour'
);

CREATE POLICY "Users can leave permitted rides"
ON public.ride_participants FOR DELETE TO authenticated
USING (
  user_id = auth.uid()
  AND (
    NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
    OR EXISTS (
      SELECT 1
      FROM public.rides
      WHERE rides.id = ride_participants.ride_id
        AND (rides.date + rides.time) AT TIME ZONE 'Europe/Paris' > now() + interval '1 hour'
    )
  )
);

CREATE POLICY "Admins can remove participants from unlocked rides"
ON public.ride_participants FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  )
  AND EXISTS (
    SELECT 1
    FROM public.rides
    WHERE rides.id = ride_participants.ride_id
      AND (rides.date + rides.time) AT TIME ZONE 'Europe/Paris' > now() + interval '1 hour'
  )
);
