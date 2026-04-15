import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_fonts/google_fonts.dart'; 

import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart';
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
  
  final List<Color> _fallbackAdColors = [Colors.blue.shade800, Colors.deepPurple, Colors.teal];
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDynamicCarousel();
    });
  }

  void _startDynamicCarousel() {
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    int interval = systemProvider.carouselIntervalSeconds > 0 ? systemProvider.carouselIntervalSeconds : 5;

    _carouselTimer = Timer.periodic(Duration(seconds: interval), (Timer timer) {
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
    final uiProvider = Provider.of<UiProvider>(context, listen: false); 
    uiProvider.playSound('click'); 

    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      uiProvider.playSound('error'); 
      _showErrorSnackBar('يرجى إدخال رقم الهاتف وكلمة المرور.');
      return;
    }

    setState(() => isLoading = true);
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    
    // تجاوز وضع الصيانة فقط لمالك النظام
    if (systemProvider.isMaintenanceMode && phone != '774578241') {
      setState(() => isLoading = false);
      uiProvider.playSound('error');
      _showErrorSnackBar('النظام تحت الصيانة حالياً. يرجى المحاولة لاحقاً.');
      return;
    }

    final Map<String, dynamic>? userData = await systemProvider.loginUser(phone, password);
    
    if (!mounted) return;
    setState(() => isLoading = false);

    if (userData != null) {
      String userRole = userData['role']; 
      
      Provider.of<ThemeProvider>(context, listen: false).setUser(userRole, phone);
      uiProvider.playSound('success'); 
      
      if (userRole == 'super_admin' || userRole == 'staff') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard()));
      } else if (userRole == 'agent') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AgentDashboardScreen()));
      } else if (userRole == 'user' || userRole == 'pos') { // 👈 التعديل السحري هنا لدعم البقالات
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      }
    } else {
      uiProvider.playSound('error'); 
      _showErrorSnackBar('رقم الهاتف غير مسجل أو كلمة المرور خاطئة!');
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
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    bool isExist = await systemProvider.checkUserExists(phone);

    if (!mounted) return;

    if (isExist) {
      setState(() => isLoading = false);
      uiProvider.playSound('error');
      _showErrorSnackBar('هذا الرقم مسجل مسبقاً! يرجى تسجيل الدخول.');
      setState(() => isLoginMode = true);
    } else {
      await systemProvider.registerNewUser(name: name, phone: phone, password: password, role: 'user');
      if (!mounted) return;
      setState(() => isLoading = false);

      Provider.of<ThemeProvider>(context, listen: false).setUser('user', phone);
      uiProvider.playSound('success');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserDashboardScreen()));
      _showSuccessSnackBar('تم التسجيل بنجاح! أهلاً بك.');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    Provider.of<UiProvider>(context, listen: false).playSound('click');
    if (kIsWeb) {
      _showErrorSnackBar('عذراً، الدخول بالبصمة يعمل فقط على تطبيقات الهواتف (Android/iOS) وليس المتصفح.');
      return;
    }
    _showErrorSnackBar('قم بتسجيل الدخول برقمك وكلمة المرور أولاً لتفعيل الجلسة.');
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

  // ==========================================
  // 3. بناء الواجهة مع دروع الحماية
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // 🛡️ درع الصيانة العامة
    if (systemProvider.isMaintenanceMode) {
      return Scaffold(
        backgroundColor: themeProvider.primaryColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle, size: 100, color: Colors.redAccent),
              const SizedBox(height: 20),
              Text('النظام تحت الصيانة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeProvider.adaptiveTextColor)),
              const SizedBox(height: 10),
              Text('نعمل على تحسين تجربتكم، سنعود قريباً.', style: TextStyle(fontSize: 16, color: themeProvider.adaptiveTextColor.withOpacity(0.7))),
              const SizedBox(height: 40),
              // زر دخول طوارئ يظهر فقط للمالك (للتجاوز)
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

    // 🛡️ درع التحديث الإجباري
    if (systemProvider.isForcedUpdate) {
      return Scaffold(
        backgroundColor: themeProvider.primaryColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, size: 100, color: Colors.orange),
              const SizedBox(height: 20),
              Text('تحديث هام متاح', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeProvider.adaptiveTextColor)),
              const SizedBox(height: 10),
              Text('يرجى تحديث التطبيق إلى آخر إصدار لمتابعة الاستخدام.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: themeProvider.adaptiveTextColor.withOpacity(0.7))),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                onPressed: () { /* كود التوجيه لمتجر بلاي أو أبل */ },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('تحديث الآن', style: TextStyle(color: Colors.white, fontSize: 16)),
              )
            ],
          ),
        ),
      );
    }

    // الواجهة الطبيعية إذا لم تكن هناك صيانة أو تحديث
    final List<String> carouselImages = systemProvider.loginCarouselImages;
    final String welcomeMessage = systemProvider.loginWelcomeMessage.isNotEmpty ? systemProvider.loginWelcomeMessage : 'أهلاً بك في نظام كروت نت';
    final CrossAxisAlignment columnAlign = systemProvider.appNameAlign == 'right' ? CrossAxisAlignment.start : (systemProvider.appNameAlign == 'left' ? CrossAxisAlignment.end : CrossAxisAlignment.center);
    final String customFont = systemProvider.appNameFont;
    final Color customColor = Color(systemProvider.appNameColor);
    final String appName = systemProvider.appName.isNotEmpty ? systemProvider.appName : 'شبكة كروت نت';

    return Scaffold(
      backgroundColor: Color(systemProvider.loginBgColor),
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
                          child: Image.network(
                            carouselImages[index], 
                            fit: BoxFit.contain, 
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade300,
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)),
                            ),
                          ),
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
                
                // شريط الأخبار محمي بشرط الظهور (showNewsBar)
                if (systemProvider.showNewsBar)
                  Container(
                    width: double.infinity, height: 35, 
                    color: Color(systemProvider.marqueeBgColor), 
                    child: _CustomMarquee(
                      text: welcomeMessage,
                      textColor: Color(systemProvider.marqueeTextColor), 
                      direction: systemProvider.marqueeDirection, 
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
                        if (systemProvider.appLogoUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              systemProvider.appLogoUrl, 
                              height: 100, 
                              fit: BoxFit.contain, 
                              errorBuilder: (c, e, s) => const SizedBox.shrink()
                            ),
                          ),
                          const SizedBox(height: 15), 
                        ],
                        Text(
                          appName, 
                          textAlign: systemProvider.appNameAlign == 'right' ? TextAlign.right : (systemProvider.appNameAlign == 'left' ? TextAlign.left : TextAlign.center),
                          style: customFont == 'System' || customFont.isEmpty
                              ? TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: customColor)
                              : GoogleFonts.getFont(
                                  customFont,
                                  textStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: customColor),
                                ),
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
                              Provider.of<UiProvider>(context, listen: false).playSound('click');
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
                                Checkbox(value: rememberMe, onChanged: (value) {
                                  Provider.of<UiProvider>(context, listen: false).playSound('click');
                                  setState(() => rememberMe = value!);
                                }),
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
                              Provider.of<UiProvider>(context, listen: false).playSound('click');
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

  // نافذة دخول طوارئ تظهر للمالك فقط إذا كان النظام تحت الصيانة
  void _showEmergencyLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('دخول الطوارئ', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الإدارة (774578241)')),
              const SizedBox(height: 10),
              TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _processLogin(); // سيمرر الدخول لأن الرقم سيطابق الاستثناء
              }, 
              child: const Text('دخول')
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🚀 أداة الشريط المتحرك (Marquee)
// ==========================================
class _CustomMarquee extends StatefulWidget {
  final String text;
  final Color textColor;
  final String direction;

  const _CustomMarquee({
    required this.text, 
    required this.textColor, 
    required this.direction
  });

  @override
  State<_CustomMarquee> createState() => _CustomMarqueeState();
}

class _CustomMarqueeState extends State<_CustomMarquee> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    if (!mounted) return;
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        
        if (maxScroll > 0) {
          if (currentScroll >= maxScroll) {
            _scrollController.jumpTo(0.0);
          } else {
            _scrollController.jumpTo(currentScroll + 1.5);
          }
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
    return Directionality(
      textDirection: widget.direction == 'ltr' ? TextDirection.ltr : TextDirection.rtl,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(), 
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 400.0, vertical: 6.0),
          child: Text(
            widget.text, 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.textColor)
          ),
        ),
      ),
    );
  }
}
