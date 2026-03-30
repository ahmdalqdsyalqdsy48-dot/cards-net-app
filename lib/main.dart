import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 1. استدعاء مكتبة العقل المدبر (Provider)

// 👇 2. استدعاء ملف الذاكرة الذي أنشأناه للتو لحفظ الألوان والوضع الليلي
import 'core/providers/theme_provider.dart'; 
// استدعاء صفحة تسجيل الدخول الموحد
import 'features/auth/screens/sso_login_screen.dart';

void main() {
  // 3. قمنا بتغليف التطبيق بـ MultiProvider لكي نتمكن من توزيع "العقل" على كل الشاشات
  runApp(
    MultiProvider(
      providers: [
        // إخبار التطبيق بإنشاء واستخدام ThemeProvider منذ اللحظة الأولى
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
    // 4. هنا نقوم بـ "الاستماع" للعقل المدبر لمعرفة اللون والوضع الحالي
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'نظام كروت نت', // حافظنا على اسم تطبيقك الأصلي الرائع
      debugShowCheckedModeBanner: false, // إخفاء شريط التجربة
      
      // 5. تطبيق الوضع الليلي أو النهاري بناءً على ما يتذكره التطبيق
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // 6. تخصيص المظهر الفاتح ليتلون باللون الذي يختاره الزبون
      theme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.light, // مظهر فاتح
        ),
        useMaterial3: true,
      ),
      
      // 7. تخصيص المظهر الداكن ليتلون أيضاً باللون الذي يختاره الزبون
      darkTheme: ThemeData(
        primaryColor: themeProvider.primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: Brightness.dark, // مظهر داكن
        ),
        useMaterial3: true,
      ),
      
      // الواجهة الرئيسية (شاشة تسجيل الدخول)
      home: const SSOLoginScreen(),
    );
  }
}
