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

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isRefreshing = false;
  
  // Lista local para permitir reordenação instantânea sem "pulos"
  List<Package> _packages = [];
  bool _isLoading = true;
  StreamSubscription? _streamSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
    _setupStream();
  }

  void _setupStream() {
    _streamSubscription = _firebaseService.getPackagesStream().listen((packages) {
      if (mounted) {
        setState(() {
          _packages = packages;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint('Erro no stream: $error');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  // Função chamada ao arrastar e soltar
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final Package item = _packages.removeAt(oldIndex);
      _packages.insert(newIndex, item);
    });

    // Salva a nova ordem no Firebase
    _firebaseService.reorderPackages(_packages);
  }

  Future<void> _refreshAllPackages() async {
    setState(() => _isRefreshing = true);

    try {
      // Usamos a lista local para atualizar
      for (var package in _packages) {
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
          SnackBar(content: Text('Erro ao atualizar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _deletePackage(Package package) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Encomenda'),
        content: Text(
            'Deseja remover "${package.customName ?? package.trackingCode}"?'),
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
      await _firebaseService.deletePackage(package.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encomenda removida')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rastreio de Encomendas'),
        actions: [
          IconButton(
            icon: Icon(
              AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              if (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark) {
                AdaptiveTheme.of(context).setLight();
              } else {
                AdaptiveTheme.of(context).setDark();
              }
            },
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshAllPackages,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _packages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma encomenda cadastrada',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  // physics: const AlwaysScrollableScrollPhysics(), // Opcional se quiser forçar scroll
                  padding: const EdgeInsets.all(8),
                  itemCount: _packages.length,
                  onReorder: _onReorder,
                  // Proxy Decorator dá um efeito visual de sombra ao arrastar
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
                    final package = _packages[index];
                    // ReorderableListView precisa de uma Key única para cada item
                    return Container(
                      key: ValueKey(package.id), // IMPORTANTE: Chave única
                      margin: const EdgeInsets.only(bottom: 2), // Espaçamento pequeno
                      child: PackageCard(
                        package: package,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PackageDetailsScreen(package: package),
                            ),
                          );
                        },
                        onDelete: () => _deletePackage(package),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPackageScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}