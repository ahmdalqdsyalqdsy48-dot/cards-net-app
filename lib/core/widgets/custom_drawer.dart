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

  // نافذة تكبير وتعديل الصورة الشخصية
  void _showProfileImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('الصورة الشخصية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: widget.profileImageUrl != null ? NetworkImage(widget.profileImageUrl!) : null,
                  child: widget.profileImageUrl == null ? const Icon(Icons.person, size: 70, color: Colors.blueAccent) : null,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم فتح المعرض لاختيار صورة...')));
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text('تعديل', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الصورة بنجاح.'), backgroundColor: Colors.red));
                    },
                    icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                    label: const Text('حذف', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
            // 1. الهيدر العلوي (ديناميكي اللون ومتناسق مع الوضع الليلي)
            // ==========================================
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.transparent, // يأخذ لون النظام (يدعم الوضع الليلي)
                child: Column(
                  children: [
                    // الصورة الشخصية (قابلة للنقر)
                    GestureDetector(
                      onTap: () => _showProfileImageDialog(context),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            backgroundImage: widget.profileImageUrl != null ? NetworkImage(widget.profileImageUrl!) : null,
                            child: widget.profileImageUrl == null ? Icon(Icons.person, size: 40, color: Theme.of(context).primaryColor) : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // البطاقة 1: الاسم الرباعي
                    _buildGradientCard(
                      text: widget.userName,
                      icon: Icons.badge,
                      colors: [Colors.blue.shade700, Colors.blue.shade400],
                    ),

                    // البطاقة 2: رقم الهاتف
                    _buildGradientCard(
                      text: widget.phoneNumber,
                      icon: Icons.phone,
                      colors: [Colors.teal.shade700, Colors.teal.shade400],
                    ),

                    // البطاقة 3: الدور (تأخذ عرضاً كاملاً لتجنب القص)
                    _buildGradientCard(
                      text: widget.role,
                      icon: Icons.admin_panel_settings,
                      colors: [Colors.orange.shade700, Colors.orange.shade400],
                    ),

                    // البطاقة 4: الرصيد (زاهية مع ميزة النقر)
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
            ),
            
            Divider(color: Colors.grey.withOpacity(0.3), height: 1),

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
              dense: true,
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
      margin: const EdgeInsets.only(bottom: 6), // مسافة صغيرة جداً بين البطاقات
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) Icon(trailingIcon, color: Colors.white70, size: 16),
        ],
      ),
    );
  }

  // أداة مساعدة لبناء أزرار القائمة السفلية
  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, Color iconColor, Widget targetScreen) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 11, color: Colors.grey),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }
}
