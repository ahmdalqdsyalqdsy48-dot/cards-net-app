import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';
import '../../../core/providers/theme_provider.dart';

// 👇 استدعاء شاشة الدخول للعودة إليها عند تسجيل الخروج
import '../../auth/screens/sso_login_screen.dart'; 

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  bool _useBiometrics = false;
  bool _appSounds = true; 

  final List<Color> _availableColors = [
    Colors.blue, Colors.teal, Colors.green, Colors.orange, Colors.deepPurple,
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: const CustomHeader(title: 'الإعدادات والمظهر'),
      drawer: const CustomUserDrawer(
        userName: 'محمد أحمد',
        phoneNumber: '777123456',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl, 
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileHeader(themeProvider.primaryColor),
            const SizedBox(height: 25),

            _buildSectionTitle('المظهر والتفضيلات 🎨'),
            _buildSettingsCard([
              _buildSwitchTile(
                Icons.dark_mode, 
                'الوضع الليلي', 
                'تفعيل المظهر الداكن', 
                themeProvider.isDarkMode, 
                (val) => themeProvider.toggleTheme(val), 
                themeProvider.primaryColor,
              ),
              _buildSwitchTile(
                Icons.volume_up, 
                'الأصوات التفاعلية', 
                'تشغيل الأصوات عند النقر', 
                _appSounds, 
                (val) {
                  setState(() => _appSounds = val);
                  _showToast(val ? 'تم تفعيل الأصوات 🔊' : 'تم كتم الأصوات 🔇');
                },
                themeProvider.primaryColor,
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16, top: 10, bottom: 5),
                child: Text('تخصيص لون التطبيق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              _buildColorPicker(themeProvider),
            ]),

            _buildSectionTitle('الأمان والدخول 🛡️'),
            _buildSettingsCard([
              _buildListTile(Icons.password, 'إعداد رمز PIN (6 أرقام)', 'للدخول السريع وتأكيد المشتريات', onTap: () => _showPinDialog()),
              _buildSwitchTile(
                Icons.fingerprint, 
                'الدخول بالبصمة', 
                'استخدام بصمة الإصبع أو الوجه', 
                _useBiometrics, 
                (val) {
                  setState(() => _useBiometrics = val);
                  _showToast(val ? 'تم تفعيل الدخول بالبصمة 👆' : 'تم إيقاف الدخول بالبصمة');
                }, 
                themeProvider.primaryColor
              ),
              const Divider(height: 1),
              _buildListTile(Icons.lock_reset, 'تغيير كلمة المرور الأساسية', '', onTap: () => _showPasswordDialog()),
              _buildListTile(Icons.devices, 'إدارة الأجهزة المتصلة', 'تسجيل الخروج من الهواتف الأخرى', onTap: () {
                _showToast('لا يوجد أجهزة أخرى متصلة بحسابك حالياً.');
              }),
            ]),

            _buildSectionTitle('الإعدادات المالية 💳'),
            _buildSettingsCard([
              _buildListTile(Icons.security_update_warning, 'حدود التحويل والمشتريات', 'تعيين سقف يومي لحماية رصيدك', onTap: () => _showLimitDialog()),
            ]),

            _buildSectionTitle('الحساب والمعلومات ℹ️'),
            _buildSettingsCard([
              _buildListTile(Icons.logout, 'تسجيل الخروج', '', color: Colors.orange, onTap: () => _showLogoutDialog()),
              _buildListTile(Icons.delete_forever, 'حذف الحساب نهائياً', 'لا يمكن التراجع عن هذه الخطوة', color: Colors.red, onTap: () => _showDeleteAccountDialog()),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // دوال مساعدة لإنشاء الواجهة
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

  Widget _buildColorPicker(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _availableColors.map((color) {
          final isSelected = themeProvider.primaryColor == color;
          return GestureDetector(
            onTap: () => themeProvider.changeColor(color),
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

  // إظهار إشعار سريع
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  // =========================================================
  // النوافذ المنبثقة التفاعلية الذكية (Dialogs)
  // =========================================================

  void _showPinDialog() {
    final TextEditingController pinController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعداد رمز PIN', textAlign: TextAlign.center),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number, 
          maxLength: 6, 
          obscureText: true, 
          decoration: const InputDecoration(hintText: 'أدخل 6 أرقام', border: OutlineInputBorder())
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () { 
              if (pinController.text.length == 6) {
                Navigator.pop(context); 
                _showToast('تم حفظ رمز PIN بنجاح ✅');
              } else {
                _showToast('يرجى إدخال 6 أرقام بالضبط!');
              }
            }, 
            child: const Text('حفظ')
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    final TextEditingController oldPass = TextEditingController();
    final TextEditingController newPass = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(controller: oldPass, obscureText: true, decoration: const InputDecoration(hintText: 'كلمة المرور الحالية')), 
            const SizedBox(height: 10), 
            TextField(controller: newPass, obscureText: true, decoration: const InputDecoration(hintText: 'كلمة المرور الجديدة'))
          ]
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (oldPass.text.isNotEmpty && newPass.text.isNotEmpty) {
                Navigator.pop(context);
                _showToast('تم تحديث كلمة المرور بنجاح 🔒');
              } else {
                _showToast('يرجى تعبئة جميع الحقول!');
              }
            }, 
            child: const Text('تحديث')
          ),
        ],
      ),
    );
  }

  void _showLimitDialog() {
    final TextEditingController limitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الحد اليومي للمشتريات'),
        content: TextField(
          controller: limitController,
          keyboardType: TextInputType.number, 
          decoration: const InputDecoration(hintText: 'مثال: 5000', suffixText: 'ريال')
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () { 
              if (limitController.text.isNotEmpty) {
                Navigator.pop(context); 
                _showToast('تم تحديث الحد اليومي بنجاح 🛡️');
              } else {
                _showToast('يرجى إدخال مبلغ الحد اليومي.');
              }
            }, 
            child: const Text('تأكيد')
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.orange)),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                // العودة إلى شاشة تسجيل الدخول ومسح السجل السابق
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SSOLoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text('تأكيد الخروج', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('حذف الحساب نهائياً', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: const Text('إذا قمت بحذف حسابك، ستفقد جميع كروتك ومحفظتك ونقاط المكافآت. هل أنت متأكد تماماً من هذا الإجراء؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                // محاكاة حذف الحساب والتوجيه لشاشة الدخول
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SSOLoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text('نعم، احذف حسابي', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
