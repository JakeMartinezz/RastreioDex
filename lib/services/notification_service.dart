import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Configurações para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. Configurações para iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 3. Inicializar plugin
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Lógica opcional ao clicar na notificação
      },
    );

    // 4. Solicitar permissão no Android 13+ (Obrigatório)
    if (Platform.isAndroid) {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
              
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'tracking_updates',
      'Atualizações de Rastreio',
      channelDescription: 'Notificações de atualizações de encomendas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond, // ID único
      title,
      body,
      details,
    );
  }
}
