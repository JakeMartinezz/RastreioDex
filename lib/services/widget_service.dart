import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../models/package.dart';

class WidgetService {
  static Future<void> pinPackage(Package package, BuildContext context) async {
    final title = package.customName ?? package.trackingCode;

    try {
      await HomeWidget.saveWidgetData<String>('pkg_title', title);
      await HomeWidget.saveWidgetData<String>('pkg_code', package.trackingCode);
      await HomeWidget.saveWidgetData<String>('pkg_status', package.currentStatus);
      await HomeWidget.saveWidgetData<String>(
        'pkg_desc',
        package.events.isNotEmpty ? package.events.first.description : 'Aguardando rastreamento',
      );

      await HomeWidget.updateWidget(
        name: 'TrackingWidgetProvider',
        androidName: 'TrackingWidgetProvider',
      );

      if (context.mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" selecionado para o widget!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao fixar no widget: $e');
    }
  }
}
