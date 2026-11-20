DROP POLICY IF EXISTS "Admins can delete any unlocked ride" ON public.rides;
DROP POLICY IF EXISTS "Admins can delete any ride" ON public.rides;

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
