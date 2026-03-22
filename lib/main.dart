import 'package:flutter/material.dart';

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
      // واجهة مؤقتة حتى نقوم بربط صفحة تسجيل الدخول الموحد
      home: const Scaffold(
        body: Center(
          child: Text(
            'جاري بناء النظام الموحد... أهلاً بك!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

