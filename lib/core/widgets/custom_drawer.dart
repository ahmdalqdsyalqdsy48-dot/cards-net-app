import 'package:flutter/material.dart';
// استدعاء الشاشات التي سننتقل إليها
import '../../features/super_admin/screens/super_admin_dashboard.dart';
import '../../features/super_admin/screens/agent_management_screen.dart';
import '../../features/super_admin/screens/financial_center_screen.dart';
import '../../features/super_admin/screens/subscriptions_screen.dart';
import '../../features/super_admin/screens/staff_support_screen.dart'; // السطر الجديد الخاص بالدعم الفني

class CustomDrawer extends StatelessWidget {
  final String userName;
  final String phoneNumber;
  final String role;
  final String balanceOrPoints;
  final String? profileImageUrl;

  const CustomDrawer({
    super.key,
    required this.userName,
    required this.phoneNumber,
    required this.role,
    required this.balanceOrPoints,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl, // لضمان اتجاه القائمة من اليمين لليسار
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // === 1. بطاقة الملف الشخصي ===
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).primaryColor,
                    backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                    child: profileImageUrl == null 
                        ? const Icon(Icons.person, size: 35, color: Colors.white) 
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$phoneNumber  |  $role',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balanceOrPoints,
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold, 
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),

            // === 2. عناصر القائمة مع الربط الفعلي (Navigation) ===
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // هنا قمنا بتمرير الشاشات التي سينتقل إليها الزر
                  _buildMenuItem(context, icon: Icons.home, title: 'الرئيسية', targetScreen: const SuperAdminDashboard()),
                  _buildMenuItem(context, icon: Icons.group, title: 'إدارة الوكلاء', targetScreen: const AgentManagementScreen()),
                  _buildMenuItem(context, icon: Icons.calendar_month, title: 'إدارة الاشتراكات', targetScreen: const SubscriptionsScreen()),
                  _buildMenuItem(context, icon: Icons.account_balance_wallet, title: 'المركز المالي', targetScreen: const FinancialCenterScreen()),
                  
                  // 👇 هنا تم دمج زر إدارة المدراء والدعم الفني 👇
                  _buildMenuItem(context, icon: Icons.support_agent, title: 'المدراء والدعم الفني', targetScreen: const StaffSupportScreen()),
                  
                  // الأقسام التي لم نبرمجها بعد نترك targetScreen الخاص بها فارغاً
                  _buildMenuItem(context, icon: Icons.settings, title: 'الإعدادات العامة'),
                  
                  const Divider(),
                  
                  // زر تسجيل الخروج
                  _buildMenuItem(
                    context, 
                    icon: Icons.logout, 
                    title: 'تسجيل الخروج',
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    isLogout: true, 
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === دالة مساعدة معدلة لدعم الانتقال بين الشاشات ===
  Widget _buildMenuItem(BuildContext context, {
    required IconData icon, 
    required String title,
    Color? textColor,
    Color? iconColor,
    Widget? targetScreen, // الشاشة الهدف
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Theme.of(context).iconTheme.color),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor ?? Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      onTap: () {
        // إغلاق القائمة الجانبية أولاً
        Navigator.pop(context);
        
        // التحقق من الإجراء المطلوب
        if (isLogout) {
          // العودة للشاشة الأولى (تسجيل الدخول) ومسح كل الشاشات السابقة
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (targetScreen != null) {
          // الانتقال للشاشة المطلوبة
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
          );
        } else {
          // إذا كانت الشاشة غير مبرمجة بعد، نظهر تنبيهاً صغيراً
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('قسم "$title" قيد التطوير...', textDirection: TextDirection.rtl)),
          );
        }
      },
    );
  }
}
