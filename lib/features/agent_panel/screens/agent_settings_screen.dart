import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';
import '../../auth/screens/sso_login_screen.dart';

class AgentSettingsScreen extends StatefulWidget {
  const AgentSettingsScreen({super.key});

  @override
  State<AgentSettingsScreen> createState() => _AgentSettingsScreenState();
}

class _AgentSettingsScreenState extends State<AgentSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- تبويب الطباعة ----------
  bool _autoPrintEnabled = false;
  double _defaultQty = 1.0;
  bool _isPrinterConnected = false;
  String _paperSize = '80mm';
  final TextEditingController _receiptFooterController = TextEditingController();

  // ---------- تبويب الأمان ----------
  bool _pinEnabled = false;
  bool _biometricsEnabled = false;
  int _autoLockMinutes = 0;
  String _userEmail = '';
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obsOldPass = true;
  bool _obsNewPass = true;
  bool _obsConfPass = true;

  // ---------- خصوصية ----------
  bool _hideBalance = false;
  bool _showFullName = true;
  bool _showPhone = true;

  // ---------- تبويب الإشعارات ----------
  bool _notificationsEnabled = true;
  bool _salesNotifications = true;
  bool _stockNotifications = true;
  bool _offerNotifications = true;

  // ---------- تبويب المظهر ----------
  bool _appSounds = true;
  String _appLanguage = 'ar';

  // ---------- تبويب الولاء ----------
  bool _loyaltyEnabled = false;
  double _loyaltyPointsPerRiyal = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _receiptFooterController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _play(String type) => context.read<UiProvider>().playSound(type);

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final wallet = context.read<WalletProvider>();
    final settings = context.read<SettingsProvider>();
    final auth = context.read<AuthProvider>();

    await wallet.loadUserEmail();

    setState(() {
      // طباعة
      _autoPrintEnabled = prefs.getBool('agent_autoPrint') ?? false;
      _defaultQty = prefs.getDouble('agent_defaultQty') ?? 1.0;
      _receiptFooterController.text =
          prefs.getString('agent_receiptFooter') ?? 'شكراً لتعاملكم معنا';
      _isPrinterConnected = prefs.getBool('agent_printer_connected') ?? false;
      _paperSize = prefs.getString('agent_paperSize') ?? '80mm';

      // أمان
      _biometricsEnabled = wallet.isBiometricCurrentlyEnabled;
      _autoLockMinutes = prefs.getInt('agent_autoLockMinutes') ?? 0;
      _pinEnabled = wallet.isPinEnabled;
      _userEmail = wallet.currentUserEmail ?? '';
      _emailController.text = _userEmail;

      // خصوصية
      _hideBalance = wallet.privacyHideBalance;
      _showFullName = wallet.privacyShowFullName;
      _showPhone = wallet.currentUserPrivacyShowPhone;

      // إشعارات
      _notificationsEnabled = prefs.getBool('agent_notifications_enabled') ?? true;
      _salesNotifications = prefs.getBool('agent_sales_notifications') ?? true;
      _stockNotifications = prefs.getBool('agent_stock_notifications') ?? true;
      _offerNotifications = prefs.getBool('agent_offer_notifications') ?? true;

      // مظهر
      _appSounds = settings.isSoundEnabled;
      _appLanguage = settings.getLanguageSync();

      // ولاء
      _loyaltyEnabled = prefs.getBool('agent_loyaltyEnabled') ?? false;
      _loyaltyPointsPerRiyal = prefs.getDouble('agent_loyaltyPointsPerRiyal') ?? 1.0;

      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is int) await prefs.setInt(key, value);
  }

  // ========== تغيير رمز PIN ==========
  void _showPinChangeDialog(WalletProvider wallet) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool obsOld = true, obsNew = true, obsConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تغيير رمز PIN الشامل', textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الرمز يجب أن يكون 6 أرقام بالضبط.'),
                  const SizedBox(height: 12),
                  _buildPinField(
                    controller: oldPinController,
                    label: 'رمز PIN القديم',
                    obscure: obsOld,
                    onToggle: () => setDialogState(() => obsOld = !obsOld),
                  ),
                  const SizedBox(height: 10),
                  _buildPinField(
                    controller: newPinController,
                    label: 'رمز PIN الجديد',
                    obscure: obsNew,
                    onToggle: () => setDialogState(() => obsNew = !obsNew),
                  ),
                  const SizedBox(height: 10),
                  _buildPinField(
                    controller: confirmPinController,
                    label: 'تأكيد رمز PIN الجديد',
                    obscure: obsConfirm,
                    onToggle: () => setDialogState(() => obsConfirm = !obsConfirm),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final oldPin = oldPinController.text.trim();
                  final newPin = newPinController.text.trim();
                  final confirmPin = confirmPinController.text.trim();

                  if (newPin.length != 6) {
                    _showToast('يجب أن يتكون الرمز من 6 أرقام');
                    return;
                  }
                  if (newPin != confirmPin) {
                    _showToast('الرمز الجديد غير متطابق');
                    return;
                  }

                  final result = await wallet.changeUserPinWithOld(
                      oldPin, newPin, confirmPin);
                  Navigator.pop(ctx);
                  _showToast(result);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }

  // ========== تغيير كلمة المرور ==========
  void _changePassword(WalletProvider wallet) {
    final oldPass = _oldPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

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

    final success = wallet.changeUserPassword(oldPass, newPass);
    if (success) {
      _showToast('تم تغيير كلمة المرور بنجاح');
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } else {
      _showToast('كلمة المرور القديمة غير صحيحة');
    }
  }

  // ========== تفعيل البصمة الحقيقية ==========
  Future<void> _toggleBiometric(bool value, WalletProvider wallet) async {
    if (value) {
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'يرجى تأكيد هويتك لتفعيل الدخول بالبصمة',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        if (authenticated) {
          wallet.toggleBiometric(true);
          setState(() => _biometricsEnabled = true);
          _play('success');
          _showToast('تم تفعيل الدخول بالبصمة بنجاح! 🔒');
        } else {
          _showToast('فشل التحقق من البصمة');
        }
      } catch (e) {
        _showToast('جهازك لا يدعم البصمة أو أنها غير معدّة.');
      }
    } else {
      wallet.toggleBiometric(false);
      setState(() => _biometricsEnabled = false);
      _play('success');
      _showToast('تم إيقاف الدخول بالبصمة.');
    }
  }

  // ========== طباعة اختبار PDF ==========
  Future<void> _printTestPage() async {
    _play('click');
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Text('صفحة اختبار الطباعة من تطبيق كروت نت',
              style: pw.TextStyle(fontSize: 20)),
        ),
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } else {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/test_print.pdf');
      await file.writeAsBytes(await pdf.save());
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'اختبار_الطباعة.pdf');
    }
    _showToast('تم فتح نافذة الطباعة');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textDirection: TextDirection.rtl)),
    );
  }

  // ========== الواجهة الأساسية ==========
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = context.watch<ThemeProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = theme.primaryColor;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const CustomHeader(title: 'إعدادات الوكيل'),
      drawer: CustomAgentDrawer(
        agentName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'وكيل معتمد',
        currentBalance: wallet.currentUserBalance,
      ),
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
                onTap: (index) => _play('click'),
                tabs: const [
                  Tab(icon: Icon(Icons.security), text: 'الأمان والجلسة'),
                  Tab(icon: Icon(Icons.print), text: 'الطباعة والمبيعات'),
                  Tab(icon: Icon(Icons.notifications), text: 'الإشعارات'),
                  Tab(icon: Icon(Icons.color_lens), text: 'المظهر واللغة'),
                  Tab(icon: Icon(Icons.sync), text: 'النظام والأدوات'),
                  Tab(icon: Icon(Icons.card_giftcard), text: 'الولاء والمكافآت'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSecurityTab(wallet, settings, primaryColor, colorScheme),
                  _buildPrinterTab(settings, primaryColor, colorScheme),
                  _buildNotificationsTab(primaryColor, colorScheme),
                  _buildAppearanceTab(theme, settings, primaryColor, colorScheme),
                  _buildSystemTab(wallet, primaryColor, colorScheme),
                  _buildLoyaltyTab(auth, wallet, primaryColor, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- تبويب الأمان والجلسة ----------
  Widget _buildSecurityTab(WalletProvider wallet, SettingsProvider settings,
      Color primaryColor, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('رمز PIN الشامل', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.lock_outline, color: primaryColor),
                title: Text('تغيير رمز PIN',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text(
                    'الرمز الحالي: ${wallet.currentUserPin.isNotEmpty && wallet.currentUserPin.length == 6 ? "******" : "غير معين"}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: colorScheme.onSurfaceVariant),
                onTap: () {
                  _play('click');
                  _showPinChangeDialog(wallet);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.security, color: primaryColor),
                title: Text('تفعيل رمز PIN للعمليات',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('طلب الرمز عند الشحن والتحويل والبيع',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _pinEnabled,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _play('click');
                  await wallet.togglePinEnabled(val);
                  setState(() => _pinEnabled = val);
                  _showToast(val
                      ? 'تم تفعيل طلب رمز PIN للعمليات'
                      : 'تم تعطيل طلب رمز PIN للعمليات');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('تغيير كلمة المرور', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPasswordField(
                    controller: _oldPasswordController,
                    hint: 'كلمة المرور الحالية',
                    icon: Icons.lock_outline,
                    obscure: _obsOldPass,
                    onToggle: () => setState(() => _obsOldPass = !_obsOldPass)),
                const SizedBox(height: 10),
                _buildPasswordField(
                    controller: _newPasswordController,
                    hint: 'كلمة المرور الجديدة',
                    icon: Icons.lock,
                    obscure: _obsNewPass,
                    onToggle: () => setState(() => _obsNewPass = !_obsNewPass)),
                const SizedBox(height: 10),
                _buildPasswordField(
                    controller: _confirmPasswordController,
                    hint: 'تأكيد كلمة المرور الجديدة',
                    icon: Icons.check_circle_outline,
                    obscure: _obsConfPass,
                    onToggle: () => setState(() => _obsConfPass = !_obsConfPass)),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      _play('click');
                      _changePassword(wallet);
                    },
                    child: const Text('تغيير كلمة المرور',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('أمان الجلسة', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(Icons.fingerprint, color: primaryColor),
                title: Text('تسجيل الدخول بالبصمة',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('استخدام بصمة الإصبع للدخول السريع',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _biometricsEnabled,
                activeColor: primaryColor,
                onChanged: (val) => _toggleBiometric(val, wallet),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.lock_clock, color: primaryColor),
                title: Text('القفل التلقائي للجلسة',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text(
                    _autoLockMinutes == 0 ? 'معطل' : 'بعد $_autoLockMinutes دقيقة من الخمول',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                    _play('click');
                    setState(() => _autoLockMinutes = val);
                    await _saveSetting('agent_autoLockMinutes', val);
                    _showToast(val == 0 ? 'تم تعطيل القفل التلقائي' : 'تم تعيين القفل بعد $val دقيقة');
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('البريد الإلكتروني', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: ListTile(
            leading: Icon(Icons.email, color: primaryColor),
            title: Text('البريد الإلكتروني',
                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            subtitle: Text(_userEmail.isEmpty ? 'غير مضاف' : _userEmail,
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            trailing: Icon(Icons.edit, color: colorScheme.onSurfaceVariant),
            onTap: () => _showEmailDialog(wallet),
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('الخصوصية', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(Icons.visibility_off, color: primaryColor),
                title: Text('إخفاء الرصيد عن المستخدمين',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('لن يظهر رصيدك عند البحث عنك للتحويل',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _hideBalance,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _play('click');
                  await wallet.updatePrivacySetting('hideBalance', val);
                  setState(() => _hideBalance = val);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.badge, color: primaryColor),
                title: Text('إخفاء الاسم الكامل',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('سيظهر اسمك الأول فقط أو "وكيل معتمد"',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: !_showFullName,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _play('click');
                  await wallet.updatePrivacySetting('showFullName', !val);
                  setState(() => _showFullName = !val);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.phone_disabled, color: primaryColor),
                title: Text('إخفاء رقم الهاتف',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('لن يظهر رقم هاتفك للمستخدمين الآخرين',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: !_showPhone,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _play('click');
                  await wallet.updatePrivacySetting('showPhone', !val);
                  setState(() => _showPhone = !val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('الجلسة', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text('تسجيل الخروج',
                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            subtitle: Text('إنهاء الجلسة الحالية',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 14, color: colorScheme.onSurfaceVariant),
            onTap: () {
              _play('click');
              _showLogoutDialog();
            },
          ),
        ),
      ],
    );
  }

  // ---------- تبويب الطباعة والمبيعات ----------
  Widget _buildPrinterTab(SettingsProvider settings, Color primaryColor,
      ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('حالة الطابعة', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: SwitchListTile(
            secondary: Icon(
                kIsWeb ? Icons.picture_as_pdf : Icons.bluetooth_connected,
                color: _isPrinterConnected ? Colors.green : Colors.grey),
            title: Text(kIsWeb ? 'تفعيل الطباعة (PDF)' : 'الاتصال بالطابعة',
                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            subtitle: Text(_isPrinterConnected ? 'جاهز للطباعة' : 'غير مفعّل',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            value: _isPrinterConnected,
            activeColor: primaryColor,
            onChanged: (val) async {
              _play('click');
              setState(() => _isPrinterConnected = val);
              await _saveSetting('agent_printer_connected', val);
              await settings.setPrinterConnected(val);
              _showToast(val ? 'تم تفعيل الطباعة' : 'تم تعطيل الطباعة');
            },
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('تفضيلات الطباعة', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              SwitchListTile(
                title: Text('الطباعة التلقائية فور البيع',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('تجاوز نافذة التأكيد',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                activeColor: primaryColor,
                value: _autoPrintEnabled,
                onChanged: (val) {
                  _play('click');
                  setState(() => _autoPrintEnabled = val);
                  _saveSetting('agent_autoPrint', val);
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الكمية الافتراضية: ${_defaultQty.toInt()} كروت',
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    Slider(
                      value: _defaultQty,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: primaryColor,
                      label: _defaultQty.toInt().toString(),
                      onChanged: (val) {
                        setState(() => _defaultQty = val);
                        _saveSetting('agent_defaultQty', val);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text('حجم الورق',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text(_paperSize == '80mm' ? 'ورق حراري 80 مم' : 'ورق A4'),
                trailing: DropdownButton<String>(
                  value: _paperSize,
                  items: const [
                    DropdownMenuItem(value: '80mm', child: Text('80mm (ورق حراري)')),
                    DropdownMenuItem(value: 'A4', child: Text('A4 (ورق عادي)')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    _play('click');
                    setState(() => _paperSize = val);
                    _saveSetting('agent_paperSize', val);
                    _showToast(val == '80mm' ? 'تم اختيار ورق حراري' : 'تم اختيار ورق A4');
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _receiptFooterController,
                  decoration: InputDecoration(
                    labelText: 'تذييل الفاتورة',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.text_fields),
                  ),
                  onChanged: (val) => _saveSetting('agent_receiptFooter', val),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _printTestPage,
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة صفحة اختبار'),
                  ),
                ),
              ),
            ],
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
        _sectionTitle('إعدادات الإشعارات', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(Icons.notifications_active, color: primaryColor),
                title: Text('تفعيل الإشعارات',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('استلام إشعارات داخل التطبيق',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _notificationsEnabled,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _play('click');
                  setState(() => _notificationsEnabled = val);
                  await _saveSetting('agent_notifications_enabled', val);
                  _showToast(val ? 'تم تفعيل الإشعارات' : 'تم تعطيل الإشعارات');
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.point_of_sale, color: primaryColor),
                title: Text('إشعارات المبيعات',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('إيصال بعد كل عملية بيع',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _salesNotifications,
                activeColor: primaryColor,
                onChanged: _notificationsEnabled
                    ? (val) async {
                        _play('click');
                        setState(() => _salesNotifications = val);
                        await _saveSetting('agent_sales_notifications', val);
                      }
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.inventory, color: primaryColor),
                title: Text('إشعارات انخفاض المخزون',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('عند وصول المخزون للحد الأدنى',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _stockNotifications,
                activeColor: primaryColor,
                onChanged: _notificationsEnabled
                    ? (val) async {
                        _play('click');
                        setState(() => _stockNotifications = val);
                        await _saveSetting('agent_stock_notifications', val);
                      }
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.campaign, color: primaryColor),
                title: Text('إشعارات العروض والتحديثات',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('العروض الجديدة من الإدارة',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _offerNotifications,
                activeColor: primaryColor,
                onChanged: _notificationsEnabled
                    ? (val) async {
                        _play('click');
                        setState(() => _offerNotifications = val);
                        await _saveSetting('agent_offer_notifications', val);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- تبويب المظهر واللغة ----------
  Widget _buildAppearanceTab(
      ThemeProvider theme,
      SettingsProvider settings,
      Color primaryColor,
      ColorScheme colorScheme) {
    final isDark = theme.isDarkMode;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('المظهر العام', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.brightness_6, color: primaryColor),
                title: Text('الوضع الليلي',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text(isDark ? 'داكن' : 'فاتح',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: DropdownButton<String>(
                  value: isDark ? 'dark' : 'light',
                  items: const [
                    DropdownMenuItem(value: 'light', child: Text('فاتح')),
                    DropdownMenuItem(value: 'dark', child: Text('داكن')),
                    DropdownMenuItem(value: 'auto', child: Text('تلقائي')),
                  ],
                  onChanged: (val) {
                    _play('click');
                    if (val == 'auto') {
                      final brightness = MediaQuery.of(context).platformBrightness;
                      theme.toggleTheme(brightness == Brightness.dark);
                    } else {
                      theme.toggleTheme(val == 'dark');
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.language, color: primaryColor),
                title: Text('لغة التطبيق',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text(_appLanguage == 'ar' ? 'العربية' : 'English',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: DropdownButton<String>(
                  value: _appLanguage,
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    _play('click');
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
                secondary: Icon(Icons.volume_up, color: primaryColor),
                title: Text('الأصوات التفاعلية',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('أصوات النقرات والعمليات',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _appSounds,
                activeColor: primaryColor,
                onChanged: (val) {
                  _play('click');
                  setState(() => _appSounds = val);
                  settings.setSoundEnabled(val);
                  _showToast(val ? 'تم تفعيل الأصوات' : 'تم كتم الأصوات');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('تخصيص لون الواجهة', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('لونك المفضل:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    CircleAvatar(
                      backgroundColor: primaryColor,
                      radius: 20,
                      child: primaryColor == Colors.white
                          ? const Icon(Icons.palette, color: Colors.grey)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200, width: 2)),
                    child: ColorPicker(
                      pickerColor: primaryColor,
                      onColorChanged: (color) => theme.changeColor(color),
                      paletteType: PaletteType.hsvWithHue,
                      enableAlpha: false,
                      displayThumbColor: true,
                      labelTypes: const [],
                      pickerAreaBorderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const Divider(height: 30),
                TextButton.icon(
                  onPressed: () {
                    _play('click');
                    theme.resetToDefault();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.blueGrey),
                  label: const Text('استعادة المظهر الافتراضي',
                      style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('حجم الخط', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('صغير', style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
                Expanded(
                  child: Slider(
                    value: theme.fontSizeScale,
                    min: 0.8,
                    max: 1.5,
                    divisions: 7,
                    label: theme.fontSizeScale.toStringAsFixed(2),
                    activeColor: primaryColor,
                    onChanged: (val) {
                      theme.changeFontSizeScale(val);
                    },
                  ),
                ),
                Text('كبير', style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- تبويب النظام والأدوات ----------
  Widget _buildSystemTab(WalletProvider wallet, Color primaryColor,
      ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('أدوات النظام', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                title: Text('تنظيف الذاكرة المؤقتة',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('يساعد في تسريع التطبيق',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: colorScheme.onSurfaceVariant),
                onTap: () {
                  _play('click');
                  imageCache.clear();
                  imageCache.clearLiveImages();
                  PaintingBinding.instance.imageCache.clear();
                  _showToast('تم تنظيف الذاكرة المؤقتة 🚀');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_sync, color: Colors.blue),
                title: Text('فرض المزامنة',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('سحب أحدث بيانات من السيرفر',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: colorScheme.onSurfaceVariant),
                onTap: () async {
                  _play('click');
                  showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (c) => const Center(child: CircularProgressIndicator()));
                  await wallet.loadUserEmail();
                  if (mounted) Navigator.pop(context);
                  _showToast('تمت مزامنة البيانات بنجاح 🔄');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('معلومات', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
                title: Text('إصدار التطبيق: 2.0.0',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.policy, color: colorScheme.onSurfaceVariant),
                title: Text('سياسة الخصوصية',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.open_in_new, size: 16, color: colorScheme.onSurfaceVariant),
                onTap: () async {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- تبويب الولاء والمكافآت ----------
  Widget _buildLoyaltyTab(AuthProvider auth, WalletProvider wallet,
      Color primaryColor, ColorScheme colorScheme) {
    final agentPhone = auth.activeUserPhone ?? '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('إعدادات الولاء', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(Icons.card_giftcard, color: primaryColor),
                title: Text('تفعيل نظام الولاء',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('سيتمكن المستخدمون من جمع نقاط مقابل مشترياتهم',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _loyaltyEnabled,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _play('click');
                  setState(() => _loyaltyEnabled = val);
                  await _saveSetting('agent_loyaltyEnabled', val);
                  // تحديث Firestore
                  await _db.collection('users').doc(agentPhone).update({
                    'loyaltyEnabled': val,
                  });
                  _showToast(val ? 'تم تفعيل نظام الولاء' : 'تم تعطيل نظام الولاء');
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: Text('النقاط لكل 1 ريال',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                subtitle: Text('يكسب المستخدم ${_loyaltyPointsPerRiyal.toStringAsFixed(1)} نقطة مقابل كل ريال',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: DropdownButton<double>(
                  value: _loyaltyPointsPerRiyal,
                  items: const [
                    DropdownMenuItem(value: 0.5, child: Text('0.5 نقطة')),
                    DropdownMenuItem(value: 1.0, child: Text('1 نقطة')),
                    DropdownMenuItem(value: 2.0, child: Text('2 نقطة')),
                    DropdownMenuItem(value: 5.0, child: Text('5 نقطة')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    _play('click');
                    setState(() => _loyaltyPointsPerRiyal = val);
                    await _saveSetting('agent_loyaltyPointsPerRiyal', val);
                    await _db.collection('users').doc(agentPhone).update({
                      'loyaltyPointsPerRiyal': val,
                    });
                    _showToast('تم تعيين $val نقطة لكل ريال');
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('المكافآت المتاحة للاستبدال', colorScheme.onSurface),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              // قائمة المكافآت
              StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('loyalty_rewards')
                    .where('agentPhone', isEqualTo: agentPhone)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final rewards = snapshot.data?.docs ?? [];
                  if (rewards.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('لا توجد مكافآت مضافة بعد',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: rewards.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(data['color'] ?? 0xFF009688),
                          child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
                        ),
                        title: Text(data['name'] ?? '',
                            style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                        subtitle: Text('${data['points']} نقطة',
                            style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.delete, color: colorScheme.error),
                              onPressed: () => _deleteReward(doc.id),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const Divider(height: 1),
              // زر إضافة مكافأة جديدة
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddRewardDialog(agentPhone, wallet),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة مكافأة جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- حوار إضافة مكافأة ----------
  void _showAddRewardDialog(String agentPhone, WalletProvider wallet) {
    final nameController = TextEditingController();
    final pointsController = TextEditingController();
    String? selectedCategoryId;
    Color selectedColor = Colors.teal;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('إضافة مكافأة جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المكافأة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pointsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'النقاط المطلوبة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // اختيار الفئة
                  FutureBuilder<QuerySnapshot>(
                    future: _db
                        .collection('networks')
                        .where('agentPhone', isEqualTo: agentPhone)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      List<DropdownMenuItem<String>> items = [];
                      for (var netDoc in snapshot.data!.docs) {
                        final categories = List<Map<String, dynamic>>.from(
                            (netDoc.data() as Map)['categories'] ?? []);
                        for (var cat in categories) {
                          items.add(DropdownMenuItem(
                            value: cat['id'],
                            child: Text(cat['name'] ?? ''),
                          ));
                        }
                      }
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'اختر الفئة',
                          border: OutlineInputBorder(),
                        ),
                        items: items,
                        onChanged: (val) {
                          selectedCategoryId = val;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('اللون: '),
                      GestureDetector(
                        onTap: () async {
                          final color = await showDialog<Color>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              content: ColorPicker(
                                pickerColor: selectedColor,
                                onColorChanged: (c) => selectedColor = c,
                                enableAlpha: false,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('إلغاء'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(c, selectedColor),
                                  child: const Text('اختيار'),
                                ),
                              ],
                            ),
                          );
                          if (color != null) {
                            setDialogState(() => selectedColor = color);
                          }
                        },
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selectedColor,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final name = nameController.text.trim();
                  final points = int.tryParse(pointsController.text.trim());
                  if (name.isEmpty || points == null || selectedCategoryId == null) {
                    _showToast('يرجى تعبئة جميع الحقول');
                    return;
                  }
                  setDialogState(() => isSubmitting = true);
                  try {
                    await _db.collection('loyalty_rewards').add({
                      'name': name,
                      'points': points,
                      'color': selectedColor.value,
                      'agentPhone': agentPhone,
                      'categoryId': selectedCategoryId,
                      'isActive': true,
                      'stock': 10,
                    });
                    Navigator.pop(ctx);
                    _showToast('تم إضافة المكافأة بنجاح 🎉');
                  } catch (e) {
                    setDialogState(() => isSubmitting = false);
                    _showToast('فشل إضافة المكافأة');
                  }
                },
                child: isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- حذف مكافأة ----------
  Future<void> _deleteReward(String docId) async {
    _play('click');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المكافأة'),
          content: const Text('هل أنت متأكد من حذف هذه المكافأة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      await _db.collection('loyalty_rewards').doc(docId).delete();
      _showToast('تم حذف المكافأة');
    }
  }

  // ---------- دوال مساعدة ----------
  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: Colors.blueGrey),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  // ---------- حوار البريد الإلكتروني ----------
  void _showEmailDialog(WalletProvider wallet) {
    final controller = TextEditingController(text: _userEmail);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                _play('click');
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
                _showToast(email.isEmpty ? 'تم حذف البريد الإلكتروني' : 'تم حفظ البريد الإلكتروني');
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- حوار تسجيل الخروج ----------
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.orange)),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                _play('click');
                final auth = context.read<AuthProvider>();
                auth.clearAllData();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SSOLoginScreen()),
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
}
