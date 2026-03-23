import 'package:flutter/material.dart';

// استدعاء جميع الشاشات الـ 12
import '../../features/super_admin/screens/super_admin_dashboard.dart';
import '../../features/super_admin/screens/agent_management_screen.dart';
import '../../features/super_admin/screens/financial_center_screen.dart';
import '../../features/super_admin/screens/subscriptions_screen.dart';
import '../../features/super_admin/screens/staff_support_screen.dart';
import '../../features/super_admin/screens/bank_accounts_screen.dart';
import '../../features/super_admin/screens/reports_screen.dart';
import '../../features/super_admin/screens/settings_screen.dart';
import '../../features/super_admin/screens/audit_log_screen.dart';
import '../../features/super_admin/screens/banners_screen.dart';
import '../../features/super_admin/screens/sms_gateway_screen.dart';
import '../../features/super_admin/screens/backup_screen.dart';

// تم تحويل الكلاس إلى StatefulWidget لدعم ميزة (إخفاء/إظهار) الرصيد عند النقر
class CustomDrawer extends StatefulWidget {
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
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  // متغير للتحكم في حالة الرصيد (مخفي أم ظاهر)
  bool _isBalanceHidden = false;

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // إغلاق الدرج الجانبي
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // 1. الهيدر العلوي الجديد (Modern UI Profile)
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, right: 16, left: 16, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50, // خلفية هادئة لتبرز البطاقات الملونة
                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الصورة الشخصية (جاهزة لاحقاً لإضافة وظيفة النقر للتعديل)
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 15),

                  // البطاقة 1: الاسم الرباعي
                  _buildGradientCard(
                    text: widget.userName,
                    icon: Icons.badge,
                    colors: [Colors.blue.shade700, Colors.blue.shade400],
                  ),

                  // البطاقتان 2 و 3: رقم الهاتف والدور (بجوار بعضهما لتوفير المساحة)
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildGradientCard(
                          text: widget.phoneNumber,
                          icon: Icons.phone,
                          colors: [Colors.teal.shade700, Colors.teal.shade400],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildGradientCard(
                          text: widget.role,
                          icon: Icons.admin_panel_settings,
                          colors: [Colors.orange.shade700, Colors.orange.shade400],
                        ),
                      ),
                    ],
                  ),

                  // البطاقة 4: الرصيد (مع ميزة النقر للإخفاء/الإظهار)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isBalanceHidden = !_isBalanceHidden;
                      });
                    },
                    child: _buildGradientCard(
                      text: _isBalanceHidden ? '******' : widget.balanceOrPoints,
                      icon: Icons.account_balance_wallet,
                      colors: [Colors.purple.shade700, Colors.purple.shade400],
                      trailingIcon: _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // 2. أزرار الانتقال (الروابط للشاشات الـ 12)
            // ==========================================
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(context, 'الرئيسية (غرفة العمليات)', Icons.dashboard, Colors.blue, const SuperAdminDashboard()),
                  _buildDrawerItem(context, 'إدارة الوكلاء', Icons.people_alt, Colors.purple, const AgentManagementScreen()),
                  _buildDrawerItem(context, 'إدارة الاشتراكات', Icons.event_available, Colors.teal, const SubscriptionsScreen()),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('المالية والمحاسبة', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'المركز المالي والمحافظ', Icons.account_balance_wallet, Colors.green, const FinancialCenterScreen()),
                  _buildDrawerItem(context, 'الحسابات البنكية', Icons.account_balance, Colors.indigo, const BankAccountsScreen()),
                  _buildDrawerItem(context, 'التقارير الشاملة', Icons.analytics, Colors.orange, const ReportsScreen()),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('الإدارة والتسويق', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'إدارة الموظفين والدعم', Icons.support_agent, Colors.brown, const StaffSupportScreen()),
                  _buildDrawerItem(context, 'الإعلانات والبنرات', Icons.campaign, Colors.deepOrange, const BannersScreen()),
                  _buildDrawerItem(context, 'بوابة رسائل SMS', Icons.sms, Colors.blueAccent, const SmsGatewayScreen()),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('الأمان والنظام', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'السجل الأسود للنشاط', Icons.security, Colors.red, const AuditLogScreen()),
                  _buildDrawerItem(context, 'الإعدادات العامة', Icons.settings, Colors.blueGrey, const GlobalSettingsScreen()),
                  _buildDrawerItem(context, 'النسخ الاحتياطي', Icons.save, Colors.black87, const BackupScreen()),
                ],
              ),
            ),
            
            // ==========================================
            // 3. الفوتر (تسجيل الخروج)
            // ==========================================
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                 Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // أداة مساعدة لبناء البطاقات المتدرجة الأنيقة (Gradient Cards)
  Widget _buildGradientCard({required String text, required IconData icon, required List<Color> colors, IconData? trailingIcon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) Icon(trailingIcon, color: Colors.white70, size: 18),
        ],
      ),
    );
  }

  // أداة مساعدة لبناء أزرار القائمة السفلية
  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, Color iconColor, Widget targetScreen) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }
}
