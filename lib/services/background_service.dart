import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:rastreiodex/models/package.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'tracking_service.dart';

// Nome da tarefa deve ser único
const String fetchBackgroundTask = "fetchBackgroundTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case fetchBackgroundTask:
        debugPrint("⏰ Iniciando verificação em background...");
        try {
          // Inicializa bindings do Flutter para permitir acesso a disco/rede no background
          WidgetsFlutterBinding.ensureInitialized();

          // Inicializa serviços necessários na isolate do background
          await NotificationService.initialize();

          final packages = await DatabaseService.instance.getAllPackages();

          if (packages.isEmpty) {
            debugPrint("📦 Nenhuma encomenda cadastrada.");
            return Future.value(true);
          }

          int updatesCount = 0;

          for (var package in packages) {
            // Não verifica pacotes já entregues ou arquivados
            if (package.isDelivered || package.isArchived) continue;

            try {
              final result = await TrackingService.trackPackage(package.trackingCode);

              if (result.events.isNotEmpty) {
                // Ordena eventos para garantir que o primeiro é o mais recente
                final newEvents = result.events;
                newEvents.sort((a, b) => b.dateTime.compareTo(a.dateTime));

                final lastEvent = newEvents.first;

                // Compara por data do evento (mais preciso que comparar descrição)
                final bool hasUpdates = package.events.isEmpty ||
                                        lastEvent.dateTime.isAfter(package.events.first.dateTime);

                if (hasUpdates) {
                  final updatedPackage = package.copyWith(
                    events: newEvents,
                    currentStatus: lastEvent.status,
                    lastUpdate: lastEvent.dateTime,
                    estimatedDelivery: result.estimatedDelivery,
                    isDelivered: result.isDelivered,
                  );

                  await DatabaseService.instance.createOrUpdatePackage(updatedPackage);

                  final String currentTitle = updatedPackage.customName ?? updatedPackage.trackingCode;

                  // --- ATUALIZAÇÃO DO WIDGET (Sincroniza apenas se for o item fixado) ---
                  final String? pinnedTitle = await HomeWidget.getWidgetData<String>('pkg_title');

                  if (pinnedTitle == currentTitle) {
                    await HomeWidget.saveWidgetData<String>('pkg_status', lastEvent.status);
                    await HomeWidget.saveWidgetData<String>('pkg_desc', lastEvent.description);

                    await HomeWidget.updateWidget(
                      name: 'TrackingWidgetProvider',
                      androidName: 'TrackingWidgetProvider',
                    );
                    debugPrint("📱 Widget atualizado para: $currentTitle");
                  }
                  // -------------------------------------------------------------------

                  debugPrint("🔔 Nova atualização para: ${package.trackingCode}");
                  await NotificationService.showNotification(
                    'Atualização: $currentTitle',
                    lastEvent.description,
                  );

                  updatesCount++;
                }
              }
            } catch (e) {
              debugPrint("❌ Erro ao verificar pacote ${package.trackingCode}: $e");
            }
            // Delay de segurança entre requisições
            await Future.delayed(const Duration(seconds: 1));
          }
          debugPrint("✅ Background task finalizada. $updatesCount pacotes atualizados.");

        } catch (e) {
          debugPrint("❌ Erro fatal no background task: $e");
          return Future.value(false);
        }
        break;
    }
    return Future.value(true);
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "1", // ID único da tarefa
      fetchBackgroundTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }
}