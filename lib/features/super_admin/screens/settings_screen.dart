import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:local_auth/local_auth.dart'; // 👈 مكتبة البصمة الحقيقية
import 'package:shared_preferences/shared_preferences.dart'; // 👈 مكتبة الحفظ المحلي

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 👈 متغيرات مؤقتة لتبويب المظهر (حتى لا تتغير فوراً إلا بعد الحفظ)
  bool _isInit = false;
  String _tempFont = 'System';
  double _tempFontSize = 1.0;
  bool _tempDarkMode = false;

  // 👈 متغيرات تبويب الأمان
  bool _soundsEnabled = true;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLocalSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final tp = Provider.of<ThemeProvider>(context, listen: false);
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

  // تحميل إعدادات الصوت من ذاكرة الهاتف
  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundsEnabled = prefs.getBool('soundsEnabled') ?? true;
    });
  }

  void _showSnack(String m, {bool isSuccess = true}) {
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m, textDirection: TextDirection.rtl), backgroundColor: isSuccess ? Colors.green : Colors.red)
      );
    }
  }

  // ==========================================
  // النوافذ التفاعلية الحقيقية (تتصل بالخوادم) 🌐
  // ==========================================

  void _showColorPickerDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Color pickerColor = themeProvider.primaryColor;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تخصيص مظهر لوحتك الشخصية 🎨', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) => pickerColor = color,
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithHue,
              labelTypes: const [], 
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                themeProvider.resetToDefault();
                Navigator.pop(context);
                _showSnack('تمت العودة للون الرسمي الأبيض.', isSuccess: true);
              },
              child: const Text('استعادة الافتراضي', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
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

  void _showEditNameDialog(SystemProvider systemProvider) {
    TextEditingController nameController = TextEditingController(text: systemProvider.currentUserName);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير الاسم الرباعي', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'الاسم الجديد', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                bool success = await systemProvider.changeUserName(nameController.text);
                if(mounted){
                  Navigator.pop(context);
                  _showSnack(success ? 'تم تحديث الاسم بنجاح! ✅' : 'فشل التحديث', isSuccess: success);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPasswordDialog(SystemProvider systemProvider) {
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
            title: const Text('تغيير كلمة المرور 🔐', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  if (newPass.text != confirmPass.text) {
                    _showSnack('كلمة المرور غير متطابقة!', isSuccess: false);
                    return;
                  }
                  bool success = systemProvider.changeUserPassword(oldPass.text, newPass.text);
                  Navigator.pop(context);
                  if (success) {
                    _showSnack('تم تغيير كلمة المرور بنجاح!', isSuccess: true);
                  } else {
                    _showSnack('كلمة المرور القديمة خاطئة!', isSuccess: false);
                  }
                },
                child: const Text('تأكيد التغيير', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPinDialog(SystemProvider systemProvider) {
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
            title: const Text('تغيير رمز PIN السريع 🔢', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('يُستخدم لحماية العمليات الحساسة (مثل الحذف والخصم).', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
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
                  if (newPin.text != confirmPin.text) {
                    _showSnack('الرمز غير متطابق!', isSuccess: false);
                    return;
                  }
                  bool success = await systemProvider.changeUserPin(oldPin.text, newPin.text);
                  if(mounted){
                    Navigator.pop(context);
                    if (success) {
                      _showSnack('تم تحديث رمز PIN بنجاح! ✅', isSuccess: true);
                    } else {
                      _showSnack('رمز PIN القديم خاطئ!', isSuccess: false);
                    }
                  }
                },
                child: const Text('تحديث الرمز', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
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
          content: TextField(controller: controller, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () { onSave(controller.text); Navigator.pop(context); }, child: const Text('حفظ التعديلات')),
          ],
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
          title: const Row(children: [Icon(Icons.campaign, color: Colors.orange), SizedBox(width: 8), Text('تعديل الشريط العلوي العام', style: TextStyle(fontSize: 15))]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هذا النص سيظهر في الشريط المتحرك أعلى كل الشاشات لجميع المستخدمين.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              TextField(controller: marqueeCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'اكتب إعلانك أو ترحيبك هنا...', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (marqueeCtrl.text.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('system').doc('main_info').update({
                    'announcements': [marqueeCtrl.text]
                  });
                  if(mounted){
                    Navigator.pop(context);
                    _showSnack('تم تغيير نص الشريط العلوي بنجاح!', isSuccess: true);
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

  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color safeActiveColor = themeProvider.primaryColor == const Color(0xFFFFFFFF) ? Colors.blueAccent : themeProvider.primaryColor;

    return Scaffold(
      appBar: const CustomHeader(title: 'إعدادات النظام الشخصية'),
      drawer: CustomDrawer(
        userName: systemProvider.currentUserName, 
        phoneNumber: systemProvider.currentUserPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${systemProvider.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: Colors.transparent,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: safeActiveColor, 
                unselectedLabelColor: Colors.grey,
                indicatorColor: safeActiveColor,
                tabs: const [
                  Tab(icon: Icon(Icons.palette), text: 'المظهر والخطوط'),
                  Tab(icon: Icon(Icons.security), text: 'الملف والأمان'), 
                  Tab(icon: Icon(Icons.settings_input_component), text: 'حالة النظام'),
                  Tab(icon: Icon(Icons.gavel), text: 'السياسات والحدود'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAppearanceTab(themeProvider, safeActiveColor),
                  _buildSecurityTab(systemProvider, safeActiveColor),
                  _buildSystemStatusTab(systemProvider),
                  _buildPolicyTab(systemProvider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. تبويب المظهر والخطوط 🎨 
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
                // 👈 ملاحظة هامة للمالك
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber)),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(child: Text('تنبيه: التعديلات في هذا القسم تنعكس على جهازك أنت فقط (اللوحة الشخصية للمالك) لتخصيص راحتك البصرية.', style: TextStyle(fontSize: 12, color: Colors.black87))),
                    ],
                  ),
                ),
                
                _buildSectionTitle('تخصيص ألوان الواجهة الخاصة بك'),
                const SizedBox(height: 10),
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.color_lens, color: safeActiveColor, size: 30),
                    title: const Text('دائرة الألوان الاحترافية', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('قم باختيار لونك المفضل ليتغير مظهر لوحتك بالكامل'),
                    trailing: ElevatedButton(
                      onPressed: () => _showColorPickerDialog(context),
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
                          // 👈 تمت زيادة الخطوط الاحترافية
                          items: ['System', 'Cairo', 'Tajawal', 'Almarai', 'Changa', 'Lalezar', 'Readex Pro', 'IBM Plex Sans Arabic']
                              .map((String font) => DropdownMenuItem(value: font, child: Text(font))).toList(),
                          onChanged: (val) { if (val != null) setState(() => _tempFont = val); },
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.format_size, color: Colors.orange),
                        title: const Text('حجم الخط العام'),
                        subtitle: Slider(
                          value: _tempFontSize, min: 0.8, max: 1.5, divisions: 7, label: _tempFontSize.toStringAsFixed(1),
                          onChanged: (val) => setState(() => _tempFontSize = val),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 40),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode, color: Colors.indigo),
                  title: const Text('تفعيل الوضع الليلي (Dark Mode)'),
                  value: _tempDarkMode, 
                  onChanged: (val) => setState(() => _tempDarkMode = val),
                ),
              ],
            ),
          ),
        ),
        
        // 👈 زر الحفظ الجديد
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('حفظ إعدادات المظهر', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: () {
              themeProvider.changeFontFamily(_tempFont);
              themeProvider.changeFontSizeScale(_tempFontSize);
              themeProvider.toggleTheme(_tempDarkMode);
              _showSnack('تم حفظ المظهر والخطوط بنجاح!', isSuccess: true);
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. تبويب الأمان والبيانات الشخصية 🔐 
  // ==========================================
  Widget _buildSecurityTab(SystemProvider systemProvider, Color safeActiveColor) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('الملف الشخصي للمالك'),
                const SizedBox(height: 10),
                _buildInteractiveCard(Icons.person, 'الاسم الرباعي', systemProvider.currentUserName, () => _showEditNameDialog(systemProvider)),
                
                const Divider(height: 30),
                _buildSectionTitle('إعدادات الأمان والحماية'),
                const SizedBox(height: 10),
                _buildInteractiveCard(Icons.lock_reset, 'كلمة المرور', '********', () => _showEditPasswordDialog(systemProvider), color: Colors.redAccent),
                _buildInteractiveCard(Icons.pin, 'رمز PIN السريع', '******', () => _showEditPinDialog(systemProvider), color: Colors.orange),
                
                const SizedBox(height: 10),
                Card(
                  elevation: 1,
                  child: Column(
                    children: [
                      // 👈 ميزة البصمة الحقيقية تم ربطها هنا
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint, color: Colors.green),
                        title: const Text('الدخول بالبصمة (Biometrics)'),
                        subtitle: const Text('المصادقة بمستشعر الهاتف', style: TextStyle(fontSize: 11)),
                        value: systemProvider.isBiometricCurrentlyEnabled, 
                        onChanged: (val) async {
                          if (val) {
                            try {
                              bool authenticated = await _localAuth.authenticate(
                                localizedReason: 'يرجى تأكيد هويتك لتفعيل الدخول بالبصمة',
                                options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
                              );
                              if (authenticated) {
                                systemProvider.toggleBiometric(true);
                                _showSnack('تم تفعيل البصمة بنجاح! 🔒', isSuccess: true);
                              } else {
                                _showSnack('تم إلغاء التفعيل.', isSuccess: false);
                              }
                            } catch (e) {
                              _showSnack('عذراً، جهازك لا يدعم البصمة أو أنها غير معدّة.', isSuccess: false);
                            }
                          } else {
                            systemProvider.toggleBiometric(false);
                            _showSnack('تم إيقاف الدخول بالبصمة.', isSuccess: true);
                          }
                        }, 
                      ),
                      const Divider(height: 1),
                      // 👈 ميزة تشغيل/إيقاف الأصوات
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up, color: Colors.blue),
                        title: const Text('أصوات التطبيق (النقرات والإشعارات)'),
                        value: _soundsEnabled, 
                        onChanged: (val) => setState(() => _soundsEnabled = val), 
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 👈 زر الحفظ الجديد
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: safeActiveColor, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.security, color: Colors.white),
            label: const Text('حفظ إعدادات الأمان', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('soundsEnabled', _soundsEnabled);
              _showSnack('تم حفظ التغييرات بنجاح!', isSuccess: true);
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. تبويب حالة النظام والصيانة 🚧 
  // ==========================================
  Widget _buildSystemStatusTab(SystemProvider systemProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildActionCard(Icons.article, 'تعديل نص الشريط العلوي العام', 'تغيير الخبر المتحرك في أعلى التطبيق', onTap: () {
            _showGlobalMarqueeEditDialog();
          }),
          _buildActionCard(Icons.newspaper, 'نشر إشعار إداري داخلي', 'إرسال إشعار لمجموعات معينة', onTap: () {
            _showTextEditDialog('إشعار إداري', '', (text) => systemProvider.addTargetedNews(text: text, targetRole: 'الكل'));
          }),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.handyman, color: Colors.red),
            title: const Text('وضع الصيانة العامة 🚧'),
            subtitle: const Text('منع دخول الجميع وعرض رسالة الصيانة'),
            value: systemProvider.isMaintenanceMode,
            onChanged: (val) => systemProvider.updateSystemStatusSettings(maintenance: val, forcedUpdate: systemProvider.isForcedUpdate, showNews: systemProvider.showNewsBar),
            activeColor: Colors.red,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.system_update, color: Colors.blue),
            title: const Text('التحديث الإجباري ⚠️'),
            value: systemProvider.isForcedUpdate,
            onChanged: (val) => systemProvider.updateSystemStatusSettings(maintenance: systemProvider.isMaintenanceMode, forcedUpdate: val, showNews: systemProvider.showNewsBar),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.new_label, color: Colors.orange),
            title: const Text('إظهار شريط الأخبار 🚨'),
            value: systemProvider.showNewsBar,
            onChanged: (val) => systemProvider.updateSystemStatusSettings(maintenance: systemProvider.isMaintenanceMode, forcedUpdate: systemProvider.isForcedUpdate, showNews: val),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. تبويب السياسات والحدود ⚖️ 
  // ==========================================
  Widget _buildPolicyTab(SystemProvider systemProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.calculate, color: Colors.blueGrey),
            title: const Text('جبر كسور الصرافة آلياً'),
            value: systemProvider.isCurrencyAutoRounding,
            onChanged: (val) => systemProvider.updatePoliciesSettings(terms: systemProvider.termsAndConditions, support: systemProvider.supportNumbers, minCharge: systemProvider.minimumChargeLimit, autoRounding: val),
          ),
          _buildInteractiveCard(Icons.money_off, 'الحد الأدنى للشحن', '${systemProvider.minimumChargeLimit} ريال', () {
             _showTextEditDialog('تعديل الحد الأدنى للشحن', systemProvider.minimumChargeLimit, (val) => systemProvider.updatePoliciesSettings(terms: systemProvider.termsAndConditions, support: systemProvider.supportNumbers, minCharge: val, autoRounding: systemProvider.isCurrencyAutoRounding));
          }),
          _buildActionCard(Icons.description, 'الشروط والأحكام', 'تعديل سياسة الاستخدام للتطبيق', onTap: () {
            _showTextEditDialog('تعديل الشروط والأحكام', systemProvider.termsAndConditions, (val) => systemProvider.updatePoliciesSettings(terms: val, support: systemProvider.supportNumbers, minCharge: systemProvider.minimumChargeLimit, autoRounding: systemProvider.isCurrencyAutoRounding));
          }),
          _buildActionCard(Icons.support, 'أرقام الدعم الفني العام', 'تعديل أرقام التواصل', onTap: () {
            _showTextEditDialog('تعديل أرقام الدعم الفني', systemProvider.supportNumbers, (val) => systemProvider.updatePoliciesSettings(terms: systemProvider.termsAndConditions, support: val, minCharge: systemProvider.minimumChargeLimit, autoRounding: systemProvider.isCurrencyAutoRounding));
          }),
        ],
      ),
    );
  }

  // ==========================================
  // دوال مساعدة في التصميم (UI Helpers)
  // ==========================================

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey));
  }

  Widget _buildPassField(String hint, TextEditingController controller, bool isObscure, VoidCallback toggleEye, {bool isNumber = false, int? maxLength}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLength: maxLength,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        suffixIcon: IconButton(icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: toggleEye), 
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInteractiveCard(IconData icon, String title, String value, VoidCallback onTap, {Color color = Colors.blueAccent}) {
    return Card(
      elevation: 2, margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.3))),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
        trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: onTap),
        onTap: onTap,
      ),
    );
  }
}
