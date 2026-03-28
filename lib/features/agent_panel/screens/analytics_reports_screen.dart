import 'package:flutter/material.dart';
// استدعاء الترويسة العلوية الموحدة
import '../../../core/widgets/custom_header.dart';
// استدعاء القائمة الجانبية الخاصة بالوكيل
import '../widgets/custom_agent_drawer.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key});

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> {
  // بيانات وهمية لمحاكاة المبيعات خلال الأسبوع (تُستخدم لرسم الأعمدة)
  final List<Map<String, dynamic>> _weeklySales = [
    {'day': 'السبت', 'sales': 45000, 'height': 0.4},
    {'day': 'الأحد', 'sales': 60000, 'height': 0.6},
    {'day': 'الإثنين', 'sales': 30000, 'height': 0.3},
    {'day': 'الثلاثاء', 'sales': 85000, 'height': 0.85},
    {'day': 'الأربعاء', 'sales': 50000, 'height': 0.5},
    {'day': 'الخميس', 'sales': 95000, 'height': 0.95},
    {'day': 'الجمعة', 'sales': 120000, 'height': 1.0}, // أعلى يوم
  ];

  // بيانات وهمية لأكثر الفئات مبيعاً
  final List<Map<String, dynamic>> _topCategories = [
    {'name': 'فئة أبو 500', 'count': 350, 'color': Colors.orange},
    {'name': 'فئة أبو 1000', 'count': 210, 'color': Colors.blue},
    {'name': 'فئة أبو 250', 'count': 180, 'color': Colors.green},
  ];

  @override
  Widget build(BuildContext context) {
    // التحقق من وضع النظام (نهاري أم ليلي) لضبط الألوان
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'التقارير التحليلية'),
      drawer: const CustomAgentDrawer(
        agentName: 'شبكة الصقر للواي فاي',
        phoneNumber: '777777777',
        role: 'وكيل معتمد (Agent)',
        currentBalance: 125000.0,
      ),
      // جعل اتجاه الشاشة من اليمين لليسار لدعم اللغة العربية
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. قسم الملخص المالي السريع (بطاقات علوية)
              const Text('الملخص المالي (هذا الشهر)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'إجمالي المبيعات',
                      amount: '1,450,000',
                      icon: Icons.storefront,
                      color: Colors.blue,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'صافي الأرباح',
                      amount: '72,500',
                      icon: Icons.monetization_on,
                      color: Colors.green,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 25),

              // 2. قسم الرسم البياني المبسط (أداء الأسبوع)
              const Text('أداء المبيعات (آخر 7 أيام)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              Container(
                height: 200,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _weeklySales.map((dayData) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // شريط الرسم البياني (طوله يتحدد بناءً على النسبة المئوية للمبيعات)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 20,
                          height: 120 * (dayData['height'] as double),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(dayData['height'] == 1.0 ? 1.0 : 0.5),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // اسم اليوم
                        Text(dayData['day'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 25),

              // 3. قسم أكثر الفئات مبيعاً (قائمة)
              const Text('أكثر الفئات مبيعاً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true, // مهم جداً داخل SingleChildScrollView لمنع الأخطاء
                physics: const NeverScrollableScrollPhysics(), // إيقاف التمرير الداخلي
                itemCount: _topCategories.length,
                itemBuilder: (context, index) {
                  final category = _topCategories[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: category['color'].withOpacity(0.1),
                        child: Icon(Icons.wifi, color: category['color']),
                      ),
                      title: Text(category['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text('${category['count']} كرت', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة مساعدة (Widget Builder) لإنشاء بطاقات الملخص المالي لتقليل تكرار الرمز البرمجي
  Widget _buildSummaryCard({required String title, required String amount, required IconData icon, required Color color, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('$amount ريال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }
}
