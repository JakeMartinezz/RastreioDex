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
  // 1. Criamos uma variável para guardar o Stream
  late Stream<List<Package>> _packagesStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
    // 2. Inicializamos o Stream apenas UMA vez quando a tela nasce
    _packagesStream = _firebaseService.getPackagesStream();
  }

  Future<void> _refreshAllPackages() async {
    setState(() => _isRefreshing = true);

    try {
      final packages = await _firebaseService.getAllPackages();

      for (var package in packages) {
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
    super.build(context); // Necessário para AutomaticKeepAliveClientMixin
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
            tooltip: 'Alternar tema',
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
      body: StreamBuilder<List<Package>>(
        // 3. Usamos a variável criada no initState, e não a função direta
        stream: _packagesStream,
        builder: (context, snapshot) {
          // Removido logs excessivos para limpar o console
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar encomendas',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                         // Reinicia o stream em caso de erro manual
                         _packagesStream = _firebaseService.getPackagesStream();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final packages = snapshot.data ?? [];

          if (packages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma encomenda cadastrada',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque em + para adicionar',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshAllPackages,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: packages.length,
              itemBuilder: (context, index) {
                final package = packages[index];
                return PackageCard(
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
                );
              },
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