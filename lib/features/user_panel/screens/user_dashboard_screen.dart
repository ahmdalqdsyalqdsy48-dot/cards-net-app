import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:url_launcher/url_launcher.dart'; // 👈 (اختياري) يمكنك تفعيلها لمشاركة الكروت عبر واتساب لاحقاً

import '../../../core/providers/system_provider.dart'; 
import '../../../core/providers/ui_provider.dart'; 
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
  // 👈 إضافة الاتصال بقاعدة البيانات لجلب العروض
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // دالة موحدة للانتقال بين الشاشات بسهولة مع صوت
  void _goTo(Widget screen) {
    Provider.of<UiProvider>(context, listen: false).playSound('click');
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => screen)
    );
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 👈 1. الاتصال بالعقل المدبر
    final systemProvider = Provider.of<SystemProvider>(context);
    final String role = systemProvider.currentUserRole; // فحص: هل هو user أم pos
    final bool isPos = role == 'pos'; // تحديد الهوية

    final double realBalance = systemProvider.currentUserBalance;
    
    // 👈 الإصلاح الجوهري للكومبايلر: قراءة الفاتورة التفصيلية كـ Map بدلاً من نص
    final List<Map<String, dynamic>> purchasedCards = systemProvider.userPurchasedCards;
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
                      _buildQuickActionBtn(Icons.bar_chart, 'مبيعاتي', Colors.blueGrey, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شاشة تقارير البقالة قيد التطوير 🛠️')));
                      })
                    else
                      _buildQuickActionBtn(Icons.stars, 'المكافآت', Colors.amber, () => _goTo(const RewardsScreen())),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 3. قسم الكرت النشط (يقرأ أحدث كرت فعلي مسحوب)
              if (hasActiveCard) _buildActiveCardSection(isDark, purchasedCards.last, isPos),

              // 4. قسم العروض الإعلانية المطوّر 🎟️
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(isPos ? 'عروض الوكلاء ونقاط البيع 🔥' : 'عروض حصرية لك 🔥', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 10),
              _buildPromoSection(systemProvider), // تمرير SystemProvider لمعرفة رقم الهاتف
              
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
          colors: isPos ? [Colors.purple.shade900, Colors.purple.shade600] : [Colors.blue.shade900, Colors.blue.shade500], 
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
  // بناء قسم الكرت النشط (مطوّر لقراءة الفاتورة الحقيقية)
  // ==========================================
  Widget _buildActiveCardSection(bool isDark, Map<String, dynamic> lastCardData, bool isPos) {
    
    // استخراج البيانات الحقيقية من كائن الفاتورة
    final String title = lastCardData['title'] ?? 'كرت غير معروف';
    final String actualPin = lastCardData['pin'] ?? 'غير متوفر';

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
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green), overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('رقم الكرت (PIN):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(actualPin, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
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
                      if (isPos) 
                        IconButton(
                          onPressed: () {
                            Provider.of<UiProvider>(context, listen: false).playSound('click');
                            // launchUrl(Uri.parse('https://wa.me/?text=رقم الكرت: $actualPin'));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة المشاركة جاهزة للربط', textDirection: TextDirection.rtl)));
                          }, 
                          icon: const Icon(Icons.share, size: 18, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                      if (isPos) const SizedBox(width: 15),
                      IconButton(
                        onPressed: () {
                          Provider.of<UiProvider>(context, listen: false).playSound('success');
                          Clipboard.setData(ClipboardData(text: actualPin));
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
  // بناء قسم العروض الإعلانية الترويجية (الديناميكي الحي 🎟️)
  // ==========================================
  Widget _buildPromoSection(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      // لجلب جميع العروض وتجنب أخطاء الفهارس المركبة في الفايربيز
      stream: _db.collection('coupons').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(height: 140, child: Center(child: Text('لا توجد عروض حالياً، ترقبوا جديدنا!', style: TextStyle(color: Colors.grey))));
        }

        // 👈 فلترة ذكية في الذاكرة (In-Memory Filtering) لاستبعاد الكوبونات المنتهية أو غير المخصصة للمستخدم
        var activeCoupons = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).where((offer) {
          if (offer['isActive'] != true) return false; // يجب أن يكون نشطاً
          
          DateTime expiry = (offer['expiryDate'] as Timestamp).toDate();
          if (expiry.isBefore(DateTime.now())) return false; // لم تنتهِ صلاحيته

          int current = offer['currentUsage'] ?? 0;
          int max = offer['maxUsage'] ?? 1;
          if (current >= max) return false; // لم يستنفد الحد الأقصى

          // التحقق من التخصيص
          String targetPhone = offer['targetPhone'] ?? '';
          if (targetPhone.isNotEmpty && targetPhone != sys.currentUserPhone) return false;

          return true;
        }).toList();

        // ترتيب من الأحدث للأقدم
        activeCoupons.sort((a, b) {
          Timestamp tA = a['createdAt'] ?? Timestamp.now();
          Timestamp tB = b['createdAt'] ?? Timestamp.now();
          return tB.compareTo(tA);
        });

        if (activeCoupons.isEmpty) {
          return const SizedBox(height: 140, child: Center(child: Text('لا توجد عروض تناسبك حالياً', style: TextStyle(color: Colors.grey))));
        }

        return SizedBox(
          height: 150, // زيادة الارتفاع قليلاً لاستيعاب البيانات الجديدة
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: activeCoupons.length,
            itemBuilder: (context, index) {
              var offer = activeCoupons[index];
              
              // ألوان متناوبة وجميلة للبانرات
              List<Color> gradientColors = index % 2 == 0 
                  ? [Colors.orange.shade400, Colors.deepOrange]
                  : [Colors.purple.shade400, Colors.deepPurple];

              return _buildDynamicPromoBanner(offer, gradientColors);
            },
          ),
        );
      },
    );
  }

  // بناء كرت العرض الديناميكي المربوط بالكوبون
  Widget _buildDynamicPromoBanner(Map<String, dynamic> offer, List<Color> colors) {
    String discountTitle = '';
    String subTitle = '';
    
    if (offer['discountType'] == 'percent') {
      discountTitle = 'خصم ${offer['discountValue']}%';
      subTitle = 'استخدم الكود: ${offer['code']}';
    } else if (offer['discountType'] == 'fixed') {
      discountTitle = 'خصم ${offer['discountValue']} ريال';
      subTitle = 'استخدم الكود: ${offer['code']}';
    } else if (offer['discountType'] == 'referral') {
      discountTitle = 'مكافأة دعوة!';
      subTitle = 'كود: ${offer['code']} (رصيد مجاني)';
    } else {
      discountTitle = 'عرض خاص';
      subTitle = 'استخدم الكود: ${offer['code']}';
    }

    String network = offer['targetNetwork'] ?? '';

    return GestureDetector(
      onTap: () {
        _play('success');
        Clipboard.setData(ClipboardData(text: offer['code']));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ الكود: ${offer['code']} ✂️', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: colors[1].withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(discountTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 5),
                Text(subTitle, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                // تحديد الشبكة المستهدفة للزبون
                if (network.isNotEmpty && network != 'الكل')
                  Text('🌐 صالح لشبكة: $network', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold))
                else
                  const Text('🌐 صالح لجميع الشبكات', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                
                // تنبيه الساعات السعيدة
                if (offer['isHappyHour'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('⏳ يعمل فقط من ${offer['startTime']} إلى ${offer['endTime']}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ),
              ],
            ),
            // أيقونة النسخ في الزاوية
            const Positioned(
              top: 0,
              left: 0,
              child: Icon(Icons.copy, color: Colors.white54, size: 20),
            )
          ],
        ),
      ),
    );
  }
}
