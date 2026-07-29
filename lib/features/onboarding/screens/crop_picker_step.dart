import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/crop_catalog.dart';
import '../../../data/models/catalog_crop.dart';
import '../../crops/widgets/catalog_crop_tile.dart';

class CropPickerStep extends StatefulWidget {
  const CropPickerStep({super.key, required this.onCropSelected});

  final ValueChanged<CatalogCrop> onCropSelected;

  @override
  State<CropPickerStep> createState() => _CropPickerStepState();
}

class _CropPickerStepState extends State<CropPickerStep> {
  final _searchController = TextEditingController();
  late List<CatalogCrop> _results;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _results = CropCatalog.search('');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _results = CropCatalog.search(_searchController.text));
  }

  void _selectCrop(CatalogCrop crop) {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    widget.onCropSelected(crop);
  }

  @override
  Widget build(BuildContext context) {
    final emptySearch =
        _searchController.text.trim().isNotEmpty && _results.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Choisis une première plante dans ton potager',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Une seule pour commencer — tu pourras en ajouter d\'autres après.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: vertProfond.withValues(alpha: 0.55),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Tomate, basilic, radis…',
              prefixIcon: Icon(Icons.search, color: sauge, size: 22),
            ),
          ),
          if (emptySearch) ...[
            const SizedBox(height: 12),
            Text(
              'Aucune plante trouvée. Essaie un autre mot.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: vertProfond.withValues(alpha: 0.5),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final crop = _results[index];
                return CatalogCropTile(
                  crop: crop,
                  onTap: _isSaving ? null : () => _selectCrop(crop),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
