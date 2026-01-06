import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/package.dart';

class PackageCard extends StatelessWidget {
  final Package package;
  final VoidCallback onTap;
  // onDelete removido pois agora é via swipe

  const PackageCard({
    super.key,
    required this.package,
    required this.onTap,
  });

  IconData _getPackageIcon() {
    if (package.type.contains('SEDEX')) {
      return Icons.flash_on;
    } else if (package.type.contains('PAC')) {
      return Icons.local_shipping;
    }
    return Icons.inventory_2;
  }

  Color _getStatusColor() {
    final status = package.currentStatus.toLowerCase();
    if (status.contains('entregue')) {
      return Colors.green;
    } else if (status.contains('saiu para entrega') ||
        status.contains('em trânsito')) {
      return Colors.orange;
    } else if (status.contains('aguardando')) {
      return Colors.grey;
    }
    return Colors.blue;
  }

  Widget _buildDaysInfo(BuildContext context) {
    if (package.events.isEmpty || package.lastUpdate == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final lastUpdate = package.lastUpdate!;
    final daysSinceUpdate = now.difference(lastUpdate).inDays;
    final status = package.currentStatus.toLowerCase();
    final isDelivered = status.contains('entregue');

    String text;
    Color color;
    IconData icon;

    if (isDelivered) {
      final firstEventDate = package.events.last.dateTime;
      final totalDays = lastUpdate.difference(firstEventDate).inDays;
      text = totalDays == 0 ? 'Entregue no mesmo dia' : 'Entregue em $totalDays dias';
      color = Colors.green;
      icon = Icons.check_circle_outline;
    } else if (daysSinceUpdate >= 3) {
      text = '$daysSinceUpdate dias sem atualização';
      color = Colors.red[300]!;
      icon = Icons.warning_amber_rounded;
    } else {
      final firstEventDate = package.events.last.dateTime;
      final totalDays = now.difference(firstEventDate).inDays;
      text = totalDays == 0 ? 'Postado hoje' : 'Postado há $totalDays dias';
      color = Colors.blue;
      icon = Icons.history;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = isDark ? color.withValues(alpha: 0.8) : color;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: displayColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: displayColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getPackageIcon(),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue[300]
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.customName ?? package.trackingCode,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          package.customName != null
                              ? package.trackingCode
                              : package.type,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botão de deletar removido daqui
                ],
              ),
              const SizedBox(height: 12),
              
              // Status Principal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getStatusColor().withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _getStatusColor(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        package.currentStatus,
                        style: TextStyle(
                          fontSize: 13,
                          color: _getStatusColor().withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              if (package.lastUpdate != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(package.lastUpdate!),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    
                    _buildDaysInfo(context),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}