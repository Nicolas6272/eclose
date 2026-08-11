import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/catalog_crop.dart';
import '../../../data/user_crops_repository.dart';
import '../../../data/watering_schedule.dart';

class CropSetupResult {
  const CropSetupResult({
    required this.plantedAt,
    required this.lastWateredAt,
  });

  final DateTime plantedAt;
  final DateTime lastWateredAt;
}

enum _YoungPlantAnswer { yes, no, unknown }

class CropSetupStep extends StatefulWidget {
  const CropSetupStep({
    super.key,
    required this.repository,
    required this.crop,
    required this.onContinue,
    this.isOnboarding = true,
  });

  final UserCropsRepository repository;
  final CatalogCrop crop;
  final ValueChanged<CropSetupResult> onContinue;
  final bool isOnboarding;

  @override
  State<CropSetupStep> createState() => _CropSetupStepState();
}

class _CropSetupStepState extends State<CropSetupStep> {
  double _daysSinceWatered = 0;
  _YoungPlantAnswer? _youngAnswer;
  bool _isSaving = false;

  static const int _maxWateredDaysAgo = 30;

  static DateTime _dateDaysAgo(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: days));
  }

  DateTime get _lastWateredAt => _dateDaysAgo(_daysSinceWatered.round());

  String get _wateredLabel {
    final days = _daysSinceWatered.round();
    if (days == 0) return 'Aujourd\'hui';
    if (days == 1) return 'Hier';
    return 'Il y a $days jours';
  }

  Future<void> _submit() async {
    if (_youngAnswer == null || _isSaving) return;

    final plantedAt = plantedAtFromYoungAnswer(
      isYoungSeedling: _youngAnswer == _YoungPlantAnswer.yes,
      seedlingDays: widget.crop.seedlingDays,
    );
    // Keep the user's watering date as-is (even if before plantedAt) so an
    // overdue plant lands in "À arroser" instead of being silently clamped.
    final lastWatered = _lastWateredAt;

    setState(() => _isSaving = true);

    if (widget.isOnboarding) {
      await widget.repository.saveOnboardingCrop(
        widget.crop,
        plantedAt: plantedAt,
        lastWateredAt: lastWatered,
      );
    } else {
      await widget.repository.addCropFromCatalog(
        widget.crop,
        plantedAt: plantedAt,
        lastWateredAt: lastWatered,
      );
    }

    if (mounted) {
      widget.onContinue(
        CropSetupResult(plantedAt: plantedAt, lastWateredAt: lastWatered),
      );
    }
  }

  Widget _lastWateredSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dernier arrosage',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'C\'est la base pour savoir quand arroser la prochaine fois.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: vertProfond.withValues(alpha: 0.5),
              ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _wateredLabel,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: terracotta,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: terracotta,
            inactiveTrackColor: terracotta.withValues(alpha: 0.2),
            thumbColor: terracotta,
            overlayColor: terracotta.withValues(alpha: 0.12),
            trackHeight: 4,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: _daysSinceWatered,
            min: 0,
            max: _maxWateredDaysAgo.toDouble(),
            divisions: _maxWateredDaysAgo,
            onChanged: (value) => setState(() => _daysSinceWatered = value),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aujourd\'hui',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: vertProfond.withValues(alpha: 0.45),
                  ),
            ),
            Text(
              '$_maxWateredDaysAgo j',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: vertProfond.withValues(alpha: 0.45),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _youngPlantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'C\'est un jeune plant ?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Moins de ~${widget.crop.seedlingDays} jours : on arrosera un peu plus souvent au début.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: vertProfond.withValues(alpha: 0.5),
              ),
        ),
        const SizedBox(height: 12),
        _ChoiceOption(
          label: 'Oui',
          isSelected: _youngAnswer == _YoungPlantAnswer.yes,
          onTap: () => setState(() => _youngAnswer = _YoungPlantAnswer.yes),
        ),
        const SizedBox(height: 8),
        _ChoiceOption(
          label: 'Non',
          isSelected: _youngAnswer == _YoungPlantAnswer.no,
          onTap: () => setState(() => _youngAnswer = _YoungPlantAnswer.no),
        ),
        const SizedBox(height: 8),
        _ChoiceOption(
          label: 'Je ne sais pas',
          isSelected: _youngAnswer == _YoungPlantAnswer.unknown,
          onTap: () => setState(() => _youngAnswer = _YoungPlantAnswer.unknown),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cropName = widget.crop.nameFr;
    final canSubmit = _youngAnswer != null && !_isSaving;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Ta culture : $cropName',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Deux infos pour calculer le prochain arrosage.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: vertProfond.withValues(alpha: 0.5),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 20),
          _lastWateredSection(),
          const SizedBox(height: 28),
          _youngPlantSection(),
          const Spacer(),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.isOnboarding ? 'Continuer' : 'Ajouter'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? terracotta.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? terracotta
                  : vertProfond.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? terracotta : vertProfond,
                      ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, size: 18, color: terracotta),
            ],
          ),
        ),
      ),
    );
  }
}

class CropSetupScreen extends StatelessWidget {
  const CropSetupScreen({
    super.key,
    required this.repository,
    required this.crop,
    this.isOnboarding = false,
  });

  final UserCropsRepository repository;
  final CatalogCrop crop;
  final bool isOnboarding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(crop.nameFr)),
      body: SafeArea(
        child: CropSetupStep(
          repository: repository,
          crop: crop,
          isOnboarding: isOnboarding,
          onContinue: (_) => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}
