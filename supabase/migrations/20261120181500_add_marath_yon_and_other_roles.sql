ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users
ADD CONSTRAINT users_role_check
CHECK (role IN ('rvc', 'maison_du_velo', 'admin', 'marath_yon', 'autres'));

CREATE OR REPLACE FUNCTION public.set_user_role(p_user_id UUID, p_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_target_role TEXT;
  v_target_is_active BOOLEAN;
  v_active_admin_count BIGINT;
BEGIN
  LOCK TABLE public.users IN SHARE ROW EXCLUSIVE MODE;

  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active
  ) THEN
    RAISE EXCEPTION 'admin_required' USING ERRCODE = '42501';
  END IF;

  IF p_role IS NULL OR p_role NOT IN ('admin', 'rvc', 'maison_du_velo', 'marath_yon', 'autres') THEN
    RAISE EXCEPTION 'invalid_user_role' USING ERRCODE = '22023';
  END IF;

  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'cannot_change_own_role' USING ERRCODE = '42501';
  END IF;

  SELECT role, is_active
  INTO v_target_role, v_target_is_active
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0002';
  END IF;

  IF v_target_role = p_role THEN
    RETURN;
  END IF;

  IF v_target_role = 'admin' AND v_target_is_active AND p_role <> 'admin' THEN
    SELECT count(*)
    INTO v_active_admin_count
    FROM public.users
    WHERE role = 'admin'
      AND is_active;

    IF v_active_admin_count <= 1 THEN
      RAISE EXCEPTION 'cannot_remove_last_active_admin' USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE public.users
  SET role = p_role
  WHERE id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_user_role(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_user_role(UUID, TEXT) TO authenticated;

COMMENT ON COLUMN public.users.role IS
'Organization assigned by an administrator: rvc, maison_du_velo, admin, marath_yon, or autres.';
