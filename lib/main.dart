import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:google_fonts/google_fonts.dart'; // 👈 استدعاء مكتبة الخطوط

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
            systemProvider.currentUserPhone == 'لا يوجد رقم' ? null : systemProvider.currentUserPhone
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

    // 👈 دالة ذكية لتطبيق نوع الخط المختار من لوحة التحكم
    TextTheme _applyFont(TextTheme baseTheme, Color textColor) {
      if (themeProvider.fontFamily == 'System') return baseTheme.apply(bodyColor: textColor, displayColor: textColor);
      
      try {
        return GoogleFonts.getTextTheme(
          themeProvider.fontFamily,
          baseTheme,
        ).apply(bodyColor: textColor, displayColor: textColor);
      } catch (e) {
        // إذا فشل تحميل الخط، استخدم خط كالفون الافتراضي
        return GoogleFonts.cairoTextTheme(baseTheme).apply(bodyColor: textColor, displayColor: textColor);
      }
    }

    return MaterialApp(
      title: 'نظام كروت نت',
      debugShowCheckedModeBanner: false,
      
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // 👈 السر هنا: تطبيق نسبة تكبير أو تصغير الخط المحددة من لوحة المالك على النظام بأكمله
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeProvider.fontSizeScale),
          ),
          child: child!,
        );
      },

      // ==========================================
      // ☀️ الوضع النهاري 
      // ==========================================
      theme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        scaffoldBackgroundColor: themeProvider.primaryColor, 
        
        // 👈 تطبيق الخط واللون المتجاوب مع الخلفية
        textTheme: _applyFont(ThemeData.light().textTheme, themeProvider.adaptiveTextColor),
        
        iconTheme: IconThemeData(color: themeProvider.adaptiveTextColor),
        
        appBarTheme: AppBarTheme(
          backgroundColor: themeProvider.primaryColor,
          foregroundColor: themeProvider.adaptiveTextColor, 
          elevation: 0, 
        ),

        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      
      // ==========================================
      // 🌙 الوضع الليلي 
      // ==========================================
      darkTheme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        scaffoldBackgroundColor: Color.alphaBlend(
          themeProvider.primaryColor.withOpacity(0.2), 
          const Color(0xFF121212),
        ),
        
        // 👈 تطبيق الخط واللون الأبيض الثابت في الوضع الليلي
        textTheme: _applyFont(ThemeData.dark().textTheme, Colors.white),
        
        iconTheme: const IconThemeData(color: Colors.white),
        appBarTheme: AppBarTheme(
          backgroundColor: Color.alphaBlend(
            themeProvider.primaryColor.withOpacity(0.2), 
            const Color(0xFF121212),
          ),
          foregroundColor: Colors.white,
          elevation: 0,
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
