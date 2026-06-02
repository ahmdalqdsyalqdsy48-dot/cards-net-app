import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

import 'portals_management_screen.dart';
import 'banners_screen.dart';
import 'sms_gateway_screen.dart';
import 'backup_screen.dart';
import 'audit_log_screen.dart';
import 'advanced_reset_screen.dart';

class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isInit = false;
  String _tempFont = 'System';
  double _tempFontSize = 1.0;
  bool _tempDarkMode = false;

  bool _tempSoundsEnabled = true;
  final LocalAuthentication _localAuth = LocalAuthentication();

  late bool _tempMaintenance, _tempForcedUpdate, _tempShowNews, _tempAutoRounding;
  late String _tempMinCharge;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadInitialData();
  }

  void _loadInitialData() {
    final settings = context.read<SettingsProvider>();
    _tempMaintenance = settings.isMaintenanceMode;
    _tempForcedUpdate = settings.isForcedUpdate;
    _tempShowNews = settings.showNewsBar;
    _tempAutoRounding = settings.isCurrencyAutoRounding;
    _tempMinCharge = settings.minimumChargeLimit;
    _tempSoundsEnabled = settings.isSoundEnabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final tp = context.read<ThemeProvider>();
      _tempFont = tp.fontFamily;
      _tempFontSize = tp.fontSizeScale;
      _tempDarkMode = tp.isDarkMode;
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnack(String m, {bool isSuccess = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m, textDirection: TextDirection.rtl),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _play(String type) => context.read<UiProvider>().playSound(type);
  void _playClick() => _play('click');

  void _navigateTo(Widget screen) {
    _playClick();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final Color safeActiveColor = themeProvider.primaryColor == const Color(0xFFFFFFFF)
        ? Colors.blueAccent
        : themeProvider.primaryColor;

    return Scaffold(
      appBar: const CustomHeader(title: 'إعدادات النظام الشاملة'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: safeActiveColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: safeActiveColor,
              onTap: (_) => _playClick(),
              tabs: const [
                Tab(icon: Icon(Icons.palette), text: 'المظهر والخطوط'),
                Tab(icon: Icon(Icons.security), text: 'الملف والأمان'),
                Tab(icon: Icon(Icons.settings_input_component), text: 'حالة النظام'),
                Tab(icon: Icon(Icons.gavel), text: 'السياسات والحدود'),
                Tab(icon: Icon(Icons.link), text: 'روابط متقدمة'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAppearanceTab(themeProvider, safeActiveColor),
                  _buildSecurityTab(settings, wallet, safeActiveColor),
                  _buildSystemStatusTab(settings, safeActiveColor),
                  _buildPolicyTab(settings, safeActiveColor),
                  _buildQuickLinksTab(settings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. تبويب المظهر والخطوط
  // ==========================================
  Widget _buildAppearanceTab(ThemeProvider themeProvider, Color safeActiveColor) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLocalNotice(),
                _buildSectionTitle('تخصيص ألوان الواجهة الخاصة بك'),
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.color_lens, color: safeActiveColor, size: 30),
                    title: const Text('دائرة الألوان الاحترافية', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('قم باختيار لونك المفضل ليتغير مظهر لوحتك بالكامل'),
                    trailing: ElevatedButton(
                      onPressed: () {
                        _playClick();
                        _showColorPickerDialog(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: safeActiveColor),
                      child: const Text('تخصيص المظهر', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
                const Divider(height: 40),
                _buildSectionTitle('إدارة الخطوط (محلية)'),
                Card(
                  elevation: 1,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.font_download, color: Colors.blue),
                        title: const Text('نوع الخط'),
                        trailing: DropdownButton<String>(
                          value: _tempFont,
                          items: [
                            'System',
                            'Cairo',
                            'Tajawal',
                            'Almarai',
                            'Changa',
                            'Lalezar',
                            'Readex Pro',
                            'IBM Plex Sans Arabic'
                          ].map((font) => DropdownMenuItem(value: font, child: Text(font))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _playClick();
                              setState(() => _tempFont = val);
                            }
                          },
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.format_size, color: Colors.orange),
                        title: const Text('حجم الخط العام'),
                        subtitle: Slider(
                          value: _tempFontSize,
                          min: 0.8,
                          max: 1.5,
                          divisions: 7,
                          label: _tempFontSize.toStringAsFixed(1),
                          onChanged: (val) => setState(() => _tempFontSize = val),
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode, color: Colors.indigo),
                  title: const Text('تفعيل الوضع الليلي (Dark Mode)'),
                  value: _tempDarkMode,
                  onChanged: (val) {
                    _playClick();
                    setState(() => _tempDarkMode = val);
                  },
                ),
              ],
            ),
          ),
        ),
        _buildSaveButton(
          onSave: () {
            themeProvider.changeFontFamily(_tempFont);
            themeProvider.changeFontSizeScale(_tempFontSize);
            themeProvider.toggleTheme(_tempDarkMode);
            _play('success');
            _showSnack('تم حفظ المظهر والخطوط بنجاح! ✨');
          },
          color: Colors.green,
          label: 'حفظ إعدادات المظهر',
        ),
      ],
    );
  }

  // ==========================================
  // 2. تبويب الأمان والبيانات الشخصية
  // ==========================================
  Widget _buildSecurityTab(SettingsProvider settings, WalletProvider wallet, Color safeActiveColor) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('الملف الشخصي للمالك'),
                _buildInteractiveCard(
                  Icons.person,
                  'الاسم الرباعي',
                  wallet.currentUserName,
                  () => _showEditNameDialog(wallet),
                ),
                const Divider(height: 30),
                _buildSectionTitle('إعدادات الأمان والحماية'),
                _buildInteractiveCard(
                  Icons.lock_reset,
                  'كلمة المرور',
                  '********',
                  () => _showEditPasswordDialog(wallet),
                  color: Colors.redAccent,
                ),
                _buildInteractiveCard(
                  Icons.pin,
                  'رمز PIN السريع',
                  '******',
                  () => _showEditPinDialog(wallet),
                  color: Colors.orange,
                ),
                Card(
                  elevation: 1,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint, color: Colors.green),
                        title: const Text('الدخول بالبصمة (Biometrics)'),
                        subtitle: const Text('المصادقة بمستشعر الهاتف', style: TextStyle(fontSize: 11)),
                        value: wallet.isBiometricCurrentlyEnabled,
                        onChanged: (val) async {
                          _playClick();
                          if (val) {
                            try {
                              bool authenticated = await _localAuth.authenticate(
                                localizedReason: 'يرجى تأكيد هويتك لتفعيل الدخول بالبصمة',
                                options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
                              );
                              if (authenticated) {
                                wallet.toggleBiometric(true);
                                _play('success');
                                _showSnack('تم تفعيل البصمة بنجاح! 🔒');
                              }
                            } catch (e) {
                              _showSnack('عذراً، جهازك لا يدعم البصمة أو أنها غير معدّة.', isSuccess: false);
                            }
                          } else {
                            wallet.toggleBiometric(false);
                            _play('success');
                            _showSnack('تم إيقاف الدخول بالبصمة.');
                          }
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up, color: Colors.blue),
                        title: const Text('أصوات التطبيق (النقرات والإشعارات)'),
                        value: _tempSoundsEnabled,
                        onChanged: (val) {
                          _playClick();
                          setState(() => _tempSoundsEnabled = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildSaveButton(
          onSave: () async {
            await settings.setSoundEnabled(_tempSoundsEnabled);
            _play('success');
            _showSnack('تم حفظ إعدادات الأمان والأصوات! ✅');
          },
          color: safeActiveColor,
          label: 'حفظ إعدادات الأمان',
        ),
      ],
    );
  }

  // ==========================================
  // 3. تبويب حالة النظام
  // ==========================================
  Widget _buildSystemStatusTab(SettingsProvider settings, Color safeActiveColor) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActionCard(
                  Icons.article,
                  'تعديل نص الشريط العلوي العام',
                  'تغيير الخبر المتحرك في أعلى التطبيق',
                  onTap: () {
                    _playClick();
                    _showGlobalMarqueeEditDialog();
                  },
                ),
                _buildActionCard(
                  Icons.newspaper,
                  'نشر إشعار إداري داخلي',
                  'إرسال إشعار لمجموعات معينة',
                  onTap: () {
                    _playClick();
                    _showTextEditDialog(
                      'إشعار إداري',
                      '',
                      (text) => settings.addTargetedNews(text: text, targetRole: 'الكل'),
                    );
                  },
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.handyman, color: Colors.red),
                  title: const Text('وضع الصيانة العامة 🚧'),
                  subtitle: const Text('منع دخول الجميع وعرض رسالة الصيانة'),
                  value: _tempMaintenance,
                  onChanged: (val) {
                    _playClick();
                    setState(() => _tempMaintenance = val);
                  },
                  activeColor: Colors.red,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.system_update, color: Colors.blue),
                  title: const Text('التحديث الإجباري ⚠️'),
                  value: _tempForcedUpdate,
                  onChanged: (val) {
                    _playClick();
                    setState(() => _tempForcedUpdate = val);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.new_label, color: Colors.orange),
                  title: const Text('إظهار شريط الأخبار 🚨'),
                  value: _tempShowNews,
                  onChanged: (val) {
                    _playClick();
                    setState(() => _tempShowNews = val);
                  },
                ),
              ],
            ),
          ),
        ),
        _buildSaveButton(
          onSave: () async {
            await settings.updateSystemStatusSettings(
              maintenance: _tempMaintenance,
              forcedUpdate: _tempForcedUpdate,
              showNews: _tempShowNews,
            );
            _play('success');
            _showSnack('تم تحديث حالة النظام فورياً! 🚀');
          },
          color: Colors.redAccent,
          label: 'تحديث حالة النظام الآن',
        ),
      ],
    );
  }

  // ==========================================
  // 4. تبويب السياسات والحدود
  // ==========================================
  Widget _buildPolicyTab(SettingsProvider settings, Color safeActiveColor) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.calculate, color: Colors.blueGrey),
                  title: const Text('جبر كسور الصرافة آلياً'),
                  value: _tempAutoRounding,
                  onChanged: (val) {
                    _playClick();
                    setState(() => _tempAutoRounding = val);
                  },
                ),
                _buildInteractiveCard(
                  Icons.money_off,
                  'الحد الأدنى للشحن',
                  '$_tempMinCharge ريال',
                  () {
                    _playClick();
                    _showTextEditDialog(
                      'تعديل الحد الأدنى للشحن',
                      _tempMinCharge,
                      (val) => setState(() => _tempMinCharge = val),
                    );
                  },
                ),
                _buildActionCard(
                  Icons.description,
                  'الشروط والأحكام',
                  'تعديل سياسة الاستخدام للتطبيق',
                  onTap: () {
                    _playClick();
                    _showTextEditDialog(
                      'تعديل الشروط والأحكام',
                      settings.termsAndConditions,
                      (val) => settings.updatePoliciesSettings(
                        terms: val,
                        support: settings.supportNumbers,
                        minCharge: _tempMinCharge,
                        autoRounding: _tempAutoRounding,
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  Icons.support,
                  'أرقام الدعم الفني العام',
                  'تعديل أرقام التواصل',
                  onTap: () {
                    _playClick();
                    _showTextEditDialog(
                      'تعديل أرقام الدعم الفني',
                      settings.supportNumbers,
                      (val) => settings.updatePoliciesSettings(
                        terms: settings.termsAndConditions,
                        support: val,
                        minCharge: _tempMinCharge,
                        autoRounding: _tempAutoRounding,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        _buildSaveButton(
          onSave: () async {
            await settings.updatePoliciesSettings(
              terms: settings.termsAndConditions,
              support: settings.supportNumbers,
              minCharge: _tempMinCharge,
              autoRounding: _tempAutoRounding,
            );
            _play('success');
            _showSnack('تم تطبيق السياسات الجديدة بنجاح! ⚖️');
          },
          color: Colors.blueGrey,
          label: 'تثبيت السياسات والحدود',
        ),
      ],
    );
  }

  // ==========================================
  // 5. تبويب الروابط المتقدمة (جديد)
  // ==========================================
  Widget _buildQuickLinksTab(SettingsProvider settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('⚡ إعدادات متقدمة (شاشات متخصصة)'),
          _buildQuickLinkCard(Icons.web, 'إدارة البوابات الذكية', 'الهوية، الدخول، السلايدر', () => _navigateTo(const PortalsManagementScreen())),
          _buildQuickLinkCard(Icons.campaign, 'الإعلانات والبنرات', 'الحملات التسويقية', () => _navigateTo(const BannersScreen())),
          _buildQuickLinkCard(Icons.sms, 'بوابة رسائل الـ SMS', 'إعدادات المزود والقوالب', () => _navigateTo(const SmsGatewayScreen())),
          _buildQuickLinkCard(Icons.cloud_upload, 'النسخ الاحتياطي السحابي', 'يدوي، تلقائي، ربط الحسابات', () => _navigateTo(const BackupScreen())),
          _buildQuickLinkCard(Icons.security, 'السجل الأسود للنشاط', 'مراقبة جميع الأحداث', () => _navigateTo(const AuditLogScreen())),
          _buildQuickLinkCard(Icons.cleaning_services, 'التحكم الشامل', 'إعادة تهيئة وفرمتة', () => _navigateTo(const AdvancedResetScreen())),
          const Divider(height: 30),
          _buildSectionTitle('📈 أرقام النظام (قراءة فقط)'),
          _buildReadOnlyRow('الرصيد الرئيسي', '${settings.adminMainBalance.toStringAsFixed(0)} ريال'),
          _buildReadOnlyRow('إجمالي الكروت', '${settings.totalSystemCards}'),
          _buildReadOnlyRow('رصيد SMS', '${settings.smsBalance}'),
        ],
      ),
    );
  }

  // ==========================================
  // مكوّنات مساعدة
  // ==========================================
  Widget _buildLocalNotice() => Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'هذا القسم لتخصيص راحتك البصرية فقط ولا ينعكس على المستخدمين.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      );

  Widget _buildSaveButton({
    required VoidCallback onSave,
    required Color color,
    required String label,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.save, color: Colors.white),
          label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: () {
            _playClick();
            onSave();
          },
        ),
      );

  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey),
        ),
      );

  Widget _buildInteractiveCard(
    IconData icon,
    String title,
    String value,
    VoidCallback onTap, {
    Color color = Colors.blueAccent,
  }) =>
      Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          trailing: const Icon(Icons.edit, color: Colors.blue),
          onTap: onTap,
        ),
      );

  Widget _buildActionCard(IconData icon, String title, String subtitle, {VoidCallback? onTap}) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(icon, color: Colors.blueAccent),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: onTap,
        ),
      );

  Widget _buildQuickLinkCard(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon, color: Colors.blueAccent),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: onTap,
        ),
      );

  Widget _buildReadOnlyRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
          ],
        ),
      );

  Widget _buildPassField(
    String hint,
    TextEditingController ctrl,
    bool obs,
    VoidCallback toggle, {
    bool isNumber = false,
    int? maxLength,
  }) =>
      TextField(
        controller: ctrl,
        obscureText: obs,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLength: maxLength,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: IconButton(
            icon: Icon(obs ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
            onPressed: toggle,
          ),
        ),
      );

  // ==========================================
  // دوال الحوارات
  // ==========================================
  void _showColorPickerDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    Color pickerColor = themeProvider.primaryColor;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تخصيص مظهر لوحتك الشخصية 🎨'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (c) => pickerColor = c,
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              paletteType: PaletteType.hsvWithHue,
              labelTypes: const [],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                themeProvider.resetToDefault();
                Navigator.pop(context);
                _play('success');
                _showSnack('تمت العودة للون الرسمي الأبيض.');
              },
              child: const Text('استعادة الافتراضي', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                themeProvider.changeColor(pickerColor);
                Navigator.pop(context);
                _play('success');
                _showSnack('تم اعتماد اللون! 🎨');
              },
              child: const Text('اعتماد اللون'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(WalletProvider wallet) {
    TextEditingController nameController = TextEditingController(text: wallet.currentUserName);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير الاسم الرباعي'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'الاسم الجديد',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                _playClick();
                bool success = await wallet.changeUserName(nameController.text);
                if (mounted) {
                  Navigator.pop(context);
                  _showSnack(success ? 'تم تحديث الاسم بنجاح! ✅' : 'فشل التحديث', isSuccess: success);
                  if (success) _play('success'); else _play('error');
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPasswordDialog(WalletProvider wallet) {
    TextEditingController oldPass = TextEditingController();
    TextEditingController newPass = TextEditingController();
    TextEditingController confirmPass = TextEditingController();
    bool obsOld = true, obsNew = true, obsConfirm = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تغيير كلمة المرور 🔐'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPassField('كلمة المرور القديمة', oldPass, obsOld, () => setState(() => obsOld = !obsOld)),
                const SizedBox(height: 10),
                _buildPassField('كلمة المرور الجديدة', newPass, obsNew, () => setState(() => obsNew = !obsNew)),
                const SizedBox(height: 10),
                _buildPassField('تأكيد الجديدة', confirmPass, obsConfirm, () => setState(() => obsConfirm = !obsConfirm)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () {
                  _playClick();
                  if (newPass.text != confirmPass.text) {
                    _showSnack('كلمة المرور غير متطابقة!', isSuccess: false);
                    return;
                  }
                  bool success = wallet.changeUserPassword(oldPass.text, newPass.text);
                  Navigator.pop(context);
                  _showSnack(success ? 'تم تغيير كلمة المرور بنجاح!' : 'القديمة خاطئة!', isSuccess: success);
                  if (success) _play('success'); else _play('error');
                },
                child: const Text('تأكيد التغيير'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPinDialog(WalletProvider wallet) {
    TextEditingController oldPin = TextEditingController();
    TextEditingController newPin = TextEditingController();
    TextEditingController confirmPin = TextEditingController();
    bool obsOld = true, obsNew = true, obsConfirm = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تغيير رمز PIN السريع 🔢'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('يُستخدم لحماية العمليات الحساسة.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 15),
                _buildPassField('رمز PIN القديم', oldPin, obsOld, () => setState(() => obsOld = !obsOld), isNumber: true, maxLength: 6),
                const SizedBox(height: 10),
                _buildPassField('رمز PIN الجديد', newPin, obsNew, () => setState(() => obsNew = !obsNew), isNumber: true, maxLength: 6),
                const SizedBox(height: 10),
                _buildPassField('تأكيد PIN', confirmPin, obsConfirm, () => setState(() => obsConfirm = !obsConfirm), isNumber: true, maxLength: 6),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  _playClick();
                  if (newPin.text != confirmPin.text) {
                    _showSnack('الرمز غير متطابق!', isSuccess: false);
                    return;
                  }
                  bool success = await wallet.changeUserPin(oldPin.text, newPin.text);
                  if (mounted) {
                    Navigator.pop(context);
                    _showSnack(success ? 'تم تحديث PIN بنجاح!' : 'القديم خاطئ!', isSuccess: success);
                    if (success) _play('success'); else _play('error');
                  }
                },
                child: const Text('تحديث الرمز'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGlobalMarqueeEditDialog() {
    TextEditingController marqueeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Colors.orange),
              SizedBox(width: 8),
              Text('تعديل الشريط العلوي العام', style: TextStyle(fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هذا النص سيظهر للجميع فوراً.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              TextField(
                controller: marqueeCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'اكتب إعلانك هنا...', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (marqueeCtrl.text.isNotEmpty) {
                  _playClick();
                  await FirebaseFirestore.instance.collection('system').doc('main_info').update({
                    'announcements': [marqueeCtrl.text],
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _play('success');
                    _showSnack('تم تغيير نص الشريط بنجاح!');
                  }
                }
              },
              child: const Text('تطبيق وحفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextEditDialog(String title, String initialValue, Function(String) onSave) {
    TextEditingController controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                _playClick();
                onSave(controller.text);
                Navigator.pop(context);
                _play('success');
                _showSnack('تم الحفظ بنجاح! ✅');
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }
}
