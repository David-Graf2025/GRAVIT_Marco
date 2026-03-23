import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/config_loader.dart';
import 'core/di/injection.dart';
import 'presentation/providers/upload_provider.dart';
import 'presentation/screens/access_gate/access_gate_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize configuration from .env file
  await ConfigLoader.initialize();
  
  // Setup dependency injection
  await setupDependencyInjection();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UploadNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GRAVIT DOKU HELPER',
      theme: AppTheme.dark(),
      home: const AccessGate(),
    );
  }
}
