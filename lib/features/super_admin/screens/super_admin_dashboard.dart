import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; // 👈 هذا هو السطر الذي استدعينا فيه الهيدر

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      // 👈 انظر هنا! بدلاً من كتابة كود الهيدر الطويل، وضعنا هذا السطر الصغير فقط:
      appBar: const CustomHeader(title: 'الرئيسية (غرفة العمليات)'), 
      
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أدوات التحكم العلوية (فلاتر التاريخ وتصدير الملخص)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.date_range, size: 18),
                    label: const Text('فلترة التاريخ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade900,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('تصدير الملخص'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // البطاقات الإحصائية التفاعلية
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'الوكلاء النشطين',
                      value: '45',
                      icon: Icons.people,
                      color: Colors.blue,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'الوكلاء المجمدين',
                      value: '3',
                      icon: Icons.person_off,
                      color: Colors.red,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'إجمالي المحافظ',
                      value: '12,450,000',
                      subtitle: 'ريال يمني',
                      icon: Icons.account_balance_wallet,
                      color: Colors.green,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // أداة مساعدة لبناء البطاقات الإحصائية
  Widget _buildStatCard(BuildContext context, {required String title, required String value, String? subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 30),
                Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 14),
              ],
            ),
            const SizedBox(height: 15),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
