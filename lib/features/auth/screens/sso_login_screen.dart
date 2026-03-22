import 'package:flutter/material.dart';

class SSOLoginScreen extends StatefulWidget {
  const SSOLoginScreen({super.key});

  @override
  State<SSOLoginScreen> createState() => _SSOLoginScreenState();
}

class _SSOLoginScreenState extends State<SSOLoginScreen> {
  bool isLoginTab = true; // للتبديل بين تسجيل الدخول والتسجيل الجديد

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 1. الثلث الأول: الإعلانات الصورية المتغيرة
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

              // 2. الشريط الترحيبي (Marquee Placeholder)
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

              // 3. اسم التطبيق (كما حدده مالك النظام)
              const Text(
                'كروت نت',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueAccent,
                ),
              ),

              const SizedBox(height: 30),

              // 4. أزرار التبويب (تسجيل دخول / تسجيل جديد)
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

              // 5. حقول الإدخال بناءً على التبويب
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

  // قسم: تسجيل الدخول للمسجلين مسبقاً
  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'رقم الهاتف',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: const Icon(Icons.visibility),
          ),
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // زر الدخول
            },
            child: const Text('دخول', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // قسم: تسجيل حساب جديد
  Widget _buildRegisterForm() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'الاسم الرباعي',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'رقم الهاتف',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.lock),
          ),
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {},
            child: const Text('تسجيل حساب', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
