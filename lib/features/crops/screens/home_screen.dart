import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fr_sort.dart';
import '../../../data/crop_catalog.dart';
import '../../../data/models/catalog_crop.dart';
import '../../../data/models/user_crop.dart';
import '../../../data/user_crops_repository.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../onboarding/screens/crop_picker_screen.dart';
import '../widgets/crop_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final UserCropsRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<UserCrop>> _cropsFuture;

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  void _loadCrops() {
    _cropsFuture = widget.repository.getCrops();
  }

  Future<void> _refresh() async {
    setState(_loadCrops);
    await _cropsFuture;
  }

  Future<void> _logPrefs() async {
    await widget.repository.logAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prefs loggées dans le terminal'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _waterCrop(UserCrop crop) async {
    await widget.repository.markWatered(crop.id);
    await _refresh();
  }

  Future<void> _addCrop() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CropPickerScreen(repository: widget.repository),
      ),
    );
    if (added == true) await _refresh();
  }

  Future<void> _resetOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset onboarding ?'),
        content: const Text(
          'Supprime toutes les plantes et relance l\'onboarding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await widget.repository.resetOnboarding();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OnboardingFlow(repository: widget.repository),
      ),
      (_) => false,
    );
  }

  List<UserCrop> _dueToday(List<UserCrop> crops) {
    return crops.where((crop) {
      final catalog = CropCatalog.byId(crop.catalogCropId);
      return catalog != null && crop.isDue(catalog);
    }).toList();
  }

  Map<CropCategory, List<UserCrop>> _groupByCategory(List<UserCrop> crops) {
    final map = <CropCategory, List<UserCrop>>{
      for (final c in CropCategory.values) c: <UserCrop>[],
    };
    for (final crop in crops) {
      final catalog = CropCatalog.byId(crop.catalogCropId);
      final category = catalog?.category ?? CropCategory.legume;
      map[category]!.add(crop);
    }
    for (final list in map.values) {
      list.sort((a, b) => compareFr(a.displayName, b.displayName));
    }
    return map;
  }

  Widget _pageSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: vertProfond.withValues(alpha: 0.55),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _todayPreview(List<UserCrop> due) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageSectionTitle(
          'À arroser aujourd\'hui',
          subtitle: due.isEmpty
              ? 'Rien à faire pour le moment'
              : due.length == 1
                  ? '1 plante à arroser'
                  : '${due.length} plantes à arroser',
        ),
        if (due.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: sauge.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sauge.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20, color: sauge),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tout est à jour',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: sauge,
                        ),
                  ),
                ),
              ],
            ),
          )
        else
          ...due.map(
            (crop) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CropCard(
                crop: crop,
                onWater: () => _waterCrop(crop),
              ),
            ),
          ),
      ],
    );
  }

  Widget _categoryTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: FilledButton.icon(
        onPressed: _addCrop,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une plante'),
      ),
    );
  }

  Future<void> _onDevAction(String action) async {
    switch (action) {
      case 'log_prefs':
        await _logPrefs();
      case 'reset_onboarding':
        await _resetOnboarding();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon potager'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu dev',
            icon: const Icon(Icons.bug_report_outlined),
            onSelected: _onDevAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'log_prefs',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.terminal),
                  title: Text('Log prefs'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'reset_onboarding',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.restart_alt),
                  title: Text('Reset onboarding'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<UserCrop>>(
          future: _cropsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: terracotta),
              );
            }

            final crops = snapshot.data ?? [];
            if (crops.isEmpty) {
              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Ton potager est vide.\nAjoute une première plante.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  _buildActions(),
                ],
              );
            }

            final due = _dueToday(crops);
            final grouped = _groupByCategory(crops);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    children: [
                      _todayPreview(due),
                      const SizedBox(height: 28),
                      _pageSectionTitle(
                        'Toutes mes plantes',
                        subtitle: 'Classées par catégorie',
                      ),
                      for (final category in CropCategory.values)
                        if (grouped[category]!.isNotEmpty) ...[
                          _categoryTitle(category.labelFr),
                          ...grouped[category]!.map(
                            (crop) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CropCard(
                                crop: crop,
                                showWaterAlways: false,
                                onWater: due.contains(crop)
                                    ? () => _waterCrop(crop)
                                    : null,
                              ),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
                _buildActions(),
              ],
            );
          },
        ),
      ),
    );
  }
}
