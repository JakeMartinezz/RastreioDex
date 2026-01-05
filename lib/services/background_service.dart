import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import 'tracking_service.dart';
import 'notification_service.dart';

// Nome da tarefa para referência
const String fetchBackgroundTask = "fetchBackgroundTask";

@pragma('vm:entry-point') // Obrigatório para o Dart saber que isso roda em background
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case fetchBackgroundTask:
        debugPrint("⏰ Iniciando verificação em background...");
        try {
          // 1. Inicializar Firebase (necessário pois estamos em outra thread)
          await Firebase.initializeApp();
          
          // 2. Inicializar Notificações
          // Nota: Não precisamos dos listeners de push aqui, apenas do canal local
          await NotificationService.initialize();

          final firebaseService = FirebaseService();
          
          // 3. Buscar todas as encomendas
          final packages = await firebaseService.getAllPackages();
          debugPrint("📦 Background: Verificando ${packages.length} encomendas");

          int updatesCount = 0;

          for (var package in packages) {
            // Se já foi entregue, talvez pular para economizar dados/bateria
            // if (package.currentStatus.toLowerCase().contains('entregue')) continue;

            try {
              // 4. Consultar API
              final events = await TrackingService.trackPackage(package.trackingCode);
              
              if (events.isNotEmpty) {
                // 5. Tentar atualizar no Firebase
                final hasUpdates = await firebaseService.updatePackageTracking(
                  package.id, 
                  events
                );

                if (hasUpdates) {
                  updatesCount++;
                  debugPrint("🔔 Nova atualização para: ${package.trackingCode}");
                  
                  // 6. Enviar Notificação Local
                  await NotificationService.showNotification(
                    'Atualização: ${package.customName ?? package.trackingCode}',
                    events.first.description,
                  );
                }
              }
            } catch (e) {
              debugPrint("❌ Erro ao verificar pacote ${package.trackingCode}: $e");
            }
            
            // Pequeno delay para não sobrecarregar a API se tiver muitos pacotes
            await Future.delayed(const Duration(seconds: 1));
          }

          debugPrint("✅ Fim do background task. Atualizações: $updatesCount");
          
        } catch (e) {
          debugPrint("❌ Erro fatal no background task: $e");
          return Future.value(false);
        }
        break;
    }
    return Future.value(true);
  });
}