import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_plant.dart';
import '../../../data/user_plants_repository.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../onboarding/screens/plant_picker_screen.dart';
import '../widgets/plant_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final UserPlantsRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<UserPlant>> _plantsFuture;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  void _loadPlants() {
    _plantsFuture = widget.repository.getPlants();
  }

  Future<void> _refresh() async {
    setState(_loadPlants);
    await _plantsFuture;
  }

  Future<void> _logSharedPrefs() async {
    await widget.repository.logAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SharedPrefs loggé dans le terminal'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _waterPlant(UserPlant plant) async {
    await widget.repository.markWatered(plant.id);
    await _refresh();
  }

  Future<void> _addPlant() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlantPickerScreen(
          repository: widget.repository,
        ),
      ),
    );

    if (added == true) {
      await _refresh();
    }
  }

  Future<void> _resetOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset onboarding ?'),
        content: const Text(
          'Supprime toutes les plantes et relance l\'onboarding depuis le début.',
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

  Widget _buildDevActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _addPlant,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une plante'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _resetOnboarding,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset onboarding'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes plantes'),
        actions: [
          IconButton(
            onPressed: _logSharedPrefs,
            tooltip: 'Log SharedPreferences',
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<UserPlant>>(
          future: _plantsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: terracotta));
            }

            final plants = snapshot.data ?? [];

            if (plants.isEmpty) {
              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Aucune plante pour l\'instant.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  _buildDevActions(),
                ],
              );
            }

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: terracotta,
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      itemCount: plants.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final plant = plants[index];
                        return PlantCard(
                          plant: plant,
                          onWater: () => _waterPlant(plant),
                        );
                      },
                    ),
                  ),
                ),
                _buildDevActions(),
              ],
            );
          },
        ),
      ),
    );
  }
}
