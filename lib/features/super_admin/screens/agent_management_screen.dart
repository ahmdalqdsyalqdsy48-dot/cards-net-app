import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class AgentManagementScreen extends StatelessWidget {
  const AgentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(
        title: 'إدارة الوكلاء',
        isOnline: true,
      ),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      // زر عائم لإضافة وكيل جديد في أسفل الشاشة
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // برمجة نافذة إضافة وكيل جديد (الاسم، الهاتف، الشبكة، العمولة، إلخ)
        },
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة وكيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // شريط معلومات سريع
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('قائمة الوكلاء (شركاء النظام)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: const Text('النشطين: 45', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // قائمة الوكلاء (على شكل بطاقات لتناسب الجوال)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: 3, // عدد الوكلاء الوهميين للتجربة
                  itemBuilder: (context, index) {
                    return _buildAgentCard(
                      context,
                      agentName: 'أحمد القدسي ${index + 1}',
                      networkName: 'شبكة الصقر $index',
                      phone: '77000000$index',
                      balance: '${(index + 1) * 150} ألف ريال',
                      isActive: index != 2, // لنجعل الوكيل الثالث مجمداً للتجربة
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === دالة مساعدة لتصميم بطاقة الوكيل وأزرار التحكم ===
  Widget _buildAgentCard(BuildContext context, {
    required String agentName,
    required String networkName,
    required String phone,
    required String balance,
    required bool isActive,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // السطر الأول: بيانات الوكيل الأساسية
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  child: Icon(Icons.person, color: isActive ? Colors.blue : Colors.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('$networkName | $phone', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                // حالة الوكيل
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'نشط' : 'مجمد',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            
            const Divider(height: 25),
            
            // السطر الثاني: الرصيد وأزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المحفظة', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(balance, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 14)),
                  ],
                ),
                // أزرار التحكم الفردية (كما طلبتها)
                Row(
                  children: [
                    _buildIconButton(icon: Icons.visibility, color: Colors.blue, tooltip: 'تفاصيل المبيعات'),
                    _buildIconButton(icon: Icons.edit, color: Colors.orange, tooltip: 'تعديل البيانات'),
                    _buildIconButton(icon: isActive ? Icons.pause_circle_filled : Icons.play_circle_fill, color: isActive ? Colors.amber : Colors.green, tooltip: isActive ? 'تجميد فوري' : 'فك التجميد'),
                    _buildIconButton(icon: Icons.delete_forever, color: Colors.red, tooltip: 'حذف آمن'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // تصميم مصغر لأزرار التحكم
  Widget _buildIconButton({required IconData icon, required Color color, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          // برمجة وظيفة الزر لاحقاً
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}
