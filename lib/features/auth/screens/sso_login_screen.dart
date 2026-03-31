import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart'; // مكتبة البصمة

import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart';

import '../../super_admin/screens/super_admin_dashboard.dart';
import '../../agent_panel/screens/agent_dashboard_screen.dart';
import '../../user_panel/screens/user_dashboard_screen.dart';

class SSOLoginScreen extends StatefulWidget {
  const SSOLoginScreen({super.key});

  @override
  State<SSOLoginScreen> createState() => _SSOLoginScreenState();
}

class _SSOLoginScreenState extends State<SSOLoginScreen> {
  // ==========================================
  // 1. متحكمات وحالة الشاشة (State)
  // ==========================================
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  bool isLoading = false; // حالة التحميل (Loading) لمنع الضغط المتكرر
  bool obscurePassword = true; // إخفاء/إظهار كلمة المرور
  bool rememberMe = false; // خيار تذكرني
  bool isLoginMode = true; // التبديل بين تسجيل الدخول وإنشاء حساب جديد

  // مكتبة البصمة
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ==========================================
  // 2. دالة تسجيل الدخول (الذكية والآمنة)
  // ==========================================
  Future<void> _processLogin() async {
    // إخفاء لوحة المفاتيح عند الضغط
    FocusScope.of(context).unfocus();

    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    // 1. التحقق من الحقول الفارغة
    if (phone.isEmpty || password.isEmpty) {
      _showErrorSnackBar('يرجى إدخال رقم الهاتف وكلمة المرور.');
      return;
    }

    // 2. تفعيل حالة التحميل (Loading)
    setState(() => isLoading = true);

    // محاكاة الاتصال بالخادم (تأخير بسيط ليرى المستخدم مؤشر التحميل)
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // 3. فحص حساب مالك النظام الثابت (حالة استثنائية عليا)
    if (phone == '774578241' && password == '75486958aaa') {
      Provider.of<ThemeProvider>(context, listen: false).setRole('super_admin');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard()));
      return;
    }

    // 4. الاتصال بقاعدة البيانات الحقيقية
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    final Map<String, dynamic>? userData = systemProvider.loginUser(phone, password);
    
    // 5. إيقاف حالة التحميل بعد وصول الرد
    setState(() => isLoading = false);

    if (userData != null) {
      // نجاح الدخول: التوجيه الذكي حسب الدور (بدون سؤال المستخدم)
      String userRole = userData['role']; 
      Provider.of<ThemeProvider>(context, listen: false).setRole(userRole);
      
      if (userRole == 'agent') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AgentDashboardScreen()));
      } else if (userRole == 'user') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      }
    } else {
      // فشل الدخول: رسالة واضحة
      _showErrorSnackBar('رقم الهاتف غير مسجل أو كلمة المرور خاطئة!');
    }
  }

  // ==========================================
  // 3. دالة البصمة
  // ==========================================
  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) {
        _showErrorSnackBar('جهازك لا يدعم البصمة أو غير مفعلة.');
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'يرجى وضع إصبعك على المستشعر لتسجيل الدخول السريع',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (didAuthenticate) {
        // سيتم ربطها لاحقاً بجلب بيانات آخر مستخدم من ذاكرة الهاتف
        _showSuccessSnackBar('نجحت البصمة! جاري الدخول...');
        Provider.of<ThemeProvider>(context, listen: false).setRole('user');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      }
    } catch (e) {
      _showErrorSnackBar('فشلت عملية التحقق من البصمة.');
    }
  }

  // ==========================================
  // 4. دوال مساعدة لرسائل الخطأ والنجاح
  // ==========================================
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, textDirection: TextDirection.rtl), backgroundColor: Colors.red.shade800, behavior: SnackBarBehavior.floating));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, textDirection: TextDirection.rtl), backgroundColor: Colors.green.shade800, behavior: SnackBarBehavior.floating));
  }

  // ==========================================
  // 5. بناء واجهة المستخدم (Minimal & Clean UI)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch, // لجعل الأزرار تمتد بعرض الشاشة
                children: [
                  // 1. الشعار واسم التطبيق
                  const Icon(Icons.wifi_tethering, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text('كروت نت', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text('أسرع شبكة لبيع الكروت والخدمات', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  const SizedBox(height: 40),

                  // 2. حقل رقم الهاتف
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next, // زر التالي في الكيبورد
                    decoration: InputDecoration(
                      labelText: "رقم الهاتف",
                      prefixIcon: const Icon(Icons.phone_android),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. حقل كلمة المرور مع زر الإظهار/الإخفاء 👁
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done, // زر الإرسال في الكيبورد
                    onSubmitted: (_) => isLoading ? null : _processLogin(), // الدخول عند ضغط Enter
                    decoration: InputDecoration(
                      labelText: "كلمة المرور",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                  ),
                  
                  // 4. خيارات إضافية (تذكرني + نسيت كلمة المرور)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: rememberMe,
                            onChanged: (value) => setState(() => rememberMe = value!),
                            activeColor: Colors.blueAccent,
                          ),
                          const Text("تذكرني", style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          _showErrorSnackBar('سيتم تفعيل استعادة كلمة المرور لاحقاً.');
                        },
                        child: const Text("نسيت كلمة المرور؟", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 5. زر تسجيل الدخول (مع حالة التحميل)
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isLoading ? null : _processLogin, // تعطيل الزر أثناء التحميل
                      child: isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text("تسجيل الدخول", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // 6. زر الدخول السريع بالبصمة
                  SizedBox(
                    height: 55,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.fingerprint, size: 28, color: Colors.blueAccent),
                      label: const Text("الدخول السريع بالبصمة", style: TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      onPressed: isLoading ? null : _authenticateWithBiometrics,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 7. رابط إنشاء حساب جديد
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("ليس لديك حساب؟", style: TextStyle(fontSize: 15)),
                      TextButton(
                        onPressed: () {
                          _showSuccessSnackBar('سيتم توجيهك لصفحة التسجيل قريباً.');
                          // يمكنك لاحقاً فتح شاشة تسجيل مستقلة هنا
                        },
                        child: const Text("إنشاء حساب جديد", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
