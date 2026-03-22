import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(
        title: 'الرئيسية - غرفة العمليات',
        isOnline: true,
      ),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === أدوات التحكم العلوية (فلترة وتصدير) ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // برمجة فلتر التاريخ لاحقاً
                      },
                      icon: const Icon(Icons.date_range),
                      label: const Text('فلترة التاريخ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        foregroundColor: Theme.of(context).primaryColor,
                        elevation: 0,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // برمجة تصدير PDF لاحقاً
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('تصدير الملخص'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        foregroundColor: Colors.green,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 25),
                const Text(
                  'نظرة عامة على الإمبراطورية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                // === البطاقات الإحصائية التفاعلية (Grid) ===
                GridView.count(
                  crossAxisCount: 2, // عرض بطاقتين في كل سطر
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  shrinkWrap: true, // مهم جداً داخل SingleChildScrollView
                  physics: const NeverScrollableScrollPhysics(), // منع التمرير الداخلي
                  childAspectRatio: 1.1, // للتحكم بطول وعرض البطاقة
                  children: [
                    _buildStatCard(
                      context,
                      title: 'الوكلاء',
                      value: '🟢 45 | 🔴 5',
                      icon: Icons.group,
                      color: Colors.blue,
                      onTap: () {
                        // الانتقال لقسم إدارة الوكلاء
                      },
                    ),
                    _buildStatCard(
                      context,
                      title: 'إجمالي المحافظ',
                      value: '15,400,000 ر.ي',
                      icon: Icons.account_balance_wallet,
                      color: Colors.purple,
                      onTap: () {
                        // الانتقال للمركز المالي
                      },
                    ),
                    _buildStatCard(
                      context,
                      title: 'أرباح النظام (الصافي)',
                      value: '5,430,000 ر.ي',
                      icon: Icons.trending_up,
                      color: Colors.green,
                      onTap: () {
                        // الانتقال لقسم التقارير
                      },
                    ),
                    _buildStatCard(
                      context,
                      title: 'الدعم الفني',
                      value: '🟡 3 تذاكر معلقة',
                      icon: Icons.support_agent,
                      color: Colors.orange,
                      onTap: () {
                        // الانتقال لقسم الدعم الفني
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // === دالة مساعدة لتصميم البطاقات الإحصائية بشكل أنيق ===
  Widget _buildStatCard(BuildContext context, {
    required String title, 
    required String value, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), // لون خلفية شفاف وجميل
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
              textDirection: TextDirection.ltr, // لضبط الأرقام
            ),
          ],
        ),
      ),
    );
  }
}
