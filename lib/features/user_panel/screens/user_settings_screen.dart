import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
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
  double _monthlyLimit = 0.0;
  String _userPin = '';
  bool _notificationsEnabled = true;
  bool _marketingNotifications = true;
  bool _transactionNotifications = true;
  bool _emailNotifications = false;
  bool _hideBalanceFromOthers = false;
  bool _showFullName = true;
  String _userEmail = '';
  String _appLanguage = 'ar';
  int _autoLockMinutes = 0;

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final wallet = context.read<WalletProvider>();
    final settings = context.read<SettingsProvider>();

    await wallet.loadUserEmail();

    final currentPin = wallet.currentUserPin;
    final savedLang = settings.getLanguageSync();
    final email = wallet.currentUserEmail ?? '';

    setState(() {
      _appSounds = settings.isSoundEnabled;
      _dailyLimit = prefs.getDouble('user_daily_limit') ?? 0.0;
      _monthlyLimit = prefs.getDouble('user_monthly_limit') ?? 0.0;
      _userPin = currentPin.isNotEmpty && currentPin.length == 6 ? currentPin : '';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _marketingNotifications = prefs.getBool('marketing_notifications') ?? true;
      _transactionNotifications = prefs.getBool('transaction_notifications') ?? true;
      _emailNotifications = prefs.getBool('email_notifications') ?? false;
      _hideBalanceFromOthers = prefs.getBool('hide_balance') ?? false;
      _showFullName = prefs.getBool('show_full_name') ?? true;
      _userEmail = email;
      _emailController.text = email;
      _appLanguage = savedLang;
      _autoLockMinutes = prefs.getInt('user_autoLockMinutes') ?? 0;
    });
  }

  void _playFeedback() {
    final uiProvider = context.read<UiProvider>();
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final settings = context.watch<SettingsProvider>();
    final uiProvider = context.watch<UiProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final userName = wallet.currentUserName;
    final userPhone = auth.activeUserPhone ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const CustomHeader(title: 'الإعدادات'),
      drawer: CustomUserDrawer(userName: userName, phoneNumber: userPhone),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: primaryColor,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.onSurface),
                tabs: const [
                  Tab(text: 'الحساب'),
                  Tab(text: 'الأمان'),
                  Tab(text: 'الإشعارات'),
                  Tab(text: 'المظهر واللغة'),
                  Tab(text: 'الخصوصية'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAccountTab(wallet, primaryColor, colorScheme),
                  _buildSecurityTab(wallet, primaryColor, colorScheme),
                  _buildNotificationsTab(primaryColor, colorScheme),
                  _buildAppearanceTab(themeProvider, uiProvider, settings, wallet,
                      primaryColor, isDark, colorScheme),
                  _buildPrivacyTab(wallet, primaryColor, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- تبويب الحساب ----------
  Widget _buildAccountTab(
      WalletProvider wallet, Color primaryColor, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('الإعدادات المالية', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildListTile(
                Icons.account_balance_wallet,
                'الحد اليومي للمشتريات',
                _dailyLimit > 0
                    ? 'الحد الحالي: ${_dailyLimit.toStringAsFixed(0)} ريال'
                    : 'لم يتم تعيين حد يومي',
                primaryColor,
                onTap: () => _showLimitDialog(wallet, false),
              ),
              const Divider(height: 1),
              _buildListTile(
                Icons.calendar_month,
                'الحد الشهري للمشتريات',
                _monthlyLimit > 0
                    ? 'الحد الشهري: ${_monthlyLimit.toStringAsFixed(0)} ريال'
                    : 'لم يتم تعيين حد شهري',
                primaryColor,
                onTap: () => _showLimitDialog(wallet, true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('البريد الإلكتروني', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.email, color: primaryColor, size: 20),
            ),
            title: Text('البريد الإلكتروني',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface)),
            subtitle: Text(
                _userEmail.isEmpty ? 'غير مضاف' : _userEmail,
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 14, color: colorScheme.onSurfaceVariant),
            onTap: () => _showEmailDialog(wallet),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('الجلسة', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: _buildListTile(
            Icons.logout,
            'تسجيل الخروج',
            'إنهاء الجلسة الحالية',
            Colors.orange,
            onTap: () => _showLogoutDialog(),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('معلومات', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.info_outline,
                    color: colorScheme.onSurfaceVariant),
                title: Text('إصدار التطبيق: 2.0.0',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    Icon(Icons.policy, color: colorScheme.onSurfaceVariant),
                title: Text('سياسة الخصوصية',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.open_in_new,
                    size: 16, color: colorScheme.onSurfaceVariant),
                onTap: () async {
                  final uri = Uri.parse('https://your-website.com/privacy');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- تبويب الأمان ----------
  Widget _buildSecurityTab(
      WalletProvider wallet, Color primaryColor, ColorScheme colorScheme) {
    final useBiometrics = wallet.isBiometricCurrentlyEnabled;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('معلومات الدخول', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildListTile(
                Icons.lock_outline,
                'رمز PIN الشامل',
                _userPin.isNotEmpty
                    ? 'تم تعيين رمز PIN مكون من 6 أرقام'
                    : 'لم يتم تعيين رمز PIN بعد',
                primaryColor,
                onTap: () => _showPinDialog(wallet),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.fingerprint, color: primaryColor, size: 20),
                ),
                title: Text('الدخول بالبصمة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text(
                    kIsWeb ? 'غير مدعوم على الويب' : 'بصمة الإصبع أو الوجه',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
                value: useBiometrics && !kIsWeb,
                activeColor: primaryColor,
                onChanged: (val) {
                  _playFeedback();
                  if (kIsWeb) {
                    _showToast('البصمة مدعومة فقط على الهواتف');
                    return;
                  }
                  wallet.toggleBiometric(val);
                  _showToast(val
                      ? 'تم تفعيل الدخول بالبصمة'
                      : 'تم إيقاف الدخول بالبصمة');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('تغيير كلمة المرور', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
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
            title: Text('تغيير كلمة المرور',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface)),
            subtitle: Text('تحديث كلمة المرور الأساسية',
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 14, color: colorScheme.onSurfaceVariant),
            onTap: () => _showPasswordDialog(wallet),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('أمان الجلسة', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.lock_clock, color: primaryColor, size: 20),
            ),
            title: Text('القفل التلقائي للجلسة',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface)),
            subtitle: Text(
                _autoLockMinutes == 0
                    ? 'معطل'
                    : 'بعد $_autoLockMinutes دقيقة من الخمول',
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            trailing: DropdownButton<int>(
              value: _autoLockMinutes,
              items: const [
                DropdownMenuItem(value: 0, child: Text('معطل')),
                DropdownMenuItem(value: 1, child: Text('1 دقيقة')),
                DropdownMenuItem(value: 3, child: Text('3 دقائق')),
                DropdownMenuItem(value: 5, child: Text('5 دقائق')),
                DropdownMenuItem(value: 10, child: Text('10 دقائق')),
              ],
              onChanged: (val) async {
                if (val == null) return;
                _playFeedback();
                setState(() => _autoLockMinutes = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('user_autoLockMinutes', val);
                _showToast(val == 0
                    ? 'تم تعطيل القفل التلقائي'
                    : 'تم تعيين القفل بعد $val دقيقة');
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('خيارات متقدمة', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: _buildListTile(
            Icons.delete_forever,
            'حذف الحساب',
            'لا يمكن التراجع عن هذا الإجراء',
            colorScheme.error,
            onTap: () => _showDeleteAccountDialog(wallet),
          ),
        ),
      ],
    );
  }

  // ---------- تبويب الإشعارات ----------
  Widget _buildNotificationsTab(Color primaryColor, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('إعدادات الإشعارات', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
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
                  child: Icon(Icons.notifications_active,
                      color: primaryColor, size: 20),
                ),
                title: Text('تفعيل الإشعارات',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('استلام إشعارات داخل التطبيق',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
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
                title: Text('إشعارات التسويق والعروض',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('استلام عروض وكوبونات',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
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
                title: Text('إشعارات المعاملات المالية',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('تنبيهات الشراء والتحويل',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
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
              const Divider(height: 1),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.email, color: primaryColor, size: 20),
                ),
                title: Text('إيصالات البريد الإلكتروني',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('إرسال إيصالات المعاملات إلى بريدك',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
                value: _emailNotifications,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _playFeedback();
                  setState(() => _emailNotifications = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('email_notifications', val);
                  _showToast(val
                      ? 'تم تفعيل إيصالات البريد'
                      : 'تم تعطيل إيصالات البريد');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- تبويب المظهر واللغة ----------
  Widget _buildAppearanceTab(
      ThemeProvider themeProvider,
      UiProvider uiProvider,
      SettingsProvider settings,
      WalletProvider wallet,
      Color primaryColor,
      bool isDark,
      ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('المظهر العام', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.brightness_6,
                      color: primaryColor, size: 20),
                ),
                title: Text('الوضع الليلي',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text(isDark ? 'داكن' : 'فاتح',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
                trailing: DropdownButton<String>(
                  value: isDark ? 'dark' : 'light',
                  items: const [
                    DropdownMenuItem(value: 'light', child: Text('فاتح')),
                    DropdownMenuItem(value: 'dark', child: Text('داكن')),
                    DropdownMenuItem(value: 'auto', child: Text('تلقائي')),
                  ],
                  onChanged: (val) {
                    _playFeedback();
                    if (val == 'auto') {
                      final brightness =
                          MediaQuery.of(context).platformBrightness;
                      themeProvider
                          .toggleTheme(brightness == Brightness.dark);
                    } else {
                      themeProvider.toggleTheme(val == 'dark');
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child:
                      Icon(Icons.language, color: primaryColor, size: 20),
                ),
                title: Text('لغة التطبيق',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text(
                    _appLanguage == 'ar' ? 'العربية' : 'English',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
                trailing: DropdownButton<String>(
                  value: _appLanguage,
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    _playFeedback();
                    setState(() => _appLanguage = val);
                    await settings.changeAppLanguage(val);
                    _showToast(val == 'ar'
                        ? 'تم تغيير اللغة إلى العربية'
                        : 'Language changed to English');
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.volume_up, color: primaryColor, size: 20),
                ),
                title: Text('الأصوات التفاعلية',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('تشغيل الأصوات والاهتزاز',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
                value: _appSounds,
                activeColor: primaryColor,
                onChanged: (val) async {
                  setState(() => _appSounds = val);
                  settings.setSoundEnabled(val);
                  _playFeedback();
                  _showToast(val ? 'تم تفعيل الأصوات' : 'تم كتم الأصوات');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('تخصيص لون الواجهة', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'اختر لوناً شخصياً ينعكس على جميع الشاشات والقوائم والبطاقات.',
                    style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _openColorWheelPicker(themeProvider, wallet),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(
                                colors: [
                                  Colors.red,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.purple,
                                  Colors.red
                                ],
                              ),
                              border: Border.all(
                                  color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        Colors.black.withOpacity(0.1),
                                    blurRadius: 8),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('اختر لوناً',
                            style: TextStyle(
                                fontSize: 12, color: primaryColor)),
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
                            backgroundColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            foregroundColor:
                                isDark ? Colors.white : Colors.black87,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(30)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('استعادة',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('حجم الخط', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('صغير',
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurface)),
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
                Text('كبير',
                    style: TextStyle(
                        fontSize: 16, color: colorScheme.onSurface)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- تبويب الخصوصية ----------
  Widget _buildPrivacyTab(
      WalletProvider wallet, Color primaryColor, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('الخصوصية', colorScheme.onSurface),
        Card(
          elevation: 0,
          color: colorScheme.surface,
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
                  child: Icon(Icons.visibility_off,
                      color: primaryColor, size: 20),
                ),
                title: Text('إخفاء الرصيد عن الآخرين',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text(
                    'لن يظهر رصيدك للمستخدمين عند البحث',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
                value: _hideBalanceFromOthers,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _playFeedback();
                  setState(() => _hideBalanceFromOthers = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('hide_balance', val);
                  await wallet.updatePrivacySetting('hideBalance', val);
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
                title: Text('إظهار الاسم الكامل',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('عند استقبال التحويلات',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
                value: _showFullName,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _playFeedback();
                  setState(() => _showFullName = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('show_full_name', val);
                  await wallet.updatePrivacySetting('showFullName', val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- أدوات مساعدة ----------
  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle,
      Color color,
      {required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration:
            BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant))
          : null,
      trailing: Icon(Icons.arrow_forward_ios,
          size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  // ---------- حوارات ----------
  void _showPasswordDialog(WalletProvider wallet) {
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                        icon: Icon(obscureOld
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setStateDialog(() => obscureOld = !obscureOld),
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
                        icon: Icon(obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setStateDialog(() => obscureNew = !obscureNew),
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
                        icon: Icon(obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setStateDialog(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  _playFeedback();
                  final oldPass = oldPassController.text.trim();
                  final newPass = newPassController.text.trim();
                  final confirmPass = confirmPassController.text.trim();

                  if (oldPass.isEmpty ||
                      newPass.isEmpty ||
                      confirmPass.isEmpty) {
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

                  final success =
                      wallet.changeUserPassword(oldPass, newPass);
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

  void _showPinDialog(WalletProvider wallet) {
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title:
                const Text('تغيير رمز PIN', textAlign: TextAlign.center),
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
                        icon: Icon(obscureOld
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setStateDialog(() => obscureOld = !obscureOld),
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
                        icon: Icon(obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setStateDialog(() => obscureNew = !obscureNew),
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
                        icon: Icon(obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setStateDialog(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  _playFeedback();
                  final oldPin = oldPinController.text.trim();
                  final newPin = newPinController.text.trim();
                  final confirmPin = confirmPinController.text.trim();
                  final result = await wallet.changeUserPinWithOld(
                      oldPin, newPin, confirmPin);
                  if (result == 'تم تحديث رمز PIN بنجاح.') {
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

  void _showLimitDialog(WalletProvider wallet, bool isMonthly) {
    final limitController = TextEditingController(
        text: isMonthly
            ? (_monthlyLimit > 0 ? _monthlyLimit.toStringAsFixed(0) : '')
            : (_dailyLimit > 0 ? _dailyLimit.toStringAsFixed(0) : ''));
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(isMonthly ? 'الحد الشهري للمشتريات' : 'الحد اليومي للمشتريات'),
          content: TextField(
            controller: limitController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                hintText: 'مثال: 5000',
                suffixText: 'ريال',
                border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                _playFeedback();
                final newLimit =
                    double.tryParse(limitController.text.trim()) ?? 0.0;
                if (isMonthly) {
                  await wallet.updateUserMonthlyLimit(newLimit);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('user_monthly_limit', newLimit);
                  setState(() => _monthlyLimit = newLimit);
                } else {
                  await wallet.updateUserDailyLimit(newLimit);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('user_daily_limit', newLimit);
                  setState(() => _dailyLimit = newLimit);
                }
                Navigator.pop(context);
                _showToast(newLimit > 0
                    ? 'تم تعيين ${isMonthly ? "الحد الشهري" : "الحد اليومي"} إلى $newLimit ريال'
                    : 'تم إلغاء ${isMonthly ? "الحد الشهري" : "الحد اليومي"}');
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('تسجيل الخروج',
              style: TextStyle(color: Colors.orange)),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                _playFeedback();
                final auth = context.read<AuthProvider>();
                auth.clearAllData();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SSOLoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('تأكيد',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(WalletProvider wallet) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
              const Text(
                  'سيتم حذف جميع بياناتك نهائياً. أدخل كلمة المرور للتأكيد.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                _playFeedback();
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  _showToast('يرجى إدخال كلمة المرور');
                  return;
                }
                final success = await wallet.deleteUserAccount(password);
                if (success) {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SSOLoginScreen()),
                    (route) => false,
                  );
                } else {
                  Navigator.pop(context);
                  _showToast('كلمة المرور غير صحيحة');
                }
              },
              child: const Text('نعم، احذف حسابي',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openColorWheelPicker(ThemeProvider themeProvider, WalletProvider wallet) {
    Color tempColor = themeProvider.primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('اختر لونك المفضل', textAlign: TextAlign.center),
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tempColor),
            onPressed: () async {
              _playFeedback();
              themeProvider.setUserCustomColor(tempColor);
              Navigator.pop(context);
              _showToast('تم حفظ اللون الشخصي');
              await wallet.saveUserPreferredColor(tempColor);
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEmailDialog(WalletProvider wallet) {
    final controller = TextEditingController(text: _userEmail);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('البريد الإلكتروني'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'example@email.com',
              labelText: 'أدخل بريدك الإلكتروني',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                _playFeedback();
                final email = controller.text.trim();
                if (email.isNotEmpty && !email.contains('@')) {
                  _showToast('يرجى إدخال بريد إلكتروني صحيح');
                  return;
                }
                await wallet.updateUserEmail(email);
                setState(() {
                  _userEmail = email;
                  _emailController.text = email;
                });
                Navigator.pop(context);
                _showToast(email.isEmpty
                    ? 'تم حذف البريد الإلكتروني'
                    : 'تم حفظ البريد الإلكتروني');
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
