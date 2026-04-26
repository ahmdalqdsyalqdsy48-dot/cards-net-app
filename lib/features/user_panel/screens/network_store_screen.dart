import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

class NetworkStoreScreen extends StatefulWidget {
  const NetworkStoreScreen({super.key});

  @override
  State<NetworkStoreScreen> createState() => _NetworkStoreScreenState();
}

class _NetworkStoreScreenState extends State<NetworkStoreScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showToast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ------------------- طلب شحن المحفظة -------------------
  void _showRechargeDialog(String agentPhone, String agentName) {
    _play('click');
    final amountController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('طلب شحن من $agentName',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'يرجى تحويل المبلغ المطلوب إلى الوكيل أولاً، ثم اطلب الشحن هنا ليتم إضافته لمحفظتك فور موافقته.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المطلوب شحنه',
                    suffixText: 'ريال',
                    prefixIcon: const Icon(Icons.monetization_on,
                        color: Colors.green),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              if (!isSubmitting)
                TextButton(
                    onPressed: () {
                      _play('click');
                      Navigator.pop(context);
                    },
                    child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        String amountText = amountController.text.trim();
                        if (amountText.isNotEmpty &&
                            double.tryParse(amountText) != null) {
                          setStateDialog(() => isSubmitting = true);
                          double amount = double.parse(amountText);
                          try {
                            _play('click');
                            await Provider.of<SystemProvider>(context,
                                    listen: false)
                                .requestWalletRecharge(agentPhone, amount);
                            _play('success');
                            if (mounted) {
                              Navigator.pop(context);
                              _showToast('تم إرسال طلب الشحن بنجاح ⏳');
                            }
                          } catch (e) {
                            setStateDialog(() => isSubmitting = false);
                            _play('error');
                          }
                        } else {
                          _play('error');
                          _showToast('يرجى إدخال مبلغ صحيح!', error: true);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال الطلب',
                        style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- فحص الساعة السعيدة -------------------
  bool _isWithinHappyHour(String startStr, String endStr) {
    try {
      var now = TimeOfDay.now();
      double nowDouble = now.hour + now.minute / 60.0;

      var startParts = startStr.split(':');
      double startDouble =
          int.parse(startParts[0]) + int.parse(startParts[1]) / 60.0;

      var endParts = endStr.split(':');
      double endDouble =
          int.parse(endParts[0]) + int.parse(endParts[1]) / 60.0;

      if (startDouble < endDouble) {
        return nowDouble >= startDouble && nowDouble <= endDouble;
      } else {
        return nowDouble >= startDouble || nowDouble <= endDouble;
      }
    } catch (e) {
      return false;
    }
  }

  // ------------------- جلب الخصم التلقائي (بدون await خارجي) -------------------
  Future<Map<String, dynamic>?> _fetchAutoDiscount(
      String agentPhone, bool isPos) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final String currentPhone = sys.currentUserPhone;

    final tiersSnap = await _db
        .collection('discount_tiers')
        .where('agentPhone', isEqualTo: agentPhone)
        .where('isActive', isEqualTo: true)
        .get();

    if (tiersSnap.docs.isEmpty) return null;

    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    double monthlyTotal = 0.0;
    try {
      final transSnap = await _db
          .collection('transactions')
          .where('userPhone', isEqualTo: currentPhone)
          .where('agentPhone', isEqualTo: agentPhone)
          .where('type', isEqualTo: 'purchase')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();
      for (var doc in transSnap.docs) {
        monthlyTotal += (doc.data() as Map)['amount'] ?? 0.0;
      }
    } catch (_) {}

    Map<String, dynamic>? bestTier;
    double bestCondition = -1;

    for (var doc in tiersSnap.docs) {
      final tier = doc.data() as Map<String, dynamic>;
      final targetType = tier['targetType'] ?? 'all';
      final targetPhones = List<String>.from(tier['targetPhones'] ?? []);
      final condition = (tier['condition'] ?? 0).toDouble();

      bool matches = false;
      if (targetType == 'all') matches = true;
      else if (targetType == 'user' && !isPos) matches = true;
      else if (targetType == 'pos' && isPos) matches = true;
      else if (targetType == 'specific' && targetPhones.contains(currentPhone))
        matches = true;

      if (matches && monthlyTotal >= condition) {
        if (condition > bestCondition) {
          bestCondition = condition;
          bestTier = tier;
        }
      }
    }

    if (bestTier == null) return null;
    return {
      'discountValue': (bestTier['discountValue'] ?? 0).toDouble(),
      'discountType': bestTier['discountType'] ?? 'percentage',
      'title': bestTier['title'] ?? '',
      'color': bestTier['color'] ?? Colors.amber.value,
      'condition': bestCondition,
      'monthlyTotal': monthlyTotal,
    };
  }

  double _applyAutoDiscount(double originalPrice, Map<String, dynamic> tier) {
    double val = tier['discountValue'] as double;
    String type = tier['discountType'] as String;
    if (type == 'percentage') {
      return originalPrice * (1 - val / 100);
    } else {
      return (originalPrice - val).clamp(0, originalPrice);
    }
  }

  // ------------------- نافذة الشراء (مُحسّنة بدون تجميد) -------------------
  void _showPurchaseBottomSheet(
    BuildContext context,
    String title,
    double originalPrice,
    String agentPhone,
    String agentName,
    bool isPos,
    String networkName,
  ) {
    _play('click');
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);

    // سيتم تحميل الخصم داخل النافذة
    bool isPurchased = false;
    bool isSubmittingPurchase = false;
    String actualPinFetched = '';

    // يتم جلبها لاحقاً
    Map<String, dynamic>? autoDiscount;

    double walletBalance = systemProvider.getWalletBalance(agentPhone);
    double creditLimit = 0.0;
    if (isPos) {
      Map<String, dynamic> currentUserData = systemProvider.usersList.firstWhere(
          (u) => u['phone'] == systemProvider.currentUserPhone,
          orElse: () => {});
      Map<String, dynamic> relations =
          currentUserData['agent_relations'] ?? {};
      Map<String, dynamic> myRel = relations[agentPhone] ?? {};
      creditLimit = (myRel['creditLimit'] ?? 0.0).toDouble();
    }
    double totalPurchasingPower = walletBalance + creditLimit;

    // حالة التحميل للخصم التلقائي
    bool isLoadingAutoDiscount = true;

    // متغيرات الكوبون
    double autoDiscountAmount = 0.0;
    double couponDiscountAmount = 0.0;
    String? appliedCouponDocId;
    String couponMessage = '';
    Color couponMessageColor = Colors.black;
    bool isApplyingCoupon = false;
    TextEditingController couponController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        // بدء تحميل الخصم فوراً بعد فتح النافذة
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchAutoDiscount(agentPhone, isPos).then((disc) {
            if (ctx.mounted) {
              (ctx as StatefulBuilder).setState(() {
                autoDiscount = disc;
                isLoadingAutoDiscount = false;
                if (disc != null) {
                  autoDiscountAmount =
                      originalPrice - _applyAutoDiscount(originalPrice, disc);
                }
              });
            }
          }).catchError((_) {
            if (ctx.mounted) {
              (ctx as StatefulBuilder).setState(() {
                isLoadingAutoDiscount = false;
              });
            }
          });
        });

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            double finalPrice = originalPrice - autoDiscountAmount - couponDiscountAmount;
            if (finalPrice < 0) finalPrice = 0;
            bool canAfford = totalPurchasingPower >= finalPrice;

            Future<void> applyCoupon() async {
              String code = couponController.text.trim().toUpperCase();
              if (code.isEmpty) return;
              _play('click');
              setModalState(() {
                isApplyingCoupon = true;
                couponMessage = '';
              });

              try {
                var query = await _db
                    .collection('coupons')
                    .where('agentPhone', isEqualTo: agentPhone)
                    .where('code', isEqualTo: code)
                    .get();

                if (query.docs.isEmpty) {
                  setModalState(() {
                    couponMessage = 'كود الخصم غير صحيح أو لا يتبع لهذا الوكيل';
                    couponMessageColor = Colors.red;
                    isApplyingCoupon = false;
                  });
                  _play('error');
                  return;
                }

                var doc = query.docs.first;
                var data = doc.data();

                if (data['isActive'] != true) {
                  setModalState(() {
                    couponMessage = 'هذا الكود متوقف حالياً';
                    couponMessageColor = Colors.red;
                    isApplyingCoupon = false;
                  });
                  _play('error');
                  return;
                }

                DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
                if (expiry.isBefore(DateTime.now())) {
                  setModalState(() {
                    couponMessage = 'لقد انتهت صلاحية هذا العرض';
                    couponMessageColor = Colors.red;
                    isApplyingCoupon = false;
                  });
                  _play('error');
                  return;
                }

                int currentUsage = data['currentUsage'] ?? 0;
                int maxUsage = data['maxUsage'] ?? 1;
                if (currentUsage >= maxUsage) {
                  setModalState(() {
                    couponMessage = 'تم استنفاد الحد الأقصى لاستخدام الكوبون';
                    couponMessageColor = Colors.red;
                    isApplyingCoupon = false;
                  });
                  _play('error');
                  return;
                }

                String targetPhone = data['targetPhone'] ?? '';
                if (targetPhone.isNotEmpty &&
                    targetPhone != systemProvider.currentUserPhone) {
                  setModalState(() {
                    couponMessage = 'عذراً، هذا الكود مخصص لرقم آخر';
                    couponMessageColor = Colors.red;
                    isApplyingCoupon = false;
                  });
                  _play('error');
                  return;
                }

                String targetNetwork = data['targetNetwork'] ?? '';
                if (targetNetwork.isNotEmpty &&
                    targetNetwork != 'الكل' &&
                    targetNetwork != networkName) {
                  setModalState(() {
                    couponMessage =
                        'هذا الكود مخصص لشبكة ($targetNetwork) فقط';
                    couponMessageColor = Colors.red;
                    isApplyingCoupon = false;
                  });
                  _play('error');
                  return;
                }

                if (data['isHappyHour'] == true) {
                  String sTime = data['startTime'] ?? '00:00';
                  String eTime = data['endTime'] ?? '23:59';
                  if (!_isWithinHappyHour(sTime, eTime)) {
                    setModalState(() {
                      couponMessage =
                          'هذا الكود يعمل فقط من $sTime إلى $eTime';
                      couponMessageColor = Colors.orange;
                      isApplyingCoupon = false;
                    });
                    _play('error');
                    return;
                  }
                }

                double dValue = (data['discountValue'] ?? 0).toDouble();
                String dType = data['discountType'] ?? 'fixed';

                double calculated = 0.0;
                double baseForCoupon = originalPrice - autoDiscountAmount;
                if (dType == 'percent') {
                  calculated = baseForCoupon * (dValue / 100);
                } else if (dType == 'fixed') {
                  calculated = dValue;
                } else {
                  setModalState(() {
                    couponMessage =
                        'عروض الباقات والدعوات لا تخصم من القيمة النقدية.';
                    couponMessageColor = Colors.orange;
                    isApplyingCoupon = false;
                  });
                  return;
                }

                if (calculated >= baseForCoupon) calculated = baseForCoupon;

                _play('success');
                setModalState(() {
                  couponDiscountAmount = calculated;
                  appliedCouponDocId = doc.id;
                  couponMessage = 'تم تطبيق الكوبون بنجاح! 🎉';
                  couponMessageColor = Colors.green;
                  isApplyingCoupon = false;
                });
              } catch (e) {
                setModalState(() {
                  couponMessage = 'حدث خطأ في الاتصال';
                  couponMessageColor = Colors.red;
                  isApplyingCoupon = false;
                });
                _play('error');
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),

                    if (!isPurchased) ...[
                      const Icon(Icons.shopping_cart_checkout,
                          size: 60, color: Colors.orange),
                      const SizedBox(height: 15),
                      const Text('تأكيد عملية الشراء',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text('هل أنت متأكد من شراء كرت ($title)؟',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),

                      // تحميل الخصم التلقائي
                      if (isLoadingAutoDiscount)
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('جاري تحميل الخصم التلقائي...',
                                  style: TextStyle(fontSize: 13))
                            ],
                          ),
                        ),

                      if (!isLoadingAutoDiscount && autoDiscount != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Color(autoDiscount['color'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    Color(autoDiscount['color']).withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: Color(autoDiscount['color'])),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'خصم تلقائي: ${autoDiscount['title']} (${autoDiscount['discountType'] == 'percentage' ? "${autoDiscount['discountValue']}%" : "${autoDiscount['discountValue']} ريال"})',
                                  style: TextStyle(
                                      color: Color(autoDiscount['color']),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                              Text('-$autoDiscountAmount ريال',
                                  style: TextStyle(
                                      color: Color(autoDiscount['color']),
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),

                      // حقل الكوبون
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: appliedCouponDocId != null
                                    ? Colors.green
                                    : Colors.grey.shade300)),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: couponController,
                                enabled:
                                    appliedCouponDocId == null && !isApplyingCoupon,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText:
                                      'هل لديك كود خصم؟ (انسخه من الرئيسية)',
                                  hintStyle: const TextStyle(
                                      fontWeight: FontWeight.normal,
                                      fontSize: 12),
                                  border: InputBorder.none,
                                  icon: Icon(Icons.local_offer,
                                      color: appliedCouponDocId != null
                                          ? Colors.green
                                          : Colors.grey),
                                ),
                              ),
                            ),
                            if (appliedCouponDocId == null)
                              isApplyingCoupon
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)))
                                  : TextButton(
                                      onPressed: applyCoupon,
                                      child: const Text('تطبيق',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    )
                            else
                              const Icon(Icons.check_circle,
                                  color: Colors.green),
                          ],
                        ),
                      ),
                      if (couponMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(couponMessage,
                              style: TextStyle(
                                  color: couponMessageColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 15),

                      // رصيد المشتري
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('رصيدك المتاح لدى:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                Text('الوكيل $agentName',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                                if (isPos && creditLimit > 0)
                                  Text('+ دين مسموح: $creditLimit',
                                      style: const TextStyle(
                                          color: Colors.purple,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text(
                                '${totalPurchasingPower.toStringAsFixed(0)} ريال',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: canAfford
                                        ? Colors.blue
                                        : Colors.red,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // السعر النهائي
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('المبلغ المطلوب خصمه:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (autoDiscountAmount + couponDiscountAmount > 0)
                                  Text('$originalPrice ريال',
                                      style: const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Colors.grey,
                                          fontSize: 13)),
                                Text('$finalPrice ريال',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                        fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      if (canAfford)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10))),
                            onPressed: isSubmittingPurchase
                                ? null
                                : () async {
                                    _play('click');
                                    setModalState(() =>
                                        isSubmittingPurchase = true);
                                    try {
                                      String realPin =
                                          await systemProvider.executeRealPurchase(
                                              finalPrice,
                                              title,
                                              agentPhone);

                                      if (appliedCouponDocId != null) {
                                        await _db
                                            .collection('coupons')
                                            .doc(appliedCouponDocId)
                                            .update({
                                          'currentUsage':
                                              FieldValue.increment(1)
                                        });
                                      }

                                      _play('success');
                                      setModalState(() {
                                        actualPinFetched = realPin;
                                        isPurchased = true;
                                        isSubmittingPurchase = false;
                                      });
                                    } catch (e) {
                                      _play('error');
                                      setModalState(() =>
                                          isSubmittingPurchase = false);
                                      Navigator.pop(context);
                                      _showToast(e.toString(), error: true);
                                    }
                                  },
                            child: isSubmittingPurchase
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('تأكيد وشراء الآن',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10))),
                            onPressed: () {
                              Navigator.pop(context);
                              _showRechargeDialog(agentPhone, agentName);
                            },
                            icon: const Icon(Icons.account_balance_wallet,
                                color: Colors.white),
                            label: const Text('رصيدك لا يكفي - اطلب شحن الآن',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // 🆕 زر شحن المحفظة مستقل (يظهر دائماً)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // إغلاق نافذة الشراء
                          _showRechargeDialog(agentPhone, agentName);
                        },
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.deepPurple),
                        label: const Text('⚡ شحن المحفظة',
                            style: TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      const Icon(Icons.check_circle,
                          size: 60, color: Colors.green),
                      const SizedBox(height: 15),
                      const Text('تم الشراء بنجاح! 🎉',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.5))),
                        child: Column(
                          children: [
                            const Text('رقم الكرت (PIN)',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Text(actualPinFetched,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2)),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              onPressed: () {
                                _play('click');
                                Clipboard.setData(
                                    ClipboardData(text: actualPinFetched));
                                _showToast('تم نسخ الكرت بنجاح! ✅');
                              },
                              icon: const Icon(Icons.copy,
                                  color: Colors.white),
                              label: const Text('نسخ الكرت',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          _play('click');
                          Navigator.pop(context);
                        },
                        child: const Text('إغلاق',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ------------------- بطاقة ملخص المستخدم -------------------
  Widget _buildUserSummaryTile(
      SystemProvider sys, Map<String, dynamic> agentRelations) {
    if (agentRelations.isEmpty) return const SizedBox();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('💰 رصيدك لدى الوكيل',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Row(
            children: [
              Text('${sys.currentUserBalance} ريال',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue)),
              const SizedBox(width: 12),
              // 🆕 زر شحن المحفظة في الشريط العلوي
              GestureDetector(
                onTap: () {
                  // نأخذ أول وكيل من العلاقات كمثال، يمكن تحسينه لاختيار وكيل معين
                  if (agentRelations.isNotEmpty) {
                    final firstAgent =
                        agentRelations.keys.first as String;
                    // يفترض وجود اسم الوكيل في مكان ما، هنا نمرر رقمه فقط
                    _showRechargeDialog(firstAgent, 'الوكيل');
                  }
                },
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.deepPurple, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------- بطاقة ملخص نقطة البيع -------------------
  Widget _buildPosSummaryTile(
      SystemProvider sys, Map<String, dynamic> agentRelations) {
    if (agentRelations.isEmpty) return const SizedBox();
    final firstRel = agentRelations.values.first;
    final double balance = sys.currentUserBalance;
    final double credit = (firstRel['creditLimit'] ?? 0.0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.purple.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('🏪 رصيدك + الدين المسموح',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Row(
            children: [
              Text('${balance + credit} ريال',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.purple)),
              const SizedBox(width: 12),
              // 🆕 زر شحن المحفظة
              GestureDetector(
                onTap: () {
                  if (agentRelations.isNotEmpty) {
                    final firstAgent =
                        agentRelations.keys.first as String;
                    _showRechargeDialog(firstAgent, 'الوكيل');
                  }
                },
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.deepPurple, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------- بناء الواجهة الرئيسية -------------------
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final bool isPos = sys.currentUserRole == 'pos';

    Map<String, dynamic> currentUserData = {};
    if (sys.currentUserPhone.isNotEmpty) {
      currentUserData = sys.usersList.firstWhere(
          (u) => u['phone'] == sys.currentUserPhone,
          orElse: () => {});
    }

    final List<dynamic> posAgents = currentUserData['pos_agents'] ?? [];
    final Map<String, dynamic> agentRelations =
        currentUserData['agent_relations'] ?? {};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const CustomHeader(title: 'سوق الشبكات ونقاط البيع'),
        drawer: CustomUserDrawer(
          userName: sys.currentUserName,
          phoneNumber: sys.currentUserPhone,
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // بطاقة ملخص المستخدم (مع زر الشحن)
              if (!isPos) _buildUserSummaryTile(sys, agentRelations),
              if (isPos) _buildPosSummaryTile(sys, agentRelations),

              // شريط البحث
              Container(
                color: isPos ? Colors.purple.shade800 : Colors.blue.shade800,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim().toLowerCase()),
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: isPos
                        ? 'ابحث في شبكات مورديك...'
                        : 'ابحث عن شبكة أو بقالة أو منطقة...',
                    prefixIcon: Icon(Icons.search,
                        color: isPos ? Colors.purple : Colors.blue),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),

              // التبويبات
              Container(
                color: isPos ? Colors.purple.shade800 : Colors.blue.shade800,
                child: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.orange,
                  indicatorWeight: 4,
                  tabs: [
                    Tab(icon: Icon(Icons.wifi), text: 'الشبكات المتاحة 📡'),
                    Tab(icon: Icon(Icons.store), text: 'نقاط البيع 🏪'),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    // ---------- تبويب الشبكات ----------
                    StreamBuilder<QuerySnapshot>(
                      stream: (isPos && posAgents.isNotEmpty)
                          ? _db
                              .collection('networks')
                              .where('agentPhone',
                                  whereIn: posAgents.take(10).toList())
                              .where('isActive', isEqualTo: true)
                              .snapshots()
                          : _db
                              .collection('networks')
                              .where('isActive', isEqualTo: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting)
                          return const Center(
                              child: CircularProgressIndicator());

                        if (isPos && posAgents.isEmpty)
                          return const Center(
                              child: Text('لم يتم ربطك بأي وكيل حتى الآن.',
                                  style: TextStyle(color: Colors.grey)));

                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty)
                          return const Center(
                              child: Text('لا توجد شبكات معروضة حالياً.',
                                  style: TextStyle(color: Colors.grey)));

                        var networks = snapshot.data!.docs.where((doc) {
                          var net = doc.data() as Map<String, dynamic>;
                          return (net['name']
                                      ?.toString()
                                      .toLowerCase()
                                      .contains(_searchQuery) ??
                                  false) ||
                              (net['location']
                                      ?.toString()
                                      .toLowerCase()
                                      .contains(_searchQuery) ??
                                  false);
                        }).toList();

                        if (networks.isEmpty)
                          return const Center(
                              child: Text('لا توجد شبكات مطابقة للبحث'));

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: networks.length,
                          itemBuilder: (context, index) {
                            var net = networks[index].data()
                                as Map<String, dynamic>;
                            return _buildNetworkCard(
                                net, isPos, agentRelations);
                          },
                        );
                      },
                    ),

                    // ---------- تبويب نقاط البيع ----------
                    StreamBuilder<QuerySnapshot>(
                      // 🔧 إزالة where isActive لمعالجة مشكلة عدم الظهور
                      stream:
                          _db.collection('points_of_sale').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting)
                          return const Center(
                              child: CircularProgressIndicator());
                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty)
                          return const Center(
                              child: Text('لا توجد نقاط بيع معروضة حالياً.',
                                  style: TextStyle(color: Colors.grey)));

                        var posList = snapshot.data!.docs.where((doc) {
                          var pos = doc.data() as Map<String, dynamic>;
                          // يمكنك إضافة فحص isActive هنا لاحقاً إن وجد
                          return (pos['name']
                                      ?.toString()
                                      .toLowerCase()
                                      .contains(_searchQuery) ??
                                  false) ||
                              (pos['location']
                                      ?.toString()
                                      .toLowerCase()
                                      .contains(_searchQuery) ??
                                  false);
                        }).toList();

                        if (posList.isEmpty)
                          return const Center(
                              child: Text('لا توجد نقاط بيع مطابقة للبحث'));

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: posList.length,
                          itemBuilder: (context, index) {
                            var pos = posList[index].data()
                                as Map<String, dynamic>;
                            return _buildPoSCard(pos, isPos);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- بطاقة الشبكة -------------------
  Widget _buildNetworkCard(Map<String, dynamic> network, bool isPos,
      Map<String, dynamic> agentRelations) {
    List categories = network['categories'] ?? [];
    String agentPhone = network['agentPhone'] ?? '';
    String agentName = network['agentName'] ?? 'مجهول';
    String networkName = network['name'] ?? '';

    if (isPos) {
      Map<String, dynamic> myRelationWithThisAgent =
          agentRelations[agentPhone] ?? {};
      List<dynamic> allowedCatsForThisAgent =
          myRelationWithThisAgent['allowedCategories'] ?? [];
      categories = categories
          .where((cat) => allowedCatsForThisAgent.contains(cat['id']))
          .toList();
    }

    if (categories.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 3,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(
            backgroundColor: isPos ? Colors.purple : Colors.blue,
            child: const Icon(Icons.router, color: Colors.white)),
        title: Text(networkName,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('📍 ${network['location'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black12
                : Colors.grey.shade50,
            child: Column(
              children: [
                // 🆕 زر شحن المحفظة أعلى الفئات
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Text('الوكيل: $agentName',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const Spacer(),
                      InkWell(
                        onTap: () =>
                            _showRechargeDialog(agentPhone, agentName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('⚡ شحن المحفظة',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                ...categories.map((cat) {
                  double price = (cat['price'] ?? 0).toDouble();
                  int stock = cat['stock'] ?? cat['available'] ?? 0;
                  bool isAvailable = stock > 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.3))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(cat['name'] ?? '',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isPos
                                              ? Colors.purple
                                              : Colors.orange)),
                                  const SizedBox(width: 6),
                                  if (_hasAnyAutoDiscountForUser(agentPhone, isPos))
                                    const Icon(Icons.auto_awesome,
                                        size: 16, color: Colors.amber),
                                ],
                              ),
                              Text(
                                  'السعة: ${cat['capacity']} | الوقت: ${cat['time']}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              Text('المخزون: $stock كرت',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isAvailable
                                          ? Colors.green
                                          : Colors.red)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isAvailable
                              ? () => _showPurchaseBottomSheet(
                                  context,
                                  '${network['name']} - ${cat['name']}',
                                  price,
                                  agentPhone,
                                  agentName,
                                  isPos,
                                  networkName)
                              : null,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: isAvailable
                                  ? (isPos ? Colors.purple : Colors.blue.shade800)
                                  : Colors.grey,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          child: Text(
                              isAvailable ? 'شراء ($price)' : 'نفدت الكمية',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        )
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ------------------- بطاقة نقطة البيع -------------------
  Widget _buildPoSCard(Map<String, dynamic> pos, bool isCurrentPos) {
    List stock = pos['stock'] ?? [];
    String ownerName = pos['ownerName'] ?? 'مجهول';
    String ownerPhone = pos['ownerPhone'] ?? '';

    return Card(
      elevation: 3,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.teal.withOpacity(0.3))),
      child: ExpansionTile(
        leading: const CircleAvatar(
            backgroundColor: Colors.teal,
            child: Icon(Icons.storefront, color: Colors.white)),
        title: Text(pos['name'] ?? 'بقالة بدون اسم',
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('📍 ${pos['location'] ?? ''}\n👤 $ownerName',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.teal.withOpacity(0.1)
                : Colors.teal.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الكروت المتاحة في هذه البقالة:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.teal)),
                const SizedBox(height: 10),
                if (stock.isEmpty)
                  const Text('لا يوجد كروت معروضة للبيع حالياً.',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                ...stock.map((item) {
                  int available = item['available'] ?? 0;
                  double price = (item['price'] ?? 0).toDouble();
                  bool isAvailable = available > 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${item['network']} - ${item['category']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Text('المتاح: $available كرت',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isAvailable
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isAvailable
                              ? () => _showPurchaseBottomSheet(
                                  context,
                                  'من ${pos['name']} (${item['network']})',
                                  price,
                                  ownerPhone,
                                  ownerName,
                                  isCurrentPos,
                                  item['network'])
                              : null,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          child: Text(
                              isAvailable ? 'شراء ($price)' : 'نفدت الكمية',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        )
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ------------------- مساعد: هل يوجد خصم تلقائي محتمل؟ -------------------
  bool _hasAnyAutoDiscountForUser(String agentPhone, bool isPos) {
    // للتبسيط نعيد true لإظهار الأيقونة، والتحقق الفعلي يتم داخل النافذة
    return true;
  }
}
