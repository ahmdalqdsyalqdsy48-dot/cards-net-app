import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للنسخ
import 'package:provider/provider.dart'; // 👈 1. استدعاء العقل المدبر

import '../../../core/providers/system_provider.dart'; // 👈 2. استدعاء الخادم الشامل
import '../../../core/widgets/custom_header.dart'; 
import '../widgets/custom_user_drawer.dart';

// استدعاء جميع الشاشات للانتقال إليها
import 'user_wallet_screen.dart';
import 'network_store_screen.dart';
import 'my_cards_screen.dart';
import 'rewards_screen.dart';
import 'user_transactions_screen.dart';
import 'user_support_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  // بيانات المستخدم الأساسية
  final String _userName = 'محمد أحمد';
  final String _phoneNumber = '777123456';

  // دالة موحدة للانتقال بين الشاشات بسهولة
  void _goTo(Widget screen) {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => screen)
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 👇 3. الاتصال بالعقل المدبر لجلب الرصيد الحقيقي وقائمة الكروت
    final systemProvider = Provider.of<SystemProvider>(context);
    final double realBalance = systemProvider.currentUserBalance;
    final List<String> purchasedCards = systemProvider.userPurchasedCards;
    
    // فحص: هل يمتلك الزبون كروتاً قام بشرائها؟
    final bool hasActiveCard = purchasedCards.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'الرئيسية'),
      // تم تنظيف الاستدعاء من المتغير المتعارض
      drawer: CustomUserDrawer(
        userName: _userName,
        phoneNumber: _phoneNumber,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. بطاقة الرصيد الفاخرة (تعرض الرصيد الحي)
              _buildBalanceCard(realBalance),

              // 2. الأزرار السريعة للعمليات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickActionBtn(Icons.wifi, 'شراء كرت', Colors.orange, () => _goTo(const NetworkStoreScreen())),
                    _buildQuickActionBtn(Icons.send_to_mobile, 'تحويل رصيد', Colors.teal, () => _goTo(const UserWalletScreen())),
                    _buildQuickActionBtn(Icons.stars, 'المكافآت', Colors.amber, () => _goTo(const RewardsScreen())),
                    _buildQuickActionBtn(Icons.receipt_long, 'مشترياتي', Colors.redAccent, () => _goTo(const MyCardsScreen())),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 3. قسم الكرت النشط (يظهر فقط إذا كان هناك كرت تم شراؤه)
              if (hasActiveCard) _buildActiveCardSection(isDark, purchasedCards.last),

              // 4. قسم العروض الإعلانية
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('عروض حصرية لك 🔥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 10),
              _buildPromoSection(),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // بناء بطاقة الرصيد (تقرأ الرقم الحقيقي)
  // ==========================================
  Widget _buildBalanceCard(double balance) {
    return Container(
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
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الرصيد المتاح', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // عرض الرصيد الحقيقي بدون فواصل عشرية
              Text('${balance.toStringAsFixed(0)} ريال', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _goTo(const UserWalletScreen()),
                icon: const Icon(Icons.add_circle, color: Colors.blue, size: 18),
                label: const Text('شحن', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // بناء الأزرار الدائرية السريعة
  // ==========================================
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

  // ==========================================
  // بناء قسم الكرت النشط (يقرأ أحدث كرت تم شراؤه)
  // ==========================================
  Widget _buildActiveCardSection(bool isDark, String lastPurchasedCardName) {
    // توليد رقم PIN استناداً لاسم الكرت المشتراة للعرض
    final mockPin = '8472-9102-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  // عرض اسم أحدث كرت تم شراؤه من النظام
                  Expanded(child: Text(lastPurchasedCardName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green), overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('رقم الكرت (PIN):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(mockPin, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الوقت المتبقي: غير محدد', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                  // زر سريع لنسخ الكرت مباشرة من الشاشة الرئيسية
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: mockPin));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ بنجاح ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                    }, 
                    icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goTo(const MyCardsScreen()),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('إدارة كروتي ومشترياتي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // بناء قسم العروض الإعلانية الترويجية
  // ==========================================
  Widget _buildPromoSection() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildPromoBanner('خصم 20%', 'على شبكة النور', Colors.orange.shade400, Colors.deepOrange),
          const SizedBox(width: 10),
          _buildPromoBanner('نقاط مضاعفة!', 'اشتري الآن واحصل على الضعف', Colors.purple.shade400, Colors.deepPurple),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(String title, String subtitle, Color c1, Color c2) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c1, c2]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
