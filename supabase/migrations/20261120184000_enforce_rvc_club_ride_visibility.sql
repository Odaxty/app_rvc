ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;

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
