ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'maison_du_velo';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_role_check'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
    ADD CONSTRAINT users_role_check
    CHECK (role IN ('rvc', 'maison_du_velo'));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.prevent_user_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role
    AND current_user NOT IN ('postgres', 'supabase_admin', 'service_role')
    AND COALESCE(auth.role(), '') <> 'service_role'
  THEN
    RAISE EXCEPTION 'user_role_change_forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_user_role_change ON public.users;
CREATE TRIGGER prevent_user_role_change
BEFORE UPDATE OF role ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.prevent_user_role_change();

DO $$
DECLARE
  policy_record RECORD;
BEGIN
  FOR policy_record IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('users', 'rides', 'ride_participants', 'comments')
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON public.%I',
      policy_record.policyname,
      policy_record.tablename
    );
  END LOOP;
END;
$$;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read profiles"
ON public.users FOR SELECT TO authenticated
USING (true);

CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

CREATE POLICY "Authenticated users can read permitted rides"
ON public.rides FOR SELECT TO authenticated
USING (true);

CREATE POLICY "Organization role controls ride visibility"
ON public.rides AS RESTRICTIVE FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND (role = 'rvc' OR rides.ride_type IS DISTINCT FROM 'Club')
  )
);

CREATE POLICY "Users can create permitted rides"
ON public.rides FOR INSERT TO authenticated
WITH CHECK (
  creator_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND (role = 'rvc' OR rides.ride_type IS DISTINCT FROM 'Club')
  )
);

CREATE POLICY "Creators can update permitted rides"
ON public.rides FOR UPDATE TO authenticated
USING (
  creator_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND (role = 'rvc' OR rides.ride_type IS DISTINCT FROM 'Club')
  )
)
WITH CHECK (
  creator_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND (role = 'rvc' OR rides.ride_type IS DISTINCT FROM 'Club')
  )
);

CREATE POLICY "Creators can delete own rides"
ON public.rides FOR DELETE TO authenticated
USING (creator_id = auth.uid());

CREATE POLICY "Users can read participants of permitted rides"
ON public.ride_participants FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.rides WHERE rides.id = ride_participants.ride_id
  )
);

CREATE POLICY "Users can join permitted rides"
ON public.ride_participants FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.rides WHERE rides.id = ride_participants.ride_id
  )
);

CREATE POLICY "Users can leave own rides"
ON public.ride_participants FOR DELETE TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Users can read comments on permitted rides"
ON public.comments FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.rides WHERE rides.id = comments.ride_id
  )
);

CREATE POLICY "Participants can comment on permitted rides"
ON public.comments FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.ride_participants
    WHERE ride_participants.ride_id = comments.ride_id
      AND ride_participants.user_id = auth.uid()
  )
);

COMMENT ON COLUMN public.users.role IS
'Organization assigned by an administrator: rvc or maison_du_velo.';

-- Après la migration, attribuer le rôle RVC aux comptes licenciés via le SQL Editor :
-- UPDATE public.users SET role = 'rvc' WHERE email IN ('licencie@example.com');
