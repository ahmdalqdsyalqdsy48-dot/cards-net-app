import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart'; 
// import 'package:url_launcher/url_launcher.dart'; // 👈 (اختياري) يمكنك تفعيلها لمشاركة الكروت عبر واتساب لاحقاً

import '../../../core/providers/system_provider.dart'; 
import '../../../core/providers/ui_provider.dart'; // 👈 لإضافة أصوات التفاعل
import '../../../core/widgets/custom_header.dart'; 
import '../widgets/custom_user_drawer.dart';

// استدعاء الشاشات للانتقال إليها
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

  // دالة موحدة للانتقال بين الشاشات بسهولة مع صوت
  void _goTo(Widget screen) {
    Provider.of<UiProvider>(context, listen: false).playSound('click');
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => screen)
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 👈 1. الاتصال بالعقل المدبر
    final systemProvider = Provider.of<SystemProvider>(context);
    final String role = systemProvider.currentUserRole; // فحص: هل هو user أم pos
    final bool isPos = role == 'pos'; // تحديد الهوية

    final double realBalance = systemProvider.currentUserBalance;
    final List<String> purchasedCards = systemProvider.userPurchasedCards;
    final bool hasActiveCard = purchasedCards.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'الرئيسية'),
      drawer: CustomUserDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 🌟 التمييز البصري للبقالات (يظهر للبقالة فقط)
              // ==========================================
              if (isPos)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.purple.shade500]),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text('نقطة بيع معتمدة 🏪 (أسعار الجملة مفعلة)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),

              // 1. بطاقة الرصيد الفاخرة
              _buildBalanceCard(realBalance, isPos),

              // 2. الأزرار السريعة للعمليات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickActionBtn(Icons.wifi, isPos ? 'سوق الشبكات' : 'شراء كرت', isPos ? Colors.purple : Colors.orange, () => _goTo(const NetworkStoreScreen())),
                    _buildQuickActionBtn(Icons.send_to_mobile, isPos ? 'تغذية رصيد' : 'شحن محفظة', Colors.teal, () => _goTo(const UserWalletScreen())),
                    _buildQuickActionBtn(Icons.receipt_long, 'مشترياتي', Colors.redAccent, () => _goTo(const MyCardsScreen())),
                    
                    // 👈 زر خاص للبقالات فقط، أو زر مكافآت للمستخدم العادي
                    if (isPos)
                      _buildQuickActionBtn(Icons.bar_chart, 'مبيعاتي (قريباً)', Colors.blueGrey, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شاشة تقارير البقالة قيد التطوير 🛠️')));
                      })
                    else
                      _buildQuickActionBtn(Icons.stars, 'المكافآت', Colors.amber, () => _goTo(const RewardsScreen())),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 3. قسم الكرت النشط (يظهر فقط إذا كان هناك كرت تم شراؤه)
              if (hasActiveCard) _buildActiveCardSection(isDark, purchasedCards.last, isPos),

              // 4. قسم العروض الإعلانية
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(isPos ? 'عروض الوكلاء ونقاط البيع 🔥' : 'عروض حصرية لك 🔥', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
  // بناء بطاقة الرصيد
  // ==========================================
  Widget _buildBalanceCard(double balance, bool isPos) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPos ? [Colors.purple.shade900, Colors.purple.shade600] : [Colors.blue.shade900, Colors.blue.shade500], // 👈 تغيير اللون للبقالة
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: (isPos ? Colors.purple : Colors.blue).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isPos ? 'رصيد نقطة البيع' : 'إجمالي رصيد المحافظ', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${balance.toStringAsFixed(0)} ريال', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _goTo(const UserWalletScreen()),
                icon: Icon(Icons.add_circle, color: isPos ? Colors.purple : Colors.blue, size: 18),
                label: Text('شحن', style: TextStyle(color: isPos ? Colors.purple : Colors.blue, fontWeight: FontWeight.bold)),
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
  // بناء قسم الكرت النشط (مطوّر للنسخ والمشاركة)
  // ==========================================
  Widget _buildActiveCardSection(bool isDark, String lastPurchasedCardName, bool isPos) {
    final mockPin = '8472-9102-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(isPos ? 'آخر كرت تم بيعه 🏷️' : 'الكرت النشط حالياً 🌐', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  const Text('المدة: راجع تفاصيل الكرت', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                  
                  // 👈 أزرار النسخ والمشاركة
                  Row(
                    children: [
                      if (isPos) // زر المشاركة مفيد للبقالة لإرسال الكرت للزبون
                        IconButton(
                          onPressed: () {
                            Provider.of<UiProvider>(context, listen: false).playSound('click');
                            // launchUrl(Uri.parse('https://wa.me/?text=رقم الكرت: $mockPin'));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة المشاركة جاهزة للربط', textDirection: TextDirection.rtl)));
                          }, 
                          icon: const Icon(Icons.share, size: 18, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                      if (isPos) const SizedBox(width: 15),
                      IconButton(
                        onPressed: () {
                          Provider.of<UiProvider>(context, listen: false).playSound('success');
                          Clipboard.setData(ClipboardData(text: mockPin));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ بنجاح ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                        }, 
                        icon: const Icon(Icons.copy, size: 18, color: Colors.blue), padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goTo(const MyCardsScreen()),
                  style: ElevatedButton.styleFrom(backgroundColor: isPos ? Colors.purple : Colors.green),
                  child: Text(isPos ? 'سجل المبيعات والكروت' : 'إدارة كروتي ومشترياتي', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // بناء قسم العروض
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
      decoration: BoxDecoration(gradient: LinearGradient(colors: [c1, c2]), borderRadius: BorderRadius.circular(15)),
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
