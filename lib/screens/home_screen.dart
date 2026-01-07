import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:home_widget/home_widget.dart';
import '../models/package.dart';
import '../services/database_service.dart';
import '../services/tracking_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../services/widget_service.dart';
import 'add_package_screen.dart';
import 'package_details_screen.dart';
import 'settings_screen.dart';
import '../widgets/package_card.dart';
import '../widgets/skeleton_package_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  bool _isLoading = true;
  List<Package> _activePackages = [];
  List<Package> _archivedPackages = [];
  bool _hideDelivered = false;

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();

    // Verificação de inicialização pelo widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetLaunch);

    // Escutar cliques se o app já estiver aberto (Background)
    HomeWidget.widgetClicked.listen(_handleWidgetLaunch);

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _initialLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    if (mounted) setState(() => _isLoading = true);
    await _updateLists();
    if (mounted) setState(() => _isLoading = false);
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri != null && uri.toString().contains("widget_click")) {
      debugPrint("Link do widget detectado! Abrindo seleção...");

      // Feedback visual para saber que funcionou
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carregando seleção do widget...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showWidgetSelectionDialog();
        }
      });
    }
  }

  Future<void> _showWidgetSelectionDialog() async {
    final active = _activePackages;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Selecione para o Widget',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Nenhuma encomenda ativa encontrada.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: active.length,
                  itemBuilder: (context, index) {
                    final pkg = active[index];
                    return ListTile(
                      leading: Icon(_getPackageIcon(pkg.type)),
                      title: Text(pkg.customName ?? pkg.trackingCode),
                      subtitle: Text(pkg.currentStatus),
                      onTap: () {
                        WidgetService.pinPackage(pkg, context);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  IconData _getPackageIcon(String type) {
    if (type.contains('SEDEX')) return Icons.flash_on;
    if (type.contains('PAC')) return Icons.local_shipping;
    return Icons.inventory_2;
  }

  Future<void> _updateLists() async {
    final allPackages = await DatabaseService.instance.getAllPackages();
    final hidePref = await PreferencesService.getHideDelivered();

    var active = allPackages.where((p) => !p.isArchived).toList();
    final archived = allPackages.where((p) => p.isArchived).toList();

    if (hidePref) {
      active = active.where((p) => !p.isDelivered).toList();
    }

    if (mounted) {
      setState(() {
        _activePackages = active;
        _archivedPackages = archived;
        _hideDelivered = hidePref;
      });
    }
  }

  Future<void> _refreshPackages() async {
    // Then, update from network
    try {
      final packagesToUpdate = await DatabaseService.instance.getAllPackages();
      for (var package in packagesToUpdate) {
        if (package.isDelivered || package.isArchived) continue;

        try {
          final result = await TrackingService.trackPackage(package.trackingCode);
          if (result.events.isNotEmpty) {
            final updatedPackage = package.copyWith(
              events: result.events,
              lastUpdate: DateTime.now(),
              currentStatus: result.events.first.status,
              isDelivered: result.isDelivered,
              estimatedDelivery: result.estimatedDelivery,
            );
            await DatabaseService.instance.createOrUpdatePackage(updatedPackage);

            if (package.currentStatus != updatedPackage.currentStatus) {
               await NotificationService.showNotification(
                'Encomenda Atualizada',
                '${updatedPackage.customName ?? updatedPackage.trackingCode}: ${updatedPackage.currentStatus}',
              );
            }
          }
        } catch (e) {
          debugPrint('Erro ao atualizar pacote ${package.trackingCode}: $e');
        }
      }
      await _updateLists(); // Refresh UI again with updated data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar encomendas: $e')),
        );
      }
    }
  }

  Future<void> _toggleArchive(Package package, bool archive) async {
    await HapticFeedback.mediumImpact();
    
    // Optimistic UI update
    setState(() {
      if (archive) {
        _activePackages.removeWhere((p) => p.trackingCode == package.trackingCode);
        _archivedPackages.insert(0, package.copyWith(isArchived: true));
      } else {
        _archivedPackages.removeWhere((p) => p.trackingCode == package.trackingCode);
        _activePackages.insert(0, package.copyWith(isArchived: false));
      }
    });

    await DatabaseService.instance.toggleArchive(package.trackingCode, archive);
    
    if (mounted) {
      final action = archive ? 'arquivada' : 'desarquivada';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Encomenda $action'),
          action: SnackBarAction(
            label: 'DESFAZER',
            onPressed: () => _toggleArchive(package, !archive), // Recursive call to undo
          ),
        ),
      );
    }
    // No full reload needed due to optimistic update
  }

  Future<bool> _deletePackage(Package package) async {
    HapticFeedback.selectionClick();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Encomenda'),
        content: Text('Deseja remover permanentemente "${package.customName ?? package.trackingCode}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await HapticFeedback.heavyImpact();
      await DatabaseService.instance.deletePackage(package.trackingCode);
      setState(() {
        _activePackages.removeWhere((p) => p.trackingCode == package.trackingCode);
        _archivedPackages.removeWhere((p) => p.trackingCode == package.trackingCode);
      });
      return true;
    }
    return false;
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final Package item = _activePackages.removeAt(oldIndex);
      _activePackages.insert(newIndex, item);
    });
    DatabaseService.instance.updatePackageOrder(_activePackages);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customTabBarTheme = TabBarThemeData(
      indicator: BoxDecoration(
        color: isDark ? Colors.grey[600] : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.1).round()), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: isDark ? Colors.white : Colors.black,
      unselectedLabelColor: Colors.grey,
      labelPadding: EdgeInsets.zero,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    );

    return Scaffold(
      appBar: AppBar(
        title: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 36,
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
          child: AnimatedTheme(
            data: Theme.of(context).copyWith(tabBarTheme: customTabBarTheme),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'Ativos'), Tab(text: 'Arquivados')],
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => isDark ? AdaptiveTheme.of(context).setLight() : AdaptiveTheme.of(context).setDark(),
            tooltip: 'Alternar tema',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              _updateLists();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildActiveList(), _buildArchivedList()],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPackageScreen()));
                _updateLists();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
      itemCount: 6,
      itemBuilder: (context, index) => const SkeletonPackageCard(),
    );
  }

  Widget _buildActiveList() {
    if (_isLoading) return _buildLoadingList();
    if (_activePackages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_hideDelivered ? 'Nenhuma encomenda pendente' : 'Nenhuma encomenda ativa', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            if (_hideDelivered)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('(Entregues estão ocultos)', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshPackages,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
        itemCount: _activePackages.length,
        onReorder: _onReorder,
        itemBuilder: (context, index) {
          final package = _activePackages[index];
          return Dismissible(
            key: Key(package.trackingCode),
            direction: DismissDirection.horizontal,
            background: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.archive, color: Colors.white),
            ),
            secondaryBackground: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.endToStart) {
                return await _deletePackage(package);
              } else {
                _toggleArchive(package, true);
                return false; // Don't dismiss, UI is updated optimistically
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              child: PackageCard(
                package: package,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => PackageDetailsScreen(package: package)));
                  _updateLists();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArchivedList() {
    if (_isLoading) return _buildLoadingList();
    if (_archivedPackages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Nenhum item arquivado', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _archivedPackages.length,
      itemBuilder: (context, index) {
        final package = _archivedPackages[index];
        return Dismissible(
          key: Key(package.trackingCode),
          direction: DismissDirection.horizontal,
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.unarchive, color: Colors.white),
          ),
          secondaryBackground: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              return await _deletePackage(package);
            } else {
              _toggleArchive(package, false);
              return false; // Don't dismiss, UI is updated optimistically
            }
          },
          child: PackageCard(
            package: package,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => PackageDetailsScreen(package: package)));
              _updateLists();
            },
          ),
        );
      },
    );
  }
}