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
            // 1. الهيدر العلوي الجديد (Modern & Compact Profile)
            // تم تغيير الخلفية للون غامق متدرج لإبراز البطاقات وتصغير الهوامش
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, right: 12, left: 12, bottom: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade600],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // مركزة العناصر
                children: [
                  // الصورة الشخصية أصغر قليلاً (Compact)
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(Icons.person, size: 35, color: Colors.white),
                  ),
                  const SizedBox(height: 12), // تقليل المسافة

                  // البطاقة 1: الاسم الرباعي (تصميم أصغر - Slim Card)
                  _buildGradientCard(
                    text: widget.userName,
                    icon: Icons.badge,
                    colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.1)],
                  ),

                  // البطاقتان 2 و 3: رقم الهاتف والدور (بجوار بعضهما - Slim Cards)
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildGradientCard(
                          text: widget.phoneNumber,
                          icon: Icons.phone,
                          colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.1)],
                        ),
                      ),
                      const SizedBox(width: 5), // مسافة ضيقة
                      Expanded(
                        flex: 2,
                        child: _buildGradientCard(
                          text: widget.role,
                          icon: Icons.admin_panel_settings,
                          colors: [Colors.orange.shade800, Colors.orange.shade500],
                        ),
                      ),
                    ],
                  ),

                  // البطاقة 4: الرصيد (زاهية وSlim - مع ميزة النقر)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isBalanceHidden = !_isBalanceHidden;
                      });
                    },
                    child: _buildGradientCard(
                      text: _isBalanceHidden ? '******' : widget.balanceOrPoints,
                      icon: Icons.account_balance_wallet,
                      colors: [Colors.purple.shade800, Colors.purple.shade500],
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
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('المالية والمحاسبة', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'المركز المالي والمحافظ', Icons.account_balance_wallet, Colors.green, const FinancialCenterScreen()),
                  _buildDrawerItem(context, 'الحسابات البنكية', Icons.account_balance, Colors.indigo, const BankAccountsScreen()),
                  _buildDrawerItem(context, 'التقارير الشاملة', Icons.analytics, Colors.orange, const ReportsScreen()),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('الإدارة والتسويق', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'إدارة الموظفين والدعم', Icons.support_agent, Colors.brown, const StaffSupportScreen()),
                  _buildDrawerItem(context, 'الإعلانات والبنرات', Icons.campaign, Colors.deepOrange, const BannersScreen()),
                  _buildDrawerItem(context, 'بوابة رسائل SMS', Icons.sms, Colors.blueAccent, const SmsGatewayScreen()),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('الأمان والنظام', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  
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
              dense: true, // تصغير المساحة
              leading: const Icon(Icons.logout, color: Colors.red, size: 20),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                 Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  // أداة مساعدة لبناء البطاقات المتدرجة الأنيقة والمضغوطة (Slim Gradient Cards)
  Widget _buildGradientCard({required String text, required IconData icon, required List<Color> colors, IconData? trailingIcon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5), // تقليل الهامش السفلي
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), // تقليل الهوامش الداخلية (Slim)
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(8), // حواف حادة قليلاً للأناقة
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) Icon(trailingIcon, color: Colors.white70, size: 16),
        ],
      ),
    );
  }

  // أداة مساعدة لبناء أزرار القائمة السفلية (Compact Drawer Item)
  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, Color iconColor, Widget targetScreen) {
    return ListTile(
      dense: true, // تصغير مساحة العنصر عمودياً
      visualDensity: VisualDensity.compact, // ضغط المساحة
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 11, color: Colors.grey),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }
}
