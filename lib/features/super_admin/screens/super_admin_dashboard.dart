import 'dart:async';
import 'package:flutter/material.dart';
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
  // === المتغيرات للتحكم بالمنطق البرمجي ===
  bool _showPopup = false;
  Timer? _popupTimer;

  // قاعدة بيانات وهمية مصغرة لسجل التنبيهات
  final List<Map<String, dynamic>> _notifications = [
    {'id': 1, 'title': 'تحذير رصيد', 'text': 'محفظة "شبكة الصقر" فارغة تقريباً!', 'time': 'الآن'},
    {'id': 2, 'title': 'تجميد آلي', 'text': 'تم تجميد وكيل "العالمية" لتجاوز الحد المسموح.', 'time': 'قبل 10 دقائق'},
    {'id': 3, 'title': 'طلب شحن', 'text': 'طلب شحن جديد من "وكالة النور" بمبلغ 50,000.', 'time': 'قبل ساعة'},
  ];

  // دالة إظهار النافذة المنبثقة وتشغيل عداد الـ 5 ثوانٍ
  void _triggerNotificationPopup() {
    setState(() {
      _showPopup = true;
    });

    _popupTimer?.cancel();

    _popupTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showPopup) {
        setState(() {
          _showPopup = false;
        });
      }
    });
  }

  // دالة الإغلاق اليدوي للنافذة
  void _closePopup() {
    _popupTimer?.cancel();
    setState(() {
      _showPopup = false;
    });
  }

  // دالة الحذف النهائي من سجل التنبيهات الجانبي
  void _deleteNotification(int index) {
    setState(() {
      _notifications.removeAt(index);
    });
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.blueAccent),
        centerTitle: true,
        // قمنا بإزالة كلمة const من هنا لحل المشكلة
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: CircleAvatar(radius: 4, backgroundColor: Colors.green),
            ),
            Text('الرئيسية - غرفة العمليات', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_active, color: Colors.blueAccent),
                  onPressed: _triggerNotificationPopup,
                ),
                if (_notifications.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                    ),
                  ),
              ],
            ),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.history, color: Colors.grey),
              tooltip: 'سجل التنبيهات الجانبي',
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),

      endDrawer: Drawer(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.blueAccent,
                child: const SafeArea(
                  bottom: false,
                  child: Text('سجل التنبيهات 🔔', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: _notifications.isEmpty
                    ? const Center(child: Text('لا توجد تنبيهات سابقة.'))
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final note = _notifications[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                              title: Text(note['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${note['text']}\n${note['time']}', style: const TextStyle(fontSize: 12)),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'حذف التنبيه نهائياً',
                                onPressed: () => _deleteNotification(index),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),

      body: Stack(
        children: [
          SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.date_range, size: 18),
                          label: const Text('فلترة التاريخ 📅'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.1), foregroundColor: Colors.blue, elevation: 0),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('تصدير الملخص 🖨️'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1), foregroundColor: Colors.green, elevation: 0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

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
                          title: 'الإعدادات العامة',
                          value: 'إدارة الهوية',
                          icon: Icons.settings,
                          color: Colors.blueGrey,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_showPopup)
            Positioned(
              top: 15,
              left: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                    border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // قمنا بإزالة كلمة const من هنا أيضاً
                        Row(
                          children: const [
                            Icon(Icons.notifications_active, color: Colors.red),
                            SizedBox(width: 8),
                            Text('تنبيهات النظام العاجلة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
                          ],
                        ),
                        const Divider(),
                        if (_notifications.isNotEmpty)
                          Text(_notifications.first['text'], style: const TextStyle(fontSize: 14))
                        else
                          const Text('لا توجد تنبيهات جديدة حالياً.'),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _closePopup,
                              child: const Text('إغلاق الآن', style: TextStyle(color: Colors.grey)),
                            ),
                          ],
                        ),
                        LinearProgressIndicator(backgroundColor: Colors.grey.shade200, color: Colors.red, value: null),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

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
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color), textAlign: TextAlign.center, textDirection: TextDirection.ltr),
          ],
        ),
      ),
    );
  }
}
