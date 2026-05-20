import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart';    // ما زلنا نحتاجه لـ checkUserExists و getLanguageSync
import '../../../core/providers/auth_provider.dart';       // ✅ الجديد
import '../../../core/providers/settings_provider.dart';   // ✅ الجديد
import '../../../core/providers/wallet_provider.dart';     // ✅ الجديد
import '../../../core/providers/ui_provider.dart';

import '../../super_admin/screens/super_admin_dashboard.dart';
import '../../agent_panel/screens/agent_dashboard_screen.dart';
import '../../user_panel/screens/user_dashboard_screen.dart';

class SSOLoginScreen extends StatefulWidget {
  const SSOLoginScreen({super.key});

  @override
  State<SSOLoginScreen> createState() => _SSOLoginScreenState();
}

class _SSOLoginScreenState extends State<SSOLoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  bool isLoginMode = true;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscurePin = true;
  bool rememberMe = false;
  bool usePinLogin = false;

  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;

  final List<Color> _fallbackAdColors = [
    Colors.blue.shade800,
    Colors.deepPurple,
    Colors.teal
  ];
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDynamicCarousel();
    });
  }

  void _startDynamicCarousel() {
    // ✅ استبدال SystemProvider بـ SettingsProvider
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    int interval = settingsProvider.carouselIntervalSeconds > 0
        ? settingsProvider.carouselIntervalSeconds
        : 5;

    _carouselTimer = Timer.periodic(Duration(seconds: interval), (Timer timer) {
      int itemCount = settingsProvider.loginCarouselImages.isNotEmpty
          ? settingsProvider.loginCarouselImages.length
          : _fallbackAdColors.length;

      if (itemCount > 0) {
        if (_currentPage < itemCount - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          _pageController.animateToPage(_currentPage,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut);
        }
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    nameController.dispose();
    pinController.dispose();
    super.dispose();
  }

  // ==========================================
  // نافذة إعداد PIN لأول مرة
  // ==========================================
  Future<String?> _showPinSetupIfNeeded() async {
    // ✅ استبدال SystemProvider بـ WalletProvider
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    // لكن currentUserPin غير موجودة في WalletProvider الذي أنشأناه،
    // سنضيفها لاحقاً. حالياً نستخدم SystemProvider للـ PIN فقط
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final currentPin = sys.currentUserPin;

    if (currentPin.isNotEmpty && currentPin.length == 6) return currentPin;

    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool visible = false;
    bool confirmVisible = false;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إعداد رمز PIN الشامل', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('يجب تعيين رمز مكون من 6 أرقام لتأمين حسابك وجميع العمليات.'),
                const SizedBox(height: 16),
                TextField(
                  controller: pinCtrl,
                  obscureText: !visible,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'الرمز السري (6 أرقام)',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => visible = !visible),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: !confirmVisible,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'تأكيد الرمز السري',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(confirmVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => confirmVisible = !confirmVisible),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تخطي'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (pinCtrl.text.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يجب أن يكون الرمز 6 أرقام', textDirection: TextDirection.rtl)),
                    );
                    return;
                  }
                  if (pinCtrl.text != confirmCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرمز غير متطابق', textDirection: TextDirection.rtl)),
                    );
                    return;
                  }
                  Navigator.pop(ctx, pinCtrl.text);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      await sys.updateUserPin(result);
      return result;
    }
    return null;
  }

  // ==========================================
  // حفظ بيانات الدخول للبصمة
  // ==========================================
  Future<void> _saveCredentialsForBiometrics(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_phone', phone);
    if (usePinLogin) {
      await prefs.setString('saved_pin', pinController.text.trim());
      await prefs.setBool('saved_usePin', true);
      await prefs.remove('saved_password');
    } else {
      await prefs.setString('saved_password', passwordController.text.trim());
      await prefs.setBool('saved_usePin', false);
      await prefs.remove('saved_pin');
    }
  }

  // ==========================================
  // العمليات الأساسية
  // ==========================================
  Future<void> _processLogin() async {
    FocusScope.of(context).unfocus();
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    uiProvider.playSound('click');

    String phone = phoneController.text.trim();

    if (phone.isEmpty) {
      uiProvider.playSound('error');
      _showErrorSnackBar('يرجى إدخال رقم الهاتف.');
      return;
    }

    if (!usePinLogin) {
      String password = passwordController.text.trim();
      if (password.isEmpty) {
        uiProvider.playSound('error');
        _showErrorSnackBar('يرجى إدخال كلمة المرور.');
        return;
      }
    } else {
      String pin = pinController.text.trim();
      if (pin.length != 6) {
        uiProvider.playSound('error');
        _showErrorSnackBar('يرجى إدخال رمز PIN المكون من 6 أرقام.');
        return;
      }
    }

    setState(() => isLoading = true);

    // ✅ استبدال SystemProvider بـ SettingsProvider و AuthProvider
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (settingsProvider.isMaintenanceMode && phone != '774578241') {
      setState(() => isLoading = false);
      uiProvider.playSound('error');
      _showErrorSnackBar('النظام تحت الصيانة حالياً. يرجى المحاولة لاحقاً.');
      return;
    }

    Map<String, dynamic>? userData;
    if (usePinLogin) {
      userData = await authProvider.loginWithPin(phone, pinController.text.trim());
    } else {
      userData = await authProvider.loginUser(phone, passwordController.text.trim());
    }

    if (!mounted) return;
    setState(() => isLoading = false);

    if (userData != null) {
      String userRole = userData['role'];

      // إجبار المستخدمين الجدد على تعيين PIN
      if (userRole == 'user' || userRole == 'pos') {
        final pinSet = await _showPinSetupIfNeeded();
        if (pinSet == null) {
          _showErrorSnackBar('يجب تعيين رمز PIN للمتابعة.');
          return;
        }
      }

      // حفظ بيانات الدخول للبصمة
      await _saveCredentialsForBiometrics(phone);

      Provider.of<ThemeProvider>(context, listen: false).setUser(userRole, phone);
      uiProvider.playSound('success');

      if (userRole == 'super_admin' || userRole == 'staff') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard()));
      } else if (userRole == 'agent') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AgentDashboardScreen()));
      } else if (userRole == 'user' || userRole == 'pos') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      }
    } else {
      uiProvider.playSound('error');
      _showErrorSnackBar(usePinLogin ? 'رقم الهاتف أو رمز PIN غير صحيح!' : 'رقم الهاتف غير مسجل أو كلمة المرور خاطئة!');
    }
  }

  Future<void> _processRegistration() async {
    FocusScope.of(context).unfocus();
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    uiProvider.playSound('click');

    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();
    String name = nameController.text.trim();

    if (phone.isEmpty || password.isEmpty || name.isEmpty) {
      uiProvider.playSound('error');
      _showErrorSnackBar('يرجى تعبئة جميع الحقول!');
      return;
    }

    setState(() => isLoading = true);
    // ✅ checkUserExists ما زالت في SystemProvider حالياً
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool isExist = await systemProvider.checkUserExists(phone);

    if (!mounted) return;

    if (isExist) {
      setState(() => isLoading = false);
      uiProvider.playSound('error');
      _showErrorSnackBar('هذا الرقم مسجل مسبقاً! يرجى تسجيل الدخول.');
      setState(() => isLoginMode = true);
    } else {
      await authProvider.registerNewUser(name: name, phone: phone, password: password, role: 'user');
      if (!mounted) return;
      setState(() => isLoading = false);

      final pinSet = await _showPinSetupIfNeeded();
      if (pinSet == null) {
        _showErrorSnackBar('يجب تعيين رمز PIN للمتابعة.');
        return;
      }

      await _saveCredentialsForBiometrics(phone);

      Provider.of<ThemeProvider>(context, listen: false).setUser('user', phone);
      uiProvider.playSound('success');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      _showSuccessSnackBar('تم التسجيل بنجاح! أهلاً بك.');
    }
  }

  // ==========================================
  // الدخول السريع بالبصمة
  // ==========================================
  Future<void> _authenticateWithBiometrics() async {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    uiProvider.playSound('click');

    if (kIsWeb) {
      _showErrorSnackBar('عذراً، الدخول بالبصمة يعمل فقط على تطبيقات الهواتف (Android/iOS) وليس المتصفح.');
      return;
    }

    try {
      final bool canAuthenticate = await auth.authenticate(
        localizedReason: 'الرجاء مسح بصمة الإصبع لتسجيل الدخول',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (!canAuthenticate) {
        _showErrorSnackBar('فشل التحقق بالبصمة');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('saved_phone') ?? '';
      final password = prefs.getString('saved_password') ?? '';
      final usePin = prefs.getBool('saved_usePin') ?? false;
      final pin = prefs.getString('saved_pin') ?? '';

      if (phone.isEmpty) {
        _showErrorSnackBar('لا توجد بيانات دخول محفوظة. الرجاء تسجيل الدخول بكلمة المرور أولاً.');
        return;
      }

      setState(() => isLoading = true);
      // ✅ استبدال SystemProvider بـ AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      Map<String, dynamic>? userData;
      if (usePin && pin.length == 6) {
        userData = await authProvider.loginWithPin(phone, pin);
      } else if (password.isNotEmpty) {
        userData = await authProvider.loginUser(phone, password);
      }

      if (!mounted) return;
      setState(() => isLoading = false);

      if (userData != null) {
        String userRole = userData['role'];
        Provider.of<ThemeProvider>(context, listen: false).setUser(userRole, phone);
        uiProvider.playSound('success');

        if (userRole == 'super_admin' || userRole == 'staff') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SuperAdminDashboard()));
        } else if (userRole == 'agent') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AgentDashboardScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserDashboardScreen()));
        }
      } else {
        _showErrorSnackBar('تعذر تسجيل الدخول. قد تكون كلمة المرور تغيرت.');
      }
    } catch (e) {
      _showErrorSnackBar('فشل التحقق بالبصمة');
    }
  }

  void _showForgotPasswordDialog() {
    Provider.of<UiProvider>(context, listen: false).playSound('click');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة كلمة المرور', textDirection: TextDirection.rtl),
        content: const TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'أدخل رقم هاتفك المسجل', prefixIcon: Icon(Icons.phone)), textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () {
            Navigator.pop(context);
            Provider.of<UiProvider>(context, listen: false).playSound('success');
            _showSuccessSnackBar('تم إرسال رمز الاستعادة (OTP) إلى رقمك.');
          }, child: const Text('إرسال الرمز')),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, textDirection: TextDirection.rtl), backgroundColor: Colors.red.shade800));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, textDirection: TextDirection.rtl), backgroundColor: Colors.green.shade800));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ✅ استبدال SystemProvider بـ SettingsProvider لجميع إعدادات المظهر
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = Theme.of(context).colorScheme;

    if (settingsProvider.isMaintenanceMode) {
      return Scaffold(
        backgroundColor: themeProvider.primaryColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle, size: 100, color: Colors.redAccent),
              const SizedBox(height: 20),
              Text('النظام تحت الصيانة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.onSurface)),
              const SizedBox(height: 10),
              Text('نعمل على تحسين تجربتكم، سنعود قريباً.', style: TextStyle(fontSize: 16, color: colors.onSurface.withOpacity(0.7))),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () => _showEmergencyLoginDialog(),
                icon: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                label: const Text('دخول الطوارئ (للإدارة فقط)'),
              )
            ],
          ),
        ),
      );
    }

    if (settingsProvider.isForcedUpdate) {
      return Scaffold(
        backgroundColor: themeProvider.primaryColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, size: 100, color: Colors.orange),
              const SizedBox(height: 20),
              Text('تحديث هام متاح', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.onSurface)),
              const SizedBox(height: 10),
              Text('يرجى تحديث التطبيق إلى آخر إصدار لمتابعة الاستخدام.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: colors.onSurface.withOpacity(0.7))),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                onPressed: () {},
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('تحديث الآن', style: TextStyle(color: Colors.white, fontSize: 16)),
              )
            ],
          ),
        ),
      );
    }

    final List<String> carouselImages = settingsProvider.loginCarouselImages;
    final String welcomeMessage = settingsProvider.loginWelcomeMessage.isNotEmpty ? settingsProvider.loginWelcomeMessage : 'أهلاً بك في نظام كروت نت';
    final CrossAxisAlignment columnAlign = settingsProvider.appNameAlign == 'right' ? CrossAxisAlignment.start : (settingsProvider.appNameAlign == 'left' ? CrossAxisAlignment.end : CrossAxisAlignment.center);
    final String customFont = settingsProvider.appNameFont;
    final Color customColor = Color(settingsProvider.appNameColor);
    final String appName = settingsProvider.appName.isNotEmpty ? settingsProvider.appName : 'شبكة كروت نت';

    return Scaffold(
      backgroundColor: Color(settingsProvider.loginBgColor),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (isLoginMode) ...[
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.22,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: carouselImages.isNotEmpty ? carouselImages.length : _fallbackAdColors.length,
                    itemBuilder: (context, index) {
                      if (carouselImages.isNotEmpty) {
                        return Container(
                          color: Colors.transparent,
                          child: Image.network(carouselImages[index], fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade300, child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)))),
                        );
                      } else {
                        return Container(
                          color: _fallbackAdColors[index],
                          child: Center(child: Text('مساحة إعلانية ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                        );
                      }
                    },
                  ),
                ),
                if (settingsProvider.showNewsBar)
                  Container(
                    width: double.infinity, height: 35,
                    color: Color(settingsProvider.marqueeBgColor),
                    child: _CustomMarquee(
                      text: welcomeMessage,
                      textColor: Color(settingsProvider.marqueeTextColor),
                      direction: settingsProvider.marqueeDirection,
                    ),
                  ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      crossAxisAlignment: columnAlign,
                      children: [
                        if (settingsProvider.appLogoUrl.isNotEmpty) ...[
                          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(settingsProvider.appLogoUrl, height: 100, fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox.shrink())),
                          const SizedBox(height: 15),
                        ],
                        Text(
                          appName,
                          textAlign: settingsProvider.appNameAlign == 'right' ? TextAlign.right : (settingsProvider.appNameAlign == 'left' ? TextAlign.left : TextAlign.center),
                          style: customFont == 'System' || customFont.isEmpty
                              ? TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: customColor)
                              : GoogleFonts.getFont(customFont, textStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: customColor)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ] else ...[
                const SizedBox(height: 50),
                const Center(child: Icon(Icons.person_add, size: 60, color: Colors.blueAccent)),
                const SizedBox(height: 10),
                const Text('إنشاء حساب جديد', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 30),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isLoginMode) ...[
                        TextField(controller: nameController, decoration: InputDecoration(labelText: "الاسم الرباعي", prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: theme.cardColor)),
                        const SizedBox(height: 15),
                      ],
                      TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "رقم الهاتف", prefixIcon: const Icon(Icons.phone_android), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: theme.cardColor)),
                      const SizedBox(height: 15),
                      if (isLoginMode && usePinLogin)
                        TextField(
                          controller: pinController, obscureText: obscurePin, keyboardType: TextInputType.number, maxLength: 6,
                          decoration: InputDecoration(labelText: "رمز PIN", prefixIcon: const Icon(Icons.pin), suffixIcon: IconButton(icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () { Provider.of<UiProvider>(context, listen: false).playSound('click'); setState(() { obscurePin = !obscurePin; }); }), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: theme.cardColor),
                        )
                      else
                        TextField(
                          controller: passwordController, obscureText: obscurePassword,
                          decoration: InputDecoration(labelText: "كلمة المرور", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () { Provider.of<UiProvider>(context, listen: false).playSound('click'); setState(() { obscurePassword = !obscurePassword; }); }), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: theme.cardColor),
                        ),
                      if (isLoginMode)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [Checkbox(value: rememberMe, onChanged: (value) { Provider.of<UiProvider>(context, listen: false).playSound('click'); setState(() => rememberMe = value!); }), const Text("تذكرني", style: TextStyle(fontSize: 14))]),
                            Row(children: [Text(usePinLogin ? "PIN" : "كلمة المرور", style: const TextStyle(fontSize: 13, color: Colors.blueAccent)), Switch(value: usePinLogin, activeColor: Colors.blueAccent, onChanged: (val) { Provider.of<UiProvider>(context, listen: false).playSound('click'); setState(() => usePinLogin = val); })]),
                          ],
                        ),
                      if (isLoginMode && !usePinLogin) TextButton(onPressed: _showForgotPasswordDialog, child: const Text("نسيت كلمة المرور؟", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 20),
                      SizedBox(height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isLoginMode ? Colors.blueAccent : Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: isLoading ? null : (isLoginMode ? _processLogin : _processRegistration), child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Text(isLoginMode ? "تسجيل الدخول" : "تأكيد التسجيل", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                      const SizedBox(height: 15),
                      if (isLoginMode) SizedBox(height: 55, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blueAccent, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.fingerprint, size: 28, color: Colors.blueAccent), label: const Text("الدخول السريع بالبصمة", style: TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold)), onPressed: isLoading ? null : _authenticateWithBiometrics)),
                      const SizedBox(height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(isLoginMode ? "ليس لديك حساب؟" : "لديك حساب بالفعل؟", style: const TextStyle(fontSize: 15)), TextButton(onPressed: () { Provider.of<UiProvider>(context, listen: false).playSound('click'); setState(() { isLoginMode = !isLoginMode; phoneController.clear(); passwordController.clear(); pinController.clear(); }); }, child: Text(isLoginMode ? "إنشاء حساب جديد" : "تسجيل الدخول", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)))]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('دخول الطوارئ', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الإدارة (774578241)')), const SizedBox(height: 10), TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور'))]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), ElevatedButton(onPressed: () { Navigator.pop(context); _processLogin(); }, child: const Text('دخول'))],
        ),
      ),
    );
  }
}

class _CustomMarquee extends StatefulWidget {
  final String text;
  final Color textColor;
  final String direction;
  const _CustomMarquee({required this.text, required this.textColor, required this.direction});
  @override
  State<_CustomMarquee> createState() => _CustomMarqueeState();
}

class _CustomMarqueeState extends State<_CustomMarquee> {
  late ScrollController _scrollController;
  Timer? _timer;
  @override
  void initState() { super.initState(); _scrollController = ScrollController(); WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling()); }
  void _startScrolling() { if (!mounted) return; _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) { if (_scrollController.hasClients) { double maxScroll = _scrollController.position.maxScrollExtent; double currentScroll = _scrollController.offset; if (maxScroll > 0) { if (currentScroll >= maxScroll) { _scrollController.jumpTo(0.0); } else { _scrollController.jumpTo(currentScroll + 1.5); } } } }); }
  @override
  void dispose() { _timer?.cancel(); _scrollController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return Directionality(textDirection: widget.direction == 'ltr' ? TextDirection.ltr : TextDirection.rtl, child: SingleChildScrollView(controller: _scrollController, scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics(), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 400.0, vertical: 6.0), child: Text(widget.text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.textColor))))); }
}
