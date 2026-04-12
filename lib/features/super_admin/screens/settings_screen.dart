import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            // 👈 زر استعادة الافتراضي (اللون الأبيض)
            TextButton(
              onPressed: () {
                themeProvider.resetToDefault();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت العودة للون الرسمي الأبيض.', textDirection: TextDirection.rtl)));
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'تم تحديث الاسم بنجاح! ✅' : 'فشل التحديث', textDirection: TextDirection.rtl), backgroundColor: success ? Colors.green : Colors.red));
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور غير متطابقة!', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
                    return;
                  }
                  bool success = systemProvider.changeUserPassword(oldPass.text, newPass.text);
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح!', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور القديمة خاطئة!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز غير متطابق!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                    return;
                  }
                  bool success = await systemProvider.changeUserPin(oldPin.text, newPin.text);
                  if(mounted){
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث رمز PIN بنجاح! ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز PIN القديم خاطئ!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
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

  // 👈 النافذة الجديدة الخاصة ببرمجة وتعديل شريط الأخبار العلوي العام
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
                  // تحديث السيرفر ليعكس التغيير عند الجميع فوراً
                  await FirebaseFirestore.instance.collection('system').doc('main_info').update({
                    'announcements': [marqueeCtrl.text]
                  });
                  if(mounted){
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير نص الشريط العلوي بنجاح!', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
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

    // 👈 الذكاء اللوني: إذا كان اللون المختار هو الأبيض، استخدم الأزرق للرموز والنصوص
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
                labelColor: safeActiveColor, // استخدام اللون الآمن
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
                  _buildSecurityTab(systemProvider),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          _buildSectionTitle('إدارة الخطوط'),
          Card(
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.font_download, color: Colors.blue),
                  title: const Text('نوع الخط'),
                  trailing: DropdownButton<String>(
                    value: themeProvider.fontFamily,
                    items: ['System', 'Cairo', 'Tajawal'].map((String font) => DropdownMenuItem(value: font, child: Text(font))).toList(),
                    onChanged: (val) { if (val != null) themeProvider.changeFontFamily(val); },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.format_size, color: Colors.orange),
                  title: const Text('حجم الخط العام'),
                  subtitle: Slider(
                    value: themeProvider.fontSizeScale, min: 0.8, max: 1.5, divisions: 7, label: themeProvider.fontSizeScale.toString(),
                    onChanged: (val) => themeProvider.changeFontSizeScale(val),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode, color: Colors.indigo),
            title: const Text('تفعيل الوضع الليلي (Dark Mode)'),
            value: themeProvider.isDarkMode, 
            onChanged: (val) => themeProvider.toggleTheme(val),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. تبويب الأمان والبيانات الشخصية 🔐 
  // ==========================================
  Widget _buildSecurityTab(SystemProvider systemProvider) {
    return SingleChildScrollView(
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
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint, color: Colors.green),
              title: const Text('الدخول بالبصمة (Biometrics)'),
              value: systemProvider.isBiometricCurrentlyEnabled, 
              onChanged: (val) => systemProvider.toggleBiometric(val), 
            ),
          ),
        ],
      ),
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
          // 👈 تم إضافة زر تعديل الشريط العلوي هنا (ينادي الدالة الجديدة)
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
