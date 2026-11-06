ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS gender TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_gender_check'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
    ADD CONSTRAINT users_gender_check
    CHECK (gender IS NULL OR gender IN ('Féminin', 'Masculin'));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.users (id, email, firstname, lastname, phone, gender)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'firstname',
    new.raw_user_meta_data->>'lastname',
    NULLIF(trim(new.raw_user_meta_data->>'phone'), ''),
    NULLIF(new.raw_user_meta_data->>'gender', '')
  );
  RETURN new;
END;
$$;
