# Supabase Auth + sync (Phase 3a)

## Config app

Keys in `.env.local` (gitignored). The app loads them via `flutter_dotenv` — just run:

```bash
flutter run
```

Required keys:

```
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=sb_publishable_...   # publishable key, NOT service role
```

Apply the SQL in [`migrations/20260321120000_user_crops.sql`](migrations/20260321120000_user_crops.sql) via the Supabase SQL editor (or CLI).

Crops live in `user_crops` keyed by `user_id`. The device only keeps an onboarding draft until signup; login loads that account’s rows (no local merge).

## Auth settings (obligatoire pour V1)

1. **Authentication → Providers → Email** → désactiver **Confirm email**
   - Sinon chaque signup envoie un mail → limite **2 emails/heure** sur le SMTP gratuit
   - Même les essais ratés (mot de passe trop court, etc.) peuvent compter dans cette limite
   - Résultat : 429 après quelques clics, **aucun user visible** dans le dashboard

2. **Authentication → Rate Limits** — tu peux augmenter certaines limites (signup, etc.)
   - La limite **email** ne change pas sans **SMTP custom** (Resend, SendGrid…)

## Erreur 429 sans compte créé

C’est normal si **Confirm email** est encore activé : Supabase bloque avant de finaliser le user, ou n’affiche pas le compte tant qu’il n’est pas confirmé.

**Fix rapide :** désactiver Confirm email → attendre ~1 h (reset limite email) → réessayer **une** fois.
