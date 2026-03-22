import 'package:flutter/material.dart';
// استدعاء الهيدر والقائمة الجانبية التي صنعناها سابقاً
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // === 1. إضافة الهيدر المخصص ===
      appBar: const CustomHeader(
        title: 'الرئيسية - غرفة العمليات',
        isOnline: true, // تفعيل النقطة الخضراء
      ),

      // === 2. إضافة القائمة الجانبية مع تمرير بيانات المالك ===
      drawer: const CustomDrawer(
        userName: 'مالك النظام', // سيتم جلب الاسم الحقيقي من قاعدة البيانات لاحقاً
        phoneNumber: '774578241', // رقمك الذي حددته
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),

      // === 3. جسم اللوحة (مؤقتاً رسالة ترحيبية حتى نبني البطاقات الـ 12) ===
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings,
                size: 100,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                'أهلاً بك في غرفة العمليات!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'تم ربط الهيدر والقائمة الجانبية بنجاح 🎉',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

