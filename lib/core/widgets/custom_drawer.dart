import 'package:flutter/material.dart';
import '../../features/super_admin/screens/super_admin_dashboard.dart';
import '../../features/super_admin/screens/agent_management_screen.dart';
import '../../features/super_admin/screens/financial_center_screen.dart';
import '../../features/super_admin/screens/subscriptions_screen.dart';
import '../../features/super_admin/screens/staff_support_screen.dart';
import '../../features/super_admin/screens/bank_accounts_screen.dart';
import '../../features/super_admin/screens/reports_screen.dart'; // السطر الجديد

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
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 30, backgroundColor: Theme.of(context).primaryColor, child: const Icon(Icons.person, size: 35, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('$phoneNumber  |  $role', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(balanceOrPoints, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(context, icon: Icons.home, title: 'الرئيسية', targetScreen: const SuperAdminDashboard()),
                  _buildMenuItem(context, icon: Icons.group, title: 'إدارة الوكلاء', targetScreen: const AgentManagementScreen()),
                  _buildMenuItem(context, icon: Icons.calendar_month, title: 'إدارة الاشتراكات', targetScreen: const SubscriptionsScreen()),
                  _buildMenuItem(context, icon: Icons.account_balance_wallet, title: 'المركز المالي', targetScreen: const FinancialCenterScreen()),
                  _buildMenuItem(context, icon: Icons.support_agent, title: 'المدراء والدعم الفني', targetScreen: const StaffSupportScreen()),
                  _buildMenuItem(context, icon: Icons.account_balance, title: 'الحسابات البنكية', targetScreen: const BankAccountsScreen()),
                  
                  // 👇 زر التقارير الشاملة 👇
                  _buildMenuItem(context, icon: Icons.bar_chart, title: 'التقارير الشاملة', targetScreen: const ReportsScreen()),
                  
                  _buildMenuItem(context, icon: Icons.settings, title: 'الإعدادات العامة'),
                  const Divider(),
                  _buildMenuItem(context, icon: Icons.logout, title: 'تسجيل الخروج', textColor: Colors.red, iconColor: Colors.red, isLogout: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, Color? textColor, Color? iconColor, Widget? targetScreen, bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Theme.of(context).iconTheme.color),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor ?? Theme.of(context).textTheme.bodyLarge?.color)),
      onTap: () {
        Navigator.pop(context);
        if (isLogout) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (targetScreen != null) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => targetScreen));
        }
      },
    );
  }
}
