import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// استدعاء العقول (Providers) التي أنشأناها
import 'core/providers/theme_provider.dart';
import 'core/providers/system_provider.dart'; // 👈 1. استدعاء الخادم المحلي الشامل

import 'features/auth/screens/sso_login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // تفعيل مزود الألوان
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        // 👇 2. تفعيل مزود النظام الشامل ليكون متاحاً لجميع الشاشات
        ChangeNotifierProvider(create: (context) => SystemProvider()), 
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
      
      theme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        scaffoldBackgroundColor: themeProvider.primaryColor.withOpacity(0.05),
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      
      darkTheme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        scaffoldBackgroundColor: Color.alphaBlend(
          themeProvider.primaryColor.withOpacity(0.1), 
          const Color(0xFF121212),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      
      home: const SSOLoginScreen(),
    );
  }
}
