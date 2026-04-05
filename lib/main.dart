import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // 👈 1. استدعاء مكتبة فايربيس
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 🆕 استدعاء مكتبة فايرستور

// استدعاء العقول (Providers) التي أنشأناها
import 'core/providers/theme_provider.dart';
import 'core/providers/system_provider.dart'; 

import 'features/auth/screens/sso_login_screen.dart';

void main() async {
  // هذا السطر ضروري جداً لتهيئة محرك فلاتر قبل الاتصال بالإنترنت
  WidgetsFlutterBinding.ensureInitialized();

  // 👈 1. المفاتيح الجديدة والصحيحة 100% للتطبيق المربوط بالاستضافة
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDdZzU6VXrmmk9Ul99GTN5RLtza95tLkVE",
      authDomain: "netcardsapp.firebaseapp.com",
      projectId: "netcardsapp",
      storageBucket: "netcardsapp.firebasestorage.app",
      messagingSenderId: "100057914511",
      appId: "1:100057914511:web:75b015601ca5cb836724fa",
      measurementId: "G-4MDY84TCRQ", // إضافة معرف التتبع (اختياري ومفيد)
    ),
  );

  // 🚨 2. تفعيل الذاكرة الفولاذية (IndexedDB) للمتصفح 🚨
  // هذا الكود يضمن حفظ البيانات في القرص الصلب للمتصفح فوراً قبل إرسالها لجوجل
  // مما يحميك من ضياع البيانات عند عمل Refresh (تحديث الصفحة)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    MultiProvider(
      providers: [
        // تفعيل مزود الألوان
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        // تفعيل مزود النظام الشامل ليكون متاحاً لجميع الشاشات
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
