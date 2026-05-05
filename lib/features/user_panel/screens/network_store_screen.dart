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

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';
import 'user_wallet_screen.dart';

class NetworkStoreScreen extends StatefulWidget {
  const NetworkStoreScreen({super.key});

  @override
  State<NetworkStoreScreen> createState() => _NetworkStoreScreenState();
}

class _NetworkStoreScreenState extends State<NetworkStoreScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  final GlobalKey _cardKey = GlobalKey();
  Timer? _debounceTimer;
  bool _isSearching = false;

  // متحكمات الكمية لكل فئة (مفتاح = networkId_categoryId)
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, int> _qtyValues = {}; // لتحديث الحالة

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

  bool _isWithinHappyHour(String startStr, String endStr) {
    try {
      var now = TimeOfDay.now();
      double nowDouble = now.hour + now.minute / 60.0;
      var startParts = startStr.split(':');
      double startDouble = int.parse(startParts[0]) + int.parse(startParts[1]) / 60.0;
      var endParts = endStr.split(':');
      double endDouble = int.parse(endParts[0]) + int.parse(endParts[1]) / 60.0;
      if (startDouble < endDouble) {
        return nowDouble >= startDouble && nowDouble <= endDouble;
      } else {
        return nowDouble >= startDouble || nowDouble <= endDouble;
      }
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _fetchAutoDiscount(String agentPhone, bool isPos) async {
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

  // ===== نافذة الشراء المُحسَّنة مع الكمية =====
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
    final double originalPrice = unitPrice * quantity;

    bool isPurchased = false;
    bool isSubmittingPurchase = false;
    String actualPinFetched = '';

    Map<String, dynamic>? purchasedCardData;
    bool isLoadingCardData = false;
    String? purchasedNetworkName;
    String? purchasedLoginUrl;
    String? purchasedNote;
    String? purchasedTime;
    String? purchasedCapacity;
    Uint8List? purchasedTemplateBytes;
    double purchasedUserViewX = 50;
    double purchasedUserViewY = 50;
    double purchasedUserViewFontSize = 16;
    Color purchasedUserViewColor = Colors.black;
    int? purchasedImageWidth;
    int? purchasedImageHeight;
    int purchasedQuantity = quantity;

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
      final discount = await _fetchAutoDiscount(agentPhone, isPos);
      if (!mounted) return;
      updateState(() {
        autoDiscount = discount;
        isLoadingAutoDiscount = false;
        if (discount != null) {
          autoDiscountAmount = originalPrice - _applyAutoDiscount(originalPrice, discount);
        }
      });
    }

    double walletBalance = systemProvider.getWalletBalance(agentPhone);
    double creditLimit = 0.0;
    if (isPos) {
      Map<String, dynamic> currentUserData = systemProvider.usersList.firstWhere(
          (u) => u['phone'] == systemProvider.currentUserPhone, orElse: () => {});
      Map<String, dynamic> relations = currentUserData['agent_relations'] ?? {};
      Map<String, dynamic> myRel = relations[agentPhone] ?? {};
      creditLimit = (myRel['creditLimit'] ?? 0.0).toDouble();
    }
    double totalPurchasingPower = walletBalance + creditLimit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            _modalSetState = setModalState;
            if (isLoadingAutoDiscount && autoDiscount == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => loadDiscount());
            }

            double finalPrice = originalPrice - autoDiscountAmount - couponDiscountAmount;
            if (finalPrice < 0) finalPrice = 0;
            bool canAfford = totalPurchasingPower >= finalPrice;

            Future<void> applyCoupon() async {
              // ... (نفس كود الكوبون السابق، بدون تغيير)
              String code = couponController.text.trim().toUpperCase();
              if (code.isEmpty) return;
              _play('click');
              updateState(() { isApplyingCoupon = true; couponMessage = ''; });
              try {
                var query = await _db.collection('coupons').where('agentPhone', isEqualTo: agentPhone).where('code', isEqualTo: code).get();
                if (query.docs.isEmpty) { updateState(() { couponMessage = 'كود الخصم غير صحيح'; couponMessageColor = Colors.red; isApplyingCoupon = false; }); _play('error'); return; }
                var doc = query.docs.first; var data = doc.data();
                if (data['isActive'] != true) { updateState(() { couponMessage = 'الكود متوقف'; couponMessageColor = Colors.red; isApplyingCoupon = false; }); _play('error'); return; }
                DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
                if (expiry.isBefore(DateTime.now())) { updateState(() { couponMessage = 'انتهت الصلاحية'; couponMessageColor = Colors.red; isApplyingCoupon = false; }); _play('error'); return; }
                int currentUsage = data['currentUsage'] ?? 0; int maxUsage = data['maxUsage'] ?? 1;
                if (currentUsage >= maxUsage) { updateState(() { couponMessage = 'استنفاد الاستخدام'; couponMessageColor = Colors.red; isApplyingCoupon = false; }); _play('error'); return; }
                String targetPhone = data['targetPhone'] ?? '';
                if (targetPhone.isNotEmpty && targetPhone != systemProvider.currentUserPhone) { updateState(() { couponMessage = 'كود مخصص لرقم آخر'; couponMessageColor = Colors.red; isApplyingCoupon = false; }); _play('error'); return; }
                String targetNetwork = data['targetNetwork'] ?? '';
                if (targetNetwork.isNotEmpty && targetNetwork != 'الكل' && targetNetwork != networkName) { updateState(() { couponMessage = 'مخصص لشبكة $targetNetwork'; couponMessageColor = Colors.red; isApplyingCoupon = false; }); _play('error'); return; }
                if (data['isHappyHour'] == true) {
                  String sTime = data['startTime'] ?? '00:00'; String eTime = data['endTime'] ?? '23:59';
                  if (!_isWithinHappyHour(sTime, eTime)) { updateState(() { couponMessage = 'فقط من $sTime إلى $eTime'; couponMessageColor = Colors.orange; isApplyingCoupon = false; }); _play('error'); return; }
                }
                double dValue = (data['discountValue'] ?? 0).toDouble(); String dType = data['discountType'] ?? 'fixed';
                double calculated = 0.0; double baseForCoupon = originalPrice - autoDiscountAmount;
                if (dType == 'percent') calculated = baseForCoupon * (dValue / 100);
                else if (dType == 'fixed') calculated = dValue;
                else { updateState(() { couponMessage = 'لا يخصم نقداً'; couponMessageColor = Colors.orange; isApplyingCoupon = false; }); return; }
                if (calculated >= baseForCoupon) calculated = baseForCoupon;
                _play('success');
                updateState(() { couponDiscountAmount = calculated; appliedCouponDocId = doc.id; couponMessage = 'تم تطبيق الكوبون! 🎉'; couponMessageColor = Colors.green; isApplyingCoupon = false; });
              } catch (e) { updateState(() { couponMessage = 'خطأ'; couponMessageColor = Colors.red; isApplyingCoupon = false; }); _play('error'); }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  if (!isPurchased) ...[
                    const Icon(Icons.shopping_cart_checkout, size: 60, color: Colors.orange),
                    const SizedBox(height: 15),
                    const Text('تأكيد عملية الشراء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('شراء $quantity كرت من ($title)؟', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 20),
                    if (isLoadingAutoDiscount)
                      const Padding(padding: EdgeInsets.all(10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('جاري تحميل الخصم...', style: TextStyle(fontSize: 13))
                      ])),
                    if (!isLoadingAutoDiscount && autoDiscount != null) ...[
                      Builder(builder: (_) {
                        final discount = autoDiscount!; final color = Color(discount['color']);
                        return Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.5))),
                          child: Row(children: [
                            Icon(Icons.auto_awesome, color: color), const SizedBox(width: 10),
                            Expanded(child: Text('خصم تلقائي: ${discount['title']} (${discount['discountType'] == 'percentage' ? "${discount['discountValue']}%" : "${discount['discountValue']} ريال"})', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
                            Text('-$autoDiscountAmount ريال', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                          ]),
                        );
                      }),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: appliedCouponDocId != null ? Colors.green : Colors.grey.shade300)),
                      child: Row(children: [
                        Expanded(child: TextField(controller: couponController, enabled: appliedCouponDocId == null && !isApplyingCoupon, style: const TextStyle(fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: 'كود خصم؟', border: InputBorder.none, icon: Icon(Icons.local_offer, color: appliedCouponDocId != null ? Colors.green : Colors.grey)))),
                        if (appliedCouponDocId == null) isApplyingCoupon ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : TextButton(onPressed: applyCoupon, child: const Text('تطبيق', style: TextStyle(fontWeight: FontWeight.bold)))
                        else const Icon(Icons.check_circle, color: Colors.green),
                      ]),
                    ),
                    if (couponMessage.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(couponMessage, style: TextStyle(color: couponMessageColor, fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 15),
                    Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('رصيدك المتاح لدى:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('الوكيل $agentName', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          if (isPos && creditLimit > 0) Text('+ دين مسموح: $creditLimit', style: const TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                        Text('${totalPurchasingPower.toStringAsFixed(0)} ريال', style: TextStyle(fontWeight: FontWeight.bold, color: canAfford ? Theme.of(context).colorScheme.primary : Colors.red, fontSize: 16)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('المبلغ المطلوب:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (autoDiscountAmount + couponDiscountAmount > 0)
                            Text('$originalPrice ريال', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 13)),
                          Text('$finalPrice ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 25),
                    if (canAfford)
                      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmittingPurchase ? null : () async {
                          _play('click');
                          updateState(() => isSubmittingPurchase = true);
                          try {
                            // توليد الكروت حسب الكمية
                            List<String> pins = [];
                            for (int i = 0; i < quantity; i++) {
                              String realPin = await systemProvider.executeRealPurchase(
                                  unitPrice, title, agentPhone, categoryId);
                              pins.add(realPin);
                            }
                            actualPinFetched = pins.join(' , ');
                            await _decrementStock(agentPhone, categoryId, quantity);
                            if (appliedCouponDocId != null) {
                              await _db.collection('coupons').doc(appliedCouponDocId).update({'currentUsage': FieldValue.increment(1)});
                            }
                            _play('success');
                            updateState(() { isSubmittingPurchase = false; isLoadingCardData = true; });
                            final displayData = await _fetchCardDisplayData(title, agentPhone);
                            updateState(() {
                              isLoadingCardData = false;
                              purchasedCardData = displayData;
                              if (displayData != null) {
                                purchasedNetworkName = displayData['networkName'] ?? '';
                                purchasedLoginUrl = displayData['loginUrl'] ?? '';
                                purchasedNote = displayData['note'] ?? '';
                                purchasedTime = displayData['time'] ?? '';
                                purchasedCapacity = displayData['capacity'] ?? '';
                                purchasedTemplateBytes = displayData['templateBytes'];
                                purchasedUserViewX = (displayData['userViewX'] ?? 50).toDouble();
                                purchasedUserViewY = (displayData['userViewY'] ?? 50).toDouble();
                                purchasedUserViewFontSize = (displayData['userViewFontSize'] ?? 16).toDouble();
                                purchasedUserViewColor = Color(displayData['userViewColor'] ?? Colors.black.value);
                                purchasedImageWidth = displayData['imageWidth'];
                                purchasedImageHeight = displayData['imageHeight'];
                              }
                              isPurchased = true;
                            });
                          } catch (e) {
                            _play('error');
                            updateState(() => isSubmittingPurchase = false);
                            Navigator.pop(context);
                            _showToast(e.toString(), error: true);
                          }
                        },
                        child: isSubmittingPurchase ? const CircularProgressIndicator(color: Colors.white) : const Text('تأكيد وشراء الآن', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ))
                    else
                      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                        onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const UserWalletScreen())); },
                        icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                        label: const Text('رصيدك لا يكفي - اذهب للمحفظة', style: TextStyle(fontSize: 14, color: Colors.white)),
                      )),
                    const SizedBox(height: 8),
                    TextButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const UserWalletScreen())); }, icon: const Icon(Icons.account_balance_wallet, color: Colors.deepPurple), label: const Text('⚡ شحن المحفظة', style: TextStyle(color: Colors.deepPurple))),
                  ] else ...[
                    if (isLoadingCardData) const Center(child: CircularProgressIndicator())
                    else if (purchasedCardData == null) _buildSimpleSuccessView(actualPinFetched, originalPrice)
                    else _buildAdvancedSuccessView(actualPinFetched, purchasedTemplateBytes, purchasedImageWidth, purchasedImageHeight, purchasedUserViewX, purchasedUserViewY, purchasedUserViewFontSize, purchasedUserViewColor, purchasedNetworkName, purchasedTime, purchasedCapacity, purchasedNote, purchasedLoginUrl, purchasedQuantity),
                  ],
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _decrementStock(String agentPhone, String categoryId, int amount) async {
    final netSnap = await _db.collection('networks').where('agentPhone', isEqualTo: agentPhone).get();
    for (var netDoc in netSnap.docs) {
      List cats = List.from((netDoc.data() as Map)['categories'] ?? []);
      int idx = cats.indexWhere((c) => c['id'] == categoryId);
      if (idx != -1) {
        int realStock = cats[idx]['realStock'] ?? 0;
        cats[idx]['realStock'] = (realStock - amount).clamp(0, realStock);
        cats[idx]['stock'] = cats[idx]['realStock'] + (cats[idx]['simStock'] ?? 0);
        await _db.collection('networks').doc(netDoc.id).update({'categories': cats});
        break;
      }
    }
  }

  Widget _buildSimpleSuccessView(String pin, double price) {
    return Column(children: [
      const Icon(Icons.check_circle, size: 60, color: Colors.green),
      const SizedBox(height: 15),
      const Text('تم الشراء بنجاح! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.withOpacity(0.5))),
        child: Column(children: [
          const Text('رقم الكرت (PIN)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(pin, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: () { _play('click'); Clipboard.setData(ClipboardData(text: pin)); _showToast('تم نسخ الكرت!'); },
            icon: const Icon(Icons.copy), label: const Text('نسخ الكرت'),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      TextButton(onPressed: () { Navigator.pop(context); }, child: const Text('إغلاق')),
    ]);
  }

  Widget _buildAdvancedSuccessView(
    String pin, Uint8List? templateBytes, int? imageWidth, int? imageHeight,
    double userViewX, double userViewY, double fontSize, Color textColor,
    String? networkName, String? time, String? capacity, String? note, String? loginUrl,
    int quantity,
  ) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width * 0.9;
    double aspectRatio = 1.0;
    if (imageWidth != null && imageHeight != null && imageWidth > 0 && imageHeight > 0) {
      aspectRatio = imageWidth / imageHeight;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle, size: 50, color: Colors.green),
      const SizedBox(height: 8),
      const Text('تم الشراء بنجاح! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
      const SizedBox(height: 20),
      if (templateBytes != null)
        RepaintBoundary(
          key: _cardKey,
          child: Container(
            width: screenWidth, constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(builder: (context, constraints) {
                double containerWidth = constraints.maxWidth;
                double containerHeight = constraints.maxHeight;
                double scale = 1.0;
                double imageDisplayWidth = containerWidth;
                double imageDisplayHeight = containerHeight;
                if (imageWidth != null && imageHeight != null && imageWidth > 0 && imageHeight > 0) {
                  scale = (containerWidth / imageWidth).clamp(0.0, containerHeight / imageHeight);
                  imageDisplayWidth = imageWidth * scale;
                  imageDisplayHeight = imageHeight * scale;
                }
                double offsetX = (containerWidth - imageDisplayWidth) / 2;
                double offsetY = (containerHeight - imageDisplayHeight) / 2;
                return Stack(children: [
                  Center(child: Image.memory(templateBytes, width: imageDisplayWidth, height: imageDisplayHeight, fit: BoxFit.fill)),
                  Positioned(
                    left: offsetX + (userViewX / 100) * imageDisplayWidth,
                    top: offsetY + (userViewY / 100) * imageDisplayHeight,
                    child: Text(pin, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: 2, color: textColor)),
                  ),
                ]);
              }),
            ),
          ),
        )
      else
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [const Icon(Icons.credit_card, size: 40), const SizedBox(height: 10), Text(pin, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2))]),
        ),
      const SizedBox(height: 20),
      _buildInfoCard(theme, Icons.wifi, 'الشبكة', networkName ?? 'غير معروف'),
      if (capacity != null && capacity.isNotEmpty) _buildInfoCard(theme, Icons.data_usage, 'السعة', capacity!),
      if (time != null && time.isNotEmpty) _buildInfoCard(theme, Icons.timer, 'المدة', time!),
      _buildInfoCard(theme, Icons.calendar_today, 'صالح حتى', _formatDateShort(DateTime.now().add(Duration(hours: int.tryParse(time?.replaceAll(RegExp(r'[^0-9]'), '') ?? '24') ?? 24)))),
      if (note != null && note.isNotEmpty) _buildInfoCard(theme, Icons.note, 'ملاحظة', note!),
      const SizedBox(height: 15),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _actionChip(Icons.copy, 'نسخ', () { _play('click'); Clipboard.setData(ClipboardData(text: pin)); _showToast('تم نسخ الكرت!'); }),
        const SizedBox(width: 10),
        if (!kIsWeb) ...[
          _actionChip(Icons.share, 'مشاركة', () => _shareCard()), const SizedBox(width: 10),
          _actionChip(Icons.save_alt, 'حفظ', () => _saveCardImage()), const SizedBox(width: 10),
        ],
        if (loginUrl != null && loginUrl.isNotEmpty) _actionChip(Icons.language, '🌐 تسجيل الدخول', () { launchUrl(Uri.parse(loginUrl), mode: LaunchMode.externalApplication); }),
      ]),
      const SizedBox(height: 15),
      TextButton(onPressed: () { Navigator.pop(context); }, child: const Text('إغلاق')),
    ]);
  }

  Widget _buildInfoCard(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.dividerColor)),
      child: Row(children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary), const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
        Expanded(child: Text(value, style: TextStyle(color: theme.textTheme.bodyMedium?.color), textAlign: TextAlign.end)),
      ]),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () { _play('click'); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.colorScheme.primary.withOpacity(0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: theme.colorScheme.primary), const SizedBox(width: 4), Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 12))]),
      ),
    );
  }

  Future<void> _shareCard() async {
    if (kIsWeb) { _showToast('غير متاحة على الويب'); return; }
    try {
      RenderRepaintBoundary boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/card.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], subject: 'بطاقة الكرت');
    } catch (e) { _showToast('فشلت المشاركة', error: true); }
  }

  Future<void> _saveCardImage() async {
    if (kIsWeb) { _showToast('غير متاحة على الويب'); return; }
    try {
      RenderRepaintBoundary boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      try {
        final result = await ImageGallerySaver.saveImage(byteData.buffer.asUint8List());
        if (result != null && result['isSuccess'] == true) { _showToast('✅ تم الحفظ في المعرض'); return; }
      } catch (_) {}
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      _showToast('تم حفظ الصورة في ${file.path}');
    } catch (e) { _showToast('فشل الحفظ', error: true); }
  }

  Future<Map<String, dynamic>?> _fetchCardDisplayData(String cardTitle, String agentPhone) async {
    try {
      final parts = cardTitle.split(' - ');
      final categoryName = parts.length > 1 ? parts.sublist(1).join(' - ') : cardTitle;
      final netSnap = await _db.collection('networks').where('agentPhone', isEqualTo: agentPhone).get();
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
              final codec = await ui.instantiateImageCodec(templateBytes);
              final frame = await codec.getNextFrame();
              imgWidth = frame.image.width; imgHeight = frame.image.height;
              frame.image.dispose(); codec.dispose();
            }
            return {
              'networkName': netData['name'] ?? '', 'loginUrl': netData['loginUrl'] ?? '',
              'time': cat['time'] ?? '', 'capacity': cat['capacity'] ?? '', 'note': cat['note'] ?? '',
              'templateBytes': templateBytes, 'userViewX': cat['userViewX'] ?? 50, 'userViewY': cat['userViewY'] ?? 50,
              'userViewFontSize': cat['userViewFontSize'] ?? 16, 'userViewColor': cat['userViewColor'] ?? Colors.black.value,
              'imageWidth': imgWidth, 'imageHeight': imgHeight,
            };
          }
        }
      }
      return null;
    } catch (e) { return null; }
  }

  String _formatDateShort(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<bool> _hasAnyAutoDiscountForUser(String agentPhone, bool isPos) async {
    final tier = await _fetchAutoDiscount(agentPhone, isPos);
    return tier != null;
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() { _searchQuery = value.trim().toLowerCase(); _isSearching = false; });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _qtyControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final theme = Theme.of(context);
    final bool isPos = sys.currentUserRole == 'pos';

    Map<String, dynamic> currentUserData = {};
    if (sys.currentUserPhone.isNotEmpty) {
      currentUserData = sys.usersList.firstWhere((u) => u['phone'] == sys.currentUserPhone, orElse: () => {});
    }

    final List<dynamic> posAgents = currentUserData['pos_agents'] ?? [];
    final Map<String, dynamic> agentRelations = currentUserData['agent_relations'] ?? {};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const CustomHeader(title: 'سوق الشبكات ونقاط البيع'),
        drawer: CustomUserDrawer(userName: sys.currentUserName, phoneNumber: sys.currentUserPhone),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [
            if (!isPos) _buildUserSummaryTile(sys, agentRelations, theme),
            if (isPos) _buildPosSummaryTile(sys, agentRelations, theme),
            Container(
              color: theme.colorScheme.primary.withOpacity(0.9),
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: isPos ? 'ابحث في شبكات مورديك...' : 'ابحث عن شبكة أو بقالة أو فئة...',
                  prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_isSearching) const LinearProgressIndicator(minHeight: 2),
            Container(
              color: theme.colorScheme.primary.withOpacity(0.9),
              child: const TabBar(
                labelColor: Colors.white, unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.orange, indicatorWeight: 4,
                tabs: [Tab(icon: Icon(Icons.wifi), text: 'الشبكات 📡'), Tab(icon: Icon(Icons.store), text: 'نقاط البيع 🏪')],
              ),
            ),
            Expanded(child: TabBarView(children: [
              StreamBuilder<QuerySnapshot>(
                stream: (isPos && posAgents.isNotEmpty)
                    ? _db.collection('networks').where('agentPhone', whereIn: posAgents.take(10).toList()).where('isActive', isEqualTo: true).snapshots()
                    : _db.collection('networks').where('isActive', isEqualTo: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (isPos && posAgents.isEmpty) return const Center(child: Text('لم يتم ربطك بأي وكيل.'));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد شبكات.'));
                  var networks = snapshot.data!.docs.where((doc) {
                    var net = doc.data() as Map<String, dynamic>;
                    bool match = (net['name']?.toLowerCase().contains(_searchQuery) ?? false) ||
                        (net['location']?.toLowerCase().contains(_searchQuery) ?? false);
                    if (!match && _searchQuery.isNotEmpty) {
                      final cats = List<Map<String, dynamic>>.from(net['categories'] ?? []);
                      match = cats.any((cat) => (cat['name'] ?? '').toLowerCase().contains(_searchQuery));
                    }
                    return match;
                  }).toList();
                  if (networks.isEmpty) return const Center(child: Text('لا نتائج مطابقة'));
                  return ListView.builder(
                    padding: const EdgeInsets.all(16), itemCount: networks.length,
                    itemBuilder: (context, index) => _buildNetworkCard(networks[index].data() as Map<String, dynamic>, isPos, agentRelations),
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _db.collection('points_of_sale').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد نقاط بيع.'));
                  var posList = snapshot.data!.docs.where((doc) {
                    var pos = doc.data() as Map<String, dynamic>;
                    return (pos['name']?.toLowerCase().contains(_searchQuery) ?? false) ||
                        (pos['location']?.toLowerCase().contains(_searchQuery) ?? false) ||
                        (pos['ownerName']?.toLowerCase().contains(_searchQuery) ?? false);
                  }).toList();
                  if (posList.isEmpty) return const Center(child: Text('لا نتائج مطابقة'));
                  return ListView.builder(
                    padding: const EdgeInsets.all(16), itemCount: posList.length,
                    itemBuilder: (context, index) => _buildPoSCard(posList[index].data() as Map<String, dynamic>, isPos),
                  );
                },
              ),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildUserSummaryTile(SystemProvider sys, Map<String, dynamic> agentRelations, ThemeData theme) {
    if (agentRelations.isEmpty) return const SizedBox();
    double displayedBalance = sys.currentUserBalance;
    if (agentRelations.isNotEmpty) displayedBalance = (agentRelations.values.first['balance'] ?? displayedBalance).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), color: theme.colorScheme.primary.withOpacity(0.05),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('💰 رصيدك لدى الوكيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Row(children: [
          Text('${displayedBalance.toStringAsFixed(0)} ريال', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14)),
          const SizedBox(width: 12),
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserWalletScreen())), child: Icon(Icons.account_balance_wallet, color: theme.colorScheme.primary, size: 22)),
        ]),
      ]),
    );
  }

  Widget _buildPosSummaryTile(SystemProvider sys, Map<String, dynamic> agentRelations, ThemeData theme) {
    if (agentRelations.isEmpty) return const SizedBox();
    final firstRel = agentRelations.values.first;
    final double balance = sys.currentUserBalance;
    final double credit = (firstRel['creditLimit'] ?? 0.0).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), color: theme.colorScheme.primary.withOpacity(0.05),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('🏪 رصيدك + الدين المسموح', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [
          Text('${balance + credit} ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
          const SizedBox(width: 12),
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserWalletScreen())), child: Icon(Icons.account_balance_wallet, color: theme.colorScheme.primary, size: 22)),
        ]),
      ]),
    );
  }

  Widget _buildNetworkCard(Map<String, dynamic> network, bool isPos, Map<String, dynamic> agentRelations) {
    List categories = List<Map<String, dynamic>>.from(network['categories'] ?? []);
    String agentPhone = network['agentPhone'] ?? '';
    String agentName = network['agentName'] ?? 'مجهول';
    String networkName = network['name'] ?? '';
    final coverageAreas = List<String>.from(network['coverageAreas'] ?? []);
    final theme = Theme.of(context);

    if (isPos) {
      Map<String, dynamic> rel = agentRelations[agentPhone] ?? {};
      List<dynamic> allowed = rel['allowedCategories'] ?? [];
      categories = categories.where((cat) => allowed.contains(cat['id'])).toList();
    }
    categories = categories.where((cat) => (cat['isActive'] ?? true) == true).toList();
    if (_searchQuery.isNotEmpty) categories = categories.where((cat) => (cat['name'] ?? '').toLowerCase().contains(_searchQuery)).toList();
    if (categories.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 3, color: theme.cardColor, margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: isPos ? Colors.purple : theme.colorScheme.primary, child: const Icon(Icons.router, color: Colors.white)),
        title: Text(networkName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📍 ${network['location'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (coverageAreas.isNotEmpty) Text('📶 ${coverageAreas.join('، ')}', style: const TextStyle(fontSize: 11, color: Colors.teal)),
        ]),
        children: [Container(padding: const EdgeInsets.all(16), color: theme.brightness == Brightness.dark ? Colors.black12 : Colors.grey.shade50, child: Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
            Text('الوكيل: $agentName', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserWalletScreen())), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: const Text('⚡ شحن المحفظة', style: TextStyle(fontSize: 12, color: Colors.deepPurple, fontWeight: FontWeight.bold)))),
          ])),
          ...categories.map((cat) {
            double price = (cat['price'] ?? 0).toDouble();
            int stock = cat['stock'] ?? 0;
            bool isAvailable = stock > 0;
            String catId = cat['id'] ?? '';
            String catName = cat['name'] ?? '';
            String key = '${network['agentPhone']}_$catId'; // مفتاح فريد
            if (!_qtyControllers.containsKey(key)) {
              _qtyControllers[key] = TextEditingController(text: '1');
              _qtyValues[key] = 1;
            }
            final qtyCtrl = _qtyControllers[key]!;
            int currentQty = _qtyValues[key] ?? 1;
            if (currentQty > stock) { currentQty = stock; qtyCtrl.text = '$stock'; _qtyValues[key] = stock; }

            Uint8List? thumbBytes;
            if (cat['templateBase64'] != null && cat['templateBase64'].isNotEmpty) {
              try { thumbBytes = base64Decode(cat['templateBase64']); } catch (_) {}
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.withOpacity(0.3))),
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (thumbBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(thumbBytes, width: 60, height: 60, fit: BoxFit.cover),
                    ),
                  if (thumbBytes != null) const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(catName, style: TextStyle(fontWeight: FontWeight.bold, color: isPos ? Colors.purple : theme.colorScheme.primary)),
                        const SizedBox(width: 6),
                        FutureBuilder<bool>(future: _hasAnyAutoDiscountForUser(agentPhone, isPos), builder: (_, snap) => snap.data == true ? const Icon(Icons.auto_awesome, size: 16, color: Colors.amber) : const SizedBox()),
                      ]),
                      Text('السعة: ${cat['capacity']} | الوقت: ${cat['time']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('المخزون: $stock كرت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAvailable ? Colors.green : Colors.red)),
                      const SizedBox(height: 8),
                      // صف الكمية والسعر
                      Row(children: [
                        const Text('الكمية: ', style: TextStyle(fontSize: 12)),
                        IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: currentQty > 1 ? () {
                          setState(() { int newQ = currentQty - 1; qtyCtrl.text = '$newQ'; _qtyValues[key] = newQ; });
                        } : null),
                        SizedBox(width: 40, child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), onChanged: (v) {
                          int? parsed = int.tryParse(v);
                          if (parsed != null) { setState(() => _qtyValues[key] = parsed.clamp(1, stock)); qtyCtrl.text = '${_qtyValues[key]}'; }
                        })),
                        IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: currentQty < stock ? () {
                          setState(() { int newQ = currentQty + 1; qtyCtrl.text = '$newQ'; _qtyValues[key] = newQ; });
                        } : null),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: isAvailable ? () => _showPurchaseBottomSheet(context, '$networkName - $catName', price, currentQty, agentPhone, agentName, isPos, networkName, catId) : null,
                          style: ElevatedButton.styleFrom(backgroundColor: isAvailable ? (isPos ? Colors.purple : theme.colorScheme.primary) : Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text(isAvailable ? 'شراء ($price × $currentQty)' : 'نفدت', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            );
          }).toList(),
        ]))],
      ),
    );
  }

  Widget _buildPoSCard(Map<String, dynamic> pos, bool isCurrentPos) {
    List stock = List<Map<String, dynamic>>.from(pos['stock'] ?? []);
    String ownerName = pos['ownerName'] ?? 'مجهول';
    String ownerPhone = pos['ownerPhone'] ?? '';
    final theme = Theme.of(context);
    if (_searchQuery.isNotEmpty) stock = stock.where((item) => (item['network'] ?? '').toLowerCase().contains(_searchQuery) || (item['category'] ?? '').toLowerCase().contains(_searchQuery)).toList();

    return Card(
      elevation: 3, color: theme.cardColor, margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.teal.withOpacity(0.3))),
      child: ExpansionTile(
        leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.storefront, color: Colors.white)),
        title: Text(pos['name'] ?? 'بقالة', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('📍 ${pos['location'] ?? ''}\n👤 $ownerName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [Container(padding: const EdgeInsets.all(16), color: theme.brightness == Brightness.dark ? Colors.teal.withOpacity(0.1) : Colors.teal.shade50, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الكروت المتاحة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 10),
          if (stock.isEmpty) const Text('لا توجد كروت.', style: TextStyle(color: Colors.red)),
          ...stock.map((item) {
            int available = item['available'] ?? 0;
            double price = (item['price'] ?? 0).toDouble();
            bool isAvailable = available > 0;
            String netName = item['network'] ?? '';
            String catName = item['category'] ?? '';
            String key = '${ownerPhone}_${netName}_$catName';
            if (!_qtyControllers.containsKey(key)) { _qtyControllers[key] = TextEditingController(text: '1'); _qtyValues[key] = 1; }
            final qtyCtrl = _qtyControllers[key]!;
            int currentQty = _qtyValues[key] ?? 1;
            if (currentQty > available) { currentQty = available; qtyCtrl.text = '$available'; _qtyValues[key] = available; }

            return Container(
              margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$netName - $catName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('المتاح: $available كرت', style: TextStyle(color: isAvailable ? Colors.green : Colors.red, fontSize: 11)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('الكمية: ', style: TextStyle(fontSize: 12)),
                    IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: currentQty > 1 ? () { setState(() { int n = currentQty - 1; qtyCtrl.text = '$n'; _qtyValues[key] = n; }); } : null),
                    SizedBox(width: 40, child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), onChanged: (v) { int? p = int.tryParse(v); if (p != null) { setState(() => _qtyValues[key] = p.clamp(1, available)); qtyCtrl.text = '${_qtyValues[key]}'; } })),
                    IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: currentQty < available ? () { setState(() { int n = currentQty + 1; qtyCtrl.text = '$n'; _qtyValues[key] = n; }); } : null),
                  ]),
                ])),
                ElevatedButton(
                  onPressed: isAvailable ? () async {
                    String catId = '';
                    try {
                      final netSnap = await _db.collection('networks').where('agentPhone', isEqualTo: ownerPhone).where('name', isEqualTo: netName).limit(1).get();
                      if (netSnap.docs.isNotEmpty) {
                        final cats = List<Map<String, dynamic>>.from(netSnap.docs.first.data()['categories'] ?? []);
                        final match = cats.firstWhere((c) => c['name'] == catName, orElse: () => {});
                        catId = match['id'] ?? '';
                      }
                    } catch (_) {}
                    _showPurchaseBottomSheet(context, '$netName - $catName', price, currentQty, ownerPhone, ownerName, isCurrentPos, netName, catId);
                  } : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: Text(isAvailable ? 'شراء ($price × $currentQty)' : 'نفدت', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ]),
            );
          }).toList(),
        ]))],
      ),
    );
  }
}
