CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  participant_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  participant_name TEXT NOT NULL,
  ride_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS notifications_recipient_created_at_idx
ON public.notifications (recipient_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Users can read own notifications"
ON public.notifications FOR SELECT TO authenticated
USING (recipient_id = auth.uid());

DROP POLICY IF EXISTS "Users can mark own notifications as read" ON public.notifications;
CREATE POLICY "Users can mark own notifications as read"
ON public.notifications FOR UPDATE TO authenticated
USING (recipient_id = auth.uid())
WITH CHECK (recipient_id = auth.uid());

REVOKE ALL ON public.notifications FROM anon, authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

CREATE OR REPLACE FUNCTION public.notify_ride_creator_on_participant_join()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  ride_owner_id UUID;
  ride_title TEXT;
  participant_full_name TEXT;
BEGIN
  SELECT rides.creator_id, rides.name
  INTO ride_owner_id, ride_title
  FROM public.rides
  WHERE rides.id = NEW.ride_id;

  IF ride_owner_id IS NULL OR ride_owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  SELECT concat_ws(' ', users.firstname, users.lastname)
  INTO participant_full_name
  FROM public.users
  WHERE users.id = NEW.user_id;

  INSERT INTO public.notifications (
    recipient_id,
    ride_id,
    participant_id,
    participant_name,
    ride_name
  )
  VALUES (
    ride_owner_id,
    NEW.ride_id,
    NEW.user_id,
    COALESCE(NULLIF(participant_full_name, ''), 'Un membre'),
    ride_title
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_ride_creator_on_participant_join ON public.ride_participants;
CREATE TRIGGER notify_ride_creator_on_participant_join
AFTER INSERT ON public.ride_participants
FOR EACH ROW
EXECUTE FUNCTION public.notify_ride_creator_on_participant_join();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END;
$$;
