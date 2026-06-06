import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isRedeeming = false;

  void _play(String type) =>
      context.read<UiProvider>().playSound(type);

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

  // ========== جلب نقاط الولاء ==========
  Future<Map<String, int>> _fetchLoyaltyPoints() async {
    final wallet = context.read<WalletProvider>();
    return await wallet.getLoyaltyPoints();
  }

  // ========== عملية الاستبدال الحقيقية ==========
  Future<void> _redeemReward({
    required String rewardDocId,
    required String rewardName,
    required int pointsRequired,
    required String agentPhone,
    required String categoryId,
    required String agentName,
  }) async {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    final phone = auth.activeUserPhone ?? '';
    if (phone.isEmpty) {
      _showToast('يجب تسجيل الدخول أولاً', error: true);
      return;
    }

    // تأكيد
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الاستبدال'),
          content: Text('سيتم خصم $pointsRequired نقطة من رصيدك واستبدالها بـ $rewardName.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، استبدل'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    setState(() => _isRedeeming = true);
    _play('click');

    try {
      // 1. التحقق من الرصيد
      final pointsMap = await wallet.getLoyaltyPoints();
      final int currentPoints = pointsMap[agentPhone] ?? 0;
      if (currentPoints < pointsRequired) {
        _play('error');
        _showToast('نقاطك غير كافية', error: true);
        return;
      }

      // 2. حجز كرت من المخزون
      final cardsSnap = await _db
          .collection('cards')
          .where('agentPhone', isEqualTo: agentPhone)
          .where('categoryId', isEqualTo: categoryId)
          .where('status', isEqualTo: 'متاح')
          .limit(1)
          .get();

      if (cardsSnap.docs.isEmpty) {
        _play('error');
        _showToast('لا توجد كروت متاحة لهذه المكافأة حالياً', error: true);
        return;
      }

      final cardDoc = cardsSnap.docs.first;
      final cardData = cardDoc.data() as Map<String, dynamic>;
      final String pin = cardData['pin'] ?? 'غير متوفر';

      // 3. تنفيذ العملية (batch)
      final batch = _db.batch();
      final userRef = _db.collection('users').doc(phone);

      // خصم النقاط
      batch.update(userRef, {
        'loyaltyPoints.$agentPhone': FieldValue.increment(-pointsRequired),
        'totalLoyaltyPoints': FieldValue.increment(-pointsRequired),
      });

      // تحديث حالة الكرت
      batch.update(cardDoc.reference, {
        'status': 'مباع',
        'buyerPhone': phone,
        'soldAt': FieldValue.serverTimestamp(),
        'soldPrice': 0,
        'discountAmount': 0,
        'redeemedWithPoints': true,
      });

      // إضافة الكرت للمشتريات
      batch.update(userRef, {
        'purchasedCards': FieldValue.arrayUnion([
          {
            'title': '$agentName - $rewardName',
            'pin': pin,
            'price': 0,
            'agentPhone': agentPhone,
            'date': DateTime.now().toIso8601String(),
            'redeemed': true,
            'pointsPaid': pointsRequired,
          }
        ])
      });

      // تسجيل معاملة
      batch.set(_db.collection('transactions').doc(), {
        'fromPhone': 'SYSTEM',
        'toPhone': phone,
        'agentPhone': agentPhone,
        'agentName': agentName,
        'targetName': auth.currentUserName,
        'amount': 0,
        'type': 'loyalty_redeem',
        'title': 'استبدال نقاط - $rewardName',
        'pointsRedeemed': pointsRequired,
        'pin': pin,
        'reference': 'LR-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _play('success');
      _showSuccessDialog(rewardName, pin, pointsRequired, agentName);

      // تحديث الشاشة
      setState(() {});
    } catch (e) {
      _play('error');
      _showToast('فشل الاستبدال: $e', error: true);
    } finally {
      setState(() => _isRedeeming = false);
    }
  }

  // ========== نافذة نجاح الاستبدال ==========
  void _showSuccessDialog(String rewardName, String pin, int points, String agentName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard, color: Colors.green, size: 60),
              const SizedBox(height: 15),
              const Text('مبروك! تم الاستبدال بنجاح 🎉',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
              const SizedBox(height: 10),
              Text('تم خصم $points نقطة واستبدالها بـ $rewardName من $agentName',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Text('رقم الكرت (PIN)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(pin, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: pin));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ الكرت! ✅'), backgroundColor: Colors.green),
                        );
                      },
                      icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                      label: const Text('نسخ الكرت', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'المكافآت والولاء'),
      drawer: CustomUserDrawer(
        userName: auth.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ========== بطاقة النقاط (تختفي مع التمرير) ==========
              SliverToBoxAdapter(
                child: FutureBuilder<Map<String, int>>(
                  future: _fetchLoyaltyPoints(),
                  builder: (context, snapshot) {
                    final pointsMap = snapshot.data ?? {};
                    final int totalPoints = pointsMap.values.fold(0, (a, b) => a + b);

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber.shade700, Colors.orange.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.stars, size: 60, color: Colors.white),
                          const SizedBox(height: 10),
                          const Text('نقاطك الحالية', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          Text(
                            '${snapshot.connectionState == ConnectionState.waiting ? '...' : totalPoints} نقطة',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          // تقسيم النقاط حسب الوكيل
                          if (pointsMap.isNotEmpty)
                            ...pointsMap.entries.map((e) {
                              final agent = wallet.agentsList.firstWhere(
                                (a) => a['phone'] == e.key,
                                orElse: () => {'name': e.key},
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${agent['name'] ?? e.key}: ${e.value} نقطة',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ========== عنوان الاستبدال ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'استبدل نقاطك بكروت مجانية 🎁',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                ),
              ),

              // ========== قائمة المكافآت ==========
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('loyalty_rewards')
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    final rewards = snapshot.data?.docs ?? [];
                    if (rewards.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('لا توجد مكافآت متاحة حالياً', style: TextStyle(color: Colors.grey))),
                      );
                    }

                    return FutureBuilder<Map<String, int>>(
                      future: _fetchLoyaltyPoints(),
                      builder: (context, pointsSnapshot) {
                        final pointsMap = pointsSnapshot.data ?? {};

                        return Column(
                          children: rewards.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final String agentPhone = data['agentPhone'] ?? '';
                            final int requiredPoints = data['points'] ?? 0;
                            final int userPoints = pointsMap[agentPhone] ?? 0;
                            final bool canRedeem = userPoints >= requiredPoints;
                            final String agentName = (wallet.agentsList.firstWhere(
                              (a) => a['phone'] == agentPhone,
                              orElse: () => {'name': agentPhone},
                            ))['name'] ?? agentPhone;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(color: canRedeem ? Colors.green.withOpacity(0.5) : Colors.transparent),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Color(data['color'] ?? Colors.teal.value).withOpacity(0.1),
                                  child: Icon(Icons.card_giftcard, color: Color(data['color'] ?? Colors.teal.value)),
                                ),
                                title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'يتطلب $requiredPoints نقطة',
                                      style: TextStyle(
                                        color: canRedeem ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'لديك $userPoints نقطة لدى $agentName',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: _isRedeeming
                                      ? null
                                      : () => _redeemReward(
                                            rewardDocId: doc.id,
                                            rewardName: data['name'] ?? '',
                                            pointsRequired: requiredPoints,
                                            agentPhone: agentPhone,
                                            categoryId: data['categoryId'] ?? '',
                                            agentName: agentName,
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canRedeem ? Colors.green : Colors.grey.shade400,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('استبدال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ),

              // ========== مساحة سفلية ==========
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }
}
