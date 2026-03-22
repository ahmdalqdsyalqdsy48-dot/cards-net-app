import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';
import 'agent_management_screen.dart';
import 'financial_center_screen.dart';
import 'reports_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  // حالة لإظهار نافذة التنبيهات المنبثقة
  bool showNotificationPopup = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(title: 'غرفة العمليات', isOnline: true),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Stack( // استخدمنا Stack لوضع نافذة التنبيهات فوق المحتوى
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    // === أولاً: أدوات التحكم العلوية ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHeaderBtn(Icons.date_range, 'فلترة التاريخ 📅', Colors.blue, () {}),
                        _buildHeaderBtn(Icons.print, 'تصدير الملخص 🖨️', Colors.green, () {}),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // === ثانياً: البطاقات الإحصائية التفاعلية ===
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(
                          title: 'الوكلاء',
                          value: '🟢 45 | 🔴 5',
                          icon: Icons.group,
                          color: Colors.blue,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentManagementScreen())),
                        ),
                        _buildStatCard(
                          title: 'إجمالي المحافظ',
                          value: '15,400,000 ريال',
                          icon: Icons.account_balance_wallet,
                          color: Colors.purple,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialCenterScreen())),
                        ),
                        _buildStatCard(
                          title: 'أرباح النظام',
                          value: '5,430,000 ريال',
                          icon: Icons.trending_up,
                          color: Colors.green,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
                        ),
                        _buildStatCard(
                          title: 'سجل التنبيهات',
                          value: 'اضغط للمراجعة',
                          icon: Icons.history,
                          color: Colors.orange,
                          onTap: () {
                             // فتح تبويب سجل التنبيهات الجانبي
                             setState(() => showNotificationPopup = true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // === ثالثاً: نظام الإشعارات المنبثق (Popup) ===
          if (showNotificationPopup)
            Positioned(
              top: 10,
              left: 20,
              right: 20,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('تنبيهات النظام عاجلة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      const Divider(),
                      const ListTile(
                        leading: Icon(Icons.warning, color: Colors.amber),
                        title: Text('محفظة "شبكة الصقر" فارغة!'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => showNotificationPopup = false);
                        },
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // دالة بناء أزرار الهيدر
  Widget _buildHeaderBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(backgroundColor: color.withOpacity(0.1), foregroundColor: color, elevation: 0),
    );
  }

  // دالة بناء البطاقات الإحصائية
  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
