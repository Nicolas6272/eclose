import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/catalog_plant.dart';
import '../../../data/plants_catalog.dart';
import '../../plants/widgets/plant_avatar.dart';

class PlantPickerStep extends StatefulWidget {
  const PlantPickerStep({
    super.key,
    required this.onPlantSelected,
  });

  final ValueChanged<CatalogPlant> onPlantSelected;

  @override
  State<PlantPickerStep> createState() => _PlantPickerStepState();
}

class _PlantPickerStepState extends State<PlantPickerStep> {
  final _searchController = TextEditingController();
  List<CatalogPlant> _results = searchPlants('');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _results = searchPlants(_searchController.text));
  }

  void _selectPlant(CatalogPlant plant) {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    widget.onPlantSelected(plant);
  }

  @override
  Widget build(BuildContext context) {
    final showGenericHint = _searchController.text.trim().isNotEmpty &&
        _results.every((plant) => plant.isGeneric);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Ajoute une première plante à ta collection',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Cherche ta plante…',
              prefixIcon: Icon(Icons.search, color: sauge, size: 22),
            ),
          ),
          if (showGenericHint) ...[
            const SizedBox(height: 12),
            Text(
              'Plante introuvable ? Choisis une catégorie.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: vertProfond.withValues(alpha: 0.5),
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: vertProfond.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, index) {
                final plant = _results[index];
                return InkWell(
                  onTap: _isSaving ? null : () => _selectPlant(plant),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        PlantAvatar(plant: plant, size: 44),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            plant.commonName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        Text(
                          '${plant.wateringDays}j',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: vertProfond.withValues(alpha: 0.4),
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
