import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 1. استدعاء مكتبة مزود الحالة

// استدعاء ملف المظهر (العقل المدبر للألوان)
import '../../../core/providers/theme_provider.dart'; 

// استدعاء لوحة المالك 
import '../../super_admin/screens/super_admin_dashboard.dart';
// استدعاء لوحة الوكيل 
import '../../agent_panel/screens/agent_dashboard_screen.dart';
// استدعاء لوحة المستخدم (الزبون)
import '../../user_panel/screens/user_dashboard_screen.dart';

class SSOLoginScreen extends StatefulWidget {
  const SSOLoginScreen({super.key});

  @override
  State<SSOLoginScreen> createState() => _SSOLoginScreenState();
}

class _SSOLoginScreenState extends State<SSOLoginScreen> {
  bool isLoginTab = true; 
  
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                width: double.infinity,
                child: PageView(
                  children: [
                    Container(color: Colors.blue.shade800, child: const Center(child: Text('إعلان ترويجي 1', style: TextStyle(color: Colors.white, fontSize: 24)))),
                    Container(color: Colors.deepPurple, child: const Center(child: Text('إعلان ترويجي 2', style: TextStyle(color: Colors.white, fontSize: 24)))),
                  ],
                ),
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.amber.withOpacity(0.3),
                child: const Text(
                  'أهلاً بك في نظامنا الموحد - أسرع شبكة لبيع الكروت والخدمات...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
              ),
              
              const SizedBox(height: 20),

              const Text(
                'كروت نت',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.blueAccent),
              ),

              const SizedBox(height: 30),

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

              const SizedBox(height: 20),

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
          decoration: InputDecoration(
            labelText: 'رقم الهاتف',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: const Icon(Icons.visibility),
          ),
        ),
        const SizedBox(height: 25),
        
        Row(
          children: [
            // زر الدخول بالبصمة (مجهز للعمل الحقيقي)
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.fingerprint, color: Colors.blueAccent, size: 28),
                tooltip: 'الدخول بالبصمة',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('سيتم ربط هذا الزر بحساس البصمة (local_auth) قريباً.', textDirection: TextDirection.rtl))
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            
            // زر الدخول الرئيسي المربوط بالمظهر
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    String phone = phoneController.text.trim();
                    String password = passwordController.text.trim();

                    // === الشجرة البرمجية الذكية لتوجيه المستخدمين وتحديد المظهر ===
                    
                    // 1. حساب مالك النظام (Super Admin)
                    if (phone == '774578241' && password == '75486958aaa') {
                      // 👈 إخبار العقل المدبر بأن المالك هو من دخل ليطبق ألوانه
                      Provider.of<ThemeProvider>(context, listen: false).setRole('super_admin');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SuperAdminDashboard()),
                      );
                    } 
                    // 2. حساب الوكيل التجريبي (Agent)
                    else if (phone == '777777777' && password == 'agent123') {
                      // 👈 إخبار العقل المدبر بأن الوكيل هو من دخل ليطبق ألوانه
                      Provider.of<ThemeProvider>(context, listen: false).setRole('agent');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const AgentDashboardScreen()),
                      );
                    } 
                    // 3. حساب المستخدم العادي (الزبون)
                    else if (phone == '777123456' && password == 'user123') {
                      // 👈 إخبار العقل المدبر بأن المستخدم هو من دخل ليطبق ألوانه
                      Provider.of<ThemeProvider>(context, listen: false).setRole('user');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const UserDashboardScreen()),
                      );
                    } 
                    // 4. في حال إدخال بيانات خاطئة
                    else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('رقم الهاتف أو كلمة المرور غير صحيحة!', textDirection: TextDirection.rtl),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
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
        TextField(decoration: InputDecoration(labelText: 'الاسم الرباعي', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.person))),
        const SizedBox(height: 15),
        TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.phone))),
        const SizedBox(height: 15),
        TextField(obscureText: true, decoration: InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.lock))),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {},
            child: const Text('تسجيل حساب', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
