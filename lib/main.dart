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
    // 👈 استدعاء العقل المدبر للألوان
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'نظام كروت نت',
      debugShowCheckedModeBanner: false,
      
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // ==========================================
      // ☀️ الوضع النهاري (الذكي 100%)
      // ==========================================
      theme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        // 👈 1. جعلنا لون الخلفية 100% هو اللون الذي اختاره المستخدم
        scaffoldBackgroundColor: themeProvider.primaryColor, 
        
        // 👈 2. الذكاء اللوني: إجبار النصوص على (أبيض/أسود) لتكون مقروءة دائماً
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: themeProvider.adaptiveTextColor),
          bodyMedium: TextStyle(color: themeProvider.adaptiveTextColor),
          titleLarge: TextStyle(color: themeProvider.adaptiveTextColor),
        ),
        
        // 👈 3. جعل الأيقونات أيضاً تتبع نفس الذكاء اللوني
        iconTheme: IconThemeData(color: themeProvider.adaptiveTextColor),
        
        // 👈 4. الهيدر (الشريط العلوي) يتناغم مع الخلفية
        appBarTheme: AppBarTheme(
          backgroundColor: themeProvider.primaryColor,
          foregroundColor: themeProvider.adaptiveTextColor, 
          elevation: 0, // إزالة الظل ليندمج مع الخلفية
        ),

        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      
      // ==========================================
      // 🌙 الوضع الليلي (المريح للعين)
      // ==========================================
      darkTheme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        // في الوضع الليلي ندمج اللون المختار بنسبة 20% فقط مع الأسود لكي لا يؤذي العين
        scaffoldBackgroundColor: Color.alphaBlend(
          themeProvider.primaryColor.withOpacity(0.2), 
          const Color(0xFF121212),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
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
