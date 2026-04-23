import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart'; // 👈 جديد: للأصوات
import '../../auth/screens/sso_login_screen.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  bool _appSounds = true;
  double _dailyLimit = 0.0;
  String _userPin = '';

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appSounds = prefs.getBool('user_app_sounds') ?? true;
      _dailyLimit = prefs.getDouble('user_daily_limit') ?? 0.0;
      _userPin = prefs.getString('user_pin') ?? '';
    });
  }

  // 👈 تشغيل الصوت الحقيقي مع الاهتزاز (إن وجد)
  void _playFeedback() {
    if (!_appSounds) return;
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    uiProvider.playSound('click'); // يشغل click.mp3 من assets/sounds
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);

    final isDark = themeProvider.isDarkMode;
    final userName = systemProvider.currentUserName;
    final userPhone = systemProvider.currentUserPhone;
    final useBiometrics = systemProvider.isBiometricCurrentlyEnabled;

    // اللون النشط (المخصص أو العام)
    final primaryColor = themeProvider.activePrimaryColor;

    return Scaffold(
      backgroundColor: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.05),
      appBar: CustomHeader(title: 'الإعدادات والمظهر'),
      drawer: CustomUserDrawer(userName: userName, phoneNumber: userPhone),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileHeader(primaryColor, userName, userPhone),
            const SizedBox(height: 20),

            // بطاقة تخصيص اللون الشخصي
            _buildPersonalColorCard(themeProvider, primaryColor, isDark),
            const SizedBox(height: 15),

            // المظهر والتفضيلات
            _buildSectionTitle('المظهر والتفضيلات 🎨', primaryColor),
            _buildSettingsCard([
              _buildSwitchTile(
                Icons.dark_mode,
                'الوضع الليلي',
                'تفعيل المظهر الداكن',
                isDark,
                (val) {
                  _playFeedback();
                  themeProvider.toggleTheme(val);
                },
                primaryColor,
              ),
              _buildSwitchTile(
                Icons.volume_up,
                'الأصوات التفاعلية',
                'تشغيل الأصوات والاهتزاز عند النقر',
                _appSounds,
                (val) async {
                  setState(() => _appSounds = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('user_app_sounds', val);
                  if (val) {
                    _playFeedback(); // سيشغل صوتاً فور التفعيل
                  }
                  _showToast(val ? 'تم تفعيل الأصوات 🔊' : 'تم كتم الأصوات 🔇');
                },
                primaryColor,
              ),
            ], primaryColor, isDark),

            // الأمان والدخول
            _buildSectionTitle('الأمان والدخول 🛡️', primaryColor),
            _buildSettingsCard([
              _buildListTile(
                Icons.password,
                'إعداد رمز PIN (6 أرقام)',
                _userPin.isNotEmpty ? 'تم تعيين رمز PIN' : 'للدخول السريع وتأكيد المشتريات',
                primaryColor,
                onTap: () => _showPinDialog(systemProvider),
              ),
              _buildSwitchTile(
                Icons.fingerprint,
                'الدخول بالبصمة',
                'استخدام بصمة الإصبع أو الوجه',
                useBiometrics,
                (val) {
                  _playFeedback();
                  if (kIsWeb) {
                    _showToast('عذراً، البصمة مدعومة فقط على الهواتف وليس على الويب!');
                    return;
                  }
                  systemProvider.toggleBiometric(val);
                  _showToast(val ? 'تم تفعيل الدخول بالبصمة 👆' : 'تم إيقاف الدخول بالبصمة');
                },
                primaryColor,
              ),
              const Divider(height: 1),
              _buildListTile(
                Icons.lock_reset,
                'تغيير كلمة المرور الأساسية',
                '',
                primaryColor,
                onTap: () => _showPasswordDialog(systemProvider),
              ),
              _buildListTile(
                Icons.devices,
                'إدارة الأجهزة المتصلة',
                'تسجيل الخروج من الهواتف الأخرى',
                primaryColor,
                onTap: () {
                  _playFeedback();
                  _showToast('لا يوجد أجهزة أخرى متصلة بحسابك حالياً.');
                },
              ),
            ], primaryColor, isDark),

            // الإعدادات المالية
            _buildSectionTitle('الإعدادات المالية 💳', primaryColor),
            _buildSettingsCard([
              _buildListTile(
                Icons.security_update_warning,
                'حدود التحويل والمشتريات',
                _dailyLimit > 0 ? 'الحد اليومي: ${_dailyLimit.toStringAsFixed(0)} ريال' : 'تعيين سقف يومي لحماية رصيدك',
                primaryColor,
                onTap: () => _showLimitDialog(systemProvider),
              ),
            ], primaryColor, isDark),

            // الحساب والمعلومات
            _buildSectionTitle('الحساب والمعلومات ℹ️', primaryColor),
            _buildSettingsCard([
              _buildListTile(
                Icons.logout,
                'تسجيل الخروج',
                '',
                Colors.orange,
                onTap: () => _showLogoutDialog(),
              ),
              _buildListTile(
                Icons.delete_forever,
                'حذف الحساب نهائياً',
                'لا يمكن التراجع عن هذه الخطوة',
                Colors.red,
                onTap: () => _showDeleteAccountDialog(systemProvider),
              ),
            ], primaryColor, isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ---------- بطاقة تخصيص اللون (معدلة لاستخدام ThemeProvider) ----------
  Widget _buildPersonalColorCard(ThemeProvider themeProvider, Color currentColor, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.color_lens, color: currentColor),
                const SizedBox(width: 8),
                const Text(
                  'لون لوحة التحكم الشخصية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'اختر لوناً ينعكس على جميع شاشاتك فقط.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // زر اختيار اللون
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => _openColorWheelPicker(themeProvider),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
                          ),
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentColor,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('اختر لون', style: TextStyle(fontSize: 12)),
                  ],
                ),
                // زر استعادة الافتراضي
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        _playFeedback();
                        themeProvider.resetToDefaultColor();
                        _showToast('تم استعادة اللون الافتراضي');
                      },
                      icon: const Icon(Icons.restore, size: 20),
                      label: const Text('اللون الافتراضي'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('استعادة', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openColorWheelPicker(ThemeProvider themeProvider) {
    Color tempColor = themeProvider.activePrimaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر لونك المفضل', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (Color color) => tempColor = color,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tempColor),
            onPressed: () async {
              _playFeedback();
              themeProvider.setUserCustomColor(tempColor);
              Navigator.pop(context);
              _showToast('تم حفظ لونك الشخصي 🎨');
              // حفظ في Firestore أيضاً للنسخ الاحتياطي (اختياري)
              final sys = Provider.of<SystemProvider>(context, listen: false);
              await sys.saveUserPreferredColor(tempColor);
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------- باقي دوال الواجهة (مثل السابق مع تعديلات طفيفة) ----------
  Widget _buildProfileHeader(Color primaryColor, String name, String phone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.5)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
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

  Widget _buildSectionTitle(String title, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 15, right: 5),
      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)),
    );
  }

  Widget _buildSettingsCard(List<Widget> children, Color primaryColor, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, Color color, {required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged, Color activeColor) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: activeColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: activeColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      value: value,
      activeColor: activeColor,
      onChanged: onChanged,
    );
  }

  // ---------- نوافذ الإعدادات (محدثة) ----------
  void _showPasswordDialog(SystemProvider systemProvider) {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
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
              TextField(controller: oldPassController, obscureText: true, decoration: const InputDecoration(hintText: 'كلمة المرور الحالية')),
              const SizedBox(height: 10),
              TextField(controller: newPassController, obscureText: true, decoration: const InputDecoration(hintText: 'كلمة المرور الجديدة')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                _playFeedback();
                final oldPass = oldPassController.text.trim();
                final newPass = newPassController.text.trim();
                if (oldPass.isEmpty || newPass.isEmpty) {
                  _showToast('يرجى تعبئة جميع الحقول');
                  return;
                }
                final success = systemProvider.changeUserPassword(oldPass, newPass);
                if (success) {
                  Navigator.pop(context);
                  _showToast('تم تحديث كلمة المرور بنجاح 🔒');
                } else {
                  _showToast('كلمة المرور الحالية غير صحيحة');
                }
              },
              child: const Text('تحديث'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPinDialog(SystemProvider systemProvider) {
    final pinController = TextEditingController(text: _userPin);
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
            decoration: const InputDecoration(hintText: 'أدخل 6 أرقام', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                _playFeedback();
                final newPin = pinController.text.trim();
                if (newPin.length == 6) {
                  await systemProvider.updateUserPin(newPin);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_pin', newPin);
                  setState(() => _userPin = newPin);
                  Navigator.pop(context);
                  _showToast('تم حفظ رمز PIN بنجاح ✅');
                } else {
                  _showToast('يرجى إدخال 6 أرقام بالضبط');
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLimitDialog(SystemProvider systemProvider) {
    final limitController = TextEditingController(text: _dailyLimit > 0 ? _dailyLimit.toStringAsFixed(0) : '');
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
            decoration: const InputDecoration(hintText: 'مثال: 5000', suffixText: 'ريال', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                _playFeedback();
                final newLimit = double.tryParse(limitController.text.trim()) ?? 0.0;
                await systemProvider.updateUserDailyLimit(newLimit);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('user_daily_limit', newLimit);
                setState(() => _dailyLimit = newLimit);
                Navigator.pop(context);
                _showToast(newLimit > 0 ? 'تم تعيين الحد اليومي إلى $newLimit ريال 🛡️' : 'تم إلغاء الحد اليومي');
              },
              child: const Text('حفظ'),
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
                final sys = Provider.of<SystemProvider>(context, listen: false);
                sys.clearAllData();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SSOLoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('تأكيد الخروج', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(SystemProvider systemProvider) {
    final passwordController = TextEditingController();
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('إذا قمت بحذف حسابك، ستفقد جميع كروتك ومحفظتك ونقاط المكافآت. هل أنت متأكد تماماً؟'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'أدخل كلمة المرور للتأكيد', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                _playFeedback();
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  _showToast('يرجى إدخال كلمة المرور');
                  return;
                }
                final success = await systemProvider.deleteUserAccount(password);
                if (success) {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SSOLoginScreen()),
                    (route) => false,
                  );
                  _showToast('تم حذف الحساب بنجاح');
                } else {
                  Navigator.pop(context);
                  _showToast('كلمة المرور غير صحيحة أو فشل الحذف');
                }
              },
              child: const Text('نعم، احذف حسابي', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
