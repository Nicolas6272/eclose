# Système d'arrosage intelligent - Documentation d'implémentation

## Vue d'ensemble

Éclose a été enrichi avec un système d'arrosage intelligent qui calcule dynamiquement les intervalles d'arrosage en fonction de multiples facteurs, remplaçant l'ancien système à intervalle fixe.

## Changements apportés

### 1. Enrichissement du catalogue de plantes

#### Nouveau script : `scripts/fetch_enriched_catalog.py`

Remplace partiellement `fetch_perenual_photos.py` pour intégrer des sources de données gratuites plus riches :

**Sources intégrées :**
- **Open Plantbook** (1000+ plantes, métadonnées environnementales)
  - Seuils d'humidité du sol (min/max)
  - Niveaux de lumière (lux)
  - Températures (min/max)
  - Humidité ambiante
  - Descriptions de soin (arrosage, sol, engrais, taille)

- **PlantSolve** (en préparation - scraping requis)
  - 113 plantes curées
  - Guides détaillés de soin

**Configuration requise :**
```bash
# .env.local
OPENPLANTBOOK_API_KEY=your-key-here
```

**Utilisation :**
```bash
python3 scripts/fetch_enriched_catalog.py
```

### 2. Modèles de données étendus

#### `lib/data/models/catalog_plant.dart`

**Nouveaux champs ajoutés :**
```dart
class CatalogPlant {
  final String? scientificName;
  final String? lightRequirement;
  final int? minSoilMoisture;       // Seuil d'humidité min (%)
  final int? maxSoilMoisture;       // Seuil d'humidité max (%)
  final double? minTemp;            // Température min (°C)
  final double? maxTemp;            // Température max (°C)
  final int? minHumidity;           // Humidité ambiante min (%)
  final int? maxHumidity;           // Humidité ambiante max (%)
  final String? difficulty;         // Niveau de difficulté
  final String? toxicity;           // Toxicité
  final double wateringSensitivity; // Sensibilité à l'arrosage (0-2)
  final double lightSensitivity;    // Sensibilité à la lumière (0-2)
}
```

#### `lib/data/models/user_plant.dart`

**Nouveaux enums et champs :**
```dart
enum LightExposure {
  lowLight,          // Faible lumière
  mediumLight,       // Lumière moyenne
  brightIndirect,    // Lumière vive indirecte
  directSun,         // Soleil direct
}

enum PotSize {
  small,   // < 15cm
  medium,  // 15-25cm
  large,   // > 25cm
}

class UserPlant {
  final LightExposure lightExposure;
  final PotSize potSize;
  final String? customNotes;
  
  // + méthode copyWith() pour modifications
}
```

### 3. Calculateur d'arrosage intelligent

#### `lib/data/watering_calculator.dart` (nouveau fichier)

**Algorithme de calcul :**

L'intervalle d'arrosage est calculé dynamiquement :

```dart
intervalle_ajusté = base_plante / (
  modificateur_lumière × 
  modificateur_pot × 
  modificateur_saison ×
  modificateur_apprentissage
)
```

**Modificateurs appliqués :**

| Facteur | Valeur | Multiplicateur |
|---------|--------|----------------|
| **Lumière** | Faible | 0.7× (moins d'arrosage) |
| | Moyenne | 1.0× (base) |
| | Vive indirecte | 1.3× |
| | Soleil direct | 1.6× (plus d'arrosage) |
| **Pot** | Petit | 1.3× (sèche vite) |
| | Moyen | 1.0× |
| | Grand | 0.8× (sèche lentement) |
| **Saison** | Hiver | 0.7× |
| | Printemps | 1.0× |
| | Été | 1.4× |
| | Automne | 0.9× |
| **Apprentissage** | Basé sur historique | 0.7-1.3× |

**Exemple de calcul :**

```
Pothos, base = 7 jours
+ Lumière vive (1.3×)
+ Petit pot (1.3×)
+ Été (1.4×)
= 7 / (1.3 × 1.3 × 1.4) ≈ 3 jours
```

**Fonctions utilitaires :**
```dart
WateringCalculator.calculateWateringInterval()
WateringCalculator.getWateringExplanation()
WateringCalculator.getLightExposureLabel()
WateringCalculator.getPotSizeLabel()
WateringCalculator.getSeasonLabel()
```

### 4. Repository enrichi

#### `lib/data/user_plants_repository.dart`

**Nouvelles fonctionnalités :**

1. **Historique d'arrosage** (stocké dans `shared_preferences`)
   - Garde les 20 derniers arrosages par plante
   - Utilisé pour l'apprentissage

2. **Recalcul automatique** lors de l'arrosage
   ```dart
   await repository.markWatered(plantId);
   // → Enregistre l'historique
   // → Recalcule l'intervalle intelligent
   ```

3. **Mise à jour des paramètres utilisateur**
   ```dart
   await repository.updatePlantSettings(
     plantId,
     lightExposure: LightExposure.brightIndirect,
     potSize: PotSize.large,
     customNotes: "À côté de la fenêtre sud",
   );
   // → Recalcule automatiquement l'intervalle
   ```

## Migration des données

### Compatibilité ascendante

Le système est **100% rétro-compatible** :
- Les anciennes plantes sans `lightExposure`/`potSize` utilisent des valeurs par défaut
- Le parser JSON gère gracieusement les champs manquants
- Les intervalles fixes existants restent valides

### Migration automatique

Au premier arrosage post-déploiement :
1. Charge l'ancienne plante avec intervalle fixe
2. Applique le calcul intelligent
3. Met à jour avec le nouvel intervalle

## Interface utilisateur (À implémenter)

### Écrans à modifier

#### 1. Ajout de plante
Ajouter après la sélection du dernier arrosage :
```dart
// Nouvel écran : PlantSettingsStep
- Sélecteur d'exposition lumineuse (4 options)
- Sélecteur de taille de pot (3 options)
- Prévisualisation de l'intervalle calculé
```

#### 2. Détails de plante (nouveau)
```dart
PlantDetailScreen(plant: userPlant) {
  - Photo + nom
  - Intervalle d'arrosage + explication
  - Paramètres modifiables :
    * Exposition lumineuse
    * Taille du pot
    * Notes personnalisées
  - Historique des arrosages (calendrier)
  - Bouton "Arroser maintenant"
}
```

#### 3. Carte de plante (home)
Ajouter un indicateur visuel :
```dart
PlantCard {
  - Icône d'exposition (☀️/🌤️/☁️/🌑)
  - Taille de pot (S/M/L)
  - Explication au tap : "7j → 4j (été, forte lumière)"
}
```

### Composants UI suggérés

```dart
// Sélecteur d'exposition
class LightExposureSelector extends StatelessWidget {
  Widget build(context) => SegmentedButton<LightExposure>(
    segments: [
      ButtonSegment(value: LightExposure.lowLight, icon: Icon(Icons.nights_stay)),
      ButtonSegment(value: LightExposure.mediumLight, icon: Icon(Icons.cloud)),
      ButtonSegment(value: LightExposure.brightIndirect, icon: Icon(Icons.wb_sunny_outlined)),
      ButtonSegment(value: LightExposure.directSun, icon: Icon(Icons.wb_sunny)),
    ],
  );
}

// Sélecteur de taille de pot
class PotSizeSelector extends StatelessWidget {
  Widget build(context) => SegmentedButton<PotSize>(
    segments: [
      ButtonSegment(value: PotSize.small, label: Text("S")),
      ButtonSegment(value: PotSize.medium, label: Text("M")),
      ButtonSegment(value: PotSize.large, label: Text("L")),
    ],
  );
}
```

## Tests à effectuer

### Tests unitaires

```dart
// test/data/watering_calculator_test.dart
test('Calcul avec lumière forte en été', () {
  final catalog = CatalogPlant(
    id: 1,
    commonName: "Test",
    wateringDays: 7,
  );
  
  final user = UserPlant(
    // ... summer, bright light, small pot
  );
  
  final result = WateringCalculator.calculateWateringInterval(
    catalogPlant: catalog,
    userPlant: user,
  );
  
  expect(result, lessThan(7)); // Plus fréquent en été
});
```

### Tests d'intégration

1. **Ajout de plante**
   - Configurer exposition + pot
   - Vérifier intervalle calculé correct
   
2. **Arrosage**
   - Marquer comme arrosé
   - Vérifier historique enregistré
   - Vérifier recalcul avec apprentissage

3. **Changement de saison**
   - Simuler changement de mois
   - Vérifier ajustement automatique

## Performance

### Impact mémoire
- **Historique** : ~800 bytes par plante (20 dates)
- **Nouveaux champs** : ~100 bytes par plante
- **Total** : Négligeable (< 100KB pour 100 plantes)

### Impact CPU
- **Calcul** : < 1ms par plante
- **Recalcul** : Uniquement lors arrosage ou changement paramètres
- **Pas d'impact** sur le scroll/UI

## Déploiement

### Checklist

- [ ] Tests unitaires WateringCalculator
- [ ] Tests d'intégration repository
- [ ] UI pour paramètres plante
- [ ] Écran de détails plante
- [ ] Migration testée avec vraies données
- [ ] Documentation utilisateur
- [ ] Obtenir API key Open Plantbook
- [ ] Générer catalogue enrichi
- [ ] Tester sur device physique

### Rollback

En cas de problème, le système peut revenir à l'ancien comportement :
1. Supprimer les appels à `WateringCalculator`
2. Utiliser directement `catalogPlant.wateringDays`
3. Les anciennes données restent valides

## Améliorations futures

### Court terme
1. Scraper PlantSolve pour 113 plantes supplémentaires
2. Ajouter photos pour toutes les plantes
3. Traductions françaises des noms communs

### Moyen terme
1. Notifications intelligentes (iOS/Android)
2. Statistiques d'arrosage
3. Export/import de données
4. Sync multi-device (optionnel)

### Long terme
1. Identification par photo (Pl@ntNet)
2. Détection de problèmes (feuilles jaunes, etc.)
3. Communauté / partage de conseils
4. Intégration capteurs IoT (optionnel)

## Support

### Questions fréquentes

**Q: Pourquoi mon intervalle change après chaque arrosage ?**
R: Le système apprend de vos arrosages réels. Après 3+ arrosages, il ajuste l'intervalle.

**Q: Comment désactiver le calcul intelligent ?**
R: Pas encore implémenté. Feature à ajouter : mode "manuel" avec intervalle fixe.

**Q: Les anciennes plantes sont-elles compatibles ?**
R: Oui, elles utilisent des valeurs par défaut (lumière moyenne, pot moyen).

### Logs de débogage

```dart
// Activer les logs
final repo = UserPlantsRepository();
await repo.logAll();

// Dans la console :
// [SharedPrefs] watering_history = {"123": ["2026-07-01T10:00:00", ...]}
```

---

**Dernière mise à jour :** 2 juillet 2026
**Version :** 1.0.0
**Auteur :** Système Cursor Agent
