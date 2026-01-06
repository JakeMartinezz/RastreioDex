import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
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
            // Não verifica pacotes arquivados em background para economizar bateria/API
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
                  debugPrint("🔔 Nova atualização para: ${package.trackingCode}");
                  await NotificationService.showNotification(
                    'Atualização: ${package.customName ?? package.trackingCode}',
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
    await Workmanager().initialize(
      callbackDispatcher,
      // isInDebugMode foi removido nas versões novas, não é mais necessário aqui
    );
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "1", // ID único da tarefa
      fetchBackgroundTask,
      frequency: const Duration(minutes: 15), // Frequência mínima permitida
      constraints: Constraints(
        networkType: NetworkType.connected, // Só roda se houver internet
      ),
      // CORREÇÃO: Uso do ExistingPeriodicWorkPolicy para tarefas periódicas
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }
}