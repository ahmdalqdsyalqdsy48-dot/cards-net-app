import 'package:flutter/material.dart';
// استدعاء صفحة تسجيل الدخول الموحد
import 'features/auth/screens/sso_login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام كروت نت',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      
      // أعدنا الواجهة الرئيسية لتكون شاشة تسجيل الدخول
      home: const SSOLoginScreen(),
    );
  }
}
