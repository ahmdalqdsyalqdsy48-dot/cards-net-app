import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart'; // 👈 استدعاء مكتبة البصمة الحقيقية

import '../../../core/providers/theme_provider.dart';
import '../../super_admin/screens/super_admin_dashboard.dart';
import '../../agent_panel/screens/agent_dashboard_screen.dart';
import '../../user_panel/screens/user_dashboard_screen.dart';

class SSOLoginScreen extends StatefulWidget {
  const SSOLoginScreen({super.key});

  @override
  State<SSOLoginScreen> createState() => _SSOLoginScreenState();
}

class _SSOLoginScreenState extends State<SSOLoginScreen> {
  bool isLoginTab = true;
  
  // متحكمات النصوص
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  // ==========================================
  // 1. قاعدة بيانات محلية (لمحاكاة النظام الحقيقي)
  // ==========================================
  final List<Map<String, String>> _usersDB = [
    {'phone': '774578241', 'password': '123', 'role': 'super_admin', 'name': 'مالك النظام'},
    {'phone': '777777777', 'password': '123', 'role': 'agent', 'name': 'وكيل تجريبي'},
    {'phone': '777123456', 'password': '123', 'role': 'user', 'name': 'مستخدم تجريبي'},
  ];

  // ==========================================
  // 2. متغيرات الإعلانات المتحركة (Carousel)
  // ==========================================
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;
  final List<Color> _adColors = [Colors.blue.shade800, Colors.deepPurple, Colors.teal];

  // مكتبة البصمة
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    // تشغيل المؤقت ليغير الصورة كل 5 ثواني
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < _adColors.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
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
  // 3. دالة البصمة الحقيقية
  // ==========================================
  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جهازك لا يدعم البصمة أو غير مفعلة.', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'يرجى وضع إصبعك على المستشعر لتسجيل الدخول',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (didAuthenticate) {
        // إذا نجحت البصمة، نوجهه مثلاً كمالك نظام (أو حسب آخر مستخدم حفظه النظام)
        Provider.of<ThemeProvider>(context, listen: false).setRole('super_admin');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشلت عملية التحقق من البصمة.', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // 4. دالة تسجيل الدخول (الذكية)
  // ==========================================
  void _processLogin() {
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    // البحث عن المستخدم في قاعدة البيانات
    var user = _usersDB.where((u) => u['phone'] == phone && u['password'] == password).toList();

    if (user.isNotEmpty) {
      String role = user.first['role']!;
      
      // توجيه ذكي حسب الدور
      Provider.of<ThemeProvider>(context, listen: false).setRole(role);
      if (role == 'super_admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard()));
      } else if (role == 'agent') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AgentDashboardScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم الهاتف أو كلمة المرور غير صحيحة!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // 5. دالة التسجيل الجديد (الذكية)
  // ==========================================
  void _processRegistration() {
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();
    String name = nameController.text.trim();

    if (phone.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة جميع الحقول!', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
      return;
    }

    // فحص ما إذا كان الرقم مسجلاً مسبقاً
    bool isExist = _usersDB.any((u) => u['phone'] == phone);

    if (isExist) {
      // الحساب موجود: إظهار رسالة وتحويله لصفحة الدخول
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا الحساب مسجل مسبقاً! يرجى تسجيل الدخول.', textDirection: TextDirection.rtl), backgroundColor: Colors.blue));
      setState(() {
        isLoginTab = true; // العودة لتبويب الدخول تلقائياً
      });
    } else {
      // حساب جديد: إضافته كـ (مستخدم نهائي) وتوجيهه
      _usersDB.add({'phone': phone, 'password': password, 'role': 'user', 'name': name});
      Provider.of<ThemeProvider>(context, listen: false).setRole('user');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التسجيل بنجاح! أهلاً بك.', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ==========================================
              // الإعلانات الصورية المتغيرة تلقائياً + الأسهم
              // ==========================================
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.25,
                width: double.infinity,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) => setState(() => _currentPage = index),
                      itemCount: _adColors.length,
                      itemBuilder: (context, index) {
                        return Container(
                          color: _adColors[index],
                          child: Center(child: Text('إعلان ترويجي رقم ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                        );
                      },
                    ),
                    // سهم اليمين
                    Positioned(
                      right: 10, top: 0, bottom: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 30),
                        onPressed: () {
                          if (_currentPage > 0) {
                            _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                          }
                        },
                      ),
                    ),
                    // سهم اليسار
                    Positioned(
                      left: 10, top: 0, bottom: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
                        onPressed: () {
                          if (_currentPage < _adColors.length - 1) {
                            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // الشريط الإخباري المتحرك الفعلي (Marquee)
              // ==========================================
              Container(
                width: double.infinity,
                height: 40,
                color: Colors.amber.withOpacity(0.3),
                child: const _CustomMarquee(text: 'أهلاً بك في نظامنا الموحد - أسرع شبكة لبيع الكروت والخدمات... عروض خاصة اليوم! اغتنم الفرصة.'),
              ),
              
              const SizedBox(height: 20),

              const Text(
                'كروت نت',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.blueAccent),
              ),

              const SizedBox(height: 20),

              // أزرار التبديل بين الدخول والتسجيل
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => setState(() => isLoginTab = true),
                    child: Text('تسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: isLoginTab ? FontWeight.bold : FontWeight.normal)),
                  ),
                  const Text('|', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  TextButton(
                    onPressed: () => setState(() => isLoginTab = false),
                    child: Text('تسجيل جديد', style: TextStyle(fontSize: 18, fontWeight: !isLoginTab ? FontWeight.bold : FontWeight.normal)),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: isLoginTab ? _buildLoginForm() : _buildRegisterForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: 'رقم الهاتف (جرب: 777777777)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.phone)),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(labelText: 'كلمة المرور (جرب: 123)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.lock), suffixIcon: const Icon(Icons.visibility)),
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            // زر الدخول بالبصمة الحقيقي
            Container(
              height: 50,
              decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent), borderRadius: BorderRadius.circular(10)),
              child: IconButton(
                icon: const Icon(Icons.fingerprint, color: Colors.blueAccent, size: 28),
                tooltip: 'الدخول بالبصمة',
                onPressed: _authenticateWithBiometrics, // 👈 استدعاء الدالة الحقيقية
              ),
            ),
            const SizedBox(width: 10),
            // زر الدخول الذكي
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _processLogin, // 👈 استدعاء دالة الفحص الذكية
                  child: const Text('دخول', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'الاسم الرباعي', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.person)),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.phone)),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.lock)),
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _processRegistration, // 👈 استدعاء دالة التسجيل الذكية التي تفحص التكرار
            child: const Text('تسجيل حساب جديد', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// أداة بناء الشريط الإخباري المتحرك الحقيقي (Marquee)
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0.0); // العودة للبداية عند النهاية
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
      reverse: true, // لجعله يتحرك من اليمين لليسار لأننا بالعربية
      physics: const NeverScrollableScrollPhysics(), // منع سحب المستخدم له يدوياً
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50.0),
            child: Text(widget.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }
}
