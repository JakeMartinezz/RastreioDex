import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/home_screen.dart';
import 'services/theme_service.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa Firebase
  await Firebase.initializeApp();
  
  // Inicializa Workmanager
  // Nota: isInDebugMode foi removido na nova versão
  await Workmanager().initialize(
    callbackDispatcher, 
  );

  // Registra a tarefa periódica
  await Workmanager().registerPeriodicTask(
    "1", // ID único da tarefa
    fetchBackgroundTask, // Nome da tarefa
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    // CORREÇÃO AQUI: Mudou de ExistingWorkPolicy para ExistingPeriodicWorkPolicy
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update, 
  );

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