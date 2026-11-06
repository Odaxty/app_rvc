DROP POLICY IF EXISTS "Organization role controls ride visibility" ON public.rides;

CREATE POLICY "Organization role controls ride visibility"
ON public.rides AS RESTRICTIVE FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND (
        role IN ('rvc', 'admin')
        OR rides.ride_type IS DISTINCT FROM 'Club'
      )
  )
);

CREATE POLICY "Admins can create any ride"
ON public.rides FOR INSERT TO authenticated
WITH CHECK (
  creator_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  )
);

CREATE POLICY "Admins can update any ride"
ON public.rides FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  )
);

CREATE POLICY "Admins can delete any ride"
ON public.rides FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  )
);

CREATE POLICY "Admins can remove any participant"
ON public.ride_participants FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  )
);
