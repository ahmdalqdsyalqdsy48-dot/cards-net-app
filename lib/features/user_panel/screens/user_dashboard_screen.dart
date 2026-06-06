// lib/features/user_panel/screens/user_dashboard_screen.dart
// تم التحديث: رأس متحرك، ربط حقيقي للأزرار، إحصائيات نقاط البيع، تحسين الفلترة، دمج CouponProvider

import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/coupon_provider.dart';
import '../../../core/providers/transactions_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  DateTime? _startDate;
  DateTime? _endDate;

  void _goTo(Widget screen) {
    context.read<UiProvider>().playSound('click');
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _play(String type) => context.read<UiProvider>().playSound(type);

  // ========== اختيار التواريخ مع تحقق ==========
  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'اختر تاريخ البداية',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // إذا كان تاريخ النهاية قبل البداية، نلغيه
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    // لا يمكن اختيار تاريخ نهاية قبل تاريخ البداية
    if (_startDate != null) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _endDate ?? _startDate!,
        firstDate: _startDate!,
        lastDate: DateTime(2030),
        helpText: 'اختر تاريخ النهاية',
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      );
      if (picked != null && picked != _endDate) {
        setState(() => _endDate = picked);
      }
    } else {
      // إذا لم يحدد تاريخ بداية، نطلب منه ذلك أولاً
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار تاريخ البداية أولاً', textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _play('click');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إعادة التعيين إلى عرض الكروت بالكامل 📅', textDirection: TextDirection.rtl),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final transactions = context.watch<TransactionsProvider>();
    final couponProvider = context.watch<CouponProvider>();
    final uiProvider = context.read<UiProvider>();

    final String role = auth.currentUserRole;
    final bool isPos = role == 'pos';

    final double realBalance = wallet.currentUserBalance;
    final List<Map<String, dynamic>> purchasedCards = wallet.userPurchasedCards;

    // فلترة الكروت
    List<Map<String, dynamic>> filteredCards = purchasedCards;
    if (_startDate != null || _endDate != null) {
      filteredCards = purchasedCards.where((card) {
        try {
          final dateStr = card['date'] ?? '';
          if (dateStr.isEmpty) return false;
          final date = DateTime.parse(dateStr);
          if (_startDate != null && date.isBefore(_startDate!)) return false;
          if (_endDate != null && date.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
          return true;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    final bool hasActiveCard = purchasedCards.isNotEmpty;
    final bool hasFilteredCards = filteredCards.isNotEmpty;

    // إحصائيات نقاط البيع (حقيقية)
    final double todaySales = isPos
        ? transactions.salesList
            .where((s) {
              try {
                final d = DateTime.parse(s['date'] ?? '');
                return d.year == DateTime.now().year && d.month == DateTime.now().month && d.day == DateTime.now().day;
              } catch (_) {
                return false;
              }
            })
            .fold(0.0, (sum, s) => sum + ((s['amount'] ?? 0.0) as double))
        : 0.0;
    final int todayCardsCount = isPos
        ? transactions.salesList
            .where((s) {
              try {
                final d = DateTime.parse(s['date'] ?? '');
                return d.year == DateTime.now().year && d.month == DateTime.now().month && d.day == DateTime.now().day;
              } catch (_) {
                return false;
              }
            })
            .length
        : 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'الرئيسية'),
      drawer: CustomUserDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ====== الرأس المتحرك (يحمل شريط الفلترة والتمييز) ======
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // تمييز البقالات
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
                          Text('نقطة بيع معتمدة 🏪 (أسعار الجملة مفعلة)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),

                  // شريط الفلترة
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? themeProvider.primaryColor.withOpacity(0.4)
                          : themeProvider.primaryColor.withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _pickStartDate,
                                icon: const Icon(Icons.date_range, color: Colors.blueAccent),
                                label: Text(
                                  _startDate == null ? 'بداية الفترة' : _formatDate(_startDate!),
                                  style: const TextStyle(
                                      color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _pickEndDate,
                                icon: const Icon(Icons.date_range, color: Colors.orangeAccent),
                                label: Text(
                                  _endDate == null ? 'نهاية الفترة' : _formatDate(_endDate!),
                                  style: const TextStyle(
                                      color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_startDate != null || _endDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'عرض الكروت من ${_startDate != null ? _formatDate(_startDate!) : "البداية"} إلى ${_endDate != null ? _formatDate(_endDate!) : "اليوم"}',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear_all, color: Colors.white70),
                                  tooltip: 'إعادة تعيين الفلترة',
                                  onPressed: _resetDates,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // بطاقة الرصيد (داخل Sliver)
            SliverToBoxAdapter(
              child: _buildBalanceCard(realBalance, isPos),
            ),

            // إحصائيات نقاط البيع اليومية
            if (isPos)
              SliverToBoxAdapter(
                child: _buildPosDailyStats(todaySales, todayCardsCount),
              ),

            // الأزرار السريعة
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickActionBtn(Icons.wifi, isPos ? 'سوق الشبكات' : 'شراء كرت',
                        isPos ? Colors.purple : Colors.orange, () => _goTo(const NetworkStoreScreen())),
                    _buildQuickActionBtn(Icons.send_to_mobile, isPos ? 'تغذية رصيد' : 'شحن محفظة', Colors.teal,
                        () => _goTo(const UserWalletScreen())),
                    _buildQuickActionBtn(Icons.receipt_long, 'مشترياتي', Colors.redAccent,
                        () => _goTo(const MyCardsScreen())),
                    if (isPos)
                      _buildQuickActionBtn(Icons.bar_chart, 'مبيعاتي', Colors.blueGrey, () {
                        // ربط حقيقي بشاشة المعاملات مع إظهار المبيعات فقط
                        _goTo(const UserTransactionsScreen(showOnlySales: true));
                      })
                    else
                      _buildQuickActionBtn(Icons.stars, 'المكافآت', Colors.amber,
                          () => _goTo(const RewardsScreen())),
                  ],
                ),
              ),
            ),

            // عرض الكروت المفلترة أو الكرت النشط
            if (_startDate != null || _endDate != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    hasFilteredCards
                        ? 'الكروت المشتراة في الفترة المحددة (${filteredCards.length})'
                        : 'لا توجد كروت في هذه الفترة',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              if (hasFilteredCards)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPurchasedCardTile(filteredCards[index], isPos),
                    childCount: filteredCards.length,
                  ),
                )
              else
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('لا توجد كروت مطابقة للفترة المحددة', style: TextStyle(color: Colors.grey))),
                  ),
                ),
            ] else if (hasActiveCard)
              SliverToBoxAdapter(
                child: _buildActiveCardSection(isDark, purchasedCards.last, isPos),
              ),

            // العنوان "عروض حصرية"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(isPos ? 'عروض الوكلاء ونقاط البيع 🔥' : 'عروض حصرية لك 🔥',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),

            // العروض (من CouponProvider)
            SliverToBoxAdapter(
              child: _buildPromoSection(couponProvider, wallet, themeProvider),
            ),

            // مسافة سفلية
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  // ========== ويدجت الكرت المشترى في الفلترة ==========
  Widget _buildPurchasedCardTile(Map<String, dynamic> card, bool isPos) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPos ? Colors.purple.withOpacity(0.2) : Colors.green.withOpacity(0.2),
          child: Icon(Icons.credit_card, color: isPos ? Colors.purple : Colors.green),
        ),
        title: Text(card['title'] ?? 'كرت غير معروف'),
        subtitle: Text('PIN: ${card['pin'] ?? 'غير متوفر'}'),
        trailing: Text(card['date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }

  // ========== بطاقة الرصيد ==========
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
        boxShadow: [
          BoxShadow(
              color: (isPos ? Colors.purple : Colors.blue).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isPos ? 'رصيد نقطة البيع' : 'إجمالي رصيد المحافظ',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${balance.toStringAsFixed(0)} ريال',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _goTo(const UserWalletScreen()),
                icon: Icon(Icons.add_circle, color: isPos ? Colors.purple : Colors.blue, size: 18),
                label: Text('شحن',
                    style: TextStyle(color: isPos ? Colors.purple : Colors.blue, fontWeight: FontWeight.bold)),
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

  // ========== إحصائيات البقالة ==========
  Widget _buildPosDailyStats(double sales, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.monetization_on, 'مبيعات اليوم', '${sales.toStringAsFixed(0)} ريال', Colors.green),
          _buildStatItem(Icons.sell, 'عدد الكروت', '$count', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ],
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
          child: Text(isPos ? 'آخر كرت تم بيعه 🏷️' : 'الكرت النشط حالياً 🌐',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                          overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('رقم الكرت (PIN):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(actualPin,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المدة: راجع تفاصيل الكرت',
                      style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      if (isPos)
                        IconButton(
                          onPressed: () {
                            _play('click');
                            Share.share('رقم الكرت: $actualPin\nمن نقطة البيع: ${context.read<WalletProvider>().currentUserName}');
                          },
                          icon: const Icon(Icons.share, size: 18, color: Colors.teal),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (isPos) const SizedBox(width: 15),
                      IconButton(
                        onPressed: () {
                          _play('success');
                          Clipboard.setData(ClipboardData(text: actualPin));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('تم النسخ بنجاح ✅', textDirection: TextDirection.rtl),
                              backgroundColor: Colors.green));
                        },
                        icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                  child: Text(isPos ? 'سجل المبيعات والكروت' : 'إدارة كروتي ومشترياتي',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== العروض (باستخدام CouponProvider) ==========
  Widget _buildPromoSection(CouponProvider couponProvider, WalletProvider wallet, ThemeProvider theme) {
    final coupons = couponProvider.coupons;

    if (coupons.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('لا توجد عروض حالياً، ترقبوا جديدنا!', style: TextStyle(color: Colors.grey))));
    }

    var activeCoupons = coupons.where((offer) {
      try {
        if (offer['isActive'] != true) return false;
        if (offer['expiryDate'] == null) return false;
        final Timestamp expiryTs = offer['expiryDate'] as Timestamp;
        final DateTime expiry = expiryTs.toDate();
        if (expiry.isBefore(DateTime.now())) return false;

        final int current = offer['currentUsage'] ?? 0;
        final int max = offer['maxUsage'] ?? 1;
        if (current >= max) return false;

        final String targetId = (offer['targetPhone'] ?? '').toString().trim();
        if (targetId.isNotEmpty) {
          if (targetId != wallet.activeUserPhone &&
              targetId != (wallet.currentUserAccountNumber ?? '')) {
            return false;
          }
        }
        return true;
      } catch (_) {
        return false;
      }
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
      height: 170,
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
  }

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تم نسخ الكود: ${offer['code']}! جاري نقلك للمتجر 🛒', textDirection: TextDirection.rtl),
            backgroundColor: Colors.green));
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkStoreScreen()));
      },
      child: Container(
        width: 300,
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
                _LiveCountdownTimer(expiryDate: expiryDate),
                if (offer['isHappyHour'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('⏳ يعمل فقط من ${offer['startTime']} إلى ${offer['endTime']}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ),
              ],
            ),
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
                          child: Text('صالح لشبكة: ${offer['targetNetwork']}',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Text(offer['code'],
                            style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3)),
                      ),
                      const SizedBox(height: 15),
                      Text('ينتهي العرض في: ${intl.DateFormat('yyyy-MM-dd').format((offer['expiryDate'] as Timestamp).toDate())}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ),
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
        await Share.shareXFiles([XFile.fromData(pngBytes, mimeType: 'image/png', name: 'coupon_$code.png')],
            text: 'استخدم هذا الكود الآن! 🔥');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، حدث خطأ. يرجى استخدام مشاركة النص.'), backgroundColor: Colors.red));
    }
  }
}

// ==========================================
// ⏱️ الويدجت المستقل للعداد التنازلي الحي
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
    if (_timeLeft == Duration.zero)
      return const Text('انتهى العرض', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold));

    int days = _timeLeft.inDays;
    int hours = _timeLeft.inHours % 24;
    int minutes = _timeLeft.inMinutes % 60;
    int seconds = _timeLeft.inSeconds % 60;

    String formattedTime = '';
    if (days > 0) formattedTime += '$days يوم و ';
    formattedTime +=
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(formattedTime,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }
}
