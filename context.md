# Contexte du Projet : Application Roche Vendée Cyclisme (RVC)

## 1. 🎯 Objectif Général

- **Nom du projet :** App RVC (Roche Vendée Cyclisme)
- **Mission :** Créer une application pour la partie espoir/senior du club (compétiteurs et baroudeurs).
- **But :** Faciliter la communication entre les membres du club, organiser les sorties, partager des parcours et centraliser l'information.
- **Plateforme cible :** Web app en priorité (PWA), avec possibilité d'encapsuler pour les stores (iOS/Android) via Capacitor plus tard.

## 2. 👥 Acteurs et Rôles

- **Membre Standard (Utilisateur Connecté) :** Peut s'inscrire à une sortie, créer une sortie, uploader/télécharger un fichier GPX pour une sortie créée, commenter une sortie.
- **Visiteur (Non Connecté) :** Voit les sorties mais ne voit pas les contacts (email/téléphone). Ne peut pas s'inscrire ni commenter.
- **Administrateur (À venir) :** Rôle réservé pour la modération future.

## 3. 📊 Modèles de Données Principaux (Schéma de base)

- **User :** id, firstname, lastname, email, phone, createdAt, updatedAt.
- **Ride (Sortie) :** id, creator_id, title, date, time, location, distance, elevation_gain, elevation_loss, difficulty, gpx_url, status (active, cancelled), cancel_reason (meteo, autres), ride_type (officiel/libre), bike_type (Route/Gravel/VTT).
- **Ride_Participant :** ride_id, user_id.
- **Comment :** id, ride_id, user_id, content, image_url, createdAt.

## 4. 🚀 Fonctionnalités Clés (MVP)

- **Authentification :** Inscription et connexion obligatoires pour interagir (commenter, s'inscrire, voir les contacts).
- **Gestion des sorties :**
  - Calendrier des prochaines sorties.
  - Historique des sorties (limité aux 5 dernières sorties effectuées).
  - Annulation d'une sortie par son créateur avec motif ("Météo" ou "Autres").
- **Parcours & GPX :** Bibliothèque de traces GPS associées aux sorties (kilométrage, dénivelé positif et négatif).

## 5. 🛠️ Stack Technique

- **Frontend :** Vue 3 (Vite).
- **Backend / BDD :** Supabase (PostgreSQL, Auth, Storage pour les GPX). Backend-as-a-Service sans conteneurisation complexe.
- **Langage :** TypeScript strictement typé.
- **CSS :** Tailwind CSS (recommandé pour aller vite).

## 6. 📏 Règles de Code et d'Architecture (Directives Copilot)

- **Framework :** Utiliser EXCLUSIVEMENT Vue 3 avec la Composition API et `<script setup>`. Ne pas utiliser l'Options API (Vue 2).
- **Logique :** Extraire la logique réutilisable dans des Composables (dossier `/composables`).
- **Langue :** Commenter le code complexe en français. Nommer les variables, fichiers et fonctions en anglais (ex: `createRide`, `fetchMembers`).
- **Typage :** Utiliser des interfaces/types TypeScript stricts pour chaque modèle de base de données.
- **UX :** Gérer proprement les états de chargement (`isLoading`) et d'erreur (`error`) lors des appels à la base de données.

## 7. 🎨 Design & UI (Interface Utilisateur)

- **Couleurs de la marque (RVC) :** Rouge, Vert, Noir. Ces couleurs devront être intégrées dans la configuration de Tailwind CSS pour un usage global.
- **Style Visuel :** "Bento UI". Le design doit s'inspirer de l'écosystème Apple : des cartes aux coins arrondis, des ombres douces, des interfaces épurées et compartimentées sous forme de grilles (widgets) pour bien séparer l'information.

## 8. 📱 Les différentes pages

- **Page Home :** Une barre de recherche avec des filtres par kilométrage, heure, organisateur (club ou licencié). En dessous, l'affichage des différentes sorties disponibles / passées sous forme de cartes (Bento style). En bas, une barre de navigation (Bottom Navigation / Footer) avec à gauche la page GPX, au milieu la page Home, et à droite la page Mon Compte.
- **Page GPX :** Composée d'un filtre qui permet d'afficher tous les GPX ajoutés à l'application. Possibilité de filtrer en fonction de la distance, du point de départ et du type de parcours (VTT, Gravel, Route).
- **Page Compte :** Informations du compte utilisateur (nom, prénom, email, téléphone, etc.).

## 9. 🗄️ Modèles de Données Principaux (Schéma SQL Supabase)

Voici le schéma exact déployé sur Supabase. Copilot doit utiliser ces noms de tables et de colonnes pour toutes les requêtes :

```sql
-- 1. Table des Utilisateurs (liée à l'authentification Supabase)
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
  ride_type TEXT CHECK (ride_type IN ('Club', 'Libre')), -- La nouvelle colonne
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

-- 2. On crée des règles "Open Bar" pour le développement local
CREATE POLICY "Dev_Mode_Users" ON public.users FOR ALL USING (true);
CREATE POLICY "Dev_Mode_Rides" ON public.rides FOR ALL USING (true);
CREATE POLICY "Dev_Mode_Participants" ON public.ride_participants FOR ALL USING (true);
CREATE POLICY "Dev_Mode_Comments" ON public.comments FOR ALL USING (true);

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
