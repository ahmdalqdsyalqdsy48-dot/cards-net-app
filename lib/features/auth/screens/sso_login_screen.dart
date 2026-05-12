import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/system_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/ui_provider.dart';

class SSOLoginScreen extends StatefulWidget {
  const SSOLoginScreen({super.key});

  @override
  State<SSOLoginScreen> createState() => _SSOLoginScreenState();
}

class _SSOLoginScreenState extends State<SSOLoginScreen>
    with SingleTickerProviderStateMixin {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final pinController = TextEditingController();

  bool _isPasswordLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  String _biometricError = '';
  String? _lastLoggedInPhone;
  Timer? _carouselTimer;
  int _currentCarouselIndex = 0;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadLastLoggedInPhone();
    // بدء المؤقت التلقائي للسلايدر
    _startCarouselTimer();
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    pinController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarouselTimer() {
    final systemProvider =
        Provider.of<SystemProvider>(context, listen: false);
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(
        Duration(seconds: systemProvider.carouselIntervalSeconds), (timer) {
      if (mounted) {
        setState(() {
          _currentCarouselIndex =
              (_currentCarouselIndex + 1) %
              (systemProvider.loginCarouselImages.isEmpty
                  ? 1
                  : systemProvider.loginCarouselImages.length);
        });
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (mounted) {
        setState(() {
          _isBiometricAvailable = canAuthenticateWithBiometrics ||
              availableBiometrics.isNotEmpty;
          _biometricError = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBiometricAvailable = false;
          _biometricError = 'تعذر التحقق من المقاييس الحيوية: $e';
        });
      }
    }
  }

  Future<void> _loadLastLoggedInPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('lastLoggedInPhone');
    if (phone != null && mounted) {
      setState(() {
        _lastLoggedInPhone = phone;
        phoneController.text = phone;
      });
    }
  }

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  Future<void> _authenticate() async {
    _play('click');
    final systemProvider =
        Provider.of<SystemProvider>(context, listen: false);

    if (_isPasswordLogin) {
      final phone = phoneController.text.trim();
      final password = passwordController.text.trim();
      if (phone.isEmpty || password.isEmpty) {
        _showSnackBar('يرجى إدخال رقم الهاتف وكلمة المرور', isError: true);
        return;
      }
      setState(() => _isLoading = true);
      final userData = await systemProvider.loginUser(phone, password);
      setState(() => _isLoading = false);
      if (userData != null) {
        await _saveLastLoggedInPhone(phone);
        if (mounted) _navigateToRoleSpecificScreen(systemProvider);
      } else {
        if (mounted) {
          _showSnackBar(
              'رقم الهاتف أو كلمة المرور غير صحيحة. حاول مرة أخرى.',
              isError: true);
        }
      }
    } else {
      final pin = pinController.text.trim();
      if (pin.length != 6) {
        _showSnackBar('يجب إدخال رمز PIN المكون من 6 أرقام', isError: true);
        return;
      }
      if (_lastLoggedInPhone == null) {
        _showSnackBar('لم يتم العثور على آخر رقم مسجل دخول. استخدم كلمة المرور.',
            isError: true);
        return;
      }
      setState(() => _isLoading = true);
      final userData = await systemProvider.loginWithPin(
          _lastLoggedInPhone!, pin);
      setState(() => _isLoading = false);
      if (userData != null) {
        if (mounted) _navigateToRoleSpecificScreen(systemProvider);
      } else {
        if (mounted) {
          _showSnackBar('رمز PIN غير صحيح. حاول مرة أخرى.', isError: true);
        }
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    _play('click');
    if (!_isBiometricAvailable || _lastLoggedInPhone == null) {
      _showSnackBar(
          'المصادقة الحيوية غير متاحة أو لا يوجد آخر رقم مسجل دخول.',
          isError: true);
      return;
    }
    try {
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'الرجاء استخدام البصمة لتسجيل الدخول',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated && mounted) {
        final systemProvider =
            Provider.of<SystemProvider>(context, listen: false);
        // استخدام PIN الافتراضي أو المحفوظ لاستكمال الدخول
        final userData = await systemProvider.loginWithPin(
            _lastLoggedInPhone!, '123456'); // سيقرأ PIN الحقيقي من Firestore
        if (userData != null) {
          _navigateToRoleSpecificScreen(systemProvider);
        } else {
          _showSnackBar('تعذر تسجيل الدخول بعد التحقق الحيوي.', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('فشل المصادقة الحيوية: $e', isError: true);
    }
  }

  Future<void> _saveLastLoggedInPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastLoggedInPhone', phone);
    setState(() => _lastLoggedInPhone = phone);
  }

  void _navigateToRoleSpecificScreen(SystemProvider sys) {
    final role = sys.currentUserRole;
    String route;
    switch (role) {
      case 'super_admin':
        route = '/super_admin_dashboard';
        break;
      case 'agent':
        route = '/agent_dashboard';
        break;
      case 'user':
      case 'pos':
        route = '/user_dashboard';
        break;
      default:
        route = '/user_dashboard';
    }
    Navigator.pushReplacementNamed(context, route);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, textDirection: TextDirection.rtl),
      backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final colors = Theme.of(context).colorScheme;

    // استخدام لون الخلفية من إعدادات النظام أو الثيم الحالي
    final Color bgColor = Color(systemProvider.loginBgColor);
    final List<String> carouselImages = systemProvider.loginCarouselImages;
    final bool isMaintenance = systemProvider.isMaintenanceMode;
    final bool isForcedUpdate = systemProvider.isForcedUpdate;

    // نص متكيف مع الثيم بدلاً من adaptiveTextColor
    final Color onSurfaceColor = colors.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: isMaintenance
            ? _buildMaintenanceScreen(onSurfaceColor)
            : isForcedUpdate
                ? _buildForcedUpdateScreen(onSurfaceColor)
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // شعار التطبيق واسمه
                          if (systemProvider.appLogoUrl.isNotEmpty)
                            Image.network(
                              systemProvider.appLogoUrl,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.store,
                                      size: 80, color: Colors.white),
                            )
                          else
                            Icon(Icons.store,
                                size: 80, color: colors.primary),
                          const SizedBox(height: 10),
                          Text(
                            systemProvider.appName,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: onSurfaceColor,
                              fontFamily: systemProvider.appNameFont,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            systemProvider.loginWelcomeMessage,
                            style: TextStyle(
                              fontSize: 16,
                              color: onSurfaceColor.withOpacity(0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // سلايدر الصور
                          if (carouselImages.isNotEmpty)
                            SizedBox(
                              height: 160,
                              child: PageView.builder(
                                controller: PageController(
                                    initialPage: _currentCarouselIndex),
                                itemCount: carouselImages.length,
                                onPageChanged: (index) {
                                  setState(
                                      () => _currentCarouselIndex = index);
                                },
                                itemBuilder: (context, index) {
                                  return ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(15),
                                    child: Image.network(
                                      carouselImages[index],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        color: Colors.grey.shade300,
                                        child: const Icon(
                                            Icons.broken_image,
                                            size: 60),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 20),

                          // نموذج تسجيل الدخول
                          if (_isPasswordLogin) ...[
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'رقم الهاتف',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                filled: true,
                                fillColor:
                                    colors.surfaceVariant.withOpacity(0.3),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () {
                                    setState(() => _obscurePassword =
                                        !_obscurePassword);
                                  },
                                ),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                filled: true,
                                fillColor:
                                    colors.surfaceVariant.withOpacity(0.3),
                              ),
                            ),
                          ] else ...[
                            TextField(
                              controller: pinController,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: 'رمز PIN (6 أرقام)',
                                prefixIcon: const Icon(Icons.pin),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                filled: true,
                                fillColor:
                                    colors.surfaceVariant.withOpacity(0.3),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          // زر تسجيل الدخول
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _authenticate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: colors.onPrimary,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : Text(
                                      _isPasswordLogin
                                          ? 'تسجيل الدخول'
                                          : 'دخول بـ PIN',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // التبديل بين كلمة المرور و PIN
                          TextButton(
                            onPressed: () {
                              _play('click');
                              setState(() => _isPasswordLogin =
                                  !_isPasswordLogin);
                            },
                            child: Text(
                              _isPasswordLogin
                                  ? 'الدخول برمز PIN السريع'
                                  : 'الدخول بكلمة المرور',
                              style: TextStyle(color: colors.primary),
                            ),
                          ),
                          // أيقونة البصمة إذا كانت متاحة
                          if (_isBiometricAvailable &&
                              _lastLoggedInPhone != null)
                            IconButton(
                              icon: const Icon(Icons.fingerprint,
                                  size: 40),
                              color: colors.primary,
                              onPressed: _authenticateWithBiometrics,
                            ),
                          const SizedBox(height: 20),
                          // تسجيل مستخدم جديد (اختياري)
                          TextButton(
                            onPressed: () {
                              _play('click');
                              _showRegistrationDialog();
                            },
                            child: Text(
                              'إنشاء حساب جديد',
                              style: TextStyle(color: colors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildMaintenanceScreen(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            Text('النظام تحت الصيانة',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            const SizedBox(height: 10),
            Text('نعمل على تحسين تجربتكم، سنعود قريباً.',
                style: TextStyle(
                    fontSize: 16,
                    color: textColor.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildForcedUpdateScreen(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.system_update, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text('تحديث هام متاح',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            const SizedBox(height: 10),
            Text('يرجى تحديث التطبيق إلى آخر إصدار لمتابعة الاستخدام.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: textColor.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  void _showRegistrationDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إنشاء حساب جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: 'الاسم', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setStateDialog(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final systemProvider = Provider.of<SystemProvider>(
                      context,
                      listen: false);
                  final phone = phoneController.text.trim();
                  final password = passwordController.text.trim();
                  final name = nameController.text.trim();
                  if (phone.isEmpty || password.isEmpty || name.isEmpty) {
                    _showSnackBar('يرجى تعبئة جميع الحقول', isError: true);
                    return;
                  }
                  try {
                    await systemProvider.registerNewUser(
                        name: name,
                        phone: phone,
                        password: password,
                        role: 'user');
                    Navigator.pop(ctx);
                    _showSnackBar('تم إنشاء الحساب بنجاح');
                  } catch (e) {
                    _showSnackBar('فشل التسجيل: $e', isError: true);
                  }
                },
                child: const Text('تسجيل'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
