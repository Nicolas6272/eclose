import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/catalog_crop.dart';
import '../../../data/user_crops_repository.dart';

class CropSetupResult {
  const CropSetupResult({
    required this.plantedAt,
    required this.lastWateredAt,
  });

  final DateTime plantedAt;
  final DateTime lastWateredAt;
}

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
  DateTime? _plantedAt;
  bool _plantedIsMonthApprox = false;
  double _daysSinceWatered = 0;
  bool _isSaving = false;

  static const int _maxWateredDaysAgo = 30;

  static DateTime _dateDaysAgo(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: days));
  }

  static DateTime _midOfMonthOffset(int monthsAgo) {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month - monthsAgo, 1);
    return approximateMidMonth(target.year, target.month);
  }

  DateTime get _lastWateredAt => _dateDaysAgo(_daysSinceWatered.round());

  String get _wateredLabel {
    final days = _daysSinceWatered.round();
    if (days == 0) return 'Aujourd\'hui';
    if (days == 1) return 'Hier';
    return 'Il y a $days jours';
  }

  Future<void> _pickPlantedMonth() async {
    final now = DateTime.now();
    final months = List.generate(18, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return DateTime(d.year, d.month);
    });

    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: creme,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Tu as planté environ en…',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Pas besoin du jour exact — on prendra le milieu du mois.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: vertProfond.withValues(alpha: 0.55),
                      ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final month = months[index];
                    return ListTile(
                      title: Text(formatFrenchMonthYear(month)),
                      onTap: () => Navigator.pop(context, month),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _plantedAt = approximateMidMonth(selected.year, selected.month);
        _plantedIsMonthApprox = true;
      });
    }
  }

  Future<void> _submit() async {
    if (_plantedAt == null || _isSaving) return;

    var lastWatered = _lastWateredAt;
    if (lastWatered.isBefore(_plantedAt!)) {
      lastWatered = _plantedAt!;
    }

    setState(() => _isSaving = true);

    if (widget.isOnboarding) {
      await widget.repository.saveOnboardingCrop(
        widget.crop,
        plantedAt: _plantedAt!,
        lastWateredAt: lastWatered,
      );
    } else {
      await widget.repository.addCropFromCatalog(
        widget.crop,
        plantedAt: _plantedAt!,
        lastWateredAt: lastWatered,
      );
    }

    if (mounted) {
      widget.onContinue(
        CropSetupResult(plantedAt: _plantedAt!, lastWateredAt: lastWatered),
      );
    }
  }

  Widget _plantedSection() {
    final today = _dateDaysAgo(0);
    // Mid-week approximation when the user only remembers "this week".
    final thisWeek = _dateDaysAgo(3);
    final thisMonth = _midOfMonthOffset(0);

    final isToday = _plantedAt == today && !_plantedIsMonthApprox;
    final isThisWeek = _plantedAt == thisWeek && !_plantedIsMonthApprox;
    final isThisMonth = _plantedIsMonthApprox && _plantedAt == thisMonth;
    final isOtherMonth = _plantedAt != null &&
        _plantedIsMonthApprox &&
        _plantedAt != thisMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quand l\'as-tu plantée ?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pas besoin du jour exact.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: vertProfond.withValues(alpha: 0.5),
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateOption(
                label: 'Aujourd\'hui',
                isSelected: isToday,
                onTap: () => setState(() {
                  _plantedAt = today;
                  _plantedIsMonthApprox = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DateOption(
                label: 'Cette semaine',
                isSelected: isThisWeek,
                onTap: () => setState(() {
                  _plantedAt = thisWeek;
                  _plantedIsMonthApprox = false;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DateOption(
                label: 'Ce mois-ci',
                isSelected: isThisMonth,
                onTap: () => setState(() {
                  _plantedAt = thisMonth;
                  _plantedIsMonthApprox = true;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DateOption(
                label: isOtherMonth
                    ? formatFrenchMonthYear(_plantedAt!)
                    : 'Autre mois…',
                isSelected: isOtherMonth,
                onTap: _pickPlantedMonth,
              ),
            ),
          ],
        ),
      ],
    );
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
          'Fais glisser pour indiquer il y a combien de jours.',
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

  @override
  Widget build(BuildContext context) {
    final cropName = widget.crop.nameFr;
    final canSubmit = _plantedAt != null && !_isSaving;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Ta plante : $cropName',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quelques infos pour calculer le prochain arrosage.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: vertProfond.withValues(alpha: 0.5),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 20),
          _plantedSection(),
          const SizedBox(height: 24),
          _lastWateredSection(),
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

class _DateOption extends StatelessWidget {
  const _DateOption({
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
                  textAlign: TextAlign.center,
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
