import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/package.dart';
import '../services/firebase_service.dart';
import '../services/tracking_service.dart';
import 'edit_package_screen.dart'; // Import da nova tela

class PackageDetailsScreen extends StatefulWidget {
  final Package package;

  const PackageDetailsScreen({super.key, required this.package});

  @override
  State<PackageDetailsScreen> createState() => _PackageDetailsScreenState();
}

class _PackageDetailsScreenState extends State<PackageDetailsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isRefreshing = false;
  late Package _currentPackage;

  @override
  void initState() {
    super.initState();
    _currentPackage = widget.package;
  }

  Future<void> _refreshTracking() async {
    setState(() => _isRefreshing = true);

    try {
      final events =
          await TrackingService.trackPackage(_currentPackage.trackingCode);

      if (events.isNotEmpty) {
        final updatedPackage = _currentPackage.copyWith(
          events: events,
          lastUpdate: DateTime.now(),
          currentStatus: events.first.status,
        );

        await _firebaseService.updatePackage(updatedPackage);

        if (mounted) {
          setState(() => _currentPackage = updatedPackage);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rastreamento atualizado')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Nenhuma atualização disponível no momento')),
          );
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

  // Função para abrir a tela de edição
  Future<void> _editPackage() async {
    final updatedPackage = await Navigator.push<Package>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPackageScreen(package: _currentPackage),
      ),
    );

    if (updatedPackage != null && mounted) {
      setState(() {
        _currentPackage = updatedPackage;
      });
    }
  }

  void _copyTrackingCode() {
    Clipboard.setData(ClipboardData(text: _currentPackage.trackingCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado para área de transferência')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPackage.customName ?? 'Detalhes'),
        actions: [
          // Botão de editar adicionado aqui
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar encomenda',
            onPressed: _isRefreshing ? null : _editPackage,
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshTracking,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentPackage.trackingCode,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentPackage.type,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _copyTrackingCode,
                        tooltip: 'Copiar código',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue[300]
                              : Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _currentPackage.currentStatus,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.blue[100]
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentPackage.lastUpdate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Última atualização: ${dateFormat.format(_currentPackage.lastUpdate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Histórico de Rastreamento',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_currentPackage.events.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum evento de rastreamento disponível',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentPackage.events.length,
                      itemBuilder: (context, index) {
                        final event = _currentPackage.events[index];
                        final isFirst = index == 0;
                        final isLast = index == _currentPackage.events.length - 1;

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: isFirst
                                          ? Colors.green
                                          : Colors.blue[300],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: Colors.blue[200],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: isLast ? 0 : 24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.status,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isFirst
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isFirst
                                              ? Colors.green[700]
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        event.description,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            event.location,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateFormat.format(event.dateTime),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}