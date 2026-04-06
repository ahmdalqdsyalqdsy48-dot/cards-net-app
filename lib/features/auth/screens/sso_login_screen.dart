import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb; 
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
  final TextEditingController nameController = TextEditingController(); 
  
  bool isLoginMode = true; 
  bool isLoading = false; 
  bool obscurePassword = true; 
  bool rememberMe = false; 

  // متغيرات الإعلانات/الصور
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;
  
  // ألوان احتياطية في حال لم يرفع المالك صوراً حقيقية بعد
  final List<Color> _fallbackAdColors = [Colors.blue.shade800, Colors.deepPurple, Colors.teal];

  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    // تأخير تشغيل السلايدر حتى يتم تحميل البيانات من Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDynamicCarousel();
    });
  }

  void _startDynamicCarousel() {
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    // قراءة المدة الزمنية لتغير الصور من السيرفر (بالثواني)
    int interval = systemProvider.carouselIntervalSeconds > 0 ? systemProvider.carouselIntervalSeconds : 5;

    _carouselTimer = Timer.periodic(Duration(seconds: interval), (Timer timer) {
      // نحدد عدد العناصر بناءً على الصور المرفوعة أو الألوان الاحتياطية
      int itemCount = systemProvider.loginCarouselImages.isNotEmpty 
          ? systemProvider.loginCarouselImages.length 
          : _fallbackAdColors.length;

      if (itemCount > 0) {
        if (_currentPage < itemCount - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
    super.dispose();
  }

  // ==========================================
  // 2. العمليات الأساسية المربوطة بالعقل المدبر
  // ==========================================
  Future<void> _processLogin() async {
    FocusScope.of(context).unfocus();
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showErrorSnackBar('يرجى إدخال رقم الهاتف وكلمة المرور.');
      return;
    }

    setState(() => isLoading = true);
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    final Map<String, dynamic>? userData = await systemProvider.loginUser(phone, password);
    
    if (!mounted) return;
    setState(() => isLoading = false);

    if (userData != null) {
      String userRole = userData['role']; 
      Provider.of<ThemeProvider>(context, listen: false).setRole(userRole);
      
      if (userRole == 'super_admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard()));
      } else if (userRole == 'agent') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AgentDashboardScreen()));
      } else if (userRole == 'user') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      }
    } else {
      _showErrorSnackBar('رقم الهاتف غير مسجل أو كلمة المرور خاطئة!');
    }
  }

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
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    bool isExist = await systemProvider.checkUserExists(phone);

    if (!mounted) return;

    if (isExist) {
      setState(() => isLoading = false);
      _showErrorSnackBar('هذا الرقم مسجل مسبقاً! يرجى تسجيل الدخول.');
      setState(() => isLoginMode = true);
    } else {
      await systemProvider.registerNewUser(name: name, phone: phone, password: password, role: 'user');
      if (!mounted) return;
      setState(() => isLoading = false);

      Provider.of<ThemeProvider>(context, listen: false).setRole('user');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      _showSuccessSnackBar('تم التسجيل بنجاح! أهلاً بك.');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (kIsWeb) {
      _showErrorSnackBar('عذراً، الدخول بالبصمة يعمل فقط على تطبيقات الهواتف (Android/iOS) وليس المتصفح.');
      return;
    }
    _showErrorSnackBar('قم بتسجيل الدخول برقمك وكلمة المرور أولاً لتفعيل الجلسة.');
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة كلمة المرور', textDirection: TextDirection.rtl),
        content: const TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'أدخل رقم هاتفك المسجل', prefixIcon: Icon(Icons.phone)), textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () { Navigator.pop(context); _showSuccessSnackBar('تم إرسال رمز الاستعادة (OTP) إلى رقمك.'); }, child: const Text('إرسال الرمز')),
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

  // ==========================================
  // 3. بناء الواجهة (بالترتيب المطلوب)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 👈 استدعاء SystemProvider لقراءة الإعدادات المخصصة من الخادم
    final systemProvider = Provider.of<SystemProvider>(context);
    
    // جلب قائمة الصور والرسالة الترحيبية من الخادم
    final List<String> carouselImages = systemProvider.loginCarouselImages;
    final String welcomeMessage = systemProvider.loginWelcomeMessage.isNotEmpty 
        ? systemProvider.loginWelcomeMessage 
        : 'أهلاً بك في نظام كروت نت - أسرع شبكة لبيع الكروت والخدمات...';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (isLoginMode) ...[
                // 1. الترتيب الأول: الصور المتغيرة (Slider)
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: carouselImages.isNotEmpty ? carouselImages.length : _fallbackAdColors.length,
                    itemBuilder: (context, index) {
                      if (carouselImages.isNotEmpty) {
                        // إذا كانت هناك صور مرفوعة من المالك
                        return Image.network(carouselImages[index], fit: BoxFit.cover);
                      } else {
                        // ألوان احتياطية في حال عدم وجود صور
                        return Container(
                          color: _fallbackAdColors[index],
                          child: Center(child: Text('صورة إعلانية ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                        );
                      }
                    },
                  ),
                ),
                
                // 2. الترتيب الثاني: شريط الرسالة الترحيبية المتحركة
                Container(
                  width: double.infinity, height: 35, color: Colors.amber.withOpacity(0.3),
                  child: _CustomMarquee(text: welcomeMessage), // 👈 يقرأ الرسالة الحقيقية
                ),
                
                const SizedBox(height: 20),
                
                // 3. الترتيب الثالث: اسم التطبيق أو الشعار
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_tethering, size: 40, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('شبكة كروت نت', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  ],
                ),
                const SizedBox(height: 30),
              ] else ...[
                const SizedBox(height: 50),
                const Center(child: Icon(Icons.wifi_tethering, size: 60, color: Colors.blueAccent)),
                const SizedBox(height: 10),
                const Text('إنشاء حساب جديد', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 30),
              ],

              // 4. بقية التفاصيل: حقول الإدخال
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isLoginMode) ...[
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(labelText: "الاسم الرباعي", prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: theme.cardColor),
                        ),
                        const SizedBox(height: 15),
                      ],

                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: "رقم الهاتف", prefixIcon: const Icon(Icons.phone_android), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: theme.cardColor),
                      ),
                      const SizedBox(height: 15),

                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword, 
                        decoration: InputDecoration(
                          labelText: "كلمة المرور",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () {
                              setState(() { obscurePassword = !obscurePassword; });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true, fillColor: theme.cardColor,
                        ),
                      ),
                      
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
                              onPressed: _showForgotPasswordDialog, 
                              child: const Text("نسيت كلمة المرور؟", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 20),

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

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isLoginMode ? "ليس لديك حساب؟" : "لديك حساب بالفعل؟", style: const TextStyle(fontSize: 15)),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isLoginMode = !isLoginMode; 
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
