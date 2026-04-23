import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../auth/screens/sso_login_screen.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _appSounds = true;
  double _dailyLimit = 0.0;
  String _userPin = '';
  bool _notificationsEnabled = true;
  bool _marketingNotifications = true;
  bool _transactionNotifications = true;
  bool _hideBalanceFromOthers = false;
  bool _showFullName = true;
  String _selectedLanguage = 'ar';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appSounds = prefs.getBool('user_app_sounds') ?? true;
      _dailyLimit = prefs.getDouble('user_daily_limit') ?? 0.0;
      _userPin = prefs.getString('user_pin') ?? '';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _marketingNotifications = prefs.getBool('marketing_notifications') ?? true;
      _transactionNotifications = prefs.getBool('transaction_notifications') ?? true;
      _hideBalanceFromOthers = prefs.getBool('hide_balance') ?? false;
      _showFullName = prefs.getBool('show_full_name') ?? true;
      _selectedLanguage = prefs.getString('language') ?? 'ar';
    });
  }

  void _playFeedback() {
    if (!_appSounds) return;
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    uiProvider.playSound('click');
    if (!kIsWeb) HapticFeedback.lightImpact();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getTextColor(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final uiProvider = Provider.of<UiProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final userName = systemProvider.currentUserName;
    final userPhone = systemProvider.currentUserPhone;
    final textColor = _getTextColor(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomHeader(title: 'الإعدادات'),
      drawer: CustomUserDrawer(userName: userName, phoneNumber: userPhone),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                tabs: const [
                  Tab(text: 'الأمان'),
                  Tab(text: 'المظهر'),
                  Tab(text: 'الحساب'),
                  Tab(text: 'الإشعارات'),
                  Tab(text: 'الخصوصية'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSecurityTab(systemProvider, primaryColor, isDark, textColor),
                  _buildAppearanceTab(themeProvider, uiProvider, primaryColor, isDark, textColor),
                  _buildAccountTab(systemProvider, primaryColor, isDark, textColor),
                  _buildNotificationsTab(primaryColor, isDark, textColor),
                  _buildPrivacyTab(systemProvider, primaryColor, isDark, textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- تبويب الأمان ----------
  Widget _buildSecurityTab(SystemProvider sys, Color primaryColor, bool isDark, Color textColor) {
    final useBiometrics = sys.isBiometricCurrentlyEnabled;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('معلومات الدخول', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildListTile(
                Icons.lock_outline,
                'رمز PIN',
                _userPin.isNotEmpty ? 'تم تعيين رمز PIN مكون من 6 أرقام' : 'لم يتم تعيين رمز PIN بعد',
                primaryColor,
                textColor,
                onTap: () => _showPinDialog(sys),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fingerprint, color: primaryColor, size: 20),
                ),
                title: Text('الدخول بالبصمة', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                subtitle: Text(kIsWeb ? 'غير مدعوم على الويب' : 'بصمة الإصبع أو الوجه',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                value: useBiometrics && !kIsWeb,
                activeColor: primaryColor,
                onChanged: (val) {
                  _playFeedback();
                  if (kIsWeb) {
                    _showToast('البصمة مدعومة فقط على الهواتف');
                    return;
                  }
                  sys.toggleBiometric(val);
                  _showToast(val ? 'تم تفعيل الدخول بالبصمة' : 'تم إيقاف الدخول بالبصمة');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('تغيير كلمة المرور', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_reset, color: primaryColor, size: 20),
            ),
            title: Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            subtitle: const Text('تحديث كلمة المرور الأساسية', style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () => _showPasswordDialog(sys),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('خيارات متقدمة', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildListTile(
                Icons.devices,
                'الأجهزة المتصلة',
                'إدارة الجلسات النشطة',
                primaryColor,
                textColor,
                onTap: () => _showToast('لا توجد جلسات أخرى نشطة حالياً'),
              ),
              const Divider(height: 1),
              _buildListTile(
                Icons.delete_forever,
                'حذف الحساب',
                'لا يمكن التراجع عن هذا الإجراء',
                Colors.red,
                textColor,
                onTap: () => _showDeleteAccountDialog(sys),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- تبويب المظهر (تخصيص اللون فقط في الوضع الليلي) ----------
  Widget _buildAppearanceTab(ThemeProvider themeProvider, UiProvider uiProvider, Color primaryColor, bool isDark, Color textColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('المظهر العام', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.dark_mode, color: primaryColor, size: 20),
                ),
                title: Text('الوضع الليلي', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                subtitle: const Text('تفعيل المظهر الداكن', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: themeProvider.isDarkMode,
                activeColor: primaryColor,
                onChanged: (val) {
                  _playFeedback();
                  themeProvider.toggleTheme(val);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.volume_up, color: primaryColor, size: 20),
                ),
                title: Text('الأصوات التفاعلية', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                subtitle: const Text('تشغيل الأصوات والاهتزاز', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _appSounds,
                activeColor: primaryColor,
                onChanged: (val) async {
                  setState(() => _appSounds = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('user_app_sounds', val);
                  uiProvider.setSoundsEnabled(val);
                  if (val) {
                    uiProvider.playSound('click');
                    HapticFeedback.lightImpact();
                  }
                  _playFeedback();
                  _showToast(val ? 'تم تفعيل الأصوات' : 'تم كتم الأصوات');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (themeProvider.isDarkMode) ...[
          _buildSectionTitle('تخصيص لون الواجهة', textColor),
          Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: primaryColor.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اختر لوناً شخصياً ينعكس على جميع الشاشات والقوائم والبطاقات.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => _openColorWheelPicker(themeProvider),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const SweepGradient(
                                  colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
                                ),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('اختر لوناً', style: TextStyle(fontSize: 12, color: primaryColor)),
                        ],
                      ),
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              _playFeedback();
                              themeProvider.resetToDefaultColor();
                              _showToast('تم استعادة اللون الافتراضي');
                            },
                            icon: const Icon(Icons.restore, size: 20),
                            label: const Text('اللون الافتراضي'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('استعادة', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),
        _buildSectionTitle('حجم الخط', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('صغير', style: TextStyle(fontSize: 12, color: textColor)),
                Expanded(
                  child: Slider(
                    value: themeProvider.fontSizeScale,
                    min: 0.8,
                    max: 1.5,
                    divisions: 7,
                    label: themeProvider.fontSizeScale.toStringAsFixed(2),
                    activeColor: primaryColor,
                    onChanged: (val) {
                      themeProvider.changeFontSizeScale(val);
                    },
                  ),
                ),
                Text('كبير', style: TextStyle(fontSize: 16, color: textColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- تبويب الحساب ----------
  Widget _buildAccountTab(SystemProvider sys, Color primaryColor, bool isDark, Color textColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('الإعدادات المالية', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: _buildListTile(
            Icons.account_balance_wallet,
            'الحد اليومي للمشتريات',
            _dailyLimit > 0 ? 'الحد الحالي: ${_dailyLimit.toStringAsFixed(0)} ريال' : 'لم يتم تعيين حد يومي',
            primaryColor,
            textColor,
            onTap: () => _showLimitDialog(sys),
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionTitle('اللغة', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: Text('العربية', style: TextStyle(color: textColor)),
                value: 'ar',
                groupValue: _selectedLanguage,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _playFeedback();
                  setState(() => _selectedLanguage = val!);
                  await sys.saveLanguage(val!);   // ✅ val! آمنة
                  _showToast('تم تغيير اللغة إلى العربية');
                },
              ),
              RadioListTile<String>(
                title: Text('English', style: TextStyle(color: textColor)),
                value: 'en',
                groupValue: _selectedLanguage,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _playFeedback();
                  setState(() => _selectedLanguage = val!);
                  await sys.saveLanguage(val!);   // ✅ val! آمنة
                  _showToast('Language changed to English');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionTitle('الجلسة', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: _buildListTile(
            Icons.logout,
            'تسجيل الخروج',
            'إنهاء الجلسة الحالية',
            Colors.orange,
            textColor,
            onTap: () => _showLogoutDialog(),
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionTitle('معلومات', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('إصدار التطبيق: 2.0.0', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.policy, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('سياسة الخصوصية', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- تبويب الإشعارات ----------
  Widget _buildNotificationsTab(Color primaryColor, bool isDark, Color textColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('إعدادات الإشعارات', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_active, color: primaryColor, size: 20),
                ),
                title: Text('تفعيل الإشعارات', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                subtitle: const Text('استلام إشعارات داخل التطبيق', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _notificationsEnabled,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _playFeedback();
                  setState(() => _notificationsEnabled = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifications_enabled', val);
                  _showToast(val ? 'تم تفعيل الإشعارات' : 'تم تعطيل الإشعارات');
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.campaign, color: primaryColor, size: 20),
                ),
                title: Text('إشعارات التسويق والعروض', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                subtitle: const Text('استلام عروض وكوبونات', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _marketingNotifications,
                activeColor: primaryColor,
                onChanged: _notificationsEnabled
                    ? (val) async {
                        _playFeedback();
                        setState(() => _marketingNotifications = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('marketing_notifications', val);
                      }
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.payments, color: primaryColor, size: 20),
                ),
                title: Text('إشعارات المعاملات المالية', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                subtitle: const Text('تنبيهات الشراء والتحويل', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _transactionNotifications,
                activeColor: primaryColor,
                onChanged: _notificationsEnabled
                    ? (val) async {
                        _playFeedback();
                        setState(() => _transactionNotifications = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('transaction_notifications', val);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- تبويب الخصوصية ----------
  Widget _buildPrivacyTab(SystemProvider sys, Color primaryColor, bool isDark, Color textColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('الخصوصية', textColor),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.visibility_off, color: primaryColor, size: 20),
                ),
                title: Text('إخفاء الرصيد عن الآخرين', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                subtitle: const Text('لن يظهر رصيدك للمستخدمين عند البحث', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _hideBalanceFromOthers,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _playFeedback();
                  setState(() => _hideBalanceFromOthers = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('hide_balance', val);
                  await sys.updatePrivacySetting('hideBalance', val);
                  _showToast(val ? 'تم إخفاء الرصيد' : 'سيظهر رصيدك للآخرين');
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: primaryColor, size: 20),
                ),
                title: Text('إظهار الاسم الكامل', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                subtitle: const Text('عند استقبال التحويلات', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _showFullName,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _playFeedback();
                  setState(() => _showFullName = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('show_full_name', val);
                  await sys.updatePrivacySetting('showFullName', val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- دوال مساعدة ----------
  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, Color color, Color textColor, {required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  // ---------- نافذة كلمة المرور (3 حقول + معاينة) ----------
  void _showPasswordDialog(SystemProvider sys) {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureOld = true, obscureNew = true, obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تغيير كلمة المرور'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPassController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  _playFeedback();
                  final oldPass = oldPassController.text.trim();
                  final newPass = newPassController.text.trim();
                  final confirmPass = confirmPassController.text.trim();

                  if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                    _showToast('يرجى تعبئة جميع الحقول');
                    return;
                  }
                  if (newPass != confirmPass) {
                    _showToast('كلمة المرور الجديدة غير متطابقة');
                    return;
                  }
                  if (newPass.length < 6) {
                    _showToast('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
                    return;
                  }

                  final success = sys.changeUserPassword(oldPass, newPass);
                  if (success) {
                    Navigator.pop(context);
                    _showToast('تم تحديث كلمة المرور بنجاح');
                  } else {
                    _showToast('كلمة المرور الحالية غير صحيحة');
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- نافذة PIN بثلاثة حقول (قديم، جديد، تأكيد) + معاينة ----------
  void _showPinDialog(SystemProvider sys) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool obscureOld = true, obscureNew = true, obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تغيير رمز PIN', textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPinController,
                    obscureText: obscureOld,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'رمز PIN القديم',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPinController,
                    obscureText: obscureNew,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'رمز PIN الجديد',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPinController,
                    obscureText: obscureConfirm,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'تأكيد رمز PIN الجديد',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  _playFeedback();
                  final oldPin = oldPinController.text.trim();
                  final newPin = newPinController.text.trim();
                  final confirmPin = confirmPinController.text.trim();
                  final result = await sys.changeUserPinWithOld(oldPin, newPin, confirmPin);
                  if (result == 'تم تحديث رمز PIN بنجاح.') {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('user_pin', newPin);
                    setState(() => _userPin = newPin);
                    Navigator.pop(context);
                    _showToast(result);
                  } else {
                    _showToast(result);
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLimitDialog(SystemProvider sys) {
    final limitController = TextEditingController(text: _dailyLimit > 0 ? _dailyLimit.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('الحد اليومي للمشتريات'),
          content: TextField(
            controller: limitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'مثال: 5000', suffixText: 'ريال', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                _playFeedback();
                final newLimit = double.tryParse(limitController.text.trim()) ?? 0.0;
                await sys.updateUserDailyLimit(newLimit);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('user_daily_limit', newLimit);
                setState(() => _dailyLimit = newLimit);
                Navigator.pop(context);
                _showToast(newLimit > 0 ? 'تم تعيين الحد اليومي إلى $newLimit ريال' : 'تم إلغاء الحد اليومي');
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.orange)),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                _playFeedback();
                final sys = Provider.of<SystemProvider>(context, listen: false);
                sys.clearAllData();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SSOLoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(SystemProvider sys) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('حذف الحساب', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('سيتم حذف جميع بياناتك نهائياً. أدخل كلمة المرور للتأكيد.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                _playFeedback();
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  _showToast('يرجى إدخال كلمة المرور');
                  return;
                }
                final success = await sys.deleteUserAccount(password);
                if (success) {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SSOLoginScreen()),
                    (route) => false,
                  );
                } else {
                  Navigator.pop(context);
                  _showToast('كلمة المرور غير صحيحة');
                }
              },
              child: const Text('نعم، احذف حسابي', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openColorWheelPicker(ThemeProvider themeProvider) {
    Color tempColor = themeProvider.primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر لونك المفضل', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (Color color) => tempColor = color,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tempColor),
            onPressed: () async {
              _playFeedback();
              themeProvider.setUserCustomColor(tempColor);
              Navigator.pop(context);
              _showToast('تم حفظ اللون الشخصي');
              final sys = Provider.of<SystemProvider>(context, listen: false);
              await sys.saveUserPreferredColor(tempColor);
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
