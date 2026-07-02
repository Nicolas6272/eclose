import 'models/catalog_plant.dart';
import 'models/user_plant.dart';

enum Season {
  winter,
  spring,
  summer,
  fall,
}

class WateringCalculator {
  static int calculateWateringInterval({
    required CatalogPlant catalogPlant,
    required UserPlant userPlant,
    List<DateTime>? wateringHistory,
  }) {
    final baseInterval = catalogPlant.wateringDays;
    
    double modifier = 1.0;
    
    modifier *= _getLightModifier(
      userPlant.lightExposure,
      catalogPlant.lightSensitivity,
    );
    
    modifier *= _getPotSizeModifier(userPlant.potSize);
    
    modifier *= _getSeasonModifier(_getCurrentSeason());
    
    if (wateringHistory != null && wateringHistory.length >= 3) {
      modifier *= _getLearningModifier(
        wateringHistory,
        baseInterval,
      );
    }
    
    final adjustedInterval = (baseInterval / modifier).round();
    
    return adjustedInterval.clamp(1, 30);
  }
  
  static double _getLightModifier(
    LightExposure exposure,
    double sensitivity,
  ) {
    final baseModifier = switch (exposure) {
      LightExposure.lowLight => 0.7,
      LightExposure.mediumLight => 1.0,
      LightExposure.brightIndirect => 1.3,
      LightExposure.directSun => 1.6,
    };
    
    return 1.0 + (baseModifier - 1.0) * sensitivity;
  }
  
  static double _getPotSizeModifier(PotSize size) {
    return switch (size) {
      PotSize.small => 1.3,
      PotSize.medium => 1.0,
      PotSize.large => 0.8,
    };
  }
  
  static double _getSeasonModifier(Season season) {
    return switch (season) {
      Season.winter => 0.7,
      Season.spring => 1.0,
      Season.summer => 1.4,
      Season.fall => 0.9,
    };
  }
  
  static Season _getCurrentSeason() {
    final now = DateTime.now();
    final month = now.month;
    
    if (month >= 3 && month <= 5) return Season.spring;
    if (month >= 6 && month <= 8) return Season.summer;
    if (month >= 9 && month <= 11) return Season.fall;
    return Season.winter;
  }
  
  static double _getLearningModifier(
    List<DateTime> history,
    int baseInterval,
  ) {
    if (history.length < 3) return 1.0;
    
    final sortedHistory = List<DateTime>.from(history)..sort();
    
    final intervals = <int>[];
    for (int i = 1; i < sortedHistory.length; i++) {
      final days = sortedHistory[i].difference(sortedHistory[i - 1]).inDays;
      if (days > 0 && days < 60) {
        intervals.add(days);
      }
    }
    
    if (intervals.isEmpty) return 1.0;
    
    final avgActual = intervals.reduce((a, b) => a + b) / intervals.length;
    
    final deviation = avgActual / baseInterval;
    
    if (deviation < 0.5 || deviation > 2.0) {
      return 1.0;
    }
    
    return 1.0 + (deviation - 1.0) * 0.3;
  }
  
  static String getWateringExplanation({
    required CatalogPlant catalogPlant,
    required UserPlant userPlant,
    required int calculatedDays,
  }) {
    final parts = <String>[];
    
    parts.add('Base: ${catalogPlant.wateringDays} jours');
    
    if (userPlant.lightExposure == LightExposure.brightIndirect ||
        userPlant.lightExposure == LightExposure.directSun) {
      parts.add('+ forte lumière');
    } else if (userPlant.lightExposure == LightExposure.lowLight) {
      parts.add('- faible lumière');
    }
    
    if (userPlant.potSize == PotSize.small) {
      parts.add('+ petit pot');
    } else if (userPlant.potSize == PotSize.large) {
      parts.add('- grand pot');
    }
    
    final season = _getCurrentSeason();
    if (season == Season.summer) {
      parts.add('+ été');
    } else if (season == Season.winter) {
      parts.add('- hiver');
    }
    
    return parts.join(', ') + ' → $calculatedDays jours';
  }
  
  static String getLightExposureLabel(LightExposure exposure) {
    return switch (exposure) {
      LightExposure.lowLight => 'Faible lumière',
      LightExposure.mediumLight => 'Lumière moyenne',
      LightExposure.brightIndirect => 'Lumière vive indirecte',
      LightExposure.directSun => 'Soleil direct',
    };
  }
  
  static String getPotSizeLabel(PotSize size) {
    return switch (size) {
      PotSize.small => 'Petit (< 15cm)',
      PotSize.medium => 'Moyen (15-25cm)',
      PotSize.large => 'Grand (> 25cm)',
    };
  }
  
  static String getSeasonLabel(Season season) {
    return switch (season) {
      Season.winter => 'Hiver',
      Season.spring => 'Printemps',
      Season.summer => 'Été',
      Season.fall => 'Automne',
    };
  }
}
