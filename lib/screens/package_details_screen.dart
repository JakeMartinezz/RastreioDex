import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:home_widget/home_widget.dart'; // NOVO IMPORT
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
  final ScreenshotController _screenshotController = ScreenshotController();

  bool _isRefreshing = false;
  bool _isSharing = false;
  late Package _currentPackage;

  @override
  void initState() {
    super.initState();
    _currentPackage = widget.package;
  }

  IconData _getPackageIcon() {
    if (_currentPackage.type.contains('SEDEX')) {
      return Icons.flash_on;
    } else if (_currentPackage.type.contains('PAC')) {
      return Icons.local_shipping;
    }
    return Icons.inventory_2;
  }

  // --- NOVA FUNÇÃO: FIXAR NO WIDGET ---
  Future<void> _pinToWidget() async {
    final title = _currentPackage.customName ?? _currentPackage.trackingCode;

    try {
      // Salva os dados desta encomenda específica como a principal do Widget
      await HomeWidget.saveWidgetData<String>('pkg_title', title);
      await HomeWidget.saveWidgetData<String>(
        'pkg_code',
        _currentPackage.trackingCode,
      );
      await HomeWidget.saveWidgetData<String>(
        'pkg_status',
        _currentPackage.currentStatus,
      );
      await HomeWidget.saveWidgetData<String>(
        'pkg_desc',
        _currentPackage.events.isNotEmpty
            ? _currentPackage.events.first.description
            : 'Aguardando rastreamento',
      );

      // Solicita ao Android a atualização do Widget nativo
      await HomeWidget.updateWidget(
        name: 'TrackingWidgetProvider',
        androidName: 'TrackingWidgetProvider',
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" fixado na tela inicial!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao fixar no widget: $e');
    }
  }

  Future<void> _refreshTracking() async {
    setState(() => _isRefreshing = true);

    try {
      final result = await TrackingService.trackPackage(
        _currentPackage.trackingCode,
      );

      if (result.events.isNotEmpty) {
        final updatedPackage = _currentPackage.copyWith(
          events: result.events,
          lastUpdate: DateTime.now(),
          currentStatus: result.events.first.status,
          estimatedDelivery: result.estimatedDelivery,
        );

        await _firebaseService.updatePackage(updatedPackage);

        if (mounted) {
          setState(() => _currentPackage = updatedPackage);

          HapticFeedback.lightImpact();

          // Opcional: Atualizar widget automaticamente se este for o item fixado
          final String? pinnedTitle = await HomeWidget.getWidgetData<String>(
            'pkg_title',
          );
          if (pinnedTitle ==
              (_currentPackage.customName ?? _currentPackage.trackingCode)) {
            await _pinToWidget();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rastreamento atualizado')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma atualização disponível no momento'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
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
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: _currentPackage.trackingCode));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  Future<void> _sharePackage() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final Uint8List imageBytes = await _screenshotController
          .captureFromWidget(
            _buildShareImageWidget(context),
            delay: const Duration(milliseconds: 10),
            pixelRatio: 2.0,
          );

      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/share_${_currentPackage.trackingCode}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      String shareText = '📦 *RastreioDex*\n';
      shareText +=
          '${_currentPackage.customName ?? "Encomenda"}: ${_currentPackage.trackingCode}\n\n';

      if (_currentPackage.estimatedDelivery != null) {
        final dateFormated = DateFormat(
          'dd/MM/yyyy',
        ).format(_currentPackage.estimatedDelivery!);
        shareText += '🛍️ *Previsão de Entrega:* $dateFormated\n\n';
      }

      if (_currentPackage.events.isNotEmpty) {
        final lastEvent = _currentPackage.events.first;
        shareText += '📍 *${lastEvent.status}*\n';
        shareText += '${lastEvent.description}\n';
        shareText +=
            '${lastEvent.location} - ${DateFormat('dd/MM HH:mm').format(lastEvent.dateTime)}';
      } else {
        shareText += 'Aguardando atualizações...';
      }

      await Share.shareXFiles([XFile(imagePath)], text: shareText);
    } catch (e) {
      debugPrint('Erro ao compartilhar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao gerar imagem para compartilhar'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Widget _buildShareImageWidget(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final lastEvent = _currentPackage.events.isNotEmpty
        ? _currentPackage.events.first
        : null;

    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'RastreioDex',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            _currentPackage.customName ?? 'Sua Encomenda',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentPackage.trackingCode,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          if (_currentPackage.estimatedDelivery != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 18,
                    color: Colors.green[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Previsão: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  Text(
                    DateFormat(
                      'dd/MM/yyyy',
                    ).format(_currentPackage.estimatedDelivery!),
                    style: TextStyle(color: Colors.green[800]),
                  ),
                ],
              ),
            ),

          if (lastEvent != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lastEvent.status,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastEvent.description,
                    style: TextStyle(color: Colors.blue[800], fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.place, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lastEvent.location,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(lastEvent.dateTime),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ] else ...[
            const Center(
              child: Text(
                'Aguardando atualizações...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPackage.customName ?? 'Detalhes'),
        actions: [
          // NOVO: ÍCONE PARA FIXAR NO WIDGET
          IconButton(
            icon: const Icon(Icons.push_pin_outlined),
            tooltip: 'Fixar na Tela Inicial',
            onPressed: (_isSharing || _isRefreshing) ? null : _pinToWidget,
          ),
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            tooltip: 'Compartilhar Status',
            onPressed: (_isSharing || _isRefreshing) ? null : _sharePackage,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar',
            onPressed: (_isSharing || _isRefreshing) ? null : _editPackage,
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Atualizar agora',
            onPressed: (_isSharing || _isRefreshing) ? null : _refreshTracking,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: isDark
                  ? Colors.grey[900]
                  : Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withAlpha(76),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'icon_${_currentPackage.id}',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.withAlpha(51)
                            : Theme.of(context).primaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getPackageIcon(),
                        size: 32,
                        color: isDark
                            ? Colors.blue[300]
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.blue.withAlpha(51)
                                : Theme.of(context).primaryColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentPackage.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.blue[200]
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        if (_currentPackage.estimatedDelivery != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 16,
                                color: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Previsão: ${DateFormat('dd/MM/yyyy').format(_currentPackage.estimatedDelivery!)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.blue[200]
                                      : Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_currentPackage.lastUpdate != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.update,
                                size: 16,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Atualizado em ${dateFormat.format(_currentPackage.lastUpdate!)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
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
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.copy_all),
                    onPressed: _copyTrackingCode,
                  ),
                ],
              ),
            ),

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
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
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.place,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Text(
                          dateFormat.format(event.dateTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
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

    _animation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
                  color: widget.color.withAlpha(
                    ((1 - _controller.value) * 76).toInt(),
                  ),
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
                  color: widget.color.withAlpha(102),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
