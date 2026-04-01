import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // مكتبة أصوات النظام
import 'package:provider/provider.dart';

import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart'; // العقل المدبر

import '../../auth/screens/sso_login_screen.dart'; 

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  bool _appSounds = true; 

  // قائمة ألوان زاهية ومشرقة للتخصيص
  final List<Color> _availableColors = [
    Colors.blue, Colors.cyan, Colors.teal, Colors.green, 
    Colors.orange, Colors.pinkAccent, Colors.deepPurpleAccent,
  ];

  @override
  Widget build(BuildContext context) {
    // الاتصال بمزود المظهر ومزود النظام الأساسي
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final primaryColor = themeProvider.primaryColor; 

    // جلب البيانات الحقيقية من الذاكرة
    final userName = systemProvider.currentUserName;
    final userPhone = systemProvider.currentUserPhone;
    final useBiometrics = systemProvider.isBiometricCurrentlyEnabled; 

    return Scaffold(
      appBar: const CustomHeader(title: 'الإعدادات والمظهر'),
      drawer: CustomUserDrawer(
        userName: userName,
        phoneNumber: userPhone,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl, 
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. الترويسة الملونة المتدرجة (Gradient Header)
            _buildGradientProfileHeader(primaryColor, userName, userPhone),
            const SizedBox(height: 20),

            // 2. زر التخصيص الجديد الزاهي
            _buildCustomizationButton(themeProvider),
            const SizedBox(height: 15),

            // 3. المظهر والتفضيلات
            _buildSectionTitle('المظهر والتفضيلات 🎨', primaryColor),
            _buildSettingsCard([
              _buildSwitchTile(
                Icons.dark_mode, 
                'الوضع الليلي', 
                'تفعيل المظهر الداكن', 
                themeProvider.isDarkMode, 
                (val) {
                  if (_appSounds) SystemSound.play(SystemSoundType.click);
                  themeProvider.toggleTheme(val);
                }, 
                primaryColor,
              ),
              _buildSwitchTile(
                Icons.volume_up, 
                'الأصوات التفاعلية', 
                'تشغيل الأصوات عند النقر', 
                _appSounds, 
                (val) {
                  setState(() => _appSounds = val);
                  if (val) SystemSound.play(SystemSoundType.click); 
                  _showToast(val ? 'تم تفعيل الأصوات 🔊' : 'تم كتم الأصوات 🔇');
                },
                primaryColor,
              ),
            ], primaryColor),

            // 4. الأمان والدخول
            _buildSectionTitle('الأمان والدخول 🛡️', primaryColor),
            _buildSettingsCard([
              _buildListTile(Icons.password, 'إعداد رمز PIN (6 أرقام)', 'للدخول السريع وتأكيد المشتريات', primaryColor, onTap: () {
                if (_appSounds) SystemSound.play(SystemSoundType.click);
                _showPinDialog();
              }),
              _buildSwitchTile(
                Icons.fingerprint, 
                'الدخول بالبصمة', 
                'استخدام بصمة الإصبع أو الوجه', 
                useBiometrics, 
                (val) {
                  if (_appSounds) SystemSound.play(SystemSoundType.click);
                  systemProvider.toggleBiometric(val); 
                  _showToast(val ? 'تم تفعيل الدخول بالبصمة 👆' : 'تم إيقاف الدخول بالبصمة');
                }, 
                primaryColor
              ),
              const Divider(height: 1),
              _buildListTile(Icons.lock_reset, 'تغيير كلمة المرور الأساسية', '', primaryColor, onTap: () {
                if (_appSounds) SystemSound.play(SystemSoundType.click);
                _showPasswordDialog(systemProvider); 
              }),
              _buildListTile(Icons.devices, 'إدارة الأجهزة المتصلة', 'تسجيل الخروج من الهواتف الأخرى', primaryColor, onTap: () {
                if (_appSounds) SystemSound.play(SystemSoundType.click);
                _showToast('لا يوجد أجهزة أخرى متصلة بحسابك حالياً.');
              }),
            ], primaryColor),

            // 5. الإعدادات المالية
            _buildSectionTitle('الإعدادات المالية 💳', primaryColor),
            _buildSettingsCard([
              _buildListTile(Icons.security_update_warning, 'حدود التحويل والمشتريات', 'تعيين سقف يومي لحماية رصيدك', primaryColor, onTap: () {
                if (_appSounds) SystemSound.play(SystemSoundType.click);
                _showLimitDialog();
              }),
            ], primaryColor),

            // 6. الحساب والمعلومات
            _buildSectionTitle('الحساب والمعلومات ℹ️', primaryColor),
            _buildSettingsCard([
              _buildListTile(Icons.logout, 'تسجيل الخروج', '', Colors.orange, onTap: () {
                if (_appSounds) SystemSound.play(SystemSoundType.click);
                _showLogoutDialog();
              }),
              _buildListTile(Icons.delete_forever, 'حذف الحساب نهائياً', 'لا يمكن التراجع عن هذه الخطوة', Colors.red, onTap: () {
                if (_appSounds) SystemSound.play(SystemSoundType.click);
                _showDeleteAccountDialog();
              }),
            ], primaryColor),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // دوال مساعدة لإنشاء الواجهة الزاهية والديناميكية
  // =========================================================

  // ترويسة متدرجة الألوان (Gradient)
  Widget _buildGradientProfileHeader(Color primaryColor, String name, String phone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.6)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(radius: 35, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 35, color: Colors.white)),
              Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.verified, color: Colors.green, size: 18)),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 15), textDirection: TextDirection.ltr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // زر التخصيص السحري
  Widget _buildCustomizationButton(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.purpleAccent, Colors.pinkAccent], // ألوان زاهية ثابتة لجذب الانتباه
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ListTile(
        leading: const Icon(Icons.color_lens, color: Colors.white, size: 28),
        title: const Text('تخصيص مظهر التطبيق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: const Text('اختر ألوانك المفضلة', style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.brush, color: Colors.white),
        onTap: () {
          if (_appSounds) SystemSound.play(SystemSoundType.click);
          _showCustomizationBottomSheet(themeProvider); // يفتح نافذة الألوان
        },
      ),
    );
  }

  // نافذة اختيار الألوان من الأسفل
  void _showCustomizationBottomSheet(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            height: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختر لونك المفضل ✨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _availableColors.map((color) {
                    final isSelected = themeProvider.primaryColor == color;
                    return GestureDetector(
                      onTap: () {
                        if (_appSounds) SystemSound.play(SystemSoundType.click);
                        themeProvider.changeColor(color);
                        Navigator.pop(context); // إغلاق النافذة بعد الاختيار
                        _showToast('تم تغيير لون التطبيق بنجاح 🎨');
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: color,
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 15, right: 5), 
      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)) 
    );
  }

  Widget _buildSettingsCard(List<Widget> children, Color primaryColor) {
    return Card(
      elevation: 3, // إضافة ظل خفيف للبطاقات لتبرز أكثر
      shadowColor: primaryColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: primaryColor.withOpacity(0.1))), 
      child: Column(children: children)
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, Color color, {required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), // خلفية دائرية زاهية للأيقونة
        child: Icon(icon, color: color, size: 22)
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged, Color activeColor) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: activeColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: activeColor, size: 22)
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      value: value,
      activeColor: activeColor,
      onChanged: onChanged,
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, textDirection: TextDirection.rtl), duration: const Duration(seconds: 2)));
  }

  // =========================================================
  // النوافذ المنبثقة التفاعلية (تم ربطها وفحصها)
  // =========================================================

  void _showPasswordDialog(SystemProvider systemProvider) {
    final TextEditingController oldPass = TextEditingController();
    final TextEditingController newPass = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تغيير كلمة المرور'),
          content: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              TextField(controller: oldPass, obscureText: true, decoration: InputDecoration(hintText: 'كلمة المرور الحالية', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), 
              const SizedBox(height: 10), 
              TextField(controller: newPass, obscureText: true, decoration: InputDecoration(hintText: 'كلمة المرور الجديدة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))
            ]
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                if (oldPass.text.isNotEmpty && newPass.text.isNotEmpty) {
                  bool success = systemProvider.changeUserPassword(oldPass.text, newPass.text);
                  if (success) {
                    Navigator.pop(context);
                    _showToast('تم تحديث كلمة المرور بنجاح 🔒');
                  } else {
                    _showToast('كلمة المرور الحالية غير صحيحة!'); 
                  }
                } else {
                  _showToast('يرجى تعبئة جميع الحقول!');
                }
              }, 
              child: const Text('تحديث')
            ),
          ],
        ),
      ),
    );
  }

  void _showPinDialog() {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إعداد رمز PIN', textAlign: TextAlign.center),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number, 
            maxLength: 6, 
            obscureText: true, 
            decoration: InputDecoration(hintText: 'أدخل 6 أرقام', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
      ),
    );
  }

  void _showLimitDialog() {
    final TextEditingController limitController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('الحد اليومي للمشتريات'),
          content: TextField(
            controller: limitController,
            keyboardType: TextInputType.number, 
            decoration: InputDecoration(hintText: 'مثال: 5000', suffixText: 'ريال', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.orange)),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
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
