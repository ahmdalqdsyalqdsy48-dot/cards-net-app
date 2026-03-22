import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(
        title: 'إدارة الاشتراكات',
        isOnline: true,
      ),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // === 1. أدوات إنشاء الخطط والتسويق (أعلى الشاشة) ===
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // نافذة إنشاء خطة جديدة
                      },
                      icon: const Icon(Icons.add_task, color: Colors.white),
                      label: const Text('إنشاء خطة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // نافذة إنشاء كوبون
                      },
                      icon: const Icon(Icons.local_offer, color: Colors.purple),
                      label: const Text('كوبون ترويجي', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.purple)),
                    ),
                  ),
                ],
              ),
            ),

            // === 2. جدول المراقبة الرئيسي (حالة الاشتراكات) ===
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Text('حالة اشتراكات الوكلاء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  // وكيل في فترة مجانية (أخضر)
                  _buildSubscriptionCard(
                    context,
                    agentName: 'شبكة الصقر',
                    planName: 'فترة تجريبية (عمولة 5%)',
                    expiryDate: 'ينتهي بعد 14 يوم',
                    statusColor: Colors.green,
                    statusText: 'فترة مجانية 🟢',
                  ),
                  
                  // وكيل في باقة مدفوعة نشطة (أزرق)
                  _buildSubscriptionCard(
                    context,
                    agentName: 'شبكة القمة',
                    planName: 'الخطة السنوية المفتوحة',
                    expiryDate: 'ينتهي بعد 6 أشهر',
                    statusColor: Colors.blue,
                    statusText: 'نشط 🔵',
                  ),

                  // وكيل في فترة إنذار (برتقالي)
                  _buildSubscriptionCard(
                    context,
                    agentName: 'وكالة النور',
                    planName: 'خطة 6 أشهر (عمولة 7%)',
                    expiryDate: 'ينتهي بعد 3 أيام',
                    statusColor: Colors.orange,
                    statusText: 'إنذار شحن 🟠',
                  ),

                  // وكيل مجمد لعدم السداد (أحمر)
                  _buildSubscriptionCard(
                    context,
                    agentName: 'شبكة الوادي',
                    planName: 'خطة شهرية',
                    expiryDate: 'انتهى منذ يومين',
                    statusColor: Colors.red,
                    statusText: 'مجمد آلياً 🔴',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === دالة مساعدة لتصميم بطاقة الاشتراك وأزرار التحكم ===
  Widget _buildSubscriptionCard(BuildContext context, {
    required String agentName,
    required String planName,
    required String expiryDate,
    required Color statusColor,
    required String statusText,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(agentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.assignment, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text(planName, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.timer, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text(expiryDate, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            // أزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionBtn(icon: Icons.edit_calendar, title: 'تعديل الخطة', color: Colors.blue),
                _buildActionBtn(icon: Icons.pause_circle_outline, title: 'إيقاف مؤقت', color: Colors.orange),
                _buildActionBtn(icon: Icons.history, title: 'السجل', color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({required IconData icon, required String title, required Color color}) {
    return InkWell(
      onTap: () {},
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
