import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/auth/auth_service.dart';
import '../../../data/crop_catalog.dart';
import '../../../data/models/user_crop.dart';
import '../../../data/notifications/watering_notification_service.dart';
import '../../../data/user_crops_repository.dart';
import '../../onboarding/screens/crop_picker_screen.dart';
import '../widgets/crop_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.notifications,
    required this.auth,
    required this.onSignedOut,
  });

  final UserCropsRepository repository;
  final WateringNotificationService notifications;
  final AuthService auth;
  final Future<void> Function() onSignedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<UserCrop>> _cropsFuture;
  bool _showPermissionBanner = false;
  bool _permissionBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadCrops();
    _refreshPermissionBanner();
  }

  void _loadCrops() {
    _cropsFuture = widget.repository.getCrops();
  }

  Future<void> _syncNotifications() async {
    final crops = await widget.repository.getCrops();
    await widget.notifications.reschedule(crops);
    await _refreshPermissionBanner();
  }

  Future<void> _refreshPermissionBanner() async {
    final status = await widget.notifications.permissionStatus();
    if (!mounted) return;
    setState(() {
      _showPermissionBanner =
          !_permissionBannerDismissed &&
          status == NotificationPermissionStatus.denied;
    });
  }

  Future<void> _refresh() async {
    setState(_loadCrops);
    await _cropsFuture;
    await _syncNotifications();
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
    try {
      await widget.repository.markWatered(crop);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.friendlyError(error))),
      );
    }
  }

  /// Returns true if the crop was deleted.
  Future<bool> _confirmAndDeleteCrop(UserCrop crop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette culture ?'),
        content: Text(
          '${crop.displayName} sera retirée de ton potager.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return false;
    await widget.repository.deleteCrop(crop.id);
    await _refresh();
    return true;
  }

  Widget _swipeToDelete({
    required String dismissKey,
    required UserCrop crop,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Dismissible(
          key: ValueKey(dismissKey),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmAndDeleteCrop(crop),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: terracotta,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _addCrop() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CropPickerScreen(repository: widget.repository),
      ),
    );
    if (added == true) await _refresh();
  }

  Future<void> _openAccount() async {
    final email = widget.auth.currentUser?.email ?? 'Compte';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: creme,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Compte',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: vertProfond.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (!mounted) return;
    await widget.onSignedOut();
  }

  Future<void> _resetOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset onboarding ?'),
        content: const Text(
          'Supprime toutes les plantes, déconnecte et relance l\'onboarding.',
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
    await widget.notifications.cancelAll();
    await widget.auth.signOut();
    await widget.repository.resetDevice(clearDeviceHistory: true);
    await widget.onSignedOut();
  }

  Future<void> _testNotification() async {
    final crops = await widget.repository.getCrops();
    final dueCount = await widget.notifications.showTodayReminder(crops);
    if (!mounted) return;

    if (dueCount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission notifications refusée')),
      );
      await _refreshPermissionBanner();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          dueCount == 0
              ? 'Notif du jour envoyée (rien à arroser)'
              : 'Notif du jour envoyée ($dueCount culture${dueCount > 1 ? 's' : ''})',
        ),
      ),
    );
  }

  List<UserCrop> _dueToday(List<UserCrop> crops) {
    final due = crops.where((crop) {
      final catalog = CropCatalog.byId(crop.catalogCropId);
      return catalog != null && crop.isDue(catalog);
    }).toList();
    // Overdue first, then due today.
    due.sort((a, b) {
      final catalogA = CropCatalog.byId(a.catalogCropId)!;
      final catalogB = CropCatalog.byId(b.catalogCropId)!;
      return a
          .daysUntilWatering(catalogA)
          .compareTo(b.daysUntilWatering(catalogB));
    });
    return due;
  }

  List<UserCrop> _laterCrops(List<UserCrop> crops) {
    final later = crops.where((crop) {
      final catalog = CropCatalog.byId(crop.catalogCropId);
      return catalog != null && !crop.isDue(catalog);
    }).toList();
    later.sort((a, b) {
      final catalogA = CropCatalog.byId(a.catalogCropId)!;
      final catalogB = CropCatalog.byId(b.catalogCropId)!;
      return a
          .nextWateringAt(catalogA)
          .compareTo(b.nextWateringAt(catalogB));
    });
    return later;
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

  Widget _permissionBanner() {
    if (!_showPermissionBanner) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: terracotta.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: terracotta.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications désactivées',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'L\'app marche sans elles — active-les dans Réglages pour le rappel matinal.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: vertProfond.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    await openAppSettings();
                    await _refreshPermissionBanner();
                  },
                  child: const Text('Ouvrir Réglages'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _permissionBannerDismissed = true;
                      _showPermissionBanner = false;
                    });
                  },
                  child: Text(
                    'Plus tard',
                    style: TextStyle(
                      color: vertProfond.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueSection(List<UserCrop> due) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageSectionTitle(
          'À arroser aujourd\'hui',
          subtitle: due.isEmpty
              ? 'Rien à faire pour le moment'
              : due.length == 1
                  ? '1 culture à arroser'
                  : '${due.length} cultures à arroser',
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
            (crop) => _swipeToDelete(
              dismissKey: 'due-${crop.id}',
              crop: crop,
              child: CropCard(
                crop: crop,
                onWater: () => _waterCrop(crop),
              ),
            ),
          ),
      ],
    );
  }

  Widget _laterSection(List<UserCrop> later) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageSectionTitle(
          'Plus tard',
          subtitle: later.isEmpty
              ? 'Tout le reste est à jour'
              : later.length == 1
                  ? '1 culture à venir'
                  : '${later.length} cultures à venir',
        ),
        if (later.isEmpty)
          Text(
            'Aucune autre culture pour le moment.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: vertProfond.withValues(alpha: 0.5),
                ),
          )
        else
          ...later.map(
            (crop) => _swipeToDelete(
              dismissKey: 'later-${crop.id}',
              crop: crop,
              child: CropCard(
                crop: crop,
                showWaterAlways: true,
                onWater: () => _waterCrop(crop),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: FilledButton.icon(
        onPressed: _addCrop,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une culture'),
      ),
    );
  }

  Future<void> _onDevAction(String action) async {
    switch (action) {
      case 'log_prefs':
        await _logPrefs();
      case 'test_notif':
        await _testNotification();
      case 'reschedule_notifs':
        await _syncNotifications();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications replanifiées')),
        );
      case 'sign_out':
        await _signOut();
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
        title: Text(
          'Mon potager',
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          IconButton(
            tooltip: 'Compte',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: _openAccount,
          ),
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
                value: 'test_notif',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notifications_active_outlined),
                  title: Text('Notif du jour'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'reschedule_notifs',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule),
                  title: Text('Replanifier notifs'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'sign_out',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Déconnexion'),
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

            if (snapshot.hasError) {
              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AuthService.friendlyError(snapshot.error!),
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _refresh,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final crops = snapshot.data ?? [];
            if (crops.isEmpty) {
              return Column(
                children: [
                  _permissionBanner(),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Ton potager est vide.\nAjoute une première culture.',
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
            final later = _laterCrops(crops);

            return Column(
              children: [
                _permissionBanner(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    children: [
                      _dueSection(due),
                      const SizedBox(height: 28),
                      _laterSection(later),
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
