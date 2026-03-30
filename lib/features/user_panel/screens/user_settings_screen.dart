import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 1. استدعاء مكتبة العقل المدبر

import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';
import '../../../core/providers/theme_provider.dart'; // 👈 2. استدعاء ملف الذاكرة الخاص بنا

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  // متغيرات الحالة (التي لم نربطها بالعقل بعد)
  bool _useBiometrics = false;
  bool _appSounds = true; 

  // قائمة الألوان المتاحة لتخصيص التطبيق
  final List<Color> _availableColors = [
    Colors.blue, Colors.teal, Colors.green, Colors.orange, Colors.deepPurple,
  ];

  @override
  Widget build(BuildContext context) {
    // 👇 3. السطر السحري: هنا نقوم بالاتصال بالعقل المدبر لمعرفة اللون والوضع الحالي
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: const CustomHeader(title: 'الإعدادات والمظهر'),
      
      // 👇 تم التعديل هنا: إزالة السطر الخاص بالرصيد لكي يعمل القالب الذكي الجديد بنجاح
      drawer: const CustomUserDrawer(
        userName: 'محمد أحمد',
        phoneNumber: '777123456',
      ),
      
      body: Directionality(
        textDirection: TextDirection.rtl, 
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileHeader(themeProvider.primaryColor), // تمرير اللون للترويسة
            const SizedBox(height: 25),

            _buildSectionTitle('المظهر والتفضيلات 🎨'),
            _buildSettingsCard([
              // ربط زر الوضع الليلي بالعقل المدبر
              _buildSwitchTile(
                Icons.dark_mode, 
                'الوضع الليلي', 
                'تفعيل المظهر الداكن', 
                themeProvider.isDarkMode, // نقرأ الحالة من العقل
                (val) => themeProvider.toggleTheme(val), // نرسل الأمر للعقل للتغيير
                themeProvider.primaryColor,
              ),
              _buildSwitchTile(
                Icons.volume_up, 
                'الأصوات التفاعلية', 
                'تشغيل الأصوات عند النقر', 
                _appSounds, 
                (val) => setState(() => _appSounds = val),
                themeProvider.primaryColor,
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16, top: 10, bottom: 5),
                child: Text('تخصيص لون التطبيق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              // تمرير العقل المدبر لدالة اختيار الألوان
              _buildColorPicker(themeProvider),
            ]),

            _buildSectionTitle('الأمان والدخول 🛡️'),
            _buildSettingsCard([
              _buildListTile(Icons.password, 'إعداد رمز PIN (6 أرقام)', 'للدخول السريع وتأكيد المشتريات', onTap: () => _showPinDialog()),
              _buildSwitchTile(Icons.fingerprint, 'الدخول بالبصمة', 'استخدام بصمة الإصبع أو الوجه', _useBiometrics, (val) => setState(() => _useBiometrics = val), themeProvider.primaryColor),
              const Divider(height: 1),
              _buildListTile(Icons.lock_reset, 'تغيير كلمة المرور الأساسية', '', onTap: () => _showPasswordDialog()),
              _buildListTile(Icons.devices, 'إدارة الأجهزة المتصلة', 'تسجيل الخروج من الهواتف الأخرى', onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد أجهزة أخرى متصلة حالياً.')));
              }),
            ]),

            _buildSectionTitle('الإعدادات المالية 💳'),
            _buildSettingsCard([
              _buildListTile(Icons.security_update_warning, 'حدود التحويل والمشتريات', 'تعيين سقف يومي لحماية رصيدك', onTap: () => _showLimitDialog()),
            ]),

            _buildSectionTitle('الحساب والمعلومات ℹ️'),
            _buildSettingsCard([
              _buildListTile(Icons.logout, 'تسجيل الخروج', '', color: Colors.orange, onTap: () {}),
              _buildListTile(Icons.delete_forever, 'حذف الحساب نهائياً', 'لا يمكن التراجع عن هذه الخطوة', color: Colors.red, onTap: () {}),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // دوال بناء الواجهة الأساسية
  // =========================================================

  Widget _buildProfileHeader(Color primaryColor) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(radius: 35, backgroundColor: primaryColor.withOpacity(0.2), child: Icon(Icons.person, size: 35, color: primaryColor)),
            Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.verified, color: Colors.green, size: 18)),
          ],
        ),
        const SizedBox(width: 15),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('محمد أحمد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('+967 777123456', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  // تم تحديث هذه الدالة لكي تغير اللون في التطبيق بالكامل عبر العقل المدبر
  Widget _buildColorPicker(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _availableColors.map((color) {
          final isSelected = themeProvider.primaryColor == color;
          return GestureDetector(
            onTap: () {
              // إخبار العقل المدبر بتغيير اللون
              themeProvider.changeColor(color);
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: color,
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 8, top: 15, right: 5), child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey)));
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade300)), child: Column(children: children));
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, {Color color = Colors.black87, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged, Color activeColor) {
    return SwitchListTile(
      secondary: Icon(icon, color: activeColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      value: value,
      activeColor: activeColor,
      onChanged: onChanged,
    );
  }

  // =========================================================
  // النوافذ المنبثقة (Dialogs)
  // =========================================================

  void _showPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعداد رمز PIN', textAlign: TextAlign.center),
        content: const TextField(keyboardType: TextInputType.number, maxLength: 6, obscureText: true, decoration: InputDecoration(hintText: 'أدخل 6 أرقام', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ رمز PIN بنجاح ✅'))); }, child: const Text('حفظ')),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [TextField(obscureText: true, decoration: InputDecoration(hintText: 'كلمة المرور الحالية')), SizedBox(height: 10), TextField(obscureText: true, decoration: InputDecoration(hintText: 'كلمة المرور الجديدة'))]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('تحديث')),
        ],
      ),
    );
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الحد اليومي للمشتريات'),
        content: const TextField(keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'مثال: 5000', suffixText: 'ريال')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الحد اليومي 🔒'))); }, child: const Text('تأكيد')),
        ],
      ),
    );
  }
}
