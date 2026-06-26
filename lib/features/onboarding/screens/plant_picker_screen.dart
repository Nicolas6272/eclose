import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/catalog_plant.dart';
import '../../../data/plants_catalog.dart';
import '../../../data/user_plants_repository.dart';
import '../../plants/screens/last_watered_screen.dart';
import '../../plants/widgets/plant_avatar.dart';

class PlantPickerScreen extends StatefulWidget {
  const PlantPickerScreen({
    super.key,
    required this.repository,
  });

  final UserPlantsRepository repository;

  @override
  State<PlantPickerScreen> createState() => _PlantPickerScreenState();
}

class _PlantPickerScreenState extends State<PlantPickerScreen> {
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
    setState(() {
      _results = searchPlants(_searchController.text);
    });
  }

  Future<void> _selectPlant(CatalogPlant plant) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LastWateredScreen(
          repository: widget.repository,
          plant: plant,
        ),
      ),
    );

    if (!mounted) return;

    if (added == true) {
      Navigator.of(context).pop(true);
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final showGenericHint = _searchController.text.trim().isNotEmpty &&
        _results.every((plant) => plant.isGeneric);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajoute une plante'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Cherche ta plante…',
                  prefixIcon: Icon(Icons.search, color: sauge),
                ),
              ),
            ),
            if (showGenericHint)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Plante introuvable ? Choisis une catégorie :',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: vertProfond.withValues(alpha: 0.7),
                      ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final plant = _results[index];
                  return _PlantListTile(
                    plant: plant,
                    onTap: () => _selectPlant(plant),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantListTile extends StatelessWidget {
  const _PlantListTile({required this.plant, required this.onTap});

  final CatalogPlant plant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              PlantAvatar(plant: plant, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.commonName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Arrosage tous les ${plant.wateringDays} jours',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: vertProfond.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: sauge),
            ],
          ),
        ),
      ),
    );
  }
}
