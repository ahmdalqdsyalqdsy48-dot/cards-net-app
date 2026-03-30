import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/theme_provider.dart';
import 'features/auth/screens/sso_login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
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
      
      // تطبيق الوضع الليلي أو النهاري
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // ==========================================
      // تصميم الوضع النهاري
      // ==========================================
      theme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        // 👇 هنا الإصلاح: إعطاء الخلفية صبغة خفيفة جداً (5%) من اللون المختار
        scaffoldBackgroundColor: themeProvider.primaryColor.withOpacity(0.05),
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      
      // ==========================================
      // تصميم الوضع الليلي
      // ==========================================
      darkTheme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        // 👇 هنا الإصلاح: دمج اللون المختار بنسبة (10%) مع اللون الأسود الداكن
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
