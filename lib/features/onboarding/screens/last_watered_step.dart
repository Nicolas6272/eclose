import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/catalog_plant.dart';
import '../../../data/user_plants_repository.dart';

class LastWateredStep extends StatefulWidget {
  const LastWateredStep({
    super.key,
    required this.repository,
    required this.plant,
    required this.onContinue,
    this.isOnboarding = true,
  });

  final UserPlantsRepository repository;
  final CatalogPlant plant;
  final ValueChanged<DateTime> onContinue;
  final bool isOnboarding;

  @override
  State<LastWateredStep> createState() => _LastWateredStepState();
}

class _LastWateredStepState extends State<LastWateredStep> {
  DateTime? _selectedDate;
  bool _isSaving = false;

  static DateTime _dateDaysAgo(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: days));
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: 'Dernier arrosage',
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _isSaving) return;

    setState(() => _isSaving = true);

    if (widget.isOnboarding) {
      await widget.repository.saveOnboardingPlant(
        widget.plant,
        lastWateredAt: _selectedDate!,
      );
    } else {
      await widget.repository.addPlantFromCatalog(
        widget.plant,
        lastWateredAt: _selectedDate!,
      );
    }

    if (mounted) {
      widget.onContinue(_selectedDate!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantName = widget.plant.commonName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Quand as-tu arrosé\nton $plantName ?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'On en a besoin pour calculer le prochain rappel.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: vertProfond.withValues(alpha: 0.5),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 32),
          _LastWateredOption(
            label: 'Aujourd\'hui',
            isSelected: _selectedDate == _dateDaysAgo(0),
            onTap: () => setState(() => _selectedDate = _dateDaysAgo(0)),
          ),
          const SizedBox(height: 10),
          _LastWateredOption(
            label: 'Hier',
            isSelected: _selectedDate == _dateDaysAgo(1),
            onTap: () => setState(() => _selectedDate = _dateDaysAgo(1)),
          ),
          const SizedBox(height: 10),
          _LastWateredOption(
            label: 'Il y a 3 jours',
            isSelected: _selectedDate == _dateDaysAgo(3),
            onTap: () => setState(() => _selectedDate = _dateDaysAgo(3)),
          ),
          const SizedBox(height: 10),
          _LastWateredOption(
            label: 'Il y a une semaine',
            isSelected: _selectedDate == _dateDaysAgo(7),
            onTap: () => setState(() => _selectedDate = _dateDaysAgo(7)),
          ),
          const SizedBox(height: 10),
          _LastWateredOption(
            label: _selectedDate != null &&
                    ![
                      _dateDaysAgo(0),
                      _dateDaysAgo(1),
                      _dateDaysAgo(3),
                      _dateDaysAgo(7),
                    ].contains(_selectedDate)
                ? formatFrenchDate(_selectedDate!)
                : 'Choisir une date…',
            isSelected: _selectedDate != null &&
                ![
                  _dateDaysAgo(0),
                  _dateDaysAgo(1),
                  _dateDaysAgo(3),
                  _dateDaysAgo(7),
                ].contains(_selectedDate),
            onTap: _pickCustomDate,
          ),
          const Spacer(),
          FilledButton(
            onPressed: _selectedDate != null && !_isSaving ? _submit : null,
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _LastWateredOption extends StatelessWidget {
  const _LastWateredOption({
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? terracotta : vertProfond,
                      ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, size: 20, color: terracotta),
            ],
          ),
        ),
      ),
    );
  }
}
