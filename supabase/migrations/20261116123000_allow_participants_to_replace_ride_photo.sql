CREATE OR REPLACE FUNCTION public.replace_ride_image(
  p_ride_id uuid,
  p_image_path text,
  p_image_url text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_admin boolean;
  v_ride_start timestamptz;
  v_expected_suffix text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Une connexion est nécessaire pour changer la photo.'
      USING ERRCODE = '42501';
  END IF;

  SELECT (rides.date + rides.time) AT TIME ZONE 'Europe/Paris'
  INTO v_ride_start
  FROM public.rides AS rides
  WHERE rides.id = p_ride_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cette sortie n’existe plus.';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = v_user_id
      AND role = 'admin'
  )
  INTO v_is_admin;

  IF NOT v_is_admin AND NOT EXISTS (
    SELECT 1
    FROM public.ride_participants
    WHERE ride_id = p_ride_id
      AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Seuls les participants inscrits et les admins peuvent changer la photo.'
      USING ERRCODE = '42501';
  END IF;

  IF now() < v_ride_start + interval '1 hour' THEN
    RAISE EXCEPTION 'La photo pourra être changée une heure après le départ prévu.';
  END IF;

  IF p_image_path !~ (
    '^' || v_user_id::text || '/[0-9a-f-]{36}[.](jpg|jpeg|png|webp)$'
  ) THEN
    RAISE EXCEPTION 'Le chemin de la photo est invalide.';
  END IF;

  v_expected_suffix := '/storage/v1/object/public/ride-images/' || p_image_path;
  IF p_image_url IS NULL
    OR p_image_url NOT LIKE 'https://%'
    OR right(p_image_url, length(v_expected_suffix)) <> v_expected_suffix
  THEN
    RAISE EXCEPTION 'L’adresse de la photo est invalide.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM storage.objects
    WHERE bucket_id = 'ride-images'
      AND name = p_image_path
  ) THEN
    RAISE EXCEPTION 'La photo envoyée est introuvable.';
  END IF;

  UPDATE public.rides
  SET image_url = p_image_url
  WHERE id = p_ride_id;
END;
$$;

REVOKE ALL ON FUNCTION public.replace_ride_image(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.replace_ride_image(uuid, text, text) TO authenticated;
