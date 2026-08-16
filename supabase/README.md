# Supabase Auth + crops (Phase 3a)

## App config

`.env` is gitignored and **not** bundled as a Flutter asset.

On iOS/Android, the app runs in a sandbox and **cannot** read your Mac's
`.env` file. Inject it at build time:

```bash
# Local (simulator / device) — preferred
flutter run --dart-define-from-file=.env

# Or explicit defines
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...

# Store / CI builds
flutter build ipa --dart-define-from-file=.env
```

```
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=sb_publishable_...   # publishable key, NOT service role
```

## Migration

Apply [`migrations/20260321120000_user_crops.sql`](migrations/20260321120000_user_crops.sql):

```bash
supabase link --project-ref YOUR_REF
supabase db push
```

Or paste the SQL in the Supabase SQL editor.

Crops live in `user_crops` keyed by `user_id` (RLS). The device only keeps an onboarding draft until signup.

## Auth settings (obligatoire pour V1)

1. **Authentication → Providers → Email** → désactiver **Confirm email**
   - Sinon chaque signup envoie un mail → limite **2 emails/heure** sur le SMTP gratuit
2. **Authentication → Rate Limits** — certaines limites sont ajustables ; la limite email nécessite un SMTP custom

## Erreur 429

Souvent la limite email (Confirm email encore ON). Désactive Confirm email, attends ~1 h, réessaie une fois.
