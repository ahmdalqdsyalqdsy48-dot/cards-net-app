import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb; // لمعرفة هل التطبيق يعمل على الويب
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';

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
  // 1. متحكمات النصوص والحالة
  // ==========================================
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController(); // لحساب جديد
  
  bool isLoginMode = true; // للتبديل بين تسجيل الدخول وإنشاء حساب
  bool isLoading = false; 
  bool obscurePassword = true; 
  bool rememberMe = false; 

  // متغيرات الإعلانات
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;
  final List<Color> _adColors = [Colors.blue.shade800, Colors.deepPurple, Colors.teal];

  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    // تشغيل الإعلانات التلقائية
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < _adColors.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
    super.dispose();
  }

  // ==========================================
  // 2. العمليات الأساسية (الدخول، التسجيل، البصمة، استعادة)
  // ==========================================

  // دالة تسجيل الدخول
  Future<void> _processLogin() async {
    FocusScope.of(context).unfocus();
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showErrorSnackBar('يرجى إدخال رقم الهاتف وكلمة المرور.');
      return;
    }

    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // محاكاة التحميل
    if (!mounted) return;

    if (phone == '774578241' && password == '75486958aaa') {
      Provider.of<ThemeProvider>(context, listen: false).setRole('super_admin');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard()));
      return;
    }

    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    final Map<String, dynamic>? userData = systemProvider.loginUser(phone, password);
    
    setState(() => isLoading = false);

    if (userData != null) {
      String userRole = userData['role']; 
      Provider.of<ThemeProvider>(context, listen: false).setRole(userRole);
      if (userRole == 'agent') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AgentDashboardScreen()));
      } else if (userRole == 'user') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      }
    } else {
      _showErrorSnackBar('رقم الهاتف غير مسجل أو كلمة المرور خاطئة!');
    }
  }

  // دالة التسجيل الجديد
  Future<void> _processRegistration() async {
    FocusScope.of(context).unfocus();
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();
    String name = nameController.text.trim();

    if (phone.isEmpty || password.isEmpty || name.isEmpty) {
      _showErrorSnackBar('يرجى تعبئة جميع الحقول!');
      return;
    }

    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    bool isExist = systemProvider.checkUserExists(phone);

    setState(() => isLoading = false);

    if (isExist) {
      _showErrorSnackBar('هذا الرقم مسجل مسبقاً! يرجى تسجيل الدخول.');
      setState(() => isLoginMode = true);
    } else {
      systemProvider.registerNewUser(name: name, phone: phone, password: password, role: 'user');
      Provider.of<ThemeProvider>(context, listen: false).setRole('user');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      _showSuccessSnackBar('تم التسجيل بنجاح! أهلاً بك.');
    }
  }

  // دالة البصمة (مع معالجة خطأ الويب)
  Future<void> _authenticateWithBiometrics() async {
    if (kIsWeb) {
      _showErrorSnackBar('عذراً، الدخول بالبصمة يعمل فقط على تطبيقات الهواتف (Android/iOS) وليس المتصفح.');
      return;
    }

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
        _showSuccessSnackBar('نجحت البصمة!');
        Provider.of<ThemeProvider>(context, listen: false).setRole('user');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      }
    } catch (e) {
      _showErrorSnackBar('فشلت عملية التحقق من البصمة.');
    }
  }

  // دالة نافذة استعادة كلمة المرور
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('استعادة كلمة المرور', textDirection: TextDirection.rtl),
          content: TextField(
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'أدخل رقم هاتفك المسجل', prefixIcon: Icon(Icons.phone)),
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessSnackBar('تم إرسال رمز الاستعادة (OTP) إلى رقمك.');
              },
              child: const Text('إرسال الرمز'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, textDirection: TextDirection.rtl), backgroundColor: Colors.red.shade800));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, textDirection: TextDirection.rtl), backgroundColor: Colors.green.shade800));
  }

  // ==========================================
  // 3. بناء الواجهة
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- الإعلانات والشريط الإخباري (مخفية فقط في حالة التسجيل لتخفيف الزحمة) ---
              if (isLoginMode) ...[
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _adColors.length,
                    itemBuilder: (context, index) => Container(
                      color: _adColors[index],
                      child: Center(child: Text('إعلان ترويجي للمالك رقم ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity, height: 35, color: Colors.amber.withOpacity(0.3),
                  child: const _CustomMarquee(text: 'أهلاً بك في شبكة كروت نت - أسرع شبكة لبيع الكروت والخدمات...'),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const SizedBox(height: 50),
              ],

              // --- محتوى الفورم ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.wifi_tethering, size: 60, color: Colors.blueAccent),
                      const SizedBox(height: 10),
                      Text(isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب جديد', textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      const SizedBox(height: 30),

                      // حقل الاسم (يظهر فقط في حالة إنشاء حساب)
                      if (!isLoginMode) ...[
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(labelText: "الاسم الرباعي", prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: theme.cardColor),
                        ),
                        const SizedBox(height: 15),
                      ],

                      // حقل رقم الهاتف
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: "رقم الهاتف", prefixIcon: const Icon(Icons.phone_android), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: theme.cardColor),
                      ),
                      const SizedBox(height: 15),

                      // حقل كلمة المرور مع زر العين الفعال 👁
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword, // 👈 هنا يتم تطبيق التغيير
                        decoration: InputDecoration(
                          labelText: "كلمة المرور",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword; // 👈 تغيير الحالة هنا
                              });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true, fillColor: theme.cardColor,
                        ),
                      ),
                      
                      // خيارات إضافية (تذكرني + نسيت كلمة المرور) في حالة الدخول فقط
                      if (isLoginMode)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(value: rememberMe, onChanged: (value) => setState(() => rememberMe = value!)),
                                const Text("تذكرني", style: TextStyle(fontSize: 14)),
                              ],
                            ),
                            TextButton(
                              onPressed: _showForgotPasswordDialog, // 👈 فتح نافذة الاستعادة
                              child: const Text("نسيت كلمة المرور؟", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 20),

                      // زر التنفيذ الأساسي (دخول أو تسجيل)
                      SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: isLoginMode ? Colors.blueAccent : Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: isLoading ? null : (isLoginMode ? _processLogin : _processRegistration),
                          child: isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text(isLoginMode ? "تسجيل الدخول" : "تأكيد التسجيل", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                      const SizedBox(height: 15),

                      // زر البصمة (يظهر فقط في حالة الدخول)
                      if (isLoginMode)
                        SizedBox(
                          height: 55,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blueAccent, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            icon: const Icon(Icons.fingerprint, size: 28, color: Colors.blueAccent),
                            label: const Text("الدخول السريع بالبصمة", style: TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            onPressed: isLoading ? null : _authenticateWithBiometrics,
                          ),
                        ),

                      const SizedBox(height: 20),

                      // زر التبديل بين الدخول والتسجيل
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isLoginMode ? "ليس لديك حساب؟" : "لديك حساب بالفعل؟", style: const TextStyle(fontSize: 15)),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isLoginMode = !isLoginMode; // 👈 التبديل الحقيقي بين الشاشتين
                                phoneController.clear();
                                passwordController.clear();
                              });
                            },
                            child: Text(isLoginMode ? "إنشاء حساب جديد" : "تسجيل الدخول", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          ),
                        ],
                      ),
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
}

// ==========================================
// أداة الشريط المتحرك (Marquee)
// ==========================================
class _CustomMarquee extends StatefulWidget {
  final String text;
  const _CustomMarquee({required this.text});

  @override
  State<_CustomMarquee> createState() => _CustomMarqueeState();
}

class _CustomMarqueeState extends State<_CustomMarquee> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0.0);
        } else {
          _scrollController.animateTo(currentScroll + 2.0, duration: const Duration(milliseconds: 50), curve: Curves.linear);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 50.0), child: Text(widget.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
      ],
    );
  }
}
