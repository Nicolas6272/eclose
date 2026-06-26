# 🌱 Éclose — App de soin de plantes

> Rappels d'arrosage fiables et honnêtes. L'anti-PlantIn.

---

## Le problème qu'on résout

Les apps de soin de plantes existantes (PlantIn, Planta, Plant App) ont toutes le même problème : elles vendent une IA de reconnaissance photo qui déçoit, et piègent les utilisateurs avec des dark patterns de facturation (essais cachés, prélèvements surprises, résiliation impossible). Les avis 1-2 étoiles sur le marché français en témoignent massivement.

**Éclose résout ça en faisant une seule chose, irréprochable : te rappeler d'arroser tes plantes au bon moment.**

---

## Positionnement

- 🇫🇷 App pensée pour la France (ton, langue, support natifs)
- 🚫 Pas de scanner IA bancal en feature phare
- ✅ Pricing transparent dès le premier écran
- ✅ Rappel 24h avant toute facturation
- ✅ Annulation en 2 taps depuis l'app

---

## Stack technique

- **Framework** : Flutter (iOS + Android)
- **Base de données locale** : SQLite (via `sqflite`)
- **Notifications** : `flutter_local_notifications`
- **Paiement** : RevenueCat (gestion abonnements iOS + Android)
- **Auth** : Firebase Auth (email + Apple/Google Sign-In)
- **Backend** : Firebase (Firestore pour sync multi-appareils)
- **DB plantes** : JSON statique embarqué dans l'app (généré en amont via Perenual API, one-shot)

---

## Feature du MVP — rappel d'arrosage

### Ce qu'elle fait
1. L'utilisateur ajoute une plante depuis une liste visuelle (grille de photos)
2. L'app calcule automatiquement la fréquence d'arrosage selon l'espèce
3. L'utilisateur peut ajuster manuellement (exposition lumière, saison)
4. Notification locale au bon moment
5. Tap "Arrosé ✓" → relance correcte du compteur

### Ce qu'elle ne fait PAS (volontairement, v1)
- ❌ Scan/identification photo par IA
- ❌ Diagnostic maladie
- ❌ Journal photo
- ❌ Fertilisation / rempotage
- ❌ Communauté / partage

---

## Onboarding — flow complet

```
[Ouverture app]
      ↓
  Pas de compte requis, direct dans l'app
      ↓
[Écran "Ajoute ta première plante"]
  → Grille visuelle (photos) des plantes les plus communes
  → Barre de recherche textuelle en complément
  → Si introuvable → catégories génériques
    ("Plante à feuillage", "Succulente / Cactus", "Plante à fleurs")
      ↓
[Confirmation de valeur immédiate]
  → "On te rappellera d'arroser ton Pothos dans 7 jours 💧"
      ↓
[Permission notifications]
  → Demandée ICI seulement (jamais au lancement de l'app)
      ↓
[Ajustement optionnel, non bloquant]
  → "Plutôt en plein soleil ou à l'ombre ?"
      ↓
[Tentative d'ajout d'une 2e plante]
      ↓
[Écran paywall — timeline visuelle]
  → Aujourd'hui : début d'essai gratuit
  → J+6 : notification "ton essai se termine demain"
  → J+7 : 10€/mois ou 50€/an prélevés
  → CTA avec prix affiché EN GROS (pas en footnote)
      ↓
[Création de compte]
  → Présentée comme "sauvegarder tes plantes"
  → Email ou Apple/Google Sign-In
```

---

## Modèle de pricing

| Offre | Prix | Détail |
|---|---|---|
| 1ère plante | Gratuit | Sans compte, valeur immédiate |
| Essai | 7 jours gratuits | CB requise dès le départ |
| Mensuel | 10€/mois | Reconduction automatique |
| Annuel | 50€/an | Mis en avant (-58%, "meilleure offre") |

**Règles non négociables sur le pricing (différenciation vs concurrents) :**
- Prix affiché en clair sur le bouton CTA, jamais en petit texte
- Notification automatique 24h avant la fin de l'essai
- Annulation accessible en 2 taps depuis les paramètres de l'app
- Pas de redirection vers un formulaire web ou un email support

---

## Base de données des plantes

### Source
**Perenual API** — utilisée en one-shot pour générer un JSON statique embarqué dans l'app.

Champ clé : `watering_general_benchmark` → retourne `{ "value": "5-7", "unit": "days" }`

### Structure d'une fiche plante (JSON)
```json
{
  "id": 1,
  "common_name": "Pothos",
  "scientific_name": "Epipremnum aureum",
  "image_url": "https://...",
  "watering_days_min": 5,
  "watering_days_max": 7,
  "sunlight": "indirect",
  "category": "foliage",
  "is_generic": false
}
```

### Catégories génériques (filet de sécurité)
```json
[
  { "id": 9001, "common_name": "Plante à feuillage", "watering_days_min": 5, "watering_days_max": 10, "is_generic": true },
  { "id": 9002, "common_name": "Succulente / Cactus", "watering_days_min": 14, "watering_days_max": 21, "is_generic": true },
  { "id": 9003, "common_name": "Plante à fleurs", "watering_days_min": 3, "watering_days_max": 7, "is_generic": true }
]
```
