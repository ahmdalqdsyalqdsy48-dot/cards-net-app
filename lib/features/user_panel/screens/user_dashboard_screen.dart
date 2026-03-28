import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart'; // استدعاء الترويسة الموحدة
import '../widgets/custom_user_drawer.dart'; // استدعاء القائمة الجانبية للمستخدم

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  // بيانات وهمية للزبون (سيتم ربطها بقاعدة البيانات لاحقاً)
  final String _userName = 'محمد أحمد';
  final String _phoneNumber = '777123456';
  final double _walletBalance = 2500.0;
  
  // بيانات وهمية لكرت نشط (إذا كان الزبون قد اشترى كرتاً ولم ينتهِ بعد)
  final bool _hasActiveCard = true;
  final Map<String, String> _activeCardData = {
    'network': 'شبكة الصقر للواي فاي',
    'pin': '987654321',
    'timeRemaining': '10 ساعات و 15 دقيقة',
  };

  // دالة لعرض رسالة مؤقتة للأزرار التي لم نبرمج شاشاتها بعد
  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('سيتم نقلك إلى شاشة ($feature) 🚀'), backgroundColor: Colors.blueGrey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 👇 Scaffold في الخارج لضمان بقاء القائمة الجانبية في اليسار
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'الرئيسية'),
      drawer: CustomUserDrawer(
        userName: _userName,
        phoneNumber: _phoneNumber,
        walletBalance: _walletBalance,
      ),
      // 👇 Directionality داخل الـ body لجعل محتوى الشاشة بالعربية (من اليمين لليسار)
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 1. بطاقة الرصيد الفاخرة
              // ==========================================
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade900, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الرصيد المتاح', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_walletBalance ريال',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showComingSoon('شحن المحفظة'),
                          icon: const Icon(Icons.add_circle, color: Colors.blue, size: 18),
                          label: const Text('شحن', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ==========================================
              // 2. الأزرار السريعة (Quick Actions)
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickActionBtn(Icons.wifi, 'شراء كرت', Colors.orange, () => _showComingSoon('سوق الشبكات')),
                    _buildQuickActionBtn(Icons.send_to_mobile, 'تحويل رصيد', Colors.teal, () => _showComingSoon('التحويل للأصدقاء')),
                    _buildQuickActionBtn(Icons.qr_code_scanner, 'الدفع بـ QR', Colors.purple, () => _showComingSoon('مسح QR')),
                    _buildQuickActionBtn(Icons.sos, 'سلفني', Colors.redAccent, () => _showComingSoon('خدمة سلفني')),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ==========================================
              // 3. الكرت النشط حالياً (Active Card)
              // ==========================================
              if (_hasActiveCard) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('الكرت النشط حالياً 🌐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_activeCardData['network']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                          const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('رقم الكرت (PIN):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Row(
                            children: [
                              Text(_activeCardData['pin']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الكرت بنجاح ✅'), backgroundColor: Colors.green));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text('الوقت المتبقي: ${_activeCardData['timeRemaining']}', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showComingSoon('تسجيل الدخول لشبكة الميكروتك'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: const Text('تسجيل الدخول للشبكة تلقائياً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ==========================================
              // 4. العروض الإعلانية (Carousel Banner)
              // ==========================================
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('عروض حصرية لك 🔥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildPromoBanner('خصم 20%', 'على جميع كروت فئة 1000 من شبكة النور', Colors.orange.shade400, Colors.deepOrange),
                    const SizedBox(width: 10),
                    _buildPromoBanner('نقاط مضاعفة!', 'احصل على ضعف النقاط عند الشراء اليوم', Colors.purple.shade400, Colors.deepPurple),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // أدوات مساعدة (Widgets) لتقليل تكرار الكود
  // ==========================================

  // بناء الأزرار الدائرية السريعة
  Widget _buildQuickActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // بناء بطاقات الإعلانات الجانبية
  Widget _buildPromoBanner(String title, String subtitle, Color color1, Color color2) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
