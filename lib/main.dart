import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/providers/theme_provider.dart';
import 'core/providers/system_provider.dart';
import 'core/providers/ui_provider.dart';

import 'features/auth/screens/sso_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDdZzU6VXrmmk9Ul99GTN5RLtza95tLkVE",
      authDomain: "netcardsapp.firebaseapp.com",
      projectId: "netcardsapp",
      storageBucket: "netcardsapp.firebasestorage.app",
      messagingSenderId: "100057914511",
      appId: "1:100057914511:web:75b015601ca5cb836724fa",
      measurementId: "G-4MDY84TCRQ",
    ),
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => SystemProvider()),
        ChangeNotifierProxyProvider<SystemProvider, UiProvider>(
          create: (context) => UiProvider(null),
          update: (context, systemProvider, previous) => UiProvider(
            systemProvider.currentUserPhone == 'لا يوجد رقم'
                ? null
                : systemProvider.currentUserPhone,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'نظام كروت نت',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // ✅ استخدام الثيمات المبنية مسبقاً داخل ThemeProvider
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      // تطبيق حجم الخط المخصص
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeProvider.fontSizeScale),
          ),
          child: child!,
        );
      },
      home: const SSOLoginScreen(),
    );
  }
}
