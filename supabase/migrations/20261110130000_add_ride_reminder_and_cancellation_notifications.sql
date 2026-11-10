ALTER TABLE public.notifications
ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'participant_joined',
ADD COLUMN IF NOT EXISTS start_location TEXT,
ADD COLUMN IF NOT EXISTS creator_name TEXT;

ALTER TABLE public.notifications
ALTER COLUMN ride_id DROP NOT NULL;

ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_ride_id_fkey;

ALTER TABLE public.notifications
ADD CONSTRAINT notifications_ride_id_fkey
FOREIGN KEY (ride_id) REFERENCES public.rides(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notifications_type_check'
      AND conrelid = 'public.notifications'::regclass
  ) THEN
    ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN ('participant_joined', 'ride_reminder', 'ride_cancelled'));
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS notifications_ride_event_once_idx
ON public.notifications (recipient_id, ride_id, type)
WHERE ride_id IS NOT NULL AND type IN ('ride_reminder', 'ride_cancelled');

CREATE OR REPLACE FUNCTION public.notify_participants_ride_cancelled()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  ride_creator_name TEXT;
BEGIN
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
    creator_name
  )
  SELECT
    participants.user_id,
    OLD.id,
    participants.user_id,
    COALESCE(NULLIF(concat_ws(' ', users.firstname, users.lastname), ''), 'Un membre'),
    OLD.name,
    'ride_cancelled',
    COALESCE(NULLIF(ride_creator_name, ''), 'Le créateur')
  FROM public.ride_participants AS participants
  LEFT JOIN public.users AS users ON users.id = participants.user_id
  WHERE participants.ride_id = OLD.id
    AND participants.user_id <> OLD.creator_id
  ON CONFLICT (recipient_id, ride_id, type)
    WHERE ride_id IS NOT NULL AND type IN ('ride_reminder', 'ride_cancelled')
  DO NOTHING;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS notify_participants_ride_cancelled ON public.rides;
CREATE TRIGGER notify_participants_ride_cancelled
BEFORE DELETE ON public.rides
FOR EACH ROW
EXECUTE FUNCTION public.notify_participants_ride_cancelled();

CREATE OR REPLACE FUNCTION public.create_ride_start_reminders()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.notifications (
    recipient_id,
    ride_id,
    participant_id,
    participant_name,
    ride_name,
    type,
    start_location,
    creator_name
  )
  SELECT
    participants.user_id,
    rides.id,
    participants.user_id,
    COALESCE(NULLIF(concat_ws(' ', users.firstname, users.lastname), ''), 'Un membre'),
    rides.name,
    'ride_reminder',
    rides.start_location,
    COALESCE(NULLIF(concat_ws(' ', creators.firstname, creators.lastname), ''), 'Le créateur')
  FROM public.rides AS rides
  JOIN public.ride_participants AS participants ON participants.ride_id = rides.id
  LEFT JOIN public.users AS users ON users.id = participants.user_id
  LEFT JOIN public.users AS creators ON creators.id = rides.creator_id
  WHERE (rides.date + rides.time) AT TIME ZONE 'Europe/Paris' > now() + interval '59 minutes'
    AND (rides.date + rides.time) AT TIME ZONE 'Europe/Paris' <= now() + interval '60 minutes'
  ON CONFLICT (recipient_id, ride_id, type)
    WHERE ride_id IS NOT NULL AND type IN ('ride_reminder', 'ride_cancelled')
  DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.create_ride_start_reminders() FROM PUBLIC, anon, authenticated;

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'rvc-ride-start-reminders';

SELECT cron.schedule(
  'rvc-ride-start-reminders',
  '* * * * *',
  'SELECT public.create_ride_start_reminders();'
);
