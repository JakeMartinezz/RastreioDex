import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:home_widget/home_widget.dart';
import 'firebase_service.dart';
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
          // Inicializa serviços necessários na isolate do background
          await Firebase.initializeApp();
          await NotificationService.initialize();

          final firebaseService = FirebaseService();
          final packages = await firebaseService.getAllPackages();
          
          for (var package in packages) {
            // Não verifica pacotes arquivados em background
            if (package.isArchived) continue;

            try {
              final result = await TrackingService.trackPackage(package.trackingCode);
              
              if (result.events.isNotEmpty) {
                final hasUpdates = await firebaseService.updatePackageTracking(
                  package.id, 
                  result.events,
                  estimatedDelivery: result.estimatedDelivery
                );

                if (hasUpdates) {
                  final String currentTitle = package.customName ?? package.trackingCode;
                  
                  // --- ATUALIZAÇÃO DO WIDGET (Sincroniza apenas se for o item fixado) ---
                  final String? pinnedTitle = await HomeWidget.getWidgetData<String>('pkg_title');
                  
                  if (pinnedTitle == currentTitle) {
                    await HomeWidget.saveWidgetData<String>('pkg_status', result.events.first.status);
                    await HomeWidget.saveWidgetData<String>('pkg_desc', result.events.first.description);
                    
                    await HomeWidget.updateWidget(
                      name: 'TrackingWidgetProvider',
                      androidName: 'TrackingWidgetProvider',
                    );
                  }
                  // -------------------------------------------------------------------

                  debugPrint("🔔 Nova atualização para: ${package.trackingCode}");
                  await NotificationService.showNotification(
                    'Atualização: $currentTitle',
                    result.events.first.description,
                  );
                }
              }
            } catch (e) {
              debugPrint("❌ Erro ao verificar pacote ${package.trackingCode}: $e");
            }
            // Delay de segurança entre requisições
            await Future.delayed(const Duration(seconds: 1));
          }
          debugPrint("✅ Fim do background task.");
          
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