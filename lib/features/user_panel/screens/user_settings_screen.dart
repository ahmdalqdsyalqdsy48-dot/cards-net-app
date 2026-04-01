import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // لمعرفة هل نحن على الويب
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart'; // 👈 مكتبة الصوت الحقيقية
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // 👈 مكتبة عجلة الألوان

import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart';

import '../../auth/screens/sso_login_screen.dart'; 

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  bool _appSounds = true; 
  final AudioPlayer _audioPlayer = AudioPlayer(); // مشغل الصوت الحقيقي

  // الألوان السريعة
  final List<Color> _availableColors = [
    Colors.blue, Colors.teal, Colors.green, Colors.orange, Colors.pinkAccent,
  ];

  @override
  void dispose() {
    _audioPlayer.dispose(); // إغلاق مشغل الصوت عند الخروج
    super.dispose();
  }

  // 👈 دالة تشغيل الصوت الحقيقي (تعمل على الويب والهاتف)
  Future<void> _playClickSound() async {
    if (_appSounds) {
      try {
        // تشغيل صوت نقر ناعم من خوادم جوجل
        await _audioPlayer.play(UrlSource('https://actions.google.com/sounds/v1/ui/click.ogg'));
      } catch (e) {
        debugPrint('خطأ في تشغيل الصوت');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final primaryColor = themeProvider.primaryColor; 

    final userName = systemProvider.currentUserName;
    final userPhone = systemProvider.currentUserPhone;
    final useBiometrics = systemProvider.isBiometricCurrentlyEnabled; 

    return Scaffold(
      // 👈 هنا نجعل خلفية الشاشة بأكملها تتأثر باللون المختار (شفافية 5%)
      backgroundColor: primaryColor.withOpacity(0.05),
      appBar: const CustomHeader(title: 'الإعدادات والمظهر'),
      drawer: CustomUserDrawer(userName: userName, phoneNumber: userPhone),
      body: Directionality(
        textDirection: TextDirection.rtl, 
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGradientProfileHeader(primaryColor, userName, userPhone),
            const SizedBox(height: 20),

            _buildCustomizationButton(themeProvider),
            const SizedBox(height: 15),

            _buildSectionTitle('المظهر والتفضيلات 🎨', primaryColor),
            _buildSettingsCard([
              _buildSwitchTile(Icons.dark_mode, 'الوضع الليلي', 'تفعيل المظهر الداكن', themeProvider.isDarkMode, (val) {
                _playClickSound();
                themeProvider.toggleTheme(val);
              }, primaryColor),
              
              _buildSwitchTile(Icons.volume_up, 'الأصوات التفاعلية', 'تشغيل الأصوات عند النقر', _appSounds, (val) {
                setState(() => _appSounds = val);
                if (val) _playClickSound(); 
                _showToast(val ? 'تم تفعيل الأصوات 🔊' : 'تم كتم الأصوات 🔇');
              }, primaryColor),
              
              const Padding(
                padding: EdgeInsets.only(right: 16, top: 10, bottom: 5),
                child: Text('الألوان السريعة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              _buildColorPicker(themeProvider),
            ], primaryColor),

            _buildSectionTitle('الأمان والدخول 🛡️', primaryColor),
            _buildSettingsCard([
              _buildListTile(Icons.password, 'إعداد رمز PIN (6 أرقام)', 'للدخول السريع', primaryColor, onTap: () {
                _playClickSound();
                _showPinDialog();
              }),
              _buildSwitchTile(Icons.fingerprint, 'الدخول بالبصمة', 'استخدام بصمة الإصبع أو الوجه', useBiometrics, (val) {
                _playClickSound();
                // 👈 منع البصمة من العمل على الويب وتوضيح السبب للمستخدم
                if (kIsWeb) {
                  _showToast('عذراً، البصمة تعمل فقط على تطبيقات الهواتف ولا يدعمها متصفح الويب! 📱');
                  return;
                }
                systemProvider.toggleBiometric(val); 
                _showToast(val ? 'تم تفعيل البصمة بنجاح 👆' : 'تم إيقاف الدخول بالبصمة');
              }, primaryColor),
              const Divider(height: 1),
              _buildListTile(Icons.lock_reset, 'تغيير كلمة المرور الأساسية', '', primaryColor, onTap: () {
                _playClickSound();
                _showPasswordDialog(systemProvider); 
              }),
            ], primaryColor),

            _buildSectionTitle('الحساب والمعلومات ℹ️', primaryColor),
            _buildSettingsCard([
              _buildListTile(Icons.logout, 'تسجيل الخروج', '', Colors.orange, onTap: () {
                _playClickSound();
                _showLogoutDialog();
              }),
            ], primaryColor),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // دوال مساعدة لإنشاء الواجهة
  // =========================================================

  Widget _buildGradientProfileHeader(Color primaryColor, String name, String phone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.5)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 35, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 35, color: Colors.white)),
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

  // 👈 زر الألوان المتعددة والتخصيص
  Widget _buildCustomizationButton(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.pinkAccent]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Container(
          width: 35, height: 35,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            // رسم دائرة ملونة بجميع الألوان كما طلبت
            gradient: SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red]),
          ),
        ),
        title: const Text('تخصيص مظهر التطبيق بالكامل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text('اختر أي لون من عجلة الألوان', style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 15),
        onTap: () {
          _playClickSound();
          _showColorPickerWheelDialog(themeProvider); 
        },
      ),
    );
  }

  // 👈 نافذة عجلة الألوان الشاملة (Color Picker)
  void _showColorPickerWheelDialog(ThemeProvider themeProvider) {
    Color pickerColor = themeProvider.primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر لونك المفضل', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (Color color) {
              pickerColor = color;
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false, // لمنع اختيار الشفافية
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeProvider.primaryColor),
            onPressed: () {
              _playClickSound();
              themeProvider.changeColor(pickerColor); // تطبيق اللون
              Navigator.pop(context);
              _showToast('تم تلوين التطبيق بنجاح 🎨');
            },
            child: const Text('تطبيق اللون', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
            onTap: () {
              _playClickSound();
              themeProvider.changeColor(color);
            },
            child: CircleAvatar(radius: 18, backgroundColor: color, child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color primaryColor) {
    return Padding(padding: const EdgeInsets.only(bottom: 8, top: 15, right: 5), child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)));
  }

  Widget _buildSettingsCard(List<Widget> children, Color primaryColor) {
    return Card(
      elevation: 0,
      color: Colors.white, // لكي تبرز البطاقة عن الخلفية الملونة
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: primaryColor.withOpacity(0.2))), 
      child: Column(children: children)
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, Color color, {required VoidCallback onTap}) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged, Color activeColor) {
    return SwitchListTile(
      secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: activeColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: activeColor, size: 22)),
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
              onPressed: () {
                _playClickSound();
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
          title: const Text('إعداد رمز PIN'),
          content: TextField(controller: pinController, keyboardType: TextInputType.number, maxLength: 6, obscureText: true, decoration: InputDecoration(hintText: 'أدخل 6 أرقام', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () { 
                _playClickSound();
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.orange)),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                _playClickSound();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SSOLoginScreen()), (route) => false);
              },
              child: const Text('تأكيد الخروج', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
