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
  // profileImageUrl ستكون متغيرة (Stateful) لمحاكاة الحذف والإضافة
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
  // متغيرات محلية لمحاكاة الحالة (Dummy State)
  bool _isBalanceHidden = false;
  String? _currentLocalImageUrl; // لمحاكاة تغيير الصورة محلياً

  @override
  void initState() {
    super.initState();
    // تعيين الصورة القادمة من الخارج كصورة أولية
    _currentLocalImageUrl = widget.profileImageUrl;
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // إغلاق الدرج الجانبي
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // دالة مساعدة لإظهار رسائل الشفافية البرمجية
  void _showCandorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.handyman, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.black87))),
          ],
        ),
        backgroundColor: Colors.amber.shade100,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ==========================================
  // نافذة إدارة الصورة الشخصية (Add/Change/Delete Dummy logic)
  // ==========================================
  void _showProfileImageActionDialog(BuildContext context) {
    bool hasImage = _currentLocalImageUrl != null;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إدارة الصورة الشخصية', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // عرض الصورة بحجم كبير جداً داخل النافذة
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.blue.shade100, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  // تم حل الخطأ هنا (استخدام image بدلاً من backgroundImage)
                  image: hasImage 
                      ? DecorationImage(image: NetworkImage(_currentLocalImageUrl!), fit: BoxFit.cover) 
                      : null,
                ),
                child: !hasImage ? const Icon(Icons.person, size: 100, color: Colors.blueGrey) : null,
              ),
              const SizedBox(height: 25),
              
              const Text('💡 هذه الوظيفة تتطلب ربطاً حقيقياً بالسيرفر وصلاحيات الهاتف. حالياً نقوم بمحاكاة التصميم فقط.', style: TextStyle(fontSize: 12, color: Colors.orange)),
              const SizedBox(height: 15),

              // زري الإضافة/التغيير والحذف
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCandorSnackBar(context, 'سيتم ربط (image_picker) لفتح معرض الهاتف في النسخة القادمة.');
                    },
                    icon: Icon(hasImage ? Icons.sync : Icons.add_photo_alternate, color: Colors.white, size: 18),
                    label: Text(hasImage ? 'تغيير' : 'إضافة صورة', style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                  ),
                  if (hasImage) // يظهر الحذف فقط إذا كانت هناك صورة
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentLocalImageUrl = null; // محاكاة الحذف محلياً
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الصورة (محلياً) بنجاح.'), backgroundColor: Colors.red));
                      },
                      icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
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
    bool hasImage = _currentLocalImageUrl != null;

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // القائمة الجانبية (كل المحتوى متحرك داخل ListView)
            // ==========================================
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 1. الهيدر العلوي (أصبح متحركاً داخل الـ ListView)
                  SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      color: Colors.transparent, // يدعم لون النظام (الوضع الليلي)
                      child: Column(
                        children: [
                          // الصورة الشخصية (تم تكبيرها بشكل فخم وقابلة للنقر)
                          GestureDetector(
                            onTap: () => _showProfileImageActionDialog(context),
                            child: Container(
                              width: 100, // تكبير الحجم الكلي للحاوية
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withOpacity(0.1),
                                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                                // تم حل الخطأ هنا أيضاً
                                image: hasImage 
                                    ? DecorationImage(image: NetworkImage(_currentLocalImageUrl!), fit: BoxFit.cover) 
                                    : null,
                              ),
                              child: !hasImage ? Icon(Icons.person, size: 60, color: Theme.of(context).primaryColor.withOpacity(0.7)) : null,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // البطاقة 1: الاسم الرباعي (تصميم محسّن زاهي)
                          _buildGradientCard(
                            text: widget.userName,
                            icon: Icons.badge,
                            colors: [Colors.blue.shade800, Colors.blue.shade500],
                          ),

                          // البطاقة 2: رقم الهاتف
                          _buildGradientCard(
                            text: widget.phoneNumber,
                            icon: Icons.phone,
                            colors: [Colors.teal.shade800, Colors.teal.shade500],
                          ),

                          // البطاقة 3: الدور
                          _buildGradientCard(
                            text: widget.role,
                            icon: Icons.admin_panel_settings,
                            colors: [Colors.orange.shade800, Colors.orange.shade500],
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
                              colors: [Colors.purple.shade800, Colors.purple.shade500],
                              trailingIcon: _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                        ],
                      ),
                    ),
                  ),

                  // 2. أزرار الانتقال (الروابط للشاشات الـ 12)
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
            // 3. الفوتر (تسجيل الخروج - يبقى ثابتاً في الأسفل)
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

  // أداة مساعدة لبناء البطاقات المتدرجة الأنيقة الفخمة (Premium Gradient Cards)
  Widget _buildGradientCard({required String text, required IconData icon, required List<Color> colors, IconData? trailingIcon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), 
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topRight, 
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(10), 
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))], 
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) Icon(trailingIcon, color: Colors.white70, size: 17),
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
