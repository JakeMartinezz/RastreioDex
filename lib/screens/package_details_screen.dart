import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/package.dart';
import '../models/tracking_event.dart';
import '../services/firebase_service.dart';
import '../services/tracking_service.dart';
import 'edit_package_screen.dart';

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

  // Helper para o ícone (igual ao Card)
  IconData _getPackageIcon() {
    if (_currentPackage.type.contains('SEDEX')) {
      return Icons.flash_on;
    } else if (_currentPackage.type.contains('PAC')) {
      return Icons.local_shipping;
    }
    return Icons.inventory_2;
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
      const SnackBar(content: Text('Código copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPackage.customName ?? 'Detalhes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar',
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
            // CABEÇALHO DO PACOTE
            Container(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HERO 1: ÍCONE ---
                  Hero(
                    tag: 'icon_${_currentPackage.id}',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getPackageIcon(),
                        size: 32,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // TEXTOS
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- HERO 2: TÍTULO/CÓDIGO ---
                        Hero(
                          tag: 'title_${_currentPackage.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              _currentPackage.trackingCode,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentPackage.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        if (_currentPackage.lastUpdate != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.update,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Atualizado em ${dateFormat.format(_currentPackage.lastUpdate!)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_all),
                    onPressed: _copyTrackingCode,
                  ),
                ],
              ),
            ),

            // TIMELINE VISUAL
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Linha do Tempo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_currentPackage.events.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentPackage.events.length,
                      itemBuilder: (context, index) {
                        final event = _currentPackage.events[index];
                        final isFirst = index == 0;
                        final isLast =
                            index == _currentPackage.events.length - 1;

                        return TimelineTile(
                          event: event,
                          isFirst: isFirst,
                          isLast: isLast,
                          dateFormat: dateFormat,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aguardando eventos...',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS DA TIMELINE ---

class TimelineTile extends StatelessWidget {
  final TrackingEvent event;
  final bool isFirst;
  final bool isLast;
  final DateFormat dateFormat;

  const TimelineTile({
    super.key,
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.dateFormat,
  });

  IconData _getIcon() {
    final status = event.status.toLowerCase();
    if (status.contains('entregue')) {
      return Icons.check_circle;
    }
    if (status.contains('saiu') || status.contains('trânsito')) {
      return Icons.local_shipping;
    }
    if (status.contains('postado')) {
      return Icons.inventory_2;
    }
    if (status.contains('fiscaliza') || status.contains('aduaneira')) {
      return Icons.policy;
    }
    if (status.contains('pagamento')) {
      return Icons.payments;
    }
    return Icons.circle;
  }

  Color _getColor(BuildContext context) {
    final status = event.status.toLowerCase();
    if (status.contains('entregue')) {
      return Colors.green;
    }
    if (status.contains('saiu') || status.contains('trânsito')) {
      return Colors.blue;
    }
    if (status.contains('aguardando') || status.contains('postado')) {
      return Colors.amber[700]!;
    }
    if (status.contains('tributado') || status.contains('taxa')) {
      return Colors.red;
    }

    return Theme.of(context).primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final icon = _getIcon();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (isFirst)
                  PulsingIcon(icon: icon, color: color)
                else
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: Colors.grey[500]),
                  ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.status,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isFirst ? FontWeight.bold : FontWeight.w500,
                      color: isFirst
                          ? color
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (event.description.isNotEmpty &&
                      event.description != event.status)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        event.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!)),
                        child: Text(
                          dateFormat.format(event.dateTime),
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const PulsingIcon({super.key, required this.icon, required this.color});

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: 32 + _animation.value,
                height: 32 + _animation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color
                      .withValues(alpha: (1 - _controller.value) * 0.3),
                ),
              );
            },
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Icon(widget.icon, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}