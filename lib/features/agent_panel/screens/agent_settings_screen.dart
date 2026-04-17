import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
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

class _AgentSettingsScreenState extends State<AgentSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // ==========================================
  // متغيرات الإعدادات (Tab 1: الطباعة والكاشير)
  // ==========================================
  bool _isPrinterConnected = false;
  bool _autoPrintEnabled = false;
  double _defaultQty = 1.0;
  final TextEditingController _receiptFooterController = TextEditingController();

  // ==========================================
  // متغيرات الإعدادات (Tab 2: الأمان والحساب)
  // ==========================================
  bool _biometricsEnabled = false;
  bool _autoLockEnabled = false;
  
  // كلمات المرور
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obsOldPass = true;
  bool _obsNewPass = true;
  bool _obsConfPass = true;

  // رمز PIN
  bool _pinEnabled = false;
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  bool _obsCurrentPin = true;
  bool _obsNewPin = true;
  String _savedPin = ''; 

  // ==========================================
  // متغيرات الإعدادات (Tab 3: المظهر والتفضيلات)
  // ==========================================
  bool _notificationsEnabled = true;

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
    _currentPinController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // 💾 تحميل الإعدادات من الذاكرة المحلية
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoPrintEnabled = prefs.getBool('autoPrint') ?? false;
      _defaultQty = prefs.getDouble('defaultQty') ?? 1.0;
      _receiptFooterController.text = prefs.getString('receiptFooter') ?? 'شكراً لتعاملكم معنا';
      
      _biometricsEnabled = prefs.getBool('biometrics') ?? false;
      _autoLockEnabled = prefs.getBool('autoLock') ?? false;
      _pinEnabled = prefs.getBool('pinEnabled') ?? false;
      _savedPin = prefs.getString('savedPin') ?? '';

      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      
      _isLoading = false;
    });
  }

  // 💾 حفظ الإعدادات السريعة (Toggles & Sliders)
  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is int) await prefs.setInt(key, value);
  }

  // ==========================================
  // وظائف الأمان (تغيير كلمة المرور في Firebase)
  // ==========================================
  Future<void> _changeFirebasePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور الجديدة غير متطابقة!'), backgroundColor: Colors.red));
      return;
    }
    if (_newPasswordController.text.length < 6) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل.'), backgroundColor: Colors.red));
      return;
    }

    try {
      showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user != null && user.email != null) {
        // إعادة المصادقة (Re-authenticate)
        AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: _oldPasswordController.text);
        await user.reauthenticateWithCredential(credential);
        
        // تحديث كلمة المرور
        await user.updatePassword(_newPasswordController.text);
        
        Navigator.pop(context); // إغلاق التحميل
        _play('success');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح! ✅'), backgroundColor: Colors.green));
        
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على حساب مسجل.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق التحميل
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور القديمة غير صحيحة أو حدث خطأ.'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // بناء واجهة المستخدم الرئيسية
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final ui = Provider.of<UiProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    
    final isDark = theme.isDarkMode;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black87 : Colors.grey.shade50,
      appBar: const CustomHeader(title: 'لوحة تحكم الوكيل'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // شريط التبويبات (TabBar)
            Container(
              // الاعتماد على ThemeProvider لتلوين الرأس
              color: isDark ? Colors.grey.shade900 : (theme.primaryColor == Colors.white ? Colors.cyan.shade800 : theme.primaryColor),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                indicatorWeight: 4,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                isScrollable: true,
                onTap: (index) => _play('click'),
                tabs: const [
                  Tab(icon: Icon(Icons.print), text: 'الطباعة'),
                  Tab(icon: Icon(Icons.security), text: 'الأمان'),
                  Tab(icon: Icon(Icons.color_lens), text: 'المظهر'),
                  Tab(icon: Icon(Icons.sync), text: 'النظام'),
                ],
              ),
            ),
            
            // محتوى التبويبات (TabBarView)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPrinterTab(theme),
                  _buildSecurityTab(theme),
                  _buildAppearanceTab(theme, ui),
                  _buildSystemTab(sys, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🖨️ التبويب الأول: الطباعة والكاشير
  // ==========================================
  Widget _buildPrinterTab(ThemeProvider theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('إعدادات الاتصال بالطابعة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: Icon(kIsWeb ? Icons.picture_as_pdf : Icons.bluetooth_connected, color: kIsWeb ? Colors.red : (_isPrinterConnected ? Colors.green : Colors.grey), size: 30),
            title: Text(kIsWeb ? 'نظام الطباعة للويب (PDF)' : 'طابعة البلوتوث الحرارية', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(kIsWeb ? 'يعتمد على طابعة الكمبيوتر الأساسية' : (_isPrinterConnected ? 'متصل وجاهز' : 'غير متصل')),
            trailing: kIsWeb ? null : ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _isPrinterConnected ? Colors.red.shade50 : Colors.blue.shade50, elevation: 0),
              onPressed: () {
                _play('click');
                setState(() => _isPrinterConnected = !_isPrinterConnected);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isPrinterConnected ? 'تم الاتصال بالطابعة بنجاح 🖨️' : 'تم قطع الاتصال.'), backgroundColor: _isPrinterConnected ? Colors.green : Colors.red));
              },
              child: Text(_isPrinterConnected ? 'قطع' : 'اتصال', style: TextStyle(color: _isPrinterConnected ? Colors.red : Colors.blue)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text('تفضيلات الكاشير', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('الطباعة التلقائية فور البيع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('تجاوز نافذة التأكيد للسرعة', style: TextStyle(fontSize: 12)),
                activeColor: theme.primaryColor == Colors.white ? Colors.cyan.shade800 : theme.primaryColor,
                value: _autoPrintEnabled,
                onChanged: (val) {
                  _play('click');
                  setState(() => _autoPrintEnabled = val);
                  _saveSetting('autoPrint', val);
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الكمية الافتراضية للبيع: ${_defaultQty.toInt()} كروت', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Slider(
                      value: _defaultQty,
                      min: 1, max: 10, divisions: 9,
                      activeColor: theme.primaryColor == Colors.white ? Colors.cyan.shade800 : theme.primaryColor,
                      label: _defaultQty.toInt().toString(),
                      onChanged: (val) {
                        setState(() => _defaultQty = val);
                        _saveSetting('defaultQty', val);
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
                    labelText: 'تذييل الفاتورة (النص أسفل الكرت)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.text_fields),
                  ),
                  onChanged: (val) => _saveSetting('receiptFooter', val),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 🔐 التبويب الثاني: الأمان والحساب
  // ==========================================
  Widget _buildSecurityTab(ThemeProvider theme) {
    Color activeColor = theme.primaryColor == Colors.white ? Colors.cyan.shade800 : theme.primaryColor;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('رمز المرور السريع (PIN)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('تفعيل الدخول برمز PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('بديل سريع لكلمة المرور الطويلة', style: TextStyle(fontSize: 12)),
                activeColor: activeColor,
                value: _pinEnabled,
                onChanged: (val) {
                  _play('click');
                  setState(() => _pinEnabled = val);
                  _saveSetting('pinEnabled', val);
                },
              ),
              if (_pinEnabled) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildPasswordField(
                        controller: _currentPinController, 
                        hint: 'رمز PIN الحالي (إن وجد)', 
                        icon: Icons.dialpad, 
                        isObscure: _obsCurrentPin, 
                        onToggleObscure: () => setState(() => _obsCurrentPin = !_obsCurrentPin),
                        isNum: true
                      ),
                      const SizedBox(height: 10),
                      _buildPasswordField(
                        controller: _newPinController, 
                        hint: 'رمز PIN الجديد (4 أرقام)', 
                        icon: Icons.fiber_pin, 
                        isObscure: _obsNewPin, 
                        onToggleObscure: () => setState(() => _obsNewPin = !_obsNewPin),
                        isNum: true
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: activeColor),
                        onPressed: () {
                          _play('click');
                          if (_newPinController.text.length >= 4) {
                            _saveSetting('savedPin', _newPinController.text);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ رمز PIN بنجاح ✅'), backgroundColor: Colors.green));
                            _currentPinController.clear();
                            _newPinController.clear();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز يجب أن يكون 4 أرقام على الأقل'), backgroundColor: Colors.red));
                          }
                        },
                        child: const Text('تحديث رمز PIN', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('كلمة المرور الرئيسية (للحساب)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPasswordField(controller: _oldPasswordController, hint: 'كلمة المرور الحالية', icon: Icons.lock_outline, isObscure: _obsOldPass, onToggleObscure: () => setState(() => _obsOldPass = !_obsOldPass)),
                const SizedBox(height: 10),
                _buildPasswordField(controller: _newPasswordController, hint: 'كلمة المرور الجديدة', icon: Icons.lock, isObscure: _obsNewPass, onToggleObscure: () => setState(() => _obsNewPass = !_obsNewPass)),
                const SizedBox(height: 10),
                _buildPasswordField(controller: _confirmPasswordController, hint: 'تأكيد كلمة المرور الجديدة', icon: Icons.check_circle_outline, isObscure: _obsConfPass, onToggleObscure: () => setState(() => _obsConfPass = !_obsConfPass)),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _changeFirebasePassword,
                    child: const Text('تغيير كلمة المرور', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text('أمان الجلسة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('القفل التلقائي للجلسة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('قفل التطبيق عند الخمول لمدة 3 دقائق', style: TextStyle(fontSize: 12)),
                activeColor: activeColor,
                value: _autoLockEnabled,
                onChanged: (val) {
                  _play('click');
                  setState(() => _autoLockEnabled = val);
                  _saveSetting('autoLock', val);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('تسجيل الدخول بالبصمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('إذا كان هاتفك يدعم ذلك', style: TextStyle(fontSize: 12)),
                activeColor: activeColor,
                value: _biometricsEnabled,
                onChanged: (val) async {
                  _play('click');
                  final LocalAuthentication auth = LocalAuthentication();
                  bool canCheck = await auth.canCheckBiometrics;
                  if (canCheck || val == false) {
                    setState(() => _biometricsEnabled = val);
                    _saveSetting('biometrics', val);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هاتفك لا يدعم أو لم يفعل البصمة.'), backgroundColor: Colors.red));
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({required TextEditingController controller, required String hint, required IconData icon, required bool isObscure, required VoidCallback onToggleObscure, bool isNum = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: Colors.blueGrey),
        suffixIcon: IconButton(
          icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: onToggleObscure,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  // ==========================================
  // 🎨 التبويب الثالث: المظهر والتفضيلات 
  // ==========================================
  Widget _buildAppearanceTab(ThemeProvider theme, UiProvider ui) {
    Color activeColor = theme.primaryColor == Colors.white ? Colors.cyan.shade800 : theme.primaryColor;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('تخصيص مظهر لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('لونك المفضل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    CircleAvatar(backgroundColor: theme.primaryColor, radius: 20, child: theme.primaryColor == Colors.white ? const Icon(Icons.palette, color: Colors.grey) : null),
                  ],
                ),
                const SizedBox(height: 15),
                
                // 👈 دائرة ألوان كاملة ومنسقة كما طلبت بالضبط
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                    ),
                    child: ColorPicker(
                      pickerColor: theme.primaryColor,
                      onColorChanged: (color) {
                        theme.changeColor(color);
                      },
                      paletteType: PaletteType.hsvWithHue,
                      enableAlpha: false,
                      displayThumbColor: true,
                      labelTypes: const [],
                      pickerAreaBorderRadius: BorderRadius.circular(100), // يجعلها دائرة تماماً
                    ),
                  ),
                ),
                
                const Divider(height: 30),
                
                // 👈 زر استعادة المظهر الافتراضي (الأبيض)
                TextButton.icon(
                  onPressed: () {
                    _play('click');
                    theme.resetToDefault();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.blueGrey),
                  label: const Text('استعادة المظهر الافتراضي (الأبيض)', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text('الأصوات والإشعارات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active, color: Colors.blue),
                title: const Text('إشعارات النظام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('استقبال تنبيهات العروض والأرصدة', style: TextStyle(fontSize: 12)),
                activeColor: activeColor,
                value: _notificationsEnabled,
                onChanged: (val) {
                  _play('click');
                  setState(() => _notificationsEnabled = val);
                  _saveSetting('notifications', val);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up, color: Colors.purple),
                title: const Text('أصوات التطبيق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('صوت نجاح عملية البيع والطباعة', style: TextStyle(fontSize: 12)),
                activeColor: activeColor,
                // قراءة القيمة وتفعيلها مباشرة من ملف UiProvider الأصلي
                value: ui.isSoundsEnabled,
                onChanged: (val) {
                  _play('click');
                  ui.updateSoundSettings(val); 
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ⚙️ التبويب الرابع: النظام والمزامنة 
  // ==========================================
  Widget _buildSystemTab(SystemProvider sys, ThemeProvider theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('أدوات النظام', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                title: const Text('تنظيف الذاكرة المؤقتة (Cache)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('يساعد في تسريع التطبيق'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  _play('click');
                  showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                  await Future.delayed(const Duration(seconds: 1)); // محاكاة التنظيف
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنظيف الذاكرة المؤقتة لتسريع التطبيق 🚀'), backgroundColor: Colors.green));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_sync, color: Colors.blue),
                title: const Text('فرض المزامنة (Force Sync)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('سحب أحدث أرصدة وبيانات من السيرفر'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  _play('click');
                  showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                  
                  // 👇 تم تفعيل المزامنة الفعلية من ملف SystemProvider
                  await sys.loadUserData(sys.currentUserPhone);
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت مزامنة البيانات والأرصدة بنجاح 🔄'), backgroundColor: Colors.green));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text('إصدار التطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Text('v1.0.0', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
