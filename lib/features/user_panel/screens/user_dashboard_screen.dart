import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart'; 
import '../widgets/custom_user_drawer.dart';

// 👇 استدعاء جميع الشاشات التي قمنا بتأسيسها
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
  // بيانات تجريبية
  final String _userName = 'محمد أحمد';
  final String _phoneNumber = '777123456';
  final double _walletBalance = 2500.0;
  
  final bool _hasActiveCard = true;
  final Map<String, String> _activeCardData = {
    'network': 'شبكة الصقر للواي فاي',
    'pin': '987654321',
    'timeRemaining': '10 ساعات و 15 دقيقة',
  };

  // دالة موحدة للانتقال بين الشاشات
  void _goTo(Widget screen) {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => screen)
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'الرئيسية'),
      drawer: CustomUserDrawer(
        userName: _userName,
        phoneNumber: _phoneNumber,
        walletBalance: _walletBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. بطاقة الرصيد الفاخرة
              _buildBalanceCard(),

              // 2. الأزرار السريعة (تم ربطها جميعاً بالشاشات الفعلية)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickActionBtn(Icons.wifi, 'شراء كرت', Colors.orange, () => _goTo(const NetworkStoreScreen())),
                    _buildQuickActionBtn(Icons.send_to_mobile, 'تحويل رصيد', Colors.teal, () => _goTo(const UserWalletScreen())),
                    _buildQuickActionBtn(Icons.stars, 'المكافآت', Colors.amber, () => _goTo(const RewardsScreen())),
                    _buildQuickActionBtn(Icons.sos, 'سلفني', Colors.redAccent, () => _goTo(const MyCardsScreen())),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 3. قسم الكرت النشط
              if (_hasActiveCard) _buildActiveCardSection(isDark),

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

  // --- بناء بطاقة الرصيد ---
  Widget _buildBalanceCard() {
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
              Text('$_walletBalance ريال', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
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

  // --- بناء الأزرار الدائرية ---
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

  // --- بناء قسم الكرت النشط ---
  Widget _buildActiveCardSection(bool isDark) {
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
                  Text(_activeCardData['network']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('رقم الكرت (PIN):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_activeCardData['pin']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                ],
              ),
              const SizedBox(height: 5),
              Text('الوقت المتبقي: ${_activeCardData['timeRemaining']}', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goTo(const MyCardsScreen()),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('إدارة كروتي', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- بناء قسم العروض ---
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
