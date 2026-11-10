ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE OR REPLACE FUNCTION public.prevent_user_active_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.is_active IS DISTINCT FROM OLD.is_active
    AND current_user NOT IN ('postgres', 'supabase_admin', 'service_role')
    AND COALESCE(auth.role(), '') <> 'service_role'
  THEN
    RAISE EXCEPTION 'user_active_change_forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_user_active_change ON public.users;
CREATE TRIGGER prevent_user_active_change
BEFORE UPDATE OF is_active ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.prevent_user_active_change();

CREATE OR REPLACE FUNCTION public.sync_user_auth_ban()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE auth.users
  SET banned_until = CASE
    WHEN NEW.is_active THEN NULL
    ELSE now() + interval '100 years'
  END
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_user_auth_ban ON public.users;
CREATE TRIGGER sync_user_auth_ban
AFTER UPDATE OF is_active ON public.users
FOR EACH ROW
WHEN (NEW.is_active IS DISTINCT FROM OLD.is_active)
EXECUTE FUNCTION public.sync_user_auth_ban();

CREATE OR REPLACE FUNCTION public.set_user_active(p_user_id UUID, p_is_active BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active
  ) THEN
    RAISE EXCEPTION 'admin_required' USING ERRCODE = '42501';
  END IF;

  IF p_user_id = auth.uid() AND NOT p_is_active THEN
    RAISE EXCEPTION 'cannot_deactivate_own_account' USING ERRCODE = '42501';
  END IF;

  UPDATE public.users
  SET is_active = p_is_active
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.set_user_active(UUID, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_user_active(UUID, BOOLEAN) TO authenticated;

COMMENT ON COLUMN public.users.is_active IS
'Whether the account is allowed to authenticate. Inactive users retain their profile and data.';
