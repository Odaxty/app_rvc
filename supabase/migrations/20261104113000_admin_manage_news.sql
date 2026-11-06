ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users
ADD CONSTRAINT users_role_check
CHECK (role IN ('rvc', 'maison_du_velo', 'admin'));

DO $$
DECLARE
  policy_record RECORD;
BEGIN
  FOR policy_record IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'news'
  LOOP
    EXECUTE format('DROP POLICY %I ON public.news', policy_record.policyname);
  END LOOP;
END;
$$;

ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read news"
ON public.news FOR SELECT
USING (true);

CREATE POLICY "Admins can create news"
ON public.news FOR INSERT TO authenticated
WITH CHECK (
  author_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  )
);

CREATE POLICY "Admins can update news"
ON public.news FOR UPDATE TO authenticated
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

CREATE POLICY "Admins can delete news"
ON public.news FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  )
);
