import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class StaffSupportScreen extends StatelessWidget {
  const StaffSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // نستخدم DefaultTabController لإنشاء التبويبات بسهولة
    return DefaultTabController(
      length: 2, // عدد التبويبات
      child: Scaffold(
        appBar: const CustomHeader(
          title: 'إدارة المدراء والدعم الفني',
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
              // === شريط التبويبات ===
              Container(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                child: const TabBar(
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blueAccent,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(icon: Icon(Icons.admin_panel_settings), text: 'الموظفين والصلاحيات'),
                    Tab(icon: Icon(Icons.support_agent), text: 'تذاكر الدعم الفني'),
                  ],
                ),
              ),

              // === محتوى التبويبات ===
              Expanded(
                child: TabBarView(
                  children: [
                    _buildStaffTab(),   // محتوى التبويب الأول
                    _buildTicketsTab(), // محتوى التبويب الثاني
                  ],
                ),
              ),
            ],
          ),
        ),
        // زر عائم يظهر فقط لتسهيل إضافة موظف أو تذكرة
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: Colors.blueAccent,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  // ==========================================
  // 1. التبويب الأول: إدارة الموظفين والصلاحيات
  // ==========================================
  Widget _buildStaffTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 2, // عدد الموظفين الوهميين
      itemBuilder: (context, index) {
        bool isAccountant = index == 0; // لتمييز الأدوار
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isAccountant ? Colors.purple.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      child: Icon(Icons.person, color: isAccountant ? Colors.purple : Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isAccountant ? 'محمود المحاسب' : 'سالم (خدمة عملاء)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(isAccountant ? 'الصلاحيات: المركز المالي فقط' : 'الصلاحيات: الدعم الفني', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    // زر إيقاف الموظف
                    IconButton(
                      icon: const Icon(Icons.pause_circle_filled, color: Colors.orange),
                      tooltip: 'إيقاف مؤقت',
                      onPressed: () {},
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الراتب: 150,000 ريال', style: TextStyle(fontWeight: FontWeight.bold)),
                    // زر تسليم الراتب
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.monetization_on, color: Colors.green, size: 18),
                      label: const Text('تسليم الراتب', style: TextStyle(color: Colors.green)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 2. التبويب الثاني: صندوق تذاكر الدعم الفني
  // ==========================================
  Widget _buildTicketsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        // تحديد أهمية التذكرة لونياً
        Color priorityColor = index == 0 ? Colors.red : (index == 1 ? Colors.orange : Colors.green);
        String priorityText = index == 0 ? 'عاجل جداً' : (index == 1 ? 'متوسط' : 'عادي');

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: Border(right: BorderSide(color: priorityColor, width: 5)), // شريط جانبي يوضح الأهمية
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تذكرة #${1000 + index}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(priorityText, style: TextStyle(color: priorityColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('مشكلة في تأكيد حوالة بنكية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('من: شبكة الصقر | قبل ساعتين', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.chat),
                        label: const Text('فتح ورد'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blueAccent,
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // زر الملاحظة الداخلية السرية
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.lock, color: Colors.amber),
                        label: const Text('ملاحظة سرية', style: TextStyle(color: Colors.amber)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

