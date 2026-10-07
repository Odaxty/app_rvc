# Contexte du projet : Roche Vendée Cyclisme (RVC)

## 1. Objectif

Application web du club Roche Vendée Cyclisme, destinée à organiser et présenter les sorties vélo, partager des traces GPX et faciliter les échanges entre membres. Supabase fournit l’authentification, la base de données et le stockage des fichiers.

## 2. État actuel et rôles

- **Visiteur :** peut consulter l’accueil et les détails d’une sortie. L’accès au tracé GPX associé nécessite une session.
- **Membre connecté :** peut s’inscrire à une sortie dans la limite de sa capacité, commenter une sortie, créer des sorties et gérer les sorties dont il est le créateur.
- **Membre connecté – GPX :** peut consulter la bibliothèque et ses propres GPX, filtrer et télécharger les fichiers.
- **Profil :** un membre peut consulter et modifier son prénom, son nom, son niveau et sa photo, voir ses nombres de participations et de GPX, choisir le thème et se déconnecter.
- **Administration et modération :** non implémentées actuellement.

## 3. Fonctionnalités implémentées

- Authentification Supabase : inscription avec prénom et nom, connexion, déconnexion et réinitialisation de mot de passe par e-mail.
- Accueil des sorties avec recherche par nom, filtres par distance, type de vélo et type de sortie, sections à venir et passées, affichage progressif par lots de dix.
- Création et modification de sorties avec nom, description, date, heure, distance, lieu de départ, capacité, type de vélo, type de sortie, difficulté, image et GPX facultatif.
- Détail d’une sortie : inscription, liste des participants, tracé GPX et téléchargement si l’utilisateur est inscrit, discussion réservée aux participants, édition/suppression réservée au créateur.
- Bibliothèque GPX avec filtres par départ, arrivée et distance, pagination par lots de dix, détail cartographique et téléchargement.
- Profil modifiable avec avatar et préférence de thème clair/sombre enregistrée localement.

Les fonctionnalités non listées comme implémentées ne doivent pas être considérées comme disponibles sans vérification dans le code.

## 4. Routes

- `/` : accueil des sorties.
- `/auth` : connexion, inscription et réinitialisation du mot de passe.
- `/ride/:id` : détail d’une sortie.
- `/ride/new` : création d’une sortie (authentification requise par le flux de création).
- `/ride/:id/edit` : modification d’une sortie (route protégée).
- `/gpx` et `/gpx/:id` : bibliothèque et détail GPX (routes protégées).
- `/profile` : profil et préférences du membre.

Le garde de navigation Vue Router protège les routes marquées `requiresAuth`. Ne pas supposer qu’une route non marquée est protégée.

## 5. Modèles de données

- **Profil (`public.users`) :** `id`, `email`, `firstname`, `lastname`, `level`, `avatar_url`, dates de création et de mise à jour.
- **Trace GPX (`public.gpx_tracks`) :** `id`, `user_id`, `title`, `file_url`, `start_location`, `end_location`, `distance`, `created_at`.
- **Sortie (`public.rides`) :** créateur, GPX associé facultatif, nom, description, date, heure, distance, capacité maximale facultative, type de vélo, type de sortie, lieu de départ, difficulté, image et dates.
- **Inscription (`public.ride_participants`) :** association entre une sortie et un profil, avec date de création.
- **Message (`public.comments`) :** sortie, auteur, message et date de création.

Les définitions SQL de référence et exemples de politiques Supabase figurent dans la section 9. Le SQL contient des politiques `Dev_Mode` permissives : ne pas l’appliquer tel quel en production. Vérifier et restreindre les politiques RLS dans le projet Supabase ; le code client ne remplace pas RLS.

## 6. Stack et architecture

- Vue 3, Composition API et `<script setup>`, avec Vue Router et Vite.
- TypeScript et `vue-tsc` pour la vérification des types.
- Supabase JS pour PostgreSQL, Auth et Storage.
- Tailwind CSS 4 et CSS global dans `src/assets/main.css` pour le design adaptatif et les thèmes.
- Leaflet et `@tmcw/togeojson` pour l’affichage cartographique des traces GPX.
- Icônes avec `lucide-vue-next`.
- Composables partagés dans `src/composables/` (`useAuth`, `useTheme`).

Commandes principales : `npm run dev` pour le développement, `npm run build` pour la vérification TypeScript et la compilation, `npm run type-check` pour les types.

## 7. Conventions de développement

- Conserver Vue 3 Composition API et `<script setup>` ; ne pas introduire l’Options API.
- Réutiliser les composables, composants et conventions déjà présents avant d’ajouter une abstraction.
- Utiliser des types précis pour les données, gérer explicitement chargements et erreurs, et éviter les casts non sûrs.
- Nommer variables, fonctions et fichiers en anglais ; rédiger les textes d’interface et commentaires explicatifs en français, conformément aux usages existants.
- Ne jamais mettre une clé Supabase `service_role` dans le frontend. Les variables de configuration côté client sont `VITE_SUPABASE_URL` et `VITE_SUPABASE_ANON_KEY`.
- Conserver les vérifications d’accès côté base de données (RLS) et les validations de capacité d’inscription côté serveur/base en plus des contrôles UX.

## 8. Design et couleurs RVC

- **Vert du maillot :** `rgb(21, 101, 85)` (`#156555`).
- **Rouge du maillot :** `rgb(102, 27, 35)` (`#661b23`).
- **Noir du maillot :** `rgb(6, 5, 5)` (`#060505`).
- **Thème clair :** fond blanc ou légèrement teinté, texte noir, accents verts et rouges visibles.
- **Thème sombre :** fond noir, texte blanc, accents verts et rouges visibles.
- Répartir les deux couleurs d’accent sur toutes les pages avec mesure : boutons et états actifs, filets de cartes, bordures et détails décoratifs. Éviter les surfaces blanches uniformes et les grands aplats saturés.
- Maintenir un contraste suffisant pour les textes, formulaires, alertes et contrôles dans les deux thèmes. La préférence est gérée par `useTheme` et persistée sous `rvc-theme`.
- Garder le style Bento existant : cartes arrondies, sections lisibles et grilles adaptatives.

## 9. Schéma SQL de référence

Les définitions ci-dessous documentent le modèle Supabase utilisé par l’application. Ce SQL est un exemple historique et contient des politiques de développement permissives ; ne pas le déployer tel quel en production.

```sql
-- 1. Table des Utilisateurs (liée à l'authenti fication Supabase)
-- 1. Table USERS
-- Liée au système d'authentification de Supabase
CREATE TABLE public.users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  firstname TEXT NOT NULL,
  lastname TEXT NOT NULL,
  level TEXT, -- Ex: 'Espoir', 'Sénior', 'Baroudeur'
  avatar_url TEXT, -- Remplace 'urlpath' pour être plus explicite
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Table GPX_TRACKS (Pour gérer "mes gpx")
-- Séparer les GPX permet à un utilisateur de se constituer une bibliothèque
CREATE TABLE public.gpx_tracks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  file_url TEXT NOT NULL, -- L'URL du fichier stocké dans Supabase Storage
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  start_location TEXT,
  end_location TEXT,
  distance NUMERIC
);

CREATE TABLE public.rides (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  creator_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  gpx_id UUID REFERENCES public.gpx_tracks(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  date DATE NOT NULL,
  time TIME NOT NULL,
  distance NUMERIC NOT NULL,
  max_participants integer CHECK (max_participants IS NULL OR max_participants > 0),
  bike_type TEXT CHECK (bike_type IN ('Route', 'Gravel', 'VTT')),
  ride_type TEXT CHECK (ride_type IN ('Club', 'Libre', 'E-Bike')),
  start_location TEXT,
  difficulty SMALLINT CHECK (difficulty IS NULL OR difficulty BETWEEN 1 AND 4),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  image_url TEXT
);

-- 4. Table RIDE_PARTICIPANTS (Inscriptions aux sorties)
-- Remplace ta "liste de users". C'est une table de jointure.
CREATE TABLE public.ride_participants (
  ride_id UUID REFERENCES public.rides(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  PRIMARY KEY (ride_id, user_id) -- Un user ne peut s'inscrire qu'une seule fois à une même sortie
);

-- 5. Table COMMENTS (Les discussions)
CREATE TABLE public.comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY, -- Toujours mettre un ID unique, même pour les commentaires
  ride_id UUID REFERENCES public.rides(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 1. On active la sécurité sur toutes les tables (pour que Supabase soit content)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

-- Les règles Dev_Mode restantes sont réservées au développement local.
CREATE POLICY "Dev_Mode_Users" ON public.users FOR ALL USING (true);
CREATE POLICY "Dev_Mode_Participants" ON public.ride_participants FOR ALL USING (true);
CREATE POLICY "Dev_Mode_Comments" ON public.comments FOR ALL USING (true);

-- Accès aux sorties : lecture publique, écriture réservée au créateur connecté.
DROP POLICY IF EXISTS "Dev_Mode_Rides" ON public.rides;
DROP POLICY IF EXISTS "Public can read rides" ON public.rides;
DROP POLICY IF EXISTS "Authenticated users can create own rides" ON public.rides;
DROP POLICY IF EXISTS "Creators can update own rides" ON public.rides;
DROP POLICY IF EXISTS "Creators can delete own rides" ON public.rides;

CREATE POLICY "Public can read rides"
ON public.rides FOR SELECT
USING (true);

CREATE POLICY "Authenticated users can create own rides"
ON public.rides FOR INSERT TO authenticated
WITH CHECK (creator_id = auth.uid());

CREATE POLICY "Creators can update own rides"
ON public.rides FOR UPDATE TO authenticated
USING (creator_id = auth.uid())
WITH CHECK (creator_id = auth.uid());

CREATE POLICY "Creators can delete own rides"
ON public.rides FOR DELETE TO authenticated
USING (creator_id = auth.uid());

-- Empêcher le dépassement de la capacité, même lors d'inscriptions simultanées
CREATE OR REPLACE FUNCTION public.enforce_ride_participant_limit()
RETURNS trigger AS $$
DECLARE
  participant_limit INTEGER;
  current_participants INTEGER;
BEGIN
  SELECT max_participants
  INTO participant_limit
  FROM public.rides
  WHERE id = NEW.ride_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ride_not_found' USING ERRCODE = 'P0001';
  END IF;

  IF participant_limit IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*)
  INTO current_participants
  FROM public.ride_participants
  WHERE ride_id = NEW.ride_id;

  IF current_participants >= participant_limit THEN
    RAISE EXCEPTION 'ride_full' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_ride_participant_limit ON public.ride_participants;

CREATE TRIGGER enforce_ride_participant_limit
  BEFORE INSERT ON public.ride_participants
  FOR EACH ROW EXECUTE FUNCTION public.enforce_ride_participant_limit();

-- 1. On crée la fonction qui va transférer les données
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, firstname, lastname)
  VALUES (
    new.id, -- L'ID généré par l'authentification Supabase
    new.email,
    -- On récupère le prénom et le nom que l'on a envoyés depuis le frontend Vue.js
    new.raw_user_meta_data->>'firstname',
    new.raw_user_meta_data->>'lastname'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. On crée le Trigger (déclencheur) qui écoute les inscriptions
-- S'il existe déjà, on le supprime d'abord pour éviter une erreur
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Créer une régle pour que les user peuvent accéder au bucket images
CREATE POLICY "Authenticated users can upload ride images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'ride-images');

--Créer une régle qui permet à un user de stocker le path de l'url
CREATE POLICY "Authenticated users can upload ride GPX"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'ride-gpx'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```
