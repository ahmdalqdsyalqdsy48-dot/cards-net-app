import 'package:flutter/material.dart';
// هذا السطر مهم جداً: وهو يخبر النظام بمكان صفحة تسجيل الدخول التي أنشأناها
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
      themeMode: ThemeMode.system, // لدعم الوضع المظلم والنهاري
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      
      // هنا قمنا بتغيير الواجهة المؤقتة لفتح شاشة تسجيل الدخول الموحد مباشرة
      home: const SSOLoginScreen(),
    );
  }
}
