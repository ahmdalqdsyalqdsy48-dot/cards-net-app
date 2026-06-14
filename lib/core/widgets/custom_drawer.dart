// lib/core/widgets/custom_drawer.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart'; // للوصول إلى رقم الحساب
import '../providers/ui_provider.dart';

import '../../features/auth/screens/sso_login_screen.dart';
import '../../features/super_admin/screens/super_admin_dashboard.dart';
import '../../features/super_admin/screens/agent_management_screen.dart';
import '../../features/super_admin/screens/financial_center_screen.dart';
import '../../features/super_admin/screens/subscriptions_screen.dart';
import '../../features/super_admin/screens/staff_support_screen.dart';
import '../../features/super_admin/screens/bank_accounts_screen.dart';
import '../../features/super_admin/screens/reports_screen.dart';
import '../../features/super_admin/screens/audit_log_screen.dart';
import '../../features/super_admin/screens/banners_screen.dart';
import '../../features/super_admin/screens/sms_gateway_screen.dart';
import '../../features/super_admin/screens/backup_screen.dart';
import '../../features/super_admin/screens/portals_management_screen.dart';
import '../../features/super_admin/screens/admin_user_accounts_screen.dart';
import '../../features/super_admin/screens/advanced_reset_screen.dart';
import '../../features/super_admin/screens/settings_screen.dart';

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
  bool _isBalanceHidden = true;
  bool _isUploading = false;

  static const Map<String, List<String>> _sectionPermissions = {
    'الرئيسية': ['الرئيسية (غرفة العمليات)'],
    'إدارة الوكلاء': ['إدارة الوكلاء الشاملة', 'عرض الوكلاء', 'إضافة وكيل', 'تعديل وكيل', 'حذف وكيل', 'تجميد/تنشيط وكيل'],
    'الاشتراكات': ['إدارة الاشتراكات والباقات', 'عرض الاشتراكات', 'تعديل الاشتراكات'],
    'المركز المالي': ['المركز المالي والمحافظ', 'عرض الأرصدة', 'تسوية رصيد', 'عرض المعاملات'],
    'الحسابات البنكية': ['الحسابات البنكية', 'عرض الحسابات', 'إضافة حساب', 'تعديل حساب', 'حذف حساب'],
    'الحسابات والحظر': ['إدارة أرقام الحسابات والحظر', 'عرض الحسابات', 'تعديل رقم حساب', 'حظر/فك حظر', 'إعادة تعيين PIN'],
    'التقارير الشاملة': ['التقارير الشاملة', 'عرض التقارير'],
    'الموظفين والدعم': ['إدارة الموظفين والدعم', 'عرض الموظفين', 'إضافة موظف', 'تعديل موظف', 'حذف موظف', 'تجميد/تنشيط موظف', 'عرض الرواتب', 'تعديل الرواتب', 'تسليم راتب', 'عرض التذاكر', 'الرد على التذاكر', 'إحالة التذاكر', 'إغلاق التذاكر'],
    'الإعلانات والبنرات': ['الإعلانات التسويقية', 'عرض الإعلانات', 'إضافة إعلان', 'تعديل إعلان', 'حذف إعلان'],
    'الرسائل SMS': ['بوابة رسائل الـ SMS', 'عرض SMS', 'إرسال SMS'],
    'بوابات النظام': ['إدارة بوابات النظام', 'عرض البوابات', 'تعديل البوابات'],
    'سجل النشاط': ['السجل الأسود للنشاط (للقراءة)', 'عرض السجل'],
    'التحكم الشامل': ['التحكم الشامل (إعادة التهيئة)'],
    'النسخ الاحتياطي': ['النسخ الاحتياطي', 'عرض النسخ', 'أخذ نسخة', 'حذف نسخة'],
  };

  bool _canAccessSection(String sectionName) {
    final auth = context.read<AuthProvider>();
    if (auth.currentUserRole == 'super_admin') return true;
    final permissions = _sectionPermissions[sectionName];
    if (permissions == null) return false;
    for (var perm in permissions) {
      if (auth.hasPermission(perm)) return true;
    }
    return false;
  }

  void _playSound() {
    Provider.of<UiProvider>(context, listen: false).playSound('click');
  }

  void _navigateTo(BuildContext context, Widget screen) {
    _playSound();
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _showSnackBar(String message,
      {Color bgColor = Colors.orange, IconData icon = Icons.handyman}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(message,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    _playSound();
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 400, imageQuality: 40);
      if (pickedFile == null) return;
      setState(() => _isUploading = true);
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showSnackBar('جاري حفظ الصورة... ⏳',
          bgColor: Colors.orange.shade700, icon: Icons.cloud_upload);

      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.phoneNumber)
          .set({
        'profileImageBase64': base64Image,
      }, SetOptions(merge: true));

      setState(() => _isUploading = false);
      _playSound();
      _showSnackBar('تم تغيير الصورة الشخصية بنجاح! ✅',
          bgColor: Colors.green.shade700, icon: Icons.check_circle);
    } catch (e) {
      setState(() => _isUploading = false);
      _showSnackBar('فشل تحديث الصورة: $e',
          bgColor: Colors.red.shade700, icon: Icons.error);
    }
  }

  Future<void> _deleteProfileImage() async {
    _playSound();
    try {
      setState(() => _isUploading = true);
      if (Navigator.canPop(context)) Navigator.pop(context);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.phoneNumber)
          .update({
        'profileImageBase64': FieldValue.delete(),
      });
      setState(() => _isUploading = false);
      _playSound();
      _showSnackBar('تم حذف الصورة بنجاح.',
          bgColor: Colors.blueGrey, icon: Icons.delete);
    } catch (e) {
      setState(() => _isUploading = false);
    }
  }

  void _showProfileImageActionDialog(String? currentBase64) {
    _playSound();
    bool hasImage = currentBase64 != null && currentBase64.isNotEmpty;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('إدارة الصورة الشخصية',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  border:
                      Border.all(color: Colors.blue.shade100, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10)
                  ],
                  image: hasImage
                      ? DecorationImage(
                          image: MemoryImage(base64Decode(currentBase64)),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: !hasImage
                    ? const Icon(Icons.person,
                        size: 80, color: Colors.blueGrey)
                    : null,
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAndUploadImage,
                    icon: Icon(
                        hasImage
                            ? Icons.sync
                            : Icons.add_photo_alternate,
                        color: Colors.white,
                        size: 16),
                    label: Text(
                        hasImage ? 'تغيير' : 'إضافة',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600),
                  ),
                  if (hasImage)
                    ElevatedButton.icon(
                      onPressed: _deleteProfileImage,
                      icon: const Icon(Icons.delete_forever,
                          color: Colors.white, size: 16),
                      label: const Text('حذف',
                          style: TextStyle(
                              color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _generateGradientColors(Color baseColor) {
    final hsv = HSVColor.fromColor(baseColor);
    final darker =
        hsv.withValue((hsv.value - 0.2).clamp(0.0, 1.0)).toColor();
    final lighter =
        hsv.withValue((hsv.value + 0.1).clamp(0.0, 1.0)).toColor();
    return [darker, lighter];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = themeProvider.isDarkMode;
    final Color primaryColor = themeProvider.primaryColor;

    final Color onSurfaceColor = colors.onSurface;
    final Color onSurfaceVariant = colors.onSurfaceVariant;
    final Color surfaceColor = colors.surface;

    // 🆕 الحصول على رقم الحساب
    final walletProvider = context.watch<WalletProvider>();
    final String accountNumber = walletProvider.currentUserAccountNumber ?? 'غير متوفر';

    final nameColors = _generateGradientColors(primaryColor);
    final accountColors = _generateGradientColors(primaryColor);
    final phoneColors = _generateGradientColors(primaryColor);
    final roleColors = _generateGradientColors(primaryColor);
    final balanceColors = _generateGradientColors(primaryColor);

    return Drawer(
      backgroundColor: surfaceColor,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  SafeArea(
                    bottom: false,
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.phoneNumber)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String? base64Image;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data()
                              as Map<String, dynamic>?;
                          if (data != null &&
                              data.containsKey('profileImageBase64')) {
                            base64Image = data['profileImageBase64'];
                          }
                        }
                        bool hasImage = base64Image != null &&
                            base64Image.isNotEmpty;

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          color: Colors.transparent,
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    _showProfileImageActionDialog(
                                        base64Image),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryColor.withOpacity(0.1),
                                        border: Border.all(
                                            color: primaryColor
                                                .withOpacity(0.3),
                                            width: 2),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 8,
                                              offset: Offset(0, 3))
                                        ],
                                        image: hasImage
                                            ? DecorationImage(
                                                image: MemoryImage(
                                                    base64Decode(
                                                        base64Image!)),
                                                fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: !hasImage
                                          ? Icon(Icons.person,
                                              size: 60,
                                              color: primaryColor
                                                  .withOpacity(0.7))
                                          : null,
                                    ),
                                    if (_isUploading)
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black
                                                .withOpacity(0.5)),
                                        child:
                                            const CircularProgressIndicator(
                                                color: Colors.white),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              _buildGradientCard(
                                  text: widget.userName,
                                  icon: Icons.badge,
                                  colors: nameColors),
                              // 🆕 بطاقة رقم الحساب بين الاسم والهاتف
                              _buildGradientCard(
                                  text: 'الحساب: $accountNumber',
                                  icon: Icons.credit_card,
                                  colors: accountColors),
                              _buildGradientCard(
                                  text: widget.phoneNumber,
                                  icon: Icons.phone,
                                  colors: phoneColors),
                              _buildGradientCard(
                                  text: widget.role,
                                  icon: Icons.admin_panel_settings,
                                  colors: roleColors),
                              GestureDetector(
                                onTap: () {
                                  _playSound();
                                  setState(() => _isBalanceHidden =
                                      !_isBalanceHidden);
                                },
                                child: _buildGradientCard(
                                  text: _isBalanceHidden
                                      ? '******'
                                      : widget.balanceOrPoints,
                                  icon: Icons.account_balance_wallet,
                                  colors: balanceColors,
                                  trailingIcon: _isBalanceHidden
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Divider(
                                  height: 1,
                                  color: colors.outlineVariant),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // 🆕 المجموعة الأولى: الأساسية
                  if (_canAccessSection('الرئيسية'))
                    _buildDrawerItem(
                        context,
                        'الرئيسية',
                        Icons.dashboard,
                        Colors.blue,
                        const SuperAdminDashboard()),
                  if (_canAccessSection('إدارة الوكلاء'))
                    _buildDrawerItem(
                        context,
                        'إدارة الوكلاء',
                        Icons.people_alt,
                        Colors.purple,
                        const AgentManagementScreen()),
                  if (_canAccessSection('الاشتراكات'))
                    _buildDrawerItem(
                        context,
                        'الاشتراكات',
                        Icons.event_available,
                        Colors.teal,
                        const SubscriptionsScreen()),

                  // المجموعة الثانية: المالية
                  Divider(color: colors.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Text('المالية',
                        style: TextStyle(
                            color: onSurfaceColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (_canAccessSection('المركز المالي'))
                    _buildDrawerItem(
                        context,
                        'المركز المالي',
                        Icons.account_balance_wallet,
                        Colors.green,
                        const FinancialCenterScreen()),
                  if (_canAccessSection('الحسابات البنكية'))
                    _buildDrawerItem(
                        context,
                        'الحسابات البنكية',
                        Icons.account_balance,
                        Colors.indigo,
                        const BankAccountsScreen()),
                  if (_canAccessSection('الحسابات والحظر'))
                    _buildDrawerItem(
                        context,
                        'الحسابات والحظر',
                        Icons.credit_card,
                        Colors.blueGrey,
                        const AdminUserAccountsScreen()),
                  if (_canAccessSection('التقارير الشاملة'))
                    _buildDrawerItem(
                        context,
                        'التقارير الشاملة',
                        Icons.analytics,
                        Colors.orange,
                        const ReportsScreen()),

                  // المجموعة الثالثة: الإدارة
                  Divider(color: colors.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Text('الإدارة',
                        style: TextStyle(
                            color: onSurfaceColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (_canAccessSection('الموظفين والدعم'))
                    _buildDrawerItem(
                        context,
                        'الموظفين والدعم',
                        Icons.support_agent,
                        Colors.brown,
                        const StaffSupportScreen()),
                  if (_canAccessSection('الإعلانات والبنرات'))
                    _buildDrawerItem(
                        context,
                        'الإعلانات والبنرات',
                        Icons.campaign,
                        Colors.deepOrange,
                        const BannersScreen()),
                  if (_canAccessSection('الرسائل SMS'))
                    _buildDrawerItem(
                        context,
                        'الرسائل SMS',
                        Icons.sms,
                        Colors.blueAccent,
                        const SmsGatewayScreen()),
                  if (_canAccessSection('بوابات النظام'))
                    _buildDrawerItem(
                        context,
                        'بوابات النظام',
                        Icons.important_devices,
                        Colors.deepPurple,
                        const PortalsManagementScreen()),

                  // المجموعة الرابعة: الأمان
                  Divider(color: colors.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Text('الأمان',
                        style: TextStyle(
                            color: onSurfaceColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (_canAccessSection('سجل النشاط'))
                    _buildDrawerItem(
                        context,
                        'سجل النشاط',
                        Icons.security,
                        Colors.red,
                        const AuditLogScreen()),
                  if (_canAccessSection('التحكم الشامل'))
                    _buildDrawerItem(
                        context,
                        'التحكم الشامل',
                        Icons.cleaning_services,
                        Colors.red,
                        const AdvancedResetScreen()),
                  if (_canAccessSection('النسخ الاحتياطي'))
                    _buildDrawerItem(
                        context,
                        'النسخ الاحتياطي',
                        Icons.save,
                        Colors.black87,
                        const BackupScreen()),
                ],
              ),
            ),
            // 🆕 الإعدادات + تسجيل الخروج في الأسفل
            Divider(height: 1, color: colors.outlineVariant),
            ListTile(
              dense: true,
              leading:
                  const Icon(Icons.settings, color: Colors.blueGrey, size: 20),
              title: Text('الإعدادات',
                  style: TextStyle(
                      color: onSurfaceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 11, color: onSurfaceColor.withOpacity(0.5)),
              onTap: () => _navigateTo(context, const GlobalSettingsScreen()),
            ),
            ListTile(
              dense: true,
              leading:
                  const Icon(Icons.logout, color: Colors.red, size: 20),
              title: Text('تسجيل الخروج',
                  style: TextStyle(
                      color: onSurfaceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              onTap: () {
                _playSound();
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SSOLoginScreen()),
                    (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon,
      Color iconColor, Widget targetScreen) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final boxColor = themeProvider.isDarkMode
        ? colors.onPrimaryContainer.withOpacity(0.15)
        : colors.primaryContainer.withOpacity(0.3);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: colors.onSurface)),
      trailing: Icon(Icons.arrow_forward_ios,
          size: 11, color: colors.onSurface.withOpacity(0.5)),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }

  Widget _buildGradientCard(
      {required String text,
      required IconData icon,
      required List<Color> colors,
      IconData? trailingIcon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis)),
          if (trailingIcon != null)
            Icon(trailingIcon, color: Colors.white70, size: 17),
        ],
      ),
    );
  }
}
