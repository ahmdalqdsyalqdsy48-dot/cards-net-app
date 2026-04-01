import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // 👈 1. استدعاء مكتبة فايربيس

// استدعاء العقول (Providers) التي أنشأناها
import 'core/providers/theme_provider.dart';
import 'core/providers/system_provider.dart'; 

import 'features/auth/screens/sso_login_screen.dart';

// 👇 2. أضفنا كلمة async لكي ننتظر اتصال فايربيس قبل رسم الشاشات
void main() async {
  // 3. هذا السطر ضروري جداً لتهيئة محرك فلاتر قبل الاتصال بالإنترنت
  WidgetsFlutterBinding.ensureInitialized();

  // 4. 👈 كود الاتصال السحري بمشروعك الحقيقي على الإنترنت باستخدام مفاتيحك
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBV60g3WTr8Kf8wD0bSN2P-8aKn3efqYXk",
      authDomain: "cards-net-app.firebaseapp.com",
      projectId: "cards-net-app",
      storageBucket: "cards-net-app.firebasestorage.app",
      messagingSenderId: "504008355647",
      appId: "1:504008355647:web:c236e55cd00d7c5c8d6d8a",
    ),
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
