import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:async'; // 👈 ضروري للعداد التنازلي

import '../../../core/providers/system_provider.dart'; 
import '../../../core/providers/ui_provider.dart'; 
import '../../../core/providers/theme_provider.dart'; // 👈 ضروري لتلوين البوستر
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
  // 👈 الاتصال بقاعدة البيانات لجلب العروض
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
    
    // الاتصال بالعقل المدبر وتوفير الثيم
    final systemProvider = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String role = systemProvider.currentUserRole; 
    final bool isPos = role == 'pos'; 

    final double realBalance = systemProvider.currentUserBalance;
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

              // 3. قسم الكرت النشط
              if (hasActiveCard) _buildActiveCardSection(isDark, purchasedCards.last, isPos),

              // 4. قسم العروض الإعلانية المطوّر 🎟️
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(isPos ? 'عروض الوكلاء ونقاط البيع 🔥' : 'عروض حصرية لك 🔥', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 10),
              _buildPromoSection(systemProvider, themeProvider),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildActiveCardSection(bool isDark, Map<String, dynamic> lastCardData, bool isPos) {
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
                  Row(
                    children: [
                      if (isPos) 
                        IconButton(
                          onPressed: () {
                            _play('click');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة المشاركة جاهزة للربط', textDirection: TextDirection.rtl)));
                          }, 
                          icon: const Icon(Icons.share, size: 18, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                      if (isPos) const SizedBox(width: 15),
                      IconButton(
                        onPressed: () {
                          _play('success');
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
  Widget _buildPromoSection(SystemProvider sys, ThemeProvider theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('coupons').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(height: 180, child: Center(child: Text('لا توجد عروض حالياً، ترقبوا جديدنا!', style: TextStyle(color: Colors.grey))));
        }

        var activeCoupons = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).where((offer) {
          if (offer['isActive'] != true) return false; 
          
          DateTime expiry = (offer['expiryDate'] as Timestamp).toDate();
          if (expiry.isBefore(DateTime.now())) return false; 

          int current = offer['currentUsage'] ?? 0;
          int max = offer['maxUsage'] ?? 1;
          if (current >= max) return false; 

          String targetPhone = offer['targetPhone'] ?? '';
          if (targetPhone.isNotEmpty && targetPhone != sys.currentUserPhone) return false;

          return true;
        }).toList();

        activeCoupons.sort((a, b) {
          Timestamp tA = a['createdAt'] ?? Timestamp.now();
          Timestamp tB = b['createdAt'] ?? Timestamp.now();
          return tB.compareTo(tA);
        });

        if (activeCoupons.isEmpty) {
          return const SizedBox(height: 180, child: Center(child: Text('لا توجد عروض تناسبك حالياً', style: TextStyle(color: Colors.grey))));
        }

        return SizedBox(
          height: 170, // تم التوسيع لاستيعاب العداد التنازلي والأزرار
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: activeCoupons.length,
            itemBuilder: (context, index) {
              var offer = activeCoupons[index];
              List<Color> gradientColors = index % 2 == 0 
                  ? [Colors.orange.shade400, Colors.deepOrange]
                  : [Colors.purple.shade400, Colors.deepPurple];

              return _buildDynamicPromoBanner(offer, gradientColors, theme);
            },
          ),
        );
      },
    );
  }

  // بناء كرت العرض الديناميكي المربوط بالكوبون
  Widget _buildDynamicPromoBanner(Map<String, dynamic> offer, List<Color> colors, ThemeProvider theme) {
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
      subTitle = 'كود: ${offer['code']}';
    } else {
      discountTitle = 'عرض خاص';
      subTitle = 'استخدم الكود: ${offer['code']}';
    }

    String network = offer['targetNetwork'] ?? '';
    DateTime expiryDate = (offer['expiryDate'] as Timestamp).toDate();

    return GestureDetector(
      onTap: () {
        _play('success');
        Clipboard.setData(ClipboardData(text: offer['code']));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ الكود: ${offer['code']}! جاري نقلك للمتجر 🛒', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
        
        // 👈 التوجيه المباشر (Deep Linking) لمتجر الشبكات
        Navigator.push(context, MaterialPageRoute(builder: (context) => const NetworkStoreScreen()));
      },
      child: Container(
        width: 300, // أعرض قليلاً
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
                
                if (network.isNotEmpty && network != 'الكل')
                  Text('🌐 صالح لشبكة: $network', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold))
                else
                  const Text('🌐 صالح لجميع الشبكات', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                
                const SizedBox(height: 8),
                
                // ⏱️ العداد التنازلي الحي (FOMO Timer)
                _LiveCountdownTimer(expiryDate: expiryDate),
                
                if (offer['isHappyHour'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('⏳ يعمل فقط من ${offer['startTime']} إلى ${offer['endTime']}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ),
              ],
            ),
            
            // 📲 زر المشاركة في الزاوية
            Positioned(
              top: -10,
              left: -10,
              child: IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 22),
                onPressed: () => _showSharePosterDialog(offer, theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 📲 وظائف المشاركة المتقدمة للمستخدم النهائي
  // ==========================================
  void _showSharePosterDialog(Map<String, dynamic> offer, ThemeProvider theme) {
    _play('click');
    final GlobalKey posterKey = GlobalKey();

    String discountTitle = '';
    String subTitle = '';
    
    if (offer['discountType'] == 'percent') {
      discountTitle = 'خصم ${offer['discountValue']}%';
      subTitle = 'على مشترياتك من الكروت';
    } else if (offer['discountType'] == 'fixed') {
      discountTitle = 'خصم ${offer['discountValue']} ريال';
      subTitle = 'مباشرة على فاتورتك';
    } else if (offer['discountType'] == 'referral') {
      discountTitle = 'سجل واحصل على رصيد!';
      subTitle = 'استخدم الكود واحصل على ${offer['refereeReward']} ريال';
    } else {
      discountTitle = 'عرض خاص جداً';
      subTitle = offer['comboDesc'] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          contentPadding: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🖼️ البوستر
              RepaintBoundary(
                key: posterKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.primaryColor == Colors.white ? Colors.green.shade700 : theme.primaryColor, Colors.black87],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      const Text('🔥 عرض لا يفوتك 🔥', style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(discountTitle, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(subTitle, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                      
                      if (offer['targetNetwork'] != null && offer['targetNetwork'] != '' && offer['targetNetwork'] != 'الكل')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('صالح لشبكة: ${offer['targetNetwork']}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                        
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Text(offer['code'], style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3)),
                      ),
                      const SizedBox(height: 15),
                      Text('ينتهي العرض في: ${intl.DateFormat('yyyy-MM-dd').format((offer['expiryDate'] as Timestamp).toDate())}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              // أزرار المشاركة
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.text_fields),
                        label: const Text('كنص'),
                        onPressed: () {
                          Navigator.pop(context);
                          _shareText(offer);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        icon: const Icon(Icons.image, color: Colors.white),
                        label: const Text('كصورة', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _sharePosterImage(posterKey, offer['code']);
                        },
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _shareText(Map<String, dynamic> offer) {
    _play('click');
    String msg = "🔥 *عـرض رهيـب لا يفوتك!* 🔥\n\n";
    if (offer['discountType'] == 'percent') {
      msg += "استخدم الكود: *${offer['code']}*\nواحصل على خصم *${offer['discountValue']}%* عند شراء أي كرت!\n";
    } else if (offer['discountType'] == 'fixed') {
      msg += "استخدم الكود: *${offer['code']}*\nواحصل على خصم *${offer['discountValue']} ريال*!\n";
    } else if (offer['discountType'] == 'referral') {
      msg += "استخدم كود الدعوة الخاص بي: *${offer['code']}*\nسجل في التطبيق واحصل على رصيد مجاني *${offer['refereeReward']} ريال*!\n";
    } else {
      msg += "استخدم الكود: *${offer['code']}*\nواستفد من العرض: *${offer['comboDesc']}*\n";
    }

    if (offer['targetNetwork'] != null && offer['targetNetwork'] != '' && offer['targetNetwork'] != 'الكل') {
      msg += "🌐 *مخصص لشبكة:* ${offer['targetNetwork']}\n";
    }

    msg += "\nحمل التطبيق الآن واستفد من العرض قبل انتهائه! 🚀";
    Share.share(msg);
  }

  Future<void> _sharePosterImage(GlobalKey posterKey, String code) async {
    _play('click');
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      RenderRepaintBoundary boundary = posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        Navigator.pop(context); 
        await Share.shareXFiles([XFile.fromData(pngBytes, mimeType: 'image/png', name: 'coupon_$code.png')], text: 'استخدم هذا الكود الآن! 🔥');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عذراً، حدث خطأ. يرجى استخدام مشاركة النص.'), backgroundColor: Colors.red));
    }
  }
}

// ==========================================
// ⏱️ الويدجت المستقل للعداد التنازلي الحي (يمنع إعادة بناء الشاشة بالكامل)
// ==========================================
class _LiveCountdownTimer extends StatefulWidget {
  final DateTime expiryDate;
  const _LiveCountdownTimer({required this.expiryDate});

  @override
  __LiveCountdownTimerState createState() => __LiveCountdownTimerState();
}

class __LiveCountdownTimerState extends State<_LiveCountdownTimer> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    if (widget.expiryDate.isAfter(now)) {
      setState(() => _timeLeft = widget.expiryDate.difference(now));
    } else {
      setState(() => _timeLeft = Duration.zero);
      _timer.cancel();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == Duration.zero) return const Text('انتهى العرض', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold));
    
    int days = _timeLeft.inDays;
    int hours = _timeLeft.inHours % 24;
    int minutes = _timeLeft.inMinutes % 60;
    int seconds = _timeLeft.inSeconds % 60;

    String formattedTime = '';
    if (days > 0) formattedTime += '$days يوم و ';
    formattedTime += '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(formattedTime, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }
}
