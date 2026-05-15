import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentSettingsScreen extends StatefulWidget {
  const AgentSettingsScreen({super.key});

  @override
  State<AgentSettingsScreen> createState() => _AgentSettingsScreenState();
}

class _AgentSettingsScreenState extends State<AgentSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // ========== تبويب الطباعة ==========
  bool _autoPrintEnabled = false;
  double _defaultQty = 1.0;
  final TextEditingController _receiptFooterController = TextEditingController();

  // ========== تبويب الأمان ==========
  bool _pinEnabled = false;          // تفعيل طلب PIN للعمليات
  bool _biometricsEnabled = false;
  bool _autoLockEnabled = false;

  // حقول تغيير كلمة المرور
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obsOldPass = true;
  bool _obsNewPass = true;
  bool _obsConfPass = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _receiptFooterController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final sys = Provider.of<SystemProvider>(context, listen: false);

    setState(() {
      _autoPrintEnabled = prefs.getBool('agent_autoPrint') ?? false;
      _defaultQty = prefs.getDouble('agent_defaultQty') ?? 1.0;
      _receiptFooterController.text =
          prefs.getString('agent_receiptFooter') ?? 'شكراً لتعاملكم معنا';

      _biometricsEnabled = prefs.getBool('agent_biometrics') ?? false;
      _autoLockEnabled = prefs.getBool('agent_autoLock') ?? false;
      _pinEnabled = sys.isPinEnabled;

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

  // ========== تغيير رمز PIN الشامل (6 أرقام - ثلاث حقول) ==========
  void _showPinChangeDialog(SystemProvider sys) {
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

                  final result = await sys.changeUserPinWithOld(oldPin, newPin, confirmPin);
                  if (result == 'تم تحديث رمز PIN بنجاح.') {
                    Navigator.pop(ctx);
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

  // ========== تغيير كلمة المرور (باستخدام SystemProvider) ==========
  void _changePassword(SystemProvider sys) {
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

    final success = sys.changeUserPassword(oldPass, newPass);
    if (success) {
      _showToast('تم تغيير كلمة المرور بنجاح');
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } else {
      _showToast('كلمة المرور القديمة غير صحيحة');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textDirection: TextDirection.rtl)),
    );
  }

  // ========== بناء الواجهة ==========
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final ui = Provider.of<UiProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = theme.primaryColor;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const CustomHeader(title: 'إعدادات الوكيل'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد',
        currentBalance: sys.currentUserBalance,
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
                  Tab(icon: Icon(Icons.print), text: 'الطباعة'),
                  Tab(icon: Icon(Icons.security), text: 'الأمان'),
                  Tab(icon: Icon(Icons.color_lens), text: 'المظهر'),
                  Tab(icon: Icon(Icons.sync), text: 'النظام'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPrinterTab(primaryColor, colorScheme),
                  _buildSecurityTab(sys, primaryColor, colorScheme),
                  _buildAppearanceTab(theme, ui, primaryColor, colorScheme),
                  _buildSystemTab(sys, primaryColor, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== تبويب الطباعة ==========
  Widget _buildPrinterTab(Color primaryColor, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('إعدادات الطباعة', colorScheme.onSurface),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              SwitchListTile(
                title: Text('الطباعة التلقائية فور البيع',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الكمية الافتراضية: ${_defaultQty.toInt()} كروت',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface)),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _receiptFooterController,
                  decoration: InputDecoration(
                    labelText: 'تذييل الفاتورة',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.text_fields),
                  ),
                  onChanged: (val) =>
                      _saveSetting('agent_receiptFooter', val),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '⚠️ ميزة الاتصال بالطابعة قيد التطوير حالياً',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== تبويب الأمان ==========
  Widget _buildSecurityTab(
      SystemProvider sys, Color primaryColor, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('رمز PIN الشامل', colorScheme.onSurface),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              // زر تغيير رمز PIN
              ListTile(
                leading: Icon(Icons.lock_outline, color: primaryColor),
                title: Text('تغيير رمز PIN',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('الرمز الحالي: ${sys.currentUserPin.isNotEmpty && sys.currentUserPin.length == 6 ? "******" : "غير معين"}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: colorScheme.onSurfaceVariant),
                onTap: () {
                  _play('click');
                  _showPinChangeDialog(sys);
                },
              ),
              const Divider(height: 1),
              // مفتاح تفعيل طلب PIN للعمليات
              SwitchListTile(
                secondary: Icon(Icons.security, color: primaryColor),
                title: Text('تفعيل رمز PIN للعمليات',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('طلب الرمز عند الشحن والتحويل والبيع',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _pinEnabled,
                activeColor: primaryColor,
                onChanged: (val) async {
                  _play('click');
                  await sys.togglePinEnabled(val);
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
        const SizedBox(height: 10),
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
                    onToggle: () =>
                        setState(() => _obsOldPass = !_obsOldPass)),
                const SizedBox(height: 10),
                _buildPasswordField(
                    controller: _newPasswordController,
                    hint: 'كلمة المرور الجديدة',
                    icon: Icons.lock,
                    obscure: _obsNewPass,
                    onToggle: () =>
                        setState(() => _obsNewPass = !_obsNewPass)),
                const SizedBox(height: 10),
                _buildPasswordField(
                    controller: _confirmPasswordController,
                    hint: 'تأكيد كلمة المرور الجديدة',
                    icon: Icons.check_circle_outline,
                    obscure: _obsConfPass,
                    onToggle: () =>
                        setState(() => _obsConfPass = !_obsConfPass)),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      _play('click');
                      _changePassword(sys);
                    },
                    child: const Text('تغيير كلمة المرور',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('أمان الجلسة', colorScheme.onSurface),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              SwitchListTile(
                title: Text('القفل التلقائي للجلسة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('قيد التطوير - غير مفعل حالياً',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                activeColor: primaryColor,
                value: _autoLockEnabled,
                onChanged: (_) {
                  _play('click');
                  _showToast('هذه الميزة قيد التطوير');
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text('تسجيل الدخول بالبصمة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('قيد التطوير - غير مفعل حالياً',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                activeColor: primaryColor,
                value: _biometricsEnabled,
                onChanged: (_) {
                  _play('click');
                  _showToast('هذه الميزة قيد التطوير');
                },
              ),
            ],
          ),
        ),
      ],
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
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  // ========== تبويب المظهر ==========
  Widget _buildAppearanceTab(ThemeProvider theme, UiProvider ui,
      Color primaryColor, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('تخصيص لون الواجهة', colorScheme.onSurface),
        const SizedBox(height: 10),
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface)),
                    CircleAvatar(
                        backgroundColor: primaryColor,
                        radius: 20,
                        child: primaryColor == Colors.white
                            ? const Icon(Icons.palette, color: Colors.grey)
                            : null),
                  ],
                ),
                const SizedBox(height: 15),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.grey.shade200, width: 2),
                    ),
                    child: ColorPicker(
                      pickerColor: primaryColor,
                      onColorChanged: (color) {
                        theme.changeColor(color);
                      },
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
                      style: TextStyle(
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('الأصوات', colorScheme.onSurface),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: SwitchListTile(
            secondary: const Icon(Icons.volume_up, color: Colors.purple),
            title: Text('أصوات التطبيق',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface)),
            subtitle: Text('صوت نجاح العمليات والتنبيهات',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            activeColor: primaryColor,
            value: ui.isSoundsEnabled,
            onChanged: (val) {
              _play('click');
              ui.updateSoundSettings(val);
            },
          ),
        ),
      ],
    );
  }

  // ========== تبويب النظام ==========
  Widget _buildSystemTab(
      SystemProvider sys, Color primaryColor, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('أدوات النظام', colorScheme.onSurface),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: colorScheme.surface,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                title: Text('تنظيف الذاكرة المؤقتة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('يساعد في تسريع التطبيق',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: colorScheme.onSurfaceVariant),
                onTap: () async {
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
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                subtitle: Text('سحب أحدث بيانات من السيرفر',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: colorScheme.onSurfaceVariant),
                onTap: () async {
                  _play('click');
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                  await sys.loadUserData(sys.currentUserPhone);
                  if (mounted) Navigator.pop(context);
                  _showToast('تمت مزامنة البيانات بنجاح 🔄');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
