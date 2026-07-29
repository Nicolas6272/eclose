import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/crop_catalog.dart';
import '../../../data/models/catalog_crop.dart';
import '../../../data/user_crops_repository.dart';
import '../../crops/widgets/catalog_crop_tile.dart';
import 'crop_setup_step.dart';

class CropPickerScreen extends StatefulWidget {
  const CropPickerScreen({super.key, required this.repository});

  final UserCropsRepository repository;

  @override
  State<CropPickerScreen> createState() => _CropPickerScreenState();
}

class _CropPickerScreenState extends State<CropPickerScreen> {
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

  Future<void> _selectCrop(CatalogCrop crop) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CropSetupScreen(
          repository: widget.repository,
          crop: crop,
          isOnboarding: false,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter une plante')),
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
                  hintText: 'Tomate, basilic, radis…',
                  prefixIcon: Icon(Icons.search, color: sauge),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
      ),
    );
  }
}
