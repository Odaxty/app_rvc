ALTER TABLE public.news
DROP CONSTRAINT IF EXISTS news_category_check;

UPDATE public.news
SET category = CASE
  WHEN category = 'Club' THEN 'RVC'
  ELSE 'Autres'
END;

ALTER TABLE public.news
ADD CONSTRAINT news_category_check
CHECK (category IN ('RVC', 'Maison du Vélo', 'Autres'));

ALTER TABLE public.news
ALTER COLUMN category SET DEFAULT 'RVC';

ALTER TABLE public.notifications
ADD COLUMN IF NOT EXISTS message TEXT,
ADD COLUMN IF NOT EXISTS news_id UUID REFERENCES public.news(id) ON DELETE SET NULL;

ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
ADD CONSTRAINT notifications_type_check
CHECK (
  type IN (
    'participant_joined',
    'ride_reminder',
    'ride_cancelled',
    'comment_added',
    'ride_full',
    'news_published'
  )
);

DROP INDEX IF EXISTS public.notifications_ride_event_once_idx;
CREATE UNIQUE INDEX notifications_ride_event_once_idx
ON public.notifications (recipient_id, ride_id, type)
WHERE ride_id IS NOT NULL AND type IN ('ride_reminder', 'ride_cancelled', 'ride_full');

CREATE OR REPLACE FUNCTION public.notify_participants_on_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  ride_title TEXT;
  sender_name TEXT;
BEGIN
  SELECT rides.name
  INTO ride_title
  FROM public.rides
  WHERE rides.id = NEW.ride_id;

  SELECT COALESCE(NULLIF(concat_ws(' ', users.firstname, users.lastname), ''), 'Un membre')
  INTO sender_name
  FROM public.users
  WHERE users.id = NEW.user_id;

  INSERT INTO public.notifications (
    recipient_id,
    ride_id,
    participant_id,
    participant_name,
    ride_name,
    type,
    message
  )
  SELECT
    participants.user_id,
    NEW.ride_id,
    NEW.user_id,
    COALESCE(sender_name, 'Un membre'),
    ride_title,
    'comment_added',
    NEW.message
  FROM public.ride_participants AS participants
  WHERE participants.ride_id = NEW.ride_id
    AND participants.user_id <> NEW.user_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_participants_on_comment ON public.comments;
CREATE TRIGGER notify_participants_on_comment
AFTER INSERT ON public.comments
FOR EACH ROW
EXECUTE FUNCTION public.notify_participants_on_comment();

CREATE OR REPLACE FUNCTION public.enforce_ride_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  capacity INTEGER;
  participant_count BIGINT;
BEGIN
  SELECT rides.max_participants
  INTO capacity
  FROM public.rides
  WHERE rides.id = NEW.ride_id
  FOR UPDATE;

  IF capacity IS NULL OR EXISTS (
    SELECT 1
    FROM public.ride_participants
    WHERE ride_id = NEW.ride_id
      AND user_id = NEW.user_id
  ) THEN
    RETURN NEW;
  END IF;

  SELECT count(*)
  INTO participant_count
  FROM public.ride_participants
  WHERE ride_id = NEW.ride_id;

  IF participant_count >= capacity THEN
    RAISE EXCEPTION 'ride_full' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_ride_capacity ON public.ride_participants;
CREATE TRIGGER enforce_ride_capacity
BEFORE INSERT ON public.ride_participants
FOR EACH ROW
EXECUTE FUNCTION public.enforce_ride_capacity();

CREATE OR REPLACE FUNCTION public.notify_participants_ride_full()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  ride_capacity INTEGER;
  ride_title TEXT;
BEGIN
  SELECT rides.max_participants, rides.name
  INTO ride_capacity, ride_title
  FROM public.rides
  WHERE rides.id = NEW.ride_id;

  IF ride_capacity IS NULL OR (
    SELECT count(*)
    FROM public.ride_participants
    WHERE ride_id = NEW.ride_id
  ) < ride_capacity THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (
    recipient_id,
    ride_id,
    participant_id,
    participant_name,
    ride_name,
    type
  )
  SELECT
    participants.user_id,
    NEW.ride_id,
    participants.user_id,
    COALESCE(NULLIF(concat_ws(' ', users.firstname, users.lastname), ''), 'Un membre'),
    ride_title,
    'ride_full'
  FROM public.ride_participants AS participants
  LEFT JOIN public.users AS users ON users.id = participants.user_id
  WHERE participants.ride_id = NEW.ride_id
  ON CONFLICT (recipient_id, ride_id, type)
    WHERE ride_id IS NOT NULL AND type IN ('ride_reminder', 'ride_cancelled', 'ride_full')
  DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_participants_ride_full ON public.ride_participants;
CREATE TRIGGER notify_participants_ride_full
AFTER INSERT ON public.ride_participants
FOR EACH ROW
EXECUTE FUNCTION public.notify_participants_ride_full();

CREATE OR REPLACE FUNCTION public.notify_users_on_news_published()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  author_name TEXT;
  target_role TEXT;
BEGIN
  IF NEW.category = 'RVC' THEN
    target_role := 'rvc';
  ELSIF NEW.category = 'Maison du Vélo' THEN
    target_role := 'maison_du_velo';
  ELSE
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(concat_ws(' ', users.firstname, users.lastname), ''), 'Un administrateur')
  INTO author_name
  FROM public.users
  WHERE users.id = NEW.author_id;

  INSERT INTO public.notifications (
    recipient_id,
    ride_id,
    news_id,
    participant_id,
    participant_name,
    ride_name,
    type,
    message
  )
  SELECT
    users.id,
    NEW.ride_id,
    NEW.id,
    NEW.author_id,
    COALESCE(author_name, 'Un administrateur'),
    NEW.title,
    'news_published',
    COALESCE(NEW.summary, '')
  FROM public.users AS users
  WHERE users.role = target_role
    AND users.role <> 'admin'
    AND users.id <> NEW.author_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_users_on_news_published ON public.news;
CREATE TRIGGER notify_users_on_news_published
AFTER INSERT ON public.news
FOR EACH ROW
EXECUTE FUNCTION public.notify_users_on_news_published();

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
    creator_name,
    message
  )
  SELECT
    participants.user_id,
    rides.id,
    participants.user_id,
    COALESCE(NULLIF(concat_ws(' ', users.firstname, users.lastname), ''), 'Un membre'),
    rides.name,
    'ride_reminder',
    rides.start_location,
    COALESCE(NULLIF(concat_ws(' ', creators.firstname, creators.lastname), ''), 'Le créateur'),
    'Tu es inscrit à cette sortie. Le départ approche, es-tu prêt ?'
  FROM public.rides AS rides
  JOIN public.ride_participants AS participants ON participants.ride_id = rides.id
  LEFT JOIN public.users AS users ON users.id = participants.user_id
  LEFT JOIN public.users AS creators ON creators.id = rides.creator_id
  WHERE (rides.date + rides.time) AT TIME ZONE 'Europe/Paris' > now() + interval '59 minutes'
    AND (rides.date + rides.time) AT TIME ZONE 'Europe/Paris' <= now() + interval '60 minutes'
  ON CONFLICT (recipient_id, ride_id, type)
    WHERE ride_id IS NOT NULL AND type IN ('ride_reminder', 'ride_cancelled', 'ride_full')
  DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.create_ride_start_reminders() FROM PUBLIC, anon, authenticated;
