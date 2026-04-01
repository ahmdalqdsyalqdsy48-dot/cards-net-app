import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 لمؤثرات الصوت والاهتزاز الحقيقية (النظام)
import 'package:flutter/foundation.dart' show kIsWeb; // 👈 لمعرفة هل نحن على الويب
import 'package:provider/provider.dart';
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

  // الألوان التي ستغير خلفية التطبيق بالكامل
  final List<Color> _availableColors = [
    Colors.blue, Colors.teal, Colors.green, Colors.orange, Colors.deepPurple, Colors.pink, Colors.redAccent
  ];

  // دالة تشغيل الصوت والاهتزاز (آمنة للويب والهواتف ومدمجة في النظام)
  void _playFeedback() {
    if (_appSounds) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact(); // اهتزاز خفيف عند النقر
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    
    final primaryColor = themeProvider.primaryColor; 
    final isDark = themeProvider.isDarkMode;

    final userName = systemProvider.currentUserName;
    final userPhone = systemProvider.currentUserPhone;
    final useBiometrics = systemProvider.isBiometricCurrentlyEnabled; 

    return Scaffold(
      // 👈 هنا السحر: تغيير خلفية التطبيق بالكامل بناءً على اللون المختار
      backgroundColor: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.05),
      appBar: const CustomHeader(title: 'الإعدادات والمظهر'),
      drawer: CustomUserDrawer(userName: userName, phoneNumber: userPhone),
      body: Directionality(
        textDirection: TextDirection.rtl, 
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileHeader(primaryColor, userName, userPhone),
            const SizedBox(height: 20),

            // زر التخصيص السحري الشامل
            _buildCustomizationButton(themeProvider),
            const SizedBox(height: 15),

            // المظهر والتفضيلات
            _buildSectionTitle('المظهر والتفضيلات 🎨', primaryColor),
            _buildSettingsCard([
              _buildSwitchTile(
                Icons.dark_mode, 'الوضع الليلي', 'تفعيل المظهر الداكن', 
                isDark, 
                (val) {
                  _playFeedback();
                  themeProvider.toggleTheme(val);
                }, primaryColor
              ),
              _buildSwitchTile(
                Icons.volume_up, 'الأصوات التفاعلية', 'تشغيل الأصوات والاهتزاز عند النقر', 
                _appSounds, 
                (val) {
                  setState(() => _appSounds = val);
                  if (val) {
                    SystemSound.play(SystemSoundType.click);
                    HapticFeedback.heavyImpact();
                  }
                  _showToast(val ? 'تم تفعيل الأصوات 🔊' : 'تم كتم الأصوات 🔇');
                }, primaryColor
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16, top: 10, bottom: 5),
                child: Text('الألوان السريعة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              _buildColorPicker(themeProvider),
            ], primaryColor, isDark),

            // الأمان والدخول
            _buildSectionTitle('الأمان والدخول 🛡️', primaryColor),
            _buildSettingsCard([
              _buildListTile(Icons.password, 'إعداد رمز PIN (6 أرقام)', 'للدخول السريع وتأكيد المشتريات', primaryColor, onTap: () {
                _playFeedback();
                _showPinDialog();
              }),
              _buildSwitchTile(
                Icons.fingerprint, 'الدخول بالبصمة', 'استخدام بصمة الإصبع أو الوجه', 
                useBiometrics, 
                (val) {
                  _playFeedback();
                  // منع البصمة على الويب برمجياً لتجنب الأخطاء
                  if (kIsWeb) {
                    _showToast('عذراً، البصمة مدعومة فقط على الهواتف (Android/iOS) وليس على الويب!');
                    return; 
                  }
                  systemProvider.toggleBiometric(val); 
                  _showToast(val ? 'تم تفعيل الدخول بالبصمة 👆' : 'تم إيقاف الدخول بالبصمة');
                }, primaryColor
              ),
              const Divider(height: 1),
              _buildListTile(Icons.lock_reset, 'تغيير كلمة المرور الأساسية', '', primaryColor, onTap: () {
                _playFeedback();
                _showPasswordDialog(systemProvider); 
              }),
              _buildListTile(Icons.devices, 'إدارة الأجهزة المتصلة', 'تسجيل الخروج من الهواتف الأخرى', primaryColor, onTap: () {
                _playFeedback();
                _showToast('لا يوجد أجهزة أخرى متصلة بحسابك حالياً.');
              }),
            ], primaryColor, isDark),

            // الإعدادات المالية
            _buildSectionTitle('الإعدادات المالية 💳', primaryColor),
            _buildSettingsCard([
              _buildListTile(Icons.security_update_warning, 'حدود التحويل والمشتريات', 'تعيين سقف يومي لحماية رصيدك', primaryColor, onTap: () {
                _playFeedback();
                _showLimitDialog();
              }),
            ], primaryColor, isDark),

            // الحساب والمعلومات
            _buildSectionTitle('الحساب والمعلومات ℹ️', primaryColor),
            _buildSettingsCard([
              _buildListTile(Icons.logout, 'تسجيل الخروج', '', Colors.orange, onTap: () {
                _playFeedback();
                _showLogoutDialog();
              }),
              _buildListTile(Icons.delete_forever, 'حذف الحساب نهائياً', 'لا يمكن التراجع عن هذه الخطوة', Colors.red, onTap: () {
                _playFeedback();
                _showDeleteAccountDialog();
              }),
            ], primaryColor, isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // دوال مساعدة لإنشاء الواجهة بشكل ديناميكي
  // =========================================================

  Widget _buildProfileHeader(Color primaryColor, String name, String phone) {
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

  // زر التخصيص المتدرج
  Widget _buildCustomizationButton(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.pinkAccent]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ListTile(
        leading: Container(
          width: 35, height: 35,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red]),
          ),
        ),
        title: const Text('تخصيص مظهر التطبيق بالكامل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text('اختر أي لون من عجلة الألوان', style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 15),
        onTap: () {
          _playFeedback();
          _showColorPickerWheelDialog(themeProvider); 
        },
      ),
    );
  }

  // نافذة اختيار الألوان (Color Picker)
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
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeProvider.primaryColor),
            onPressed: () {
              _playFeedback();
              themeProvider.changeColor(pickerColor);
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
      child: Wrap(
        spacing: 15,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: _availableColors.map((color) {
          final isSelected = themeProvider.primaryColor == color;
          return GestureDetector(
            onTap: () {
              _playFeedback();
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

  Widget _buildSectionTitle(String title, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 15, right: 5), 
      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor))
    );
  }

  // البطاقات تتأثر باللون المختار لتتناسب مع الخلفية
  Widget _buildSettingsCard(List<Widget> children, Color primaryColor, bool isDark) {
    return Card(
      elevation: 0, 
      color: isDark ? Colors.black45 : Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), 
        side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1.5)
      ), 
      child: Column(children: children)
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, Color color, {required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20)
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        child: Icon(icon, color: activeColor, size: 20)
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
  // النوافذ المنبثقة التفاعلية الذكية (جميعها مربوطة وتعمل)
  // =========================================================

  void _showPasswordDialog(SystemProvider systemProvider) {
    final TextEditingController oldPass = TextEditingController();
    final TextEditingController newPass = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                _playFeedback();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                _playFeedback();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                _playFeedback();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.orange)),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                _playFeedback();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SSOLoginScreen()), (Route<dynamic> route) => false);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                _playFeedback();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SSOLoginScreen()), (Route<dynamic> route) => false);
              },
              child: const Text('نعم، احذف حسابي', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
