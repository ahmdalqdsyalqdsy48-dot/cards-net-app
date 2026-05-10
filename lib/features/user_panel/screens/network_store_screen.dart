import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:html' as html;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';
import 'user_wallet_screen.dart';

// =============================================================================
// كلاس مساعد لتجميع منطق الخصم التلقائي والكوبونات (بدون تغيير)
// =============================================================================
class DiscountHelper {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool isWithinHappyHour(String startStr, String endStr) {
    try {
      final now = TimeOfDay.now();
      final double nowDouble = now.hour + now.minute / 60.0;
      final startParts = startStr.split(':');
      final double startDouble =
          int.parse(startParts[0]) + int.parse(startParts[1]) / 60.0;
      final endParts = endStr.split(':');
      final double endDouble =
          int.parse(endParts[0]) + int.parse(endParts[1]) / 60.0;
      if (startDouble < endDouble) {
        return nowDouble >= startDouble && nowDouble <= endDouble;
      } else {
        return nowDouble >= startDouble || nowDouble <= endDouble;
      }
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchAutoDiscount(
      String agentPhone, String currentPhone, bool isPos) async {
    try {
      final tiersSnap = await _db
          .collection('discount_tiers')
          .where('agentPhone', isEqualTo: agentPhone)
          .where('isActive', isEqualTo: true)
          .get();
      if (tiersSnap.docs.isEmpty) {
        debugPrint('لا توجد شرائح خصم نشطة');
        return null;
      }

      final DateTime now = DateTime.now();
      final DateTime startOfMonth = DateTime(now.year, now.month, 1);
      double monthlyTotal = 0.0;
      try {
        final transSnap = await _db
            .collection('transactions')
            .where('userPhone', isEqualTo: currentPhone)
            .where('agentPhone', isEqualTo: agentPhone)
            .where('type', isEqualTo: 'purchase')
            .where('timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .get();
        for (var doc in transSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          monthlyTotal += (data['amount'] ?? 0).toDouble();
        }
        debugPrint('إجمالي مشتريات الشهر: $monthlyTotal');
      } catch (e) {
        debugPrint('خطأ في جلب المعاملات: $e');
      }

      Map<String, dynamic>? bestTier;
      double bestCondition = -1;

      for (var doc in tiersSnap.docs) {
        final tier = doc.data() as Map<String, dynamic>;
        final targetType = tier['targetType'] ?? 'all';
        final targetPhones = List<String>.from(tier['targetPhones'] ?? []);
        final condition = (tier['condition'] ?? 0).toDouble();

        bool matches = false;
        if (targetType == 'all') {
          matches = true;
        } else if (targetType == 'user' && !isPos) {
          matches = true;
        } else if (targetType == 'pos' && isPos) {
          matches = true;
        } else if (targetType == 'specific' &&
            targetPhones.contains(currentPhone)) {
          matches = true;
        }

        if (matches && monthlyTotal >= condition) {
          if (condition > bestCondition) {
            bestCondition = condition;
            bestTier = tier;
          }
        }
      }

      if (bestTier == null) {
        debugPrint('لا توجد شريحة متوافقة');
        return null;
      }

      debugPrint('أفضل شريحة: ${bestTier['title']}, قيمة الخصم: ${bestTier['discountValue']}');
      return {
        'discountValue': (bestTier['discountValue'] ?? 0).toDouble(),
        'discountType': bestTier['discountType'] ?? 'percentage',
        'title': bestTier['title'] ?? '',
        'color': bestTier['color'] ?? Colors.amber.value,
        'condition': bestCondition,
        'monthlyTotal': monthlyTotal,
      };
    } catch (e) {
      debugPrint('خطأ في fetchAutoDiscount: $e');
      return null;
    }
  }

  static double applyAutoDiscount(
      double originalPrice, Map<String, dynamic> tier) {
    final double val = tier['discountValue'] as double;
    final String type = tier['discountType'] as String;
    if (type == 'percentage') {
      return originalPrice * (1 - val / 100);
    } else {
      return (originalPrice - val).clamp(0, originalPrice);
    }
  }

  Future<Map<String, dynamic>?> validateCoupon({
    required String code,
    required String agentPhone,
    required String currentPhone,
    required String networkName,
    required double basePrice,
    required double autoDiscountAmount,
  }) async {
    try {
      final query = await _db
          .collection('coupons')
          .where('agentPhone', isEqualTo: agentPhone)
          .where('code', isEqualTo: code.toUpperCase())
          .get();
      if (query.docs.isEmpty) {
        return {'error': 'كود الخصم غير صالح'};
      }
      final doc = query.docs.first;
      final data = doc.data();

      if (data['isActive'] != true) {
        return {'error': 'الكود متوقف'};
      }

      final DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
      if (expiry.isBefore(DateTime.now())) {
        return {'error': 'انتهت الصلاحية'};
      }

      final int currentUsage = data['currentUsage'] ?? 0;
      final int maxUsage = data['maxUsage'] ?? 1;
      if (currentUsage >= maxUsage) {
        return {'error': 'استنفاد الاستخدام'};
      }

      final String targetPhone = data['targetPhone'] ?? '';
      if (targetPhone.isNotEmpty && targetPhone != currentPhone) {
        return {'error': 'مخصص لرقم آخر'};
      }

      final String targetNetwork = data['targetNetwork'] ?? '';
      if (targetNetwork.isNotEmpty &&
          targetNetwork != 'الكل' &&
          targetNetwork != networkName) {
        return {'error': 'مخصص لشبكة $targetNetwork'};
      }

      if (data['isHappyHour'] == true) {
        final String sTime = data['startTime'] ?? '00:00';
        final String eTime = data['endTime'] ?? '23:59';
        if (!isWithinHappyHour(sTime, eTime)) {
          return {'error': 'فقط من $sTime إلى $eTime'};
        }
      }

      final double dValue = (data['discountValue'] ?? 0).toDouble();
      final String dType = data['discountType'] ?? 'fixed';
      double calculated = 0.0;
      final double baseForCoupon = basePrice - autoDiscountAmount;

      if (dType == 'percent') {
        calculated = baseForCoupon * (dValue / 100);
      } else if (dType == 'fixed') {
        calculated = dValue;
      } else {
        return {'error': 'لا يخصم نقداً'};
      }

      if (calculated >= baseForCoupon) calculated = baseForCoupon;

      return {
        'valid': true,
        'discountAmount': calculated,
        'docId': doc.id,
        'message': 'تم تطبيق الكوبون! 🎉',
      };
    } catch (e) {
      debugPrint('خطأ في validateCoupon: $e');
      return {'error': 'خطأ في التحقق من الكود'};
    }
  }
}

// =============================================================================
// الشاشة الرئيسية - متجر الشبكات ونقاط البيع
// =============================================================================
class NetworkStoreScreen extends StatefulWidget {
  const NetworkStoreScreen({super.key});
  @override
  State<NetworkStoreScreen> createState() => _NetworkStoreScreenState();
}

class _NetworkStoreScreenState extends State<NetworkStoreScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final DiscountHelper _discountHelper = DiscountHelper();
  String _searchQuery = '';
  Timer? _debounceTimer;
  bool _isSearching = false;

  final Map<String, GlobalKey> _cardKeys = {};

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showToast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value.trim().toLowerCase();
        _isSearching = false;
      });
    });
  }

  Future<List<String>> _executePurchase({
    required String title,
    required double unitPrice,
    required int quantity,
    required String agentPhone,
    required String agentName,
    required bool isPos,
    required String networkName,
    required String categoryId,
    required String currentPhone,
    required double finalPrice,
    required double autoDiscountAmount,
    required double couponDiscountAmount,
    String? appliedCouponId,
  }) async {
    try {
      final systemProvider = Provider.of<SystemProvider>(context, listen: false);

      final pins = await systemProvider.executeBulkPurchase(
        totalPrice: finalPrice,
        unitPrice: unitPrice,
        quantity: quantity,
        discountAmount: autoDiscountAmount,
        couponDiscount: couponDiscountAmount,
        cardTitle: title,
        agentPhone: agentPhone,
        categoryId: categoryId,
        appliedCouponId: appliedCouponId,
      );

      final netQuery = await _db
          .collection('networks')
          .where('agentPhone', isEqualTo: agentPhone)
          .get();
      if (netQuery.docs.isEmpty) throw Exception('الشبكة غير موجودة');
      final netDoc = netQuery.docs.first;
      final List<dynamic> categories =
          List.from((netDoc.data() as Map)['categories'] ?? []);
      final int idx = categories.indexWhere((c) => c['id'] == categoryId);
      if (idx != -1) {
        final cat = Map<String, dynamic>.from(categories[idx]);
        int realStock = cat['realStock'] ?? 0;
        int simStock = cat['simStock'] ?? 0;
        bool allowSellSim = cat['allowSellSim'] ?? false;
        if (allowSellSim && simStock >= quantity) {
          simStock -= quantity;
        } else {
          realStock = (realStock - quantity).clamp(0, realStock);
        }
        cat['realStock'] = realStock;
        cat['simStock'] = simStock;
        cat['stock'] = realStock + simStock;
        categories[idx] = cat;
        await _db
            .collection('networks')
            .doc(netDoc.id)
            .update({'categories': categories});
      }
      return pins;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _fetchCardDisplayData(
      String cardTitle, String agentPhone) async {
    try {
      final parts = cardTitle.split(' - ');
      final categoryName =
          parts.length > 1 ? parts.sublist(1).join(' - ') : cardTitle;
      final netSnap = await _db
          .collection('networks')
          .where('agentPhone', isEqualTo: agentPhone)
          .get();
      for (var netDoc in netSnap.docs) {
        final netData = netDoc.data() as Map<String, dynamic>;
        final List categories = netData['categories'] ?? [];
        for (var cat in categories) {
          if (cat['name'] == categoryName) {
            String? templateBase64 = cat['templateBase64'];
            Uint8List? templateBytes;
            int? imgWidth, imgHeight;
            if (templateBase64 != null && templateBase64.isNotEmpty) {
              templateBytes = base64Decode(templateBase64);
              try {
                final codec = await ui.instantiateImageCodec(templateBytes);
                final frame = await codec.getNextFrame();
                imgWidth = frame.image.width;
                imgHeight = frame.image.height;
                frame.image.dispose();
                codec.dispose();
              } catch (_) {}
            }
            return {
              'networkName': netData['name'] ?? '',
              'loginUrl': netData['loginUrl'] ?? '',
              'time': cat['time'] ?? '',
              'capacity': cat['capacity'] ?? '',
              'note': cat['note'] ?? '',
              'templateBytes': templateBytes,
              'userViewX': cat['userViewX'] ?? 50,
              'userViewY': cat['userViewY'] ?? 50,
              'userViewFontSize': cat['userViewFontSize'] ?? 16,
              'userViewColor': cat['userViewColor'] ?? Colors.black.value,
              'imageWidth': imgWidth,
              'imageHeight': imgHeight,
            };
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _showPurchaseBottomSheet(
    BuildContext context,
    String title,
    double unitPrice,
    int quantity,
    String agentPhone,
    String agentName,
    bool isPos,
    String networkName,
    String categoryId,
  ) {
    _play('click');
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    final theme = Theme.of(context);
    final double originalPrice = unitPrice * quantity;

    bool isPurchased = false;
    bool isSubmittingPurchase = false;
    List<String> purchasedPins = [];

    String? purchasedNetworkName,
        purchasedLoginUrl,
        purchasedNote,
        purchasedTime,
        purchasedCapacity;
    Uint8List? purchasedTemplateBytes;
    double purchasedUserViewX = 50,
        purchasedUserViewY = 50,
        purchasedUserViewFontSize = 16;
    Color purchasedUserViewColor = Colors.black;
    int? purchasedImageWidth, purchasedImageHeight;

    Map<String, dynamic>? autoDiscount;
    bool isLoadingAutoDiscount = true;

    double autoDiscountAmount = 0.0;
    double couponDiscountAmount = 0.0;
    String? appliedCouponDocId;
    String couponMessage = '';
    Color couponMessageColor = Colors.black;
    bool isApplyingCoupon = false;
    TextEditingController couponController = TextEditingController();

    StateSetter? _modalSetState;
    void updateState(VoidCallback fn) => _modalSetState?.call(fn);

    Future<void> loadDiscount() async {
      final discount = await _discountHelper.fetchAutoDiscount(
          agentPhone, systemProvider.currentUserPhone, isPos);
      if (!mounted) return;
      updateState(() {
        autoDiscount = discount;
        isLoadingAutoDiscount = false;
        if (discount != null) {
          autoDiscountAmount = originalPrice -
              DiscountHelper.applyAutoDiscount(originalPrice, discount);
        }
      });
    }

    double walletBalance = systemProvider.getWalletBalance(agentPhone);
    double creditLimit = 0.0;
    if (isPos) {
      final currentUserData = systemProvider.usersList.firstWhere(
          (u) => u['phone'] == systemProvider.currentUserPhone,
          orElse: () => {});
      final relations = currentUserData['agent_relations'] ?? {};
      final myRel = relations[agentPhone] ?? {};
      creditLimit = (myRel['creditLimit'] ?? 0.0).toDouble();
    }
    double totalPurchasingPower = walletBalance + creditLimit;

    final sheetBackground = theme.brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            _modalSetState = setModalState;
            if (isLoadingAutoDiscount && autoDiscount == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => loadDiscount());
            }

            double finalPrice =
                originalPrice - autoDiscountAmount - couponDiscountAmount;
            if (finalPrice < 0) finalPrice = 0;
            bool canAfford = totalPurchasingPower >= finalPrice;

            Future<void> applyCoupon() async {
              String code = couponController.text.trim().toUpperCase();
              if (code.isEmpty || isApplyingCoupon) return;
              _play('click');
              updateState(() {
                isApplyingCoupon = true;
                couponMessage = '';
              });
              final result = await _discountHelper.validateCoupon(
                code: code,
                agentPhone: agentPhone,
                currentPhone: systemProvider.currentUserPhone,
                networkName: networkName,
                basePrice: originalPrice,
                autoDiscountAmount: autoDiscountAmount,
              );
              if (!mounted) return;
              if (result != null && result['valid'] == true) {
                _play('success');
                updateState(() {
                  couponDiscountAmount = result['discountAmount'];
                  appliedCouponDocId = result['docId'];
                  couponMessage = result['message'];
                  couponMessageColor = Colors.green;
                  isApplyingCoupon = false;
                });
              } else {
                _play('error');
                updateState(() {
                  couponMessage = result?['error'] ?? 'كود غير صالح';
                  couponMessageColor = Colors.red;
                  isApplyingCoupon = false;
                });
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade400,
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
                      Text('شراء $quantity كرت من ($title)?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),
                      if (isLoadingAutoDiscount)
                        const Padding(
                            padding: EdgeInsets.all(10),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  SizedBox(width: 10),
                                  Text('جاري تحميل الخصم...',
                                      style: TextStyle(fontSize: 13))
                                ])),
                      if (!isLoadingAutoDiscount && autoDiscount != null) ...[
                        Builder(builder: (_) {
                          final discount = autoDiscount!;
                          final color = Color(discount['color']);
                          return Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withOpacity(0.5))),
                            child: Row(children: [
                              Icon(Icons.auto_awesome, color: color),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                'خصم تلقائي: ${discount['title']} (${discount['discountType'] == 'percentage' ? "${discount['discountValue']}%" : "${discount['discountValue']} ريال"})',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              )),
                              Text('-$autoDiscountAmount ريال',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          );
                        }),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: appliedCouponDocId != null
                                    ? Colors.green
                                    : Colors.grey.shade400)),
                        child: Row(children: [
                          Expanded(
                              child: TextField(
                            controller: couponController,
                            enabled:
                                appliedCouponDocId == null && !isApplyingCoupon,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                                hintText: 'هل لديك كود خصم؟',
                                border: InputBorder.none,
                                icon: Icon(Icons.local_offer,
                                    color: appliedCouponDocId != null
                                        ? Colors.green
                                        : Colors.grey)),
                          )),
                          if (appliedCouponDocId == null)
                            isApplyingCoupon
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : TextButton(
                                    onPressed: applyCoupon,
                                    child: const Text('تطبيق',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)))
                          else
                            const Icon(Icons.check_circle,
                                color: Colors.green),
                        ]),
                      ),
                      if (couponMessage.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(couponMessage,
                                style: TextStyle(
                                    color: couponMessageColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: theme.colorScheme.primary)),
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
                                  ]),
                              Text(
                                  '${totalPurchasingPower.toStringAsFixed(0)} ريال',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: canAfford
                                          ? theme.colorScheme.primary
                                          : Colors.red,
                                      fontSize: 16)),
                            ]),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المبلغ المطلوب خصمه:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (autoDiscountAmount +
                                            couponDiscountAmount >
                                        0)
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
                                  ]),
                            ]),
                      ),
                      const SizedBox(height: 25),
                      if (canAfford) ...[
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))),
                              onPressed: isSubmittingPurchase
                                  ? null
                                  : () async {
                                      _play('click');
                                      bool confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title:
                                                  const Text('تأكيد الشراء'),
                                              content: Text(
                                                  'سيتم خصم $finalPrice ريال من محفظتك. متابعة؟'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: const Text('إلغاء')),
                                                ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: const Text('نعم')),
                                              ],
                                            ),
                                          ) ??
                                          false;
                                      if (!confirm) return;
                                      updateState(
                                          () => isSubmittingPurchase = true);
                                      try {
                                        final pins = await _executePurchase(
                                          title: title,
                                          unitPrice: unitPrice,
                                          quantity: quantity,
                                          agentPhone: agentPhone,
                                          agentName: agentName,
                                          isPos: isPos,
                                          networkName: networkName,
                                          categoryId: categoryId,
                                          currentPhone:
                                              systemProvider.currentUserPhone,
                                          finalPrice: finalPrice,
                                          autoDiscountAmount:
                                              autoDiscountAmount,
                                          couponDiscountAmount:
                                              couponDiscountAmount,
                                          appliedCouponId: appliedCouponDocId,
                                        );
                                        _play('success');
                                        final info = await _fetchCardDisplayData(
                                            title, agentPhone);
                                        updateState(() {
                                          isSubmittingPurchase = false;
                                          purchasedPins = pins;
                                          if (info != null) {
                                            purchasedNetworkName =
                                                info['networkName'] ?? '';
                                            purchasedLoginUrl =
                                                info['loginUrl'] ?? '';
                                            purchasedNote = info['note'] ?? '';
                                            purchasedTime = info['time'] ?? '';
                                            purchasedCapacity =
                                                info['capacity'] ?? '';
                                            purchasedTemplateBytes =
                                                info['templateBytes'];
                                            purchasedUserViewX =
                                                (info['userViewX'] ?? 50)
                                                    .toDouble();
                                            purchasedUserViewY =
                                                (info['userViewY'] ?? 50)
                                                    .toDouble();
                                            purchasedUserViewFontSize =
                                                (info['userViewFontSize'] ??
                                                        16)
                                                    .toDouble();
                                            purchasedUserViewColor = Color(
                                                info['userViewColor'] ??
                                                    Colors.black.value);
                                            purchasedImageWidth =
                                                info['imageWidth'];
                                            purchasedImageHeight =
                                                info['imageHeight'];
                                          }
                                          isPurchased = true;
                                        });
                                      } catch (e) {
                                        _play('error');
                                        updateState(() =>
                                            isSubmittingPurchase = false);
                                        Navigator.pop(context);
                                        _showToast('فشل الشراء: $e',
                                            error: true);
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
                            )),
                        const SizedBox(height: 8),
                        TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const UserWalletScreen()));
                            },
                            icon: const Icon(Icons.account_balance_wallet,
                                color: Colors.deepPurple),
                            label: const Text('⚡ شحن المحفظة',
                                style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold))),
                      ] else ...[
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const UserWalletScreen()));
                              },
                              icon: const Icon(Icons.account_balance_wallet,
                                  color: Colors.white),
                              label: const Text('رصيدك لا يكفي - اذهب للمحفظة',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            )),
                        const SizedBox(height: 8),
                        TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const UserWalletScreen()));
                            },
                            icon: const Icon(Icons.account_balance_wallet,
                                color: Colors.deepPurple),
                            label: const Text('⚡ شحن المحفظة',
                                style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ] else ...[
                      Flexible(
                        child: SingleChildScrollView(
                          child: _buildMultiCardSuccessView(
                            pins: purchasedPins,
                            networkName: purchasedNetworkName ?? '',
                            loginUrl: purchasedLoginUrl ?? '',
                            time: purchasedTime ?? '',
                            capacity: purchasedCapacity ?? '',
                            note: purchasedNote ?? '',
                            templateBytes: purchasedTemplateBytes,
                            imageWidth: purchasedImageWidth,
                            imageHeight: purchasedImageHeight,
                            userViewX: purchasedUserViewX,
                            userViewY: purchasedUserViewY,
                            fontSize: purchasedUserViewFontSize,
                            textColor: purchasedUserViewColor,
                            originalPrice: originalPrice,
                            finalPrice: finalPrice,
                            unitPrice: unitPrice,
                            quantity: quantity,
                            autoDiscountAmount: autoDiscountAmount,
                            couponDiscountAmount: couponDiscountAmount,
                          ),
                        ),
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

  // ---------- بناء عرض الكروت بعد الشراء ----------
  Widget _buildMultiCardSuccessView({
    required List<String> pins,
    required String networkName,
    required String loginUrl,
    required String time,
    required String capacity,
    required String note,
    Uint8List? templateBytes,
    int? imageWidth,
    int? imageHeight,
    required double userViewX,
    required double userViewY,
    required double fontSize,
    required Color textColor,
    required double originalPrice,
    required double finalPrice,
    required double unitPrice,
    required int quantity,
    required double autoDiscountAmount,
    required double couponDiscountAmount,
  }) {
    final theme = Theme.of(context);
    final purchaseDate = DateTime.now();
    final dateStr =
        '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}  ${purchaseDate.hour.toString().padLeft(2, '0')}:${purchaseDate.minute.toString().padLeft(2, '0')}';

    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle, size: 50, color: Colors.green),
      const SizedBox(height: 8),
      const Text('تم الشراء بنجاح! 🎉',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green)),
      const SizedBox(height: 20),
      ...List.generate(pins.length, (index) {
        final pin = pins[index];
        if (!_cardKeys.containsKey(pin)) {
          _cardKeys[pin] = GlobalKey();
        }
        return _buildSingleCard(
          pin: pin,
          templateBytes: templateBytes,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          userViewX: userViewX,
          userViewY: userViewY,
          fontSize: fontSize,
          textColor: textColor,
          networkName: networkName,
          loginUrl: loginUrl,
          time: time,
          capacity: capacity,
          note: note,
          isLast: index == pins.length - 1,
          allPins: pins,
          originalPrice: originalPrice,
          finalPrice: finalPrice,
          unitPrice: unitPrice,
          autoDiscountAmount: autoDiscountAmount,
          couponDiscountAmount: couponDiscountAmount,
          theme: theme,
          cardKey: _cardKeys[pin]!,
          purchaseDate: dateStr,
        );
      }),
      const SizedBox(height: 16),
      _buildGlobalActions(
          pins: pins,
          networkName: networkName,
          loginUrl: loginUrl,
          time: time,
          capacity: capacity,
          note: note,
          unitPrice: unitPrice,
          quantity: quantity,
          originalPrice: originalPrice,
          finalPrice: finalPrice,
          theme: theme),
    ]);
  }

  // ---------- بناء بطاقة فردية ----------
  Widget _buildSingleCard({
    required String pin,
    Uint8List? templateBytes,
    int? imageWidth,
    int? imageHeight,
    double userViewX = 50,
    double userViewY = 50,
    double fontSize = 16,
    Color textColor = Colors.black,
    required String networkName,
    required String loginUrl,
    required String time,
    required String capacity,
    required String note,
    required bool isLast,
    required List<String> allPins,
    required double originalPrice,
    required double finalPrice,
    required double unitPrice,
    required double autoDiscountAmount,
    required double couponDiscountAmount,
    required ThemeData theme,
    required GlobalKey cardKey,
    required String purchaseDate,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final infoTextColor = isDark ? Colors.white : Colors.black87;
    final gradientColors = isDark
        ? [Colors.blueGrey.shade800, Colors.blueGrey.shade900]
        : [Colors.blue.shade50, Colors.lightBlue.shade100];

    Widget cardContent = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (templateBytes != null)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(builder: (context, constraints) {
                  double cw = constraints.maxWidth,
                      ch = constraints.maxHeight;
                  double iw = cw, ih = ch;
                  if (imageWidth != null &&
                      imageHeight != null &&
                      imageWidth > 0 &&
                      imageHeight > 0) {
                    double scale =
                        (cw / imageWidth).clamp(0.0, ch / imageHeight);
                    iw = imageWidth * scale;
                    ih = imageHeight * scale;
                  }
                  double ox = (cw - iw) / 2, oy = (ch - ih) / 2;
                  final double scaleFactor = (imageWidth != null && imageWidth > 0)
                      ? iw / imageWidth
                      : 1.0;

                  return Stack(children: [
                    Center(
                        child: Image.memory(templateBytes,
                            width: iw, height: ih, fit: BoxFit.contain)),
                    Positioned(
                        left: ox + (userViewX / 100) * iw,
                        top: oy + (userViewY / 100) * ih,
                        child: Text(pin,
                            style: TextStyle(
                                fontSize: fontSize * scaleFactor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: textColor))),
                  ]);
                }),
              ),
            )
          else
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(pin,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2))),
          const SizedBox(height: 12),
          _infoRow(Icons.wifi, 'الشبكة', networkName, Colors.blue, infoTextColor),
          _infoRow(Icons.data_usage, 'السعة', capacity, Colors.orange, infoTextColor),
          _infoRow(Icons.timer, 'المدة', time, Colors.purple, infoTextColor),
          _infoRow(Icons.calendar_today, 'تاريخ الشراء', purchaseDate, Colors.teal, infoTextColor),
          if (loginUrl.isNotEmpty)
            _infoRow(Icons.language, 'رابط الدخول', loginUrl, Colors.indigo, infoTextColor),
          if (note.isNotEmpty)
            _infoRow(Icons.note, 'ملاحظة', note, Colors.amber, infoTextColor),
          _infoRow(Icons.money, 'سعر الكرت', '$unitPrice ريال', Colors.red, infoTextColor),
          if (autoDiscountAmount + couponDiscountAmount > 0)
            _infoRow(Icons.discount, 'السعر بعد الخصم', '${(finalPrice / allPins.length).toStringAsFixed(0)} ريال', Colors.green, infoTextColor),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(children: [
        RepaintBoundary(
          key: cardKey,
          child: cardContent,
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _smallButton(Icons.copy, 'نسخ', () {
            _play('click');
            Clipboard.setData(ClipboardData(text: pin));
            _showToast('تم نسخ الكرت');
          }),
          _smallButton(Icons.share, 'مشاركة', () => _shareSingleCard(
                pin: pin,
                networkName: networkName,
                loginUrl: loginUrl,
                time: time,
                capacity: capacity,
                note: note,
                originalPrice: originalPrice,
                finalPrice: finalPrice,
                unitPrice: unitPrice,
                purchaseDate: purchaseDate,
                cardKey: cardKey,
              )),
          _smallButton(Icons.save_alt, 'حفظ', () => _saveCardImage(cardKey, pin)),
          if (loginUrl.isNotEmpty)
            _smallButton(Icons.language, 'تسجيل الدخول', () {
              _play('click');
              launchUrl(Uri.parse(loginUrl),
                  mode: LaunchMode.externalApplication);
            }),
        ]),
        if (!isLast) const Divider(height: 20),
      ]),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value, Color color, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
        Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: textColor),
                textAlign: TextAlign.end)),
      ]),
    );
  }

  Widget _smallButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]),
    );
  }

  Widget _buildGlobalActions({
    required List<String> pins,
    required String networkName,
    required String loginUrl,
    required String time,
    required String capacity,
    required String note,
    required double unitPrice,
    required int quantity,
    required double originalPrice,
    required double finalPrice,
    required ThemeData theme,
  }) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      ElevatedButton.icon(
        onPressed: () {
          final all = pins.join(' , ');
          Clipboard.setData(ClipboardData(text: all));
          _showToast('تم نسخ جميع الكروت');
        },
        icon: const Icon(Icons.copy_all),
        label: const Text('نسخ الكل'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
      ),
      ElevatedButton.icon(
        onPressed: () {
          _showShareAllDialog(
            pins: pins,
            networkName: networkName,
            time: time,
            capacity: capacity,
            loginUrl: loginUrl,
            note: note,
            unitPrice: unitPrice,
            quantity: quantity,
            originalPrice: originalPrice,
            finalPrice: finalPrice,
          );
        },
        icon: const Icon(Icons.share),
        label: const Text('مشاركة الكل'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
      ),
    ]);
  }

  void _showShareAllDialog({
    required List<String> pins,
    required String networkName,
    required String time,
    required String capacity,
    required String loginUrl,
    required String note,
    required double unitPrice,
    required int quantity,
    required double originalPrice,
    required double finalPrice,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('مشاركة الكل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Colors.blue),
              title: const Text('مشاركة كنص'),
              onTap: () {
                Navigator.pop(ctx);
                final text = pins
                    .map((p) => '''
الرقم: $p
الشبكة: $networkName
السعة: $capacity
المدة: $time
رابط: $loginUrl
''')
                    .join('\n---\n');
                Share.share(text, subject: 'كروت $networkName');
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.teal),
              title: const Text('مشاركة كصورة'),
              onTap: () {
                Navigator.pop(ctx);
                _shareAllCardsAsImage(
                  pins: pins,
                  networkName: networkName,
                  time: time,
                  capacity: capacity,
                  loginUrl: loginUrl,
                  note: note,
                  unitPrice: unitPrice,
                  quantity: quantity,
                  originalPrice: originalPrice,
                  finalPrice: finalPrice,
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _shareAllCardsAsImage({
    required List<String> pins,
    required String networkName,
    required String time,
    required String capacity,
    required String loginUrl,
    required String note,
    required double unitPrice,
    required int quantity,
    required double originalPrice,
    required double finalPrice,
  }) async {
    final GlobalKey allKey = GlobalKey();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      Widget poster = Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: allKey,
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [colorScheme.surface, colorScheme.surface.withOpacity(0.8)]
                    : [colorScheme.primary.withOpacity(0.1), colorScheme.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(networkName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: colorScheme.onSurface)),
                const SizedBox(height: 10),
                ...pins.map((pin) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.confirmation_number, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(pin, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.monetization_on, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text('سعر الكرت: $unitPrice ريال', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      const Divider(),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
                Text('الكمية: $quantity كرت',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
                Text('الإجمالي: $originalPrice ريال',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                if (originalPrice != finalPrice)
                  Text('بعد الخصم: $finalPrice ريال',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
              ],
            ),
          ),
        ),
      );

      // لضمان بناء العنصر في الشجرة بدون أن يظهر للمستخدم
      OverlayEntry? entry;
      entry = OverlayEntry(
        builder: (context) => Positioned(
          left: -1000,
          top: 0,
          child: Material(child: poster),
        ),
      );
      Overlay.of(context).insert(entry);

      await Future.delayed(const Duration(milliseconds: 200));

      final RenderRepaintBoundary boundary =
          allKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      entry.remove();

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        Navigator.pop(context); // إغلاق التحميل
        await Share.shareXFiles(
            [XFile.fromData(pngBytes, mimeType: 'image/png', name: 'cards_all.png')],
            text: 'كروت $networkName');
      } else {
        Navigator.pop(context);
        _showToast('فشلت المشاركة', error: true);
      }
    } catch (e) {
      Navigator.pop(context);
      _showToast('فشلت المشاركة', error: true);
    }
  }

  // ========== مشاركة كرت (بوستر على غرار التسويق) ==========
  Future<void> _shareSingleCard({
    required String pin,
    required String networkName,
    required String loginUrl,
    required String time,
    required String capacity,
    required String note,
    required double originalPrice,
    required double finalPrice,
    required double unitPrice,
    required String purchaseDate,
    required GlobalKey cardKey,
  }) async {
    final GlobalKey posterKey = GlobalKey();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
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
                      colors: isDark
                          ? [colorScheme.surface, colorScheme.surface.withOpacity(0.8)]
                          : [colorScheme.primary.withOpacity(0.2), colorScheme.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.wifi, color: colorScheme.primary, size: 36),
                      const SizedBox(height: 8),
                      Text(networkName,
                          style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(pin,
                            style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3)),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.data_usage, color: colorScheme.secondary, size: 16),
                          const SizedBox(width: 4),
                          Text(capacity,
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
                          const SizedBox(width: 16),
                          Icon(Icons.timer, color: colorScheme.secondary, size: 16),
                          const SizedBox(width: 4),
                          Text(time, style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: Colors.teal, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                              child: Text(purchaseDate,
                                  style: TextStyle(color: colorScheme.onSurface, fontSize: 12))),
                        ],
                      ),
                      if (loginUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.language, color: Colors.indigo, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(loginUrl,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 12))),
                          ],
                        ),
                      ],
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.note, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(note,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 12))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text('سعر الكرت: $unitPrice ريال',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (unitPrice != (finalPrice / (originalPrice / unitPrice)))
                        Text('السعر المخفض للكرت: ${(finalPrice / (originalPrice / unitPrice)).toStringAsFixed(0)} ريال',
                            style: const TextStyle(
                                color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
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
                          Navigator.pop(ctx);
                          _shareCardText(
                              pin: pin,
                              networkName: networkName,
                              time: time,
                              capacity: capacity,
                              loginUrl: loginUrl,
                              originalPrice: originalPrice,
                              finalPrice: finalPrice,
                              unitPrice: unitPrice,
                              note: note,
                              purchaseDate: purchaseDate);
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
                          Navigator.pop(ctx);
                          await _shareCardPosterImage(posterKey, pin, networkName);
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

  void _shareCardText({
    required String pin,
    required String networkName,
    required String time,
    required String capacity,
    required String loginUrl,
    required double originalPrice,
    required double finalPrice,
    required double unitPrice,
    required String note,
    required String purchaseDate,
  }) {
    final text = '''
رقم الكرت: $pin
الشبكة: $networkName
السعة: $capacity
المدة: $time
تاريخ الشراء: $purchaseDate
رابط الدخول: $loginUrl
سعر الكرت: $unitPrice ريال
${unitPrice != (finalPrice / (originalPrice / unitPrice)) ? 'السعر المخفض للكرت: ${(finalPrice / (originalPrice / unitPrice)).toStringAsFixed(0)} ريال' : ''}
ملاحظة: $note
''';
    Share.share(text, subject: 'بطاقة $networkName');
  }

  Future<void> _shareCardPosterImage(GlobalKey posterKey, String pin, String networkName) async {
    _play('click');
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      RenderRepaintBoundary boundary = posterKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        Navigator.pop(context);
        await Share.shareXFiles(
            [XFile.fromData(pngBytes, mimeType: 'image/png', name: 'card_$pin.png')],
            text: '$networkName - $pin');
      }
    } catch (e) {
      Navigator.pop(context);
      _showToast('فشلت مشاركة الصورة', error: true);
    }
  }

  Future<void> _saveCardImage(GlobalKey cardKey, String pin) async {
    try {
      RenderRepaintBoundary boundary =
          cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
      if (boundary == null) return;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      if (!kIsWeb) {
        await ImageGallerySaver.saveImage(byteData.buffer.asUint8List());
      } else {
        final blob = html.Blob([byteData.buffer.asUint8List()], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, '_blank');
      }
      _showToast('تم حفظ الصورة');
    } catch (e) {
      _showToast('فشل الحفظ', error: true);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Widget _buildUserSummaryTile(SystemProvider sys,
      Map<String, dynamic> agentRelations, ThemeData theme) {
    if (agentRelations.isEmpty) return const SizedBox();
    double displayedBalance = sys.currentUserBalance;
    if (agentRelations.isNotEmpty) {
      displayedBalance =
          (agentRelations.values.first['balance'] ?? displayedBalance)
              .toDouble();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.primary.withOpacity(0.08),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('💰 رصيدك لدى الوكيل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${displayedBalance.toStringAsFixed(0)} ريال',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 14)),
            GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UserWalletScreen())),
                child: Icon(Icons.account_balance_wallet,
                    color: theme.colorScheme.primary, size: 22)),
          ]),
    );
  }

  Widget _buildPosSummaryTile(SystemProvider sys,
      Map<String, dynamic> agentRelations, ThemeData theme) {
    if (agentRelations.isEmpty) return const SizedBox();
    final firstRel = agentRelations.values.first;
    final double balance = sys.currentUserBalance;
    final double credit = (firstRel['creditLimit'] ?? 0.0).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.primary.withOpacity(0.08),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('🏪 رصيدك + الدين المسموح',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${balance + credit} ريال',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.purple)),
            GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UserWalletScreen())),
                child: Icon(Icons.account_balance_wallet,
                    color: theme.colorScheme.primary, size: 22)),
          ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final theme = Theme.of(context);
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
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const CustomHeader(title: 'سوق الشبكات ونقاط البيع'),
        drawer: CustomUserDrawer(
            userName: sys.currentUserName,
            phoneNumber: sys.currentUserPhone),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [
            if (!isPos) _buildUserSummaryTile(sys, agentRelations, theme),
            if (isPos) _buildPosSummaryTile(sys, agentRelations, theme),
            Container(
              color: isPos ? const Color(0xFF7B1FA2) : const Color(0xFF1565C0),
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: isPos
                      ? 'ابحث في شبكات مورديك...'
                      : 'ابحث عن شبكة، بقالة، منطقة، فئة...',
                  prefixIcon: Icon(Icons.search,
                      color: isPos ? const Color(0xFF7B1FA2) : const Color(0xFF1565C0)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_isSearching) const LinearProgressIndicator(minHeight: 2),
            Container(
              color: isPos ? const Color(0xFF7B1FA2) : const Color(0xFF1565C0),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.orangeAccent,
                indicatorWeight: 4,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(icon: Icon(Icons.wifi), text: 'الشبكات'),
                  Tab(icon: Icon(Icons.store), text: 'نقاط البيع')
                ],
              ),
            ),
            Expanded(
              child: TabBarView(children: [
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (isPos && posAgents.isEmpty) {
                      return const Center(child: Text('لم يتم ربطك بأي وكيل.'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('لا توجد شبكات.'));
                    }
                    var networks = snapshot.data!.docs.where((doc) {
                      var net = doc.data() as Map<String, dynamic>;
                      final q = _searchQuery;
                      if (q.isEmpty) return true;
                      return (net['name']?.toString().toLowerCase().contains(q) ?? false) ||
                          (net['location']?.toString().toLowerCase().contains(q) ?? false) ||
                          (List<String>.from(net['coverageAreas'] ?? []).any(
                              (a) => a.toLowerCase().contains(q)));
                    }).toList();
                    if (networks.isEmpty) {
                      return const Center(child: Text('لا نتائج مطابقة'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: networks.length,
                      itemBuilder: (context, index) {
                        var net = networks[index].data() as Map<String, dynamic>;
                        return NetworkCard(
                          key: ValueKey(networks[index].id),
                          network: net,
                          isPos: isPos,
                          agentRelations: agentRelations,
                          searchQuery: _searchQuery,
                          onPurchase: (title, price, qty, agentPhone,
                                  agentName, networkName, catId) =>
                              _showPurchaseBottomSheet(
                                  context,
                                  title,
                                  price,
                                  qty,
                                  agentPhone,
                                  agentName,
                                  isPos,
                                  networkName,
                                  catId),
                        );
                      },
                    );
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('points_of_sale').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('لا توجد نقاط بيع.'));
                    }
                    var posList = snapshot.data!.docs.where((doc) {
                      var pos = doc.data() as Map<String, dynamic>;
                      final q = _searchQuery;
                      if (q.isEmpty) return true;
                      return (pos['name']?.toLowerCase().contains(q) ?? false) ||
                          (pos['location']?.toLowerCase().contains(q) ?? false) ||
                          (pos['ownerName']?.toLowerCase().contains(q) ?? false);
                    }).toList();
                    if (posList.isEmpty) return const Center(child: Text('لا نتائج مطابقة'));
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: posList.length,
                      itemBuilder: (context, index) {
                        var pos = posList[index].data() as Map<String, dynamic>;
                        return PoSCard(
                          key: ValueKey(posList[index].id),
                          pos: pos,
                          isCurrentPos: isPos,
                          searchQuery: _searchQuery,
                          onPurchase: (title, price, qty, agentPhone,
                                  agentName, networkName, catId) =>
                              _showPurchaseBottomSheet(context, title, price, qty, agentPhone, agentName, isPos, networkName, catId),
                        );
                      },
                    );
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// بطاقة الشبكة - NetworkCard (مُحدَّثة مع زر الخريطة)
// =============================================================================
class NetworkCard extends StatefulWidget {
  final Map<String, dynamic> network;
  final bool isPos;
  final Map<String, dynamic> agentRelations;
  final String searchQuery;
  final Function(String title, double price, int qty, String agentPhone,
          String agentName, String networkName, String catId)
      onPurchase;

  const NetworkCard(
      {super.key,
      required this.network,
      required this.isPos,
      required this.agentRelations,
      required this.searchQuery,
      required this.onPurchase});

  @override
  State<NetworkCard> createState() => _NetworkCardState();
}

class _NetworkCardState extends State<NetworkCard>
    with AutomaticKeepAliveClientMixin {
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, int> _qtyValues = {};
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _qtyControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _showMap(double lat, double lng, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('موقع: $title'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final network = widget.network;
    List categories =
        List<Map<String, dynamic>>.from(network['categories'] ?? []);
    final theme = Theme.of(context);

    if (widget.isPos) {
      Map<String, dynamic> rel =
          widget.agentRelations[network['agentPhone'] ?? ''] ?? {};
      List<dynamic> allowed = rel['allowedCategories'] ?? [];
      double commission =
          double.tryParse(rel['commission']?.replaceAll('%', '') ?? '0') ?? 0;
      categories = categories.where((cat) => allowed.contains(cat['id'])).toList();
      for (var cat in categories) {
        double originalPrice = (cat['price'] ?? 0).toDouble();
        cat['effectivePrice'] = originalPrice * (1 - commission / 100);
      }
    }
    categories =
        categories.where((cat) => (cat['isActive'] ?? true) == true).toList();
    categories = categories.where((cat) {
      int realStock = cat['realStock'] ?? 0;
      bool allowSellSim = cat['allowSellSim'] ?? false;
      if (!allowSellSim && realStock == 0) return false;
      return true;
    }).toList();
    if (widget.searchQuery.isNotEmpty) {
      categories = categories
          .where((cat) =>
              (cat['name'] ?? '').toLowerCase().contains(widget.searchQuery))
          .toList();
    }
    if (categories.isEmpty) return const SizedBox.shrink();

    final double? lat = network['latitude']?.toDouble();
    final double? lng = network['longitude']?.toDouble();

    return Card(
      elevation: 3,
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: const Icon(Icons.router, color: Colors.white)),
        title: Row(
          children: [
            Expanded(
              child: Text(network['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (lat != null && lng != null)
              IconButton(
                icon: const Icon(Icons.map, size: 20, color: Colors.teal),
                onPressed: () => _showMap(lat, lng, network['name'] ?? ''),
                tooltip: 'عرض على الخريطة',
              ),
          ],
        ),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📍 ${network['location'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.brightness == Brightness.dark
                ? Colors.black12
                : Colors.grey.shade50,
            child: Column(children: [
              ...categories.map((cat) {
                double price = widget.isPos
                    ? (cat['effectivePrice'] ??
                        (cat['price'] ?? 0).toDouble())
                    : (cat['price'] ?? 0).toDouble();
                int realStock = cat['realStock'] ?? 0;
                int simStock = cat['simStock'] ?? 0;
                int totalStock = cat['stock'] ?? (realStock + simStock);
                bool allowSellSim = cat['allowSellSim'] ?? false;
                int buyableStock = allowSellSim ? totalStock : realStock;
                bool isAvailable = buyableStock > 0;
                String key = '${network['agentPhone']}_${cat['id']}';
                if (!_qtyControllers.containsKey(key)) {
                  _qtyControllers[key] = TextEditingController(text: '1');
                  _qtyValues[key] = 1;
                }
                final qtyCtrl = _qtyControllers[key]!;
                int currentQty = _qtyValues[key] ?? 1;
                if (currentQty > buyableStock) {
                  currentQty = buyableStock;
                  qtyCtrl.text = '$buyableStock';
                  _qtyValues[key] = buyableStock;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Column(children: [
                    if (cat['templateBase64'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(cat['templateBase64']),
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(cat['name'] ?? '',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary)),
                            Text(
                                'السعة: ${cat['capacity']} | الوقت: ${cat['time']}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Text(
                                allowSellSim
                                    ? 'المخزون: $totalStock كرت (حقيقي: $realStock)'
                                    : 'المخزون: $realStock كرت',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isAvailable
                                        ? Colors.green
                                        : Colors.red)),
                            if (!allowSellSim && realStock == 0)
                              const Text('⚠️ بيع الكروت الوهمية غير مسموح',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.orange)),
                          ])),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      QuantitySelector(
                        currentQty: currentQty,
                        maxQty: buyableStock,
                        onChanged: (newQty) {
                          setState(() {
                            _qtyValues[key] = newQty;
                            qtyCtrl.text = '$newQty';
                          });
                        },
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: isAvailable
                            ? () => widget.onPurchase(
                                '${network['name']} - ${cat['name']}',
                                price,
                                currentQty,
                                network['agentPhone'] ?? '',
                                network['agentName'] ?? '',
                                network['name'] ?? '',
                                cat['id'] ?? '')
                            : null,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: isAvailable
                                ? theme.colorScheme.primary
                                : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: Text(
                            isAvailable
                                ? 'شراء ($price × $currentQty)'
                                : 'نفدت',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ]),
                );
              }).toList(),
            ]),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// أداة اختيار الكمية (QuantitySelector) - بدون تغيير
// =============================================================================
class QuantitySelector extends StatefulWidget {
  final int currentQty;
  final int maxQty;
  final ValueChanged<int> onChanged;

  const QuantitySelector(
      {super.key,
      required this.currentQty,
      required this.maxQty,
      required this.onChanged});

  @override
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentQty}');
  }

  @override
  void didUpdateWidget(covariant QuantitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentQty != oldWidget.currentQty) {
      _controller.text = '${widget.currentQty}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: widget.currentQty > 1
              ? () {
                  widget.onChanged(widget.currentQty - 1);
                }
              : null),
      SizedBox(
          width: 40,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero),
            onChanged: (v) {
              int? p = int.tryParse(v);
              if (p != null && p >= 1 && p <= widget.maxQty) {
                widget.onChanged(p);
              } else {
                _controller.text = '${widget.currentQty}';
              }
            },
          )),
      IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: widget.currentQty < widget.maxQty
              ? () {
                  widget.onChanged(widget.currentQty + 1);
                }
              : null),
    ]);
  }
}

// =============================================================================
// بطاقة نقطة البيع - PoSCard (مع إصلاح المخزون)
// =============================================================================
class PoSCard extends StatefulWidget {
  final Map<String, dynamic> pos;
  final bool isCurrentPos;
  final String searchQuery;
  final Function(String title, double price, int qty, String agentPhone,
          String agentName, String networkName, String catId)
      onPurchase;

  const PoSCard(
      {super.key,
      required this.pos,
      required this.isCurrentPos,
      required this.searchQuery,
      required this.onPurchase});

  @override
  State<PoSCard> createState() => _PoSCardState();
}

class _PoSCardState extends State<PoSCard> with AutomaticKeepAliveClientMixin {
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, int> _qtyValues = {};
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _qtyControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pos = widget.pos;
    List stock = List<Map<String, dynamic>>.from(pos['stock'] ?? []);
    String ownerName = pos['ownerName'] ?? 'مجهول';
    String ownerPhone = pos['ownerPhone'] ?? '';
    final theme = Theme.of(context);

    if (widget.searchQuery.isNotEmpty) {
      stock = stock.where((item) {
        return (item['network'] ?? '')
                .toLowerCase()
                .contains(widget.searchQuery) ||
            (item['category'] ?? '')
                .toLowerCase()
                .contains(widget.searchQuery);
      }).toList();
    }

    return Card(
      elevation: 3,
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Colors.teal)),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const CircleAvatar(
            backgroundColor: Colors.teal,
            child: Icon(Icons.storefront, color: Colors.white)),
        title: Text(pos['name'] ?? 'بقالة بدون اسم',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📍 ${pos['location'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text('👤 صاحب البقالة: $ownerName ($ownerPhone)',
              style: const TextStyle(fontSize: 12, color: Colors.teal)),
        ]),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.brightness == Brightness.dark
                ? Colors.teal.withOpacity(0.15)
                : Colors.teal.shade50,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('الكروت المتاحة:',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 10),
              if (stock.isEmpty)
                const Text('لا توجد كروت متاحة حالياً.',
                    style: TextStyle(color: Colors.red)),
              ...stock.map((item) {
                int available = item['available'] ?? 0;
                double price = (item['price'] ?? 0).toDouble();
                bool isAvailable = available > 0;
                String key =
                    '${ownerPhone}_${item['network']}_${item['category']}';
                if (!_qtyControllers.containsKey(key)) {
                  _qtyControllers[key] = TextEditingController(text: '1');
                  _qtyValues[key] = 1;
                }
                final qtyCtrl = _qtyControllers[key]!;
                int currentQty = _qtyValues[key] ?? 1;
                if (currentQty > available) {
                  currentQty = available;
                  qtyCtrl.text = '$available';
                  _qtyValues[key] = available;
                }

                return FutureBuilder<int>(
                  future: _getRealStock(ownerPhone, item['network'] ?? '', item['category'] ?? ''),
                  initialData: available,
                  builder: (context, snapshot) {
                    int realAvailable = snapshot.data ?? available;
                    if (realAvailable != available && mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          item['available'] = realAvailable;
                          if (currentQty > realAvailable) {
                            qtyCtrl.text = '$realAvailable';
                            _qtyValues[key] = realAvailable;
                          }
                        });
                      });
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  '${item['network']} - ${item['category']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('المتاح: $realAvailable كرت',
                                  style: TextStyle(
                                      color: realAvailable > 0 ? Colors.green : Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              QuantitySelector(
                                currentQty: currentQty,
                                maxQty: realAvailable,
                                onChanged: (newQty) {
                                  setState(() {
                                    _qtyValues[key] = newQty;
                                    qtyCtrl.text = '$newQty';
                                  });
                                },
                              ),
                            ])),
                        ElevatedButton(
                          onPressed: realAvailable > 0
                              ? () async {
                                  String catId = '';
                                  try {
                                    final netSnap = await _db
                                        .collection('networks')
                                        .where('agentPhone',
                                            isEqualTo: ownerPhone)
                                        .where('name',
                                            isEqualTo: item['network'])
                                        .limit(1)
                                        .get();
                                    if (netSnap.docs.isNotEmpty) {
                                      final cats = List<Map<String, dynamic>>.from(
                                          netSnap.docs.first
                                              .data()['categories'] ??
                                              []);
                                      final match = cats.firstWhere(
                                          (c) =>
                                              c['name'] == item['category'],
                                          orElse: () => {});
                                      catId = match['id'] ?? '';
                                    }
                                  } catch (_) {}
                                  if (catId.isNotEmpty) {
                                    widget.onPurchase(
                                        '${item['network']} - ${item['category']}',
                                        price,
                                        currentQty,
                                        ownerPhone,
                                        ownerName,
                                        item['network'],
                                        catId);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'تعذر العثور على تفاصيل الكرت.'),
                                            backgroundColor: Colors.red));
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          child: Text(
                              realAvailable > 0
                                  ? 'شراء ($price × $currentQty)'
                                  : 'نفدت',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ]),
                    );
                  },
                );
              }).toList(),
            ]),
          ),
        ],
      ),
    );
  }

  Future<int> _getRealStock(String agentPhone, String networkName, String categoryName) async {
    try {
      final query = await _db
          .collection('networks')
          .where('agentPhone', isEqualTo: agentPhone)
          .where('name', isEqualTo: networkName)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data() as Map<String, dynamic>;
        final categories = List<Map<String, dynamic>>.from(data['categories'] ?? []);
        final cat = categories.firstWhere((c) => c['name'] == categoryName, orElse: () => {});
        if (cat.isNotEmpty) {
          return cat['stock'] ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }
}
