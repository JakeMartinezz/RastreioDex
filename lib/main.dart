import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'screens/home_screen.dart';
import 'services/theme_service.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa sistema de notificações
  await NotificationService.initialize();

  // Inicializa e registra background service
  await BackgroundService.initialize();
  await BackgroundService.registerPeriodicTask();

  final savedTheme = await AdaptiveTheme.getThemeMode();
  runApp(MyApp(savedTheme: savedTheme));
}

class MyApp extends StatelessWidget {
  final AdaptiveThemeMode? savedTheme;
  const MyApp({super.key, this.savedTheme});

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      initial: savedTheme ?? AdaptiveThemeMode.light,
      light: ThemeService.lightTheme,
      dark: ThemeService.darkTheme,
      builder: (light, dark) => MaterialApp(
        title: 'RastreioDex',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        home: const HomeScreen(),
      ),
    );
  }
}
