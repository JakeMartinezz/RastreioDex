import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import '../models/package.dart';
import '../services/firebase_service.dart';
import '../services/tracking_service.dart';
import '../services/notification_service.dart';
import 'add_package_screen.dart';
import 'package_details_screen.dart';
import '../widgets/package_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isRefreshing = false;
  
  late TabController _tabController;
  int _currentTabIndex = 0;

  // Lista local para Ativos (permite reordenar sem pulos)
  List<Package> _activePackages = [];
  StreamSubscription? _activeSubscription;
  bool _isActiveLoading = true;

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    
    // Inicia ouvintes
    _setupActiveStream();
    _checkAutoArchive();
  }

  void _setupActiveStream() {
    // Escuta apenas os não arquivados
    _activeSubscription = _firebaseService
        .getPackagesStream(showArchived: false)
        .listen((packages) {
      if (mounted) {
        setState(() {
          _activePackages = packages;
          _isActiveLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint('Erro no stream de ativos: $error');
      if (mounted) setState(() => _isActiveLoading = false);
    });
  }

  Future<void> _checkAutoArchive() async {
    await _firebaseService.autoArchiveDeliveredPackages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshAllPackages() async {
    setState(() => _isRefreshing = true);
    try {
      await _checkAutoArchive();

      final packages = await _firebaseService.getAllPackages();
      for (var package in packages) {
        if (package.isArchived) continue;

        final events = await TrackingService.trackPackage(package.trackingCode);
        if (events.isNotEmpty) {
          final hasUpdates =
              await _firebaseService.updatePackageTracking(package.id, events);
          if (hasUpdates) {
            await NotificationService.showNotification(
              'Encomenda Atualizada',
              '${package.customName ?? package.trackingCode}: ${events.first.description}',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final Package item = _activePackages.removeAt(oldIndex);
      _activePackages.insert(newIndex, item);
    });

    _firebaseService.reorderPackages(_activePackages);
  }

  Future<void> _toggleArchive(Package package, bool archive) async {
    if (archive) {
      setState(() {
        _activePackages.removeWhere((p) => p.id == package.id);
      });
    }

    await _firebaseService.toggleArchive(package.id, archive);
    
    if (mounted) {
      final action = archive ? 'arquivada' : 'desarquivada';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Encomenda $action'),
          action: SnackBarAction(
            label: 'DESFAZER',
            onPressed: () {
              _firebaseService.toggleArchive(package.id, !archive);
            },
          ),
        ),
      );
    }
  }

  Future<void> _deletePackage(Package package) async {
     final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Encomenda'),
        content: Text(
            'Deseja remover permanentemente "${package.customName ?? package.trackingCode}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _activePackages.removeWhere((p) => p.id == package.id);
      });
      await _firebaseService.deletePackage(package.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Garante que usamos o brilho atual para a lógica de cores
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // DEFINIÇÃO DAS CORES PARA ANIMAÇÃO
    // CORREÇÃO: Usando TabBarThemeData em vez de TabBarTheme para compatibilidade
    final customTabBarTheme = TabBarThemeData(
      indicator: BoxDecoration(
        color: isDark ? Colors.grey[600] : Colors.white, // Cor da pílula (indicador)
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: isDark ? Colors.white : Colors.black, // Cor do texto selecionado
      unselectedLabelColor: Colors.grey, // Cor do texto não selecionado
      labelPadding: EdgeInsets.zero,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      overlayColor: WidgetStateProperty.all(Colors.transparent), // Remove splash
    );

    return Scaffold(
      appBar: AppBar(
        title: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 36,
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[200], // Cor de fundo do container
            borderRadius: BorderRadius.circular(20),
          ),
          // Usamos AnimatedTheme para interpolar as propriedades do TabBar suavemente
          child: AnimatedTheme(
            data: Theme.of(context).copyWith(tabBarTheme: customTabBarTheme),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Ativos'),
                Tab(text: 'Arquivados'),
              ],
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              if (isDark) {
                AdaptiveTheme.of(context).setLight();
              } else {
                AdaptiveTheme.of(context).setDark();
              }
            },
            tooltip: 'Alternar tema',
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshAllPackages,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveList(),
          _buildArchivedList(),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0 
        ? FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPackageScreen()),
              );
            },
            child: const Icon(Icons.add),
          )
        : null,
    );
  }

  Widget _buildActiveList() {
    if (_isActiveLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activePackages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma encomenda ativa',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAllPackages,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
        itemCount: _activePackages.length,
        onReorder: _onReorder,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              return Material(
                elevation: 8.0,
                color: Colors.transparent,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                child: child,
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final package = _activePackages[index];
          return Dismissible(
            key: Key(package.id),
            direction: DismissDirection.horizontal,
            background: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.archive, color: Colors.white),
            ),
            secondaryBackground: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.endToStart) {
                await _deletePackage(package);
                return true;
              } else {
                await _toggleArchive(package, true);
                return true;
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              child: PackageCard(
                package: package,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PackageDetailsScreen(package: package),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArchivedList() {
    return StreamBuilder<List<Package>>(
      stream: _firebaseService.getPackagesStream(showArchived: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final packages = snapshot.data ?? [];

        if (packages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.archive_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Nenhum item arquivado',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final package = packages[index];
            return Dismissible(
              key: Key(package.id),
              direction: DismissDirection.horizontal,
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                   color: Colors.blue,
                   borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.unarchive, color: Colors.white),
              ),
              secondaryBackground: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                   color: Colors.red,
                   borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.endToStart) {
                  await _deletePackage(package);
                  return true;
                } else {
                  await _toggleArchive(package, false);
                  return true;
                }
              },
              child: PackageCard(
                package: package,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PackageDetailsScreen(package: package),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}