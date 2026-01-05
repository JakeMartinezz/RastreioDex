import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(
        message.notification?.title ?? 'Atualização de Encomenda',
        message.notification?.body ?? 'Sua encomenda foi atualizada',
      );
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  static Future<void> _showLocalNotification(
      String title, String body) async {
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
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  static Future<void> showNotification(String title, String body) async {
    await _showLocalNotification(title, body);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Processar mensagem em background
}
