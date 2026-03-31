import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart'; // مكتبة البصمة الحقيقية

import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart'; // 👈 استدعاء قاعدة البيانات الحقيقية

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
  
  // متحكمات النصوص لقراءة المدخلات
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  // ==========================================
  // متغيرات الإعلانات المتحركة (Carousel)
  // ==========================================
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;
  // هنا نضع ألوان الإعلانات (لاحقاً يمكن استبدالها بصور حقيقية Image.network)
  final List<Color> _adColors = [Colors.blue.shade800, Colors.deepPurple, Colors.teal];

  // مكتبة البصمة الفعالة
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    // تشغيل المؤقت ليغير الإعلان كل 5 ثواني تلقائياً
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < _adColors.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0; // العودة للإعلان الأول
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
    _carouselTimer?.cancel(); // إيقاف المؤقت عند الخروج من الشاشة للحفاظ على الذاكرة
    _pageController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  // ==========================================
  // دالة البصمة الحقيقية
  // ==========================================
  Future<void> _authenticateWithBiometrics() async {
    try {
      // فحص هل الهاتف يمتلك حساس بصمة وهل هو مفعل
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جهازك لا يدعم البصمة أو غير مفعلة.', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
        return;
      }

      // إظهار نافذة البصمة الخاصة بنظام التشغيل
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'يرجى وضع إصبعك على المستشعر لتسجيل الدخول',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (didAuthenticate) {
        // في النظام الفعلي: هنا نقرأ آخر مستخدم محفوظ في ذاكرة الهاتف وندخله
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نجحت البصمة! جاري توجيهك...', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
        
        // كمثال: توجيهه للوحة المستخدم (ستتغير برمجياً لاحقاً حسب آخر دخول)
        Provider.of<ThemeProvider>(context, listen: false).setRole('user');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشلت عملية التحقق من البصمة.', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // دالة تسجيل الدخول (الديناميكية الحقيقية)
  // ==========================================
  void _processLogin() {
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال رقم الهاتف وكلمة المرور.', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
      return;
    }

    // 1. حساب مالك النظام (الثابت الوحيد المسموح له بإدارة كل شيء)
    if (phone == '774578241' && password == '75486958aaa') {
      Provider.of<ThemeProvider>(context, listen: false).setRole('super_admin');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard()));
      return;
    }

    // 2. الاتصال بقاعدة البيانات الحقيقية للبحث عن المستخدم
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    
    // الدالة loginUser ستقوم بالبحث عن الرقم وكلمة المرور (سنبنيها في الخطوة القادمة)
    final Map<String, dynamic>? userData = systemProvider.loginUser(phone, password);
    
    if (userData != null) {
      // الحساب موجود وصحيح! نقرأ ما هو دوره
      String userRole = userData['role']; 
      
      // نطبق المظهر الخاص بدوره
      Provider.of<ThemeProvider>(context, listen: false).setRole(userRole);
      
      // توجيه ذكي حسب الدور
      if (userRole == 'agent') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AgentDashboardScreen()));
      } else if (userRole == 'user') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دور المستخدم غير مدعوم حالياً.', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
      }
    } else {
      // 3. رفض الدخول (لا يوجد وكيل أو مستخدم بهذا الرقم)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم الهاتف غير مسجل في النظام، أو كلمة المرور خاطئة!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // دالة التسجيل الجديد (تمنع التكرار فعلياً)
  // ==========================================
  void _processRegistration() {
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();
    String name = nameController.text.trim();

    if (phone.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة جميع الحقول!', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
      return;
    }

    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    
    // التحقق الفعلي من قاعدة البيانات لعدم تكرار الرقم
    bool isExist = systemProvider.checkUserExists(phone);

    if (isExist) {
      // الحساب موجود! نرفض التسجيل ونعيده لشاشة الدخول
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا الحساب مسجل مسبقاً! يرجى تسجيل الدخول.', textDirection: TextDirection.rtl), backgroundColor: Colors.blue));
      setState(() {
        isLoginTab = true; 
      });
    } else {
      // حساب جديد: نضيفه كمستخدم نهائي (user) ونحفظه في العقل المدبر
      systemProvider.registerNewUser(name: name, phone: phone, password: password, role: 'user');
      
      // توجيهه فوراً للوحة المستخدم
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
              const Text('كروت نت', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
              const SizedBox(height: 20),

              // أزرار التبديل
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
          decoration: InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.phone)),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.lock), suffixIcon: const Icon(Icons.visibility)),
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            // زر البصمة الحقيقي
            Container(
              height: 50,
              decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent), borderRadius: BorderRadius.circular(10)),
              child: IconButton(
                icon: const Icon(Icons.fingerprint, color: Colors.blueAccent, size: 28),
                tooltip: 'الدخول بالبصمة',
                onPressed: _authenticateWithBiometrics, 
              ),
            ),
            const SizedBox(width: 10),
            // زر الدخول الحقيقي
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _processLogin, 
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
            onPressed: _processRegistration, 
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
          _scrollController.jumpTo(0.0); // العودة للبداية عند الوصول للنهاية
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
      reverse: true, // يتحرك من اليمين لليسار للغة العربية
      physics: const NeverScrollableScrollPhysics(), // منع السحب اليدوي
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
