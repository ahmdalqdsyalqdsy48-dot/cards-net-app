import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // 👈 استدعاء مكتبة دائرة الألوان

// 👈 استدعاء العقل المدبر للألوان
import '../providers/theme_provider.dart';

import '../../features/auth/screens/sso_login_screen.dart';

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
  bool _isBalanceHidden = false;
  String? _currentLocalImageUrl;

  @override
  void initState() {
    super.initState();
    _currentLocalImageUrl = widget.profileImageUrl;
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

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
  // 🎨 نافذة دائرة الألوان المتقدمة
  // ==========================================
  void _showColorPickerDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Color pickerColor = themeProvider.primaryColor;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تخصيص مظهر التطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false, // لا نريد ألوان شفافة للخلفية
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithHue,
              labelTypes: const [], 
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                // 👈 الحفظ في العقل المدبر وذاكرة الهاتف
                themeProvider.changeColor(pickerColor);
                Navigator.pop(context);
              },
              child: const Text('اعتماد اللون', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

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
              Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.grey.shade100, border: Border.all(color: Colors.blue.shade100, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  image: hasImage ? DecorationImage(image: NetworkImage(_currentLocalImageUrl!), fit: BoxFit.cover) : null,
                ),
                child: !hasImage ? const Icon(Icons.person, size: 100, color: Colors.blueGrey) : null,
              ),
              const SizedBox(height: 25),
              const Text('💡 هذه الوظيفة تتطلب ربطاً حقيقياً بالسيرفر وصلاحيات الهاتف. حالياً نقوم بمحاكاة التصميم فقط.', style: TextStyle(fontSize: 12, color: Colors.orange)),
              const SizedBox(height: 15),
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
                  if (hasImage) 
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() { _currentLocalImageUrl = null; });
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
    final themeProvider = Provider.of<ThemeProvider>(context); // 👈 للوصول إلى ألوان النظام الذكية

    return Drawer(
      // 👈 لجعل الدرج متوافقاً مع لون الواجهة
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      color: Colors.transparent,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showProfileImageActionDialog(context),
                            child: Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, color: themeProvider.primaryColor.withOpacity(0.1),
                                border: Border.all(color: themeProvider.primaryColor.withOpacity(0.3), width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                                image: hasImage ? DecorationImage(image: NetworkImage(_currentLocalImageUrl!), fit: BoxFit.cover) : null,
                              ),
                              child: !hasImage ? Icon(Icons.person, size: 60, color: themeProvider.primaryColor.withOpacity(0.7)) : null,
                            ),
                          ),
                          const SizedBox(height: 15),
                          _buildGradientCard(text: widget.userName, icon: Icons.badge, colors: [themeProvider.primaryColor, themeProvider.primaryColor.withOpacity(0.7)]),
                          _buildGradientCard(text: widget.phoneNumber, icon: Icons.phone, colors: [themeProvider.primaryColor.withOpacity(0.9), themeProvider.primaryColor.withOpacity(0.6)]),
                          _buildGradientCard(text: widget.role, icon: Icons.admin_panel_settings, colors: [themeProvider.primaryColor.withOpacity(0.8), themeProvider.primaryColor.withOpacity(0.5)]),
                          GestureDetector(
                            onTap: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
                            child: _buildGradientCard(
                              text: _isBalanceHidden ? '******' : widget.balanceOrPoints,
                              icon: Icons.account_balance_wallet,
                              colors: [themeProvider.primaryColor.withOpacity(0.7), themeProvider.primaryColor.withOpacity(0.4)],
                              trailingIcon: _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(height: 1, color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
                        ],
                      ),
                    ),
                  ),
                  _buildDrawerItem(context, 'الرئيسية (غرفة العمليات)', Icons.dashboard, const SuperAdminDashboard()),
                  _buildDrawerItem(context, 'إدارة الوكلاء', Icons.people_alt, const AgentManagementScreen()),
                  _buildDrawerItem(context, 'إدارة الاشتراكات', Icons.event_available, const SubscriptionsScreen()),
                  
                  Divider(color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('المالية والمحاسبة', style: TextStyle(color: themeProvider.adaptiveTextColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'المركز المالي والمحافظ', Icons.account_balance_wallet, const FinancialCenterScreen()),
                  _buildDrawerItem(context, 'الحسابات البنكية', Icons.account_balance, const BankAccountsScreen()),
                  _buildDrawerItem(context, 'التقارير الشاملة', Icons.analytics, const ReportsScreen()),
                  
                  Divider(color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('الإدارة والتسويق', style: TextStyle(color: themeProvider.adaptiveTextColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'إدارة الموظفين والدعم', Icons.support_agent, const StaffSupportScreen()),
                  _buildDrawerItem(context, 'الإعلانات والبنرات', Icons.campaign, const BannersScreen()),
                  _buildDrawerItem(context, 'بوابة رسائل SMS', Icons.sms, const SmsGatewayScreen()),
                  
                  Divider(color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('الأمان والنظام', style: TextStyle(color: themeProvider.adaptiveTextColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold))),
                  
                  _buildDrawerItem(context, 'السجل الأسود للنشاط', Icons.security, const AuditLogScreen()),
                  _buildDrawerItem(context, 'الإعدادات العامة', Icons.settings, const GlobalSettingsScreen()),
                  _buildDrawerItem(context, 'النسخ الاحتياطي', Icons.save, const BackupScreen()),

                  // 👈 زر تخصيص المظهر الجديد (Color Picker)
                  ListTile(
                    dense: true, visualDensity: VisualDensity.compact,
                    leading: Icon(Icons.palette, color: themeProvider.adaptiveTextColor, size: 20),
                    title: Text('تخصيص المظهر والألوان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeProvider.adaptiveTextColor)),
                    onTap: () {
                      Navigator.pop(context); // إغلاق الدرج أولاً
                      _showColorPickerDialog(context); // فتح دائرة الألوان
                    },
                  ),
                ],
              ),
            ),
            
            Divider(height: 1, color: themeProvider.adaptiveTextColor.withOpacity(0.2)),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, color: Colors.red, size: 20),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                 Navigator.pop(context);
                 Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SSOLoginScreen()), (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 👈 قمت بتعديل أيقونات وألوان العناصر لتأخذ لون الواجهة الذكي بدلاً من الألوان الثابتة القديمة
  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, Widget targetScreen) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return ListTile(
      dense: true, visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: themeProvider.adaptiveTextColor.withOpacity(0.8), size: 20),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeProvider.adaptiveTextColor)),
      trailing: Icon(Icons.arrow_forward_ios, size: 11, color: themeProvider.adaptiveTextColor.withOpacity(0.5)),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }

  Widget _buildGradientCard({required String text, required IconData icon, required List<Color> colors, IconData? trailingIcon}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 8), 
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(10), 
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))], 
      ),
      child: Row(
        children: [
          Icon(icon, color: themeProvider.adaptiveTextColor, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: themeProvider.adaptiveTextColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
          if (trailingIcon != null) Icon(trailingIcon, color: themeProvider.adaptiveTextColor.withOpacity(0.7), size: 17),
        ],
      ),
    );
  }
}
