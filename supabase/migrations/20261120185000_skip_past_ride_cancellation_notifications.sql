CREATE OR REPLACE FUNCTION public.notify_participants_ride_cancelled()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  ride_creator_name TEXT;
BEGIN
  IF (OLD.date + OLD.time) AT TIME ZONE 'Europe/Paris' <= now() THEN
    RETURN OLD;
  END IF;

  SELECT concat_ws(' ', users.firstname, users.lastname)
  INTO ride_creator_name
  FROM public.users
  WHERE users.id = OLD.creator_id;

  INSERT INTO public.notifications (
    recipient_id,
    ride_id,
    participant_id,
    participant_name,
    ride_name,
    type,
    creator_name,
    message
  )
  SELECT
    participants.user_id,
    OLD.id,
    participants.user_id,
    COALESCE(NULLIF(concat_ws(' ', users.firstname, users.lastname), ''), 'Un membre'),
    OLD.name,
    'ride_cancelled',
    COALESCE(NULLIF(ride_creator_name, ''), 'Le créateur'),
    format(
      'Mince, la sortie du %s, créée par %s, a été annulée. Inscris-toi à une nouvelle sortie.',
      to_char(OLD.date, 'DD/MM/YYYY'),
      COALESCE(NULLIF(ride_creator_name, ''), 'le créateur')
    )
  FROM public.ride_participants AS participants
  LEFT JOIN public.users AS users ON users.id = participants.user_id
  WHERE participants.ride_id = OLD.id
    AND participants.user_id <> OLD.creator_id
  ON CONFLICT (recipient_id, ride_id, type)
    WHERE ride_id IS NOT NULL AND type IN ('ride_reminder', 'ride_cancelled', 'ride_full')
  DO NOTHING;

  RETURN OLD;
END;
$$;
