# rvc-app

This template should help get you started developing with Vue 3 in Vite.

## Recommended IDE Setup

[VS Code](https://code.visualstudio.com/) + [Vue (Official)](https://marketplace.visualstudio.com/items?itemName=Vue.volar) (and disable Vetur).

## Recommended Browser Setup

- Chromium-based browsers (Chrome, Edge, Brave, etc.):
  - [Vue.js devtools](https://chromewebstore.google.com/detail/vuejs-devtools/nhdogjmejiglipccpnnnanhbledajbpd)
  - [Turn on Custom Object Formatter in Chrome DevTools](http://bit.ly/object-formatters)
- Firefox:
  - [Vue.js devtools](https://addons.mozilla.org/en-US/firefox/addon/vue-js-devtools/)
  - [Turn on Custom Object Formatter in Firefox DevTools](https://fxdx.dev/firefox-devtools-custom-object-formatters/)

## Type Support for `.vue` Imports in TS

TypeScript cannot handle type information for `.vue` imports by default, so we replace the `tsc` CLI with `vue-tsc` for type checking. In editors, we need [Volar](https://marketplace.visualstudio.com/items?itemName=Vue.volar) to make the TypeScript language service aware of `.vue` types.

## Customize configuration

See [Vite Configuration Reference](https://vite.dev/config/).

## Project Setup

```sh
npm install
```

### Supabase Configuration

Create a Supabase project, copy `.env.example` to `.env.local`, and set
`VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` from the project API settings.
The anon key is intended for client-side use; never put a service role key in
this application.

To enable password resets, add the app URL (including `/auth`) to the allowed
redirect URLs in Supabase Authentication settings. The reset email redirects to
`/auth?mode=update-password` on the current app origin.

Set `VITE_GEOAPIFY_API_KEY` in `.env.local` to enable address suggestions. Use a
Geoapify key restricted to the deployed app's domains and configure usage limits.
Apply the SQL migration in `supabase/migrations` to add ride start locations and
difficulty levels before creating or listing rides.

Apply `20261110090000_add_user_account_activation.sql` to add administrator
account management and prevent inactive users from signing in. To open the
account-management page, assign the `admin` role to an existing account from the
Supabase SQL Editor:

```sql
UPDATE public.users SET role = 'admin' WHERE email = 'admin@example.com';
```

Apply `20261110110000_add_ride_join_notifications.sql` to notify a ride's creator
when another user joins. Notifications are stored securely in Supabase and
delivered in real time when the `supabase_realtime` publication is available.
Apply `20261110120000_allow_notification_deletion.sql` to allow users to delete
their own notifications, and `20261110130000_add_ride_reminder_and_cancellation_notifications.sql`
to schedule one-hour reminders and notify participants when a ride is deleted.
Apply `20261110150000_add_extended_notifications.sql` for participant message
alerts, full-ride alerts, organization-targeted news alerts, and the RVC / Maison
du Vélo / Autres news categories. Existing "Club" news is migrated to "RVC";
other old categories become "Autres". "Autres" news does not send push alerts.
Apply `20261110160000_lock_ride_participant_leaving.sql` to prevent participants
from leaving a ride during the hour before its start and after it has started.

#### Web Push (notifications lorsque l’application est fermée)

Le navigateur demande explicitement l’autorisation depuis le profil. Le Web Push
requiert HTTPS (localhost est accepté en développement) et un navigateur/appareil
compatible. Sur iOS, l’application doit généralement être installée sur l’écran
d’accueil (iOS 16.4 ou plus récent). Après le déploiement, ouvre le site dans
Safari, utilise Partager > Sur l’écran d’accueil, puis ouvre cette nouvelle icône
et active les notifications depuis le profil. Une autorisation ou un abonnement
créé dans un onglet Safari ou un raccourci existant ne vaut pas pour l’application
installée ; supprime l’ancien raccourci avant de créer l’icône à nouveau.
Les notifications internes restent disponibles si le push n’est pas configuré.

1. Générer une paire de clés VAPID, par exemple avec :

   ```sh
   npx web-push generate-vapid-keys
   ```

   Configurer la clé publique dans `VITE_VAPID_PUBLIC_KEY` (fichier `.env.local`
   et environnement de déploiement) et garder la clé privée uniquement côté serveur.
2. Déployer l’Edge Function :

   ```sh
   supabase functions deploy ride-push --no-verify-jwt
   supabase secrets set VAPID_PUBLIC_KEY="PUBLIC_KEY" VAPID_PRIVATE_KEY="PRIVATE_KEY" VAPID_SUBJECT="mailto:admin@example.com" PUSH_DISPATCH_SECRET="RANDOM_SECRET"
   ```

   `PUSH_DISPATCH_SECRET` doit être une valeur aléatoire forte, distincte des
   clés VAPID. Tu peux en générer une dans PowerShell avec
   `node -e "console.log(require('node:crypto').randomBytes(32).toString('base64url'))"`.
   Remplace `PUBLIC_KEY`, `PRIVATE_KEY` et `RANDOM_SECRET` par les vraies valeurs.
   Cette fonction n’accepte que les appels portant ce secret.
3. Créer les secrets Vault pour le déclencheur SQL, dans l’éditeur SQL Supabase
   (remplacer les valeurs d’exemple) :

   ```sql
   SELECT vault.create_secret('https://<project-ref>.supabase.co', 'rvc_project_url');
   SELECT vault.create_secret('<même-secret-que-PUSH_DISPATCH_SECRET>', 'rvc_push_dispatch_secret');
   ```

4. Appliquer `20261110140000_add_web_push_subscriptions.sql`. La table
   `push_subscriptions` est protégée par RLS ; chaque membre ne peut gérer que
   ses propres abonnements. Le déclencheur utilise `pg_net` pour transmettre à
   l’Edge Function l’identifiant d’une nouvelle notification. Il faut donc que
   `pg_net` et Vault soient disponibles dans le projet Supabase.

La clé privée VAPID, la clé `service_role` et le secret de dispatch ne doivent
jamais être ajoutés au frontend ou à `.env.local`. Sans configuration serveur,
les notifications restent uniquement dans l’application.

### Compile and Hot-Reload for Development

```sh
npm run dev
```

### Type-Check, Compile and Minify for Production

```sh
npm run build
```
