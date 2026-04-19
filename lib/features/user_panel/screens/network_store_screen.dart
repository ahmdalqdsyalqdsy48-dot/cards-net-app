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

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // 1. نافذة طلب الشحن المباشر (لو الرصيد لا يكفي) 💸
  // ==========================================
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('طلب شحن من $agentName', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('يرجى تحويل المبلغ المطلوب إلى الوكيل أولاً، ثم اطلب الشحن هنا ليتم إضافته لمحفظتك فور موافقته.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المطلوب شحنه',
                    suffixText: 'ريال',
                    prefixIcon: const Icon(Icons.monetization_on, color: Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              if (!isSubmitting)
                TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: isSubmitting ? null : () async {
                  String amountText = amountController.text.trim();
                  if (amountText.isNotEmpty && double.tryParse(amountText) != null) {
                    setStateDialog(() => isSubmitting = true);
                    double amount = double.parse(amountText);
                    try {
                      _play('click');
                      await Provider.of<SystemProvider>(context, listen: false).requestWalletRecharge(agentPhone, amount);
                      _play('success');
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الشحن بنجاح ⏳', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setStateDialog(() => isSubmitting = false);
                      _play('error');
                    }
                  } else {
                    _play('error');
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال مبلغ صحيح!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                  }
                },
                child: isSubmitting 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال الطلب', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. محرك التحقق من الساعات السعيدة (Happy Hour) ⏳
  // ==========================================
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
        return nowDouble >= startDouble || nowDouble <= endDouble; // يعبر منتصف الليل
      }
    } catch(e) { return false; }
  }

  // ==========================================
  // 3. نافذة إتمام الشراء الحقيقية (المطورة بدمج الكوبونات) 💳🎟️
  // ==========================================
  void _showPurchaseBottomSheet(BuildContext context, String title, double originalPrice, String agentPhone, String agentName, bool isPos, String networkName) {
    _play('click');
    bool isPurchased = false;
    bool isSubmittingPurchase = false; 
    String actualPinFetched = ''; 
    
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    
    double walletBalance = systemProvider.getWalletBalance(agentPhone);
    double creditLimit = 0.0;
    
    if (isPos) {
      Map<String, dynamic> currentUserData = systemProvider.usersList.firstWhere((u) => u['phone'] == systemProvider.currentUserPhone, orElse: () => {});
      Map<String, dynamic> relations = currentUserData['agent_relations'] ?? {};
      Map<String, dynamic> myRel = relations[agentPhone] ?? {};
      creditLimit = (myRel['creditLimit'] ?? 0.0).toDouble();
    }
    
    double totalPurchasingPower = walletBalance + creditLimit;
    
    // متغيرات نظام الكوبونات
    double finalPrice = originalPrice;
    double discountAmount = 0.0;
    String? appliedCouponDocId;
    String couponMessage = '';
    Color couponMessageColor = Colors.black;
    bool isApplyingCoupon = false;
    TextEditingController couponController = TextEditingController();
    
    bool canAfford = totalPurchasingPower >= finalPrice;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            // 🎟️ دالة تطبيق الكوبون الداخلية
            Future<void> _applyCoupon() async {
              String code = couponController.text.trim().toUpperCase();
              if (code.isEmpty) return;

              _play('click');
              setModalState(() { isApplyingCoupon = true; couponMessage = ''; });

              try {
                var query = await _db.collection('coupons')
                    .where('agentPhone', isEqualTo: agentPhone)
                    .where('code', isEqualTo: code)
                    .get();

                if (query.docs.isEmpty) {
                  setModalState(() { couponMessage = 'كود الخصم غير صحيح أو لا يتبع لهذا الوكيل'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                var doc = query.docs.first;
                var data = doc.data();

                // التحققات الصارمة
                if (data['isActive'] != true) {
                  setModalState(() { couponMessage = 'هذا الكود متوقف حالياً'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
                if (expiry.isBefore(DateTime.now())) {
                  setModalState(() { couponMessage = 'لقد انتهت صلاحية هذا العرض'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                int currentUsage = data['currentUsage'] ?? 0;
                int maxUsage = data['maxUsage'] ?? 1;
                if (currentUsage >= maxUsage) {
                  setModalState(() { couponMessage = 'تم استنفاد الحد الأقصى لاستخدام الكوبون'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                String targetPhone = data['targetPhone'] ?? '';
                if (targetPhone.isNotEmpty && targetPhone != systemProvider.currentUserPhone) {
                  setModalState(() { couponMessage = 'عذراً، هذا الكود مخصص لرقم آخر'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                String targetNetwork = data['targetNetwork'] ?? '';
                if (targetNetwork.isNotEmpty && targetNetwork != 'الكل' && targetNetwork != networkName) {
                  setModalState(() { couponMessage = 'هذا الكود مخصص لشبكة ($targetNetwork) فقط'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                if (data['isHappyHour'] == true) {
                  String sTime = data['startTime'] ?? '00:00';
                  String eTime = data['endTime'] ?? '23:59';
                  if (!_isWithinHappyHour(sTime, eTime)) {
                    setModalState(() { couponMessage = 'هذا الكود يعمل فقط من $sTime إلى $eTime'; couponMessageColor = Colors.orange; isApplyingCoupon = false; });
                    _play('error'); return;
                  }
                }

                // حساب قيمة الخصم
                double dValue = (data['discountValue'] ?? 0).toDouble();
                String dType = data['discountType'] ?? 'fixed';

                double calculatedDiscount = 0.0;
                if (dType == 'percent') {
                  calculatedDiscount = originalPrice * (dValue / 100);
                } else if (dType == 'fixed') {
                  calculatedDiscount = dValue;
                } else if (dType == 'combo' || dType == 'referral') {
                  setModalState(() { couponMessage = 'عروض الباقات والدعوات لا تخصم من القيمة النقدية للفاتورة.'; couponMessageColor = Colors.orange; isApplyingCoupon = false; });
                  return;
                }

                if (calculatedDiscount >= originalPrice) calculatedDiscount = originalPrice;

                _play('success');
                setModalState(() {
                  discountAmount = calculatedDiscount;
                  finalPrice = originalPrice - discountAmount;
                  canAfford = totalPurchasingPower >= finalPrice; // إعادة حساب القدرة الشرائية
                  appliedCouponDocId = doc.id;
                  couponMessage = 'تم تطبيق الخصم بنجاح! 🎉';
                  couponMessageColor = Colors.green;
                  isApplyingCoupon = false;
                });

              } catch (e) {
                setModalState(() { couponMessage = 'حدث خطأ في الاتصال'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                _play('error');
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 20, 
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20 // التجاوب مع الكيبورد
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),
                    
                    if (!isPurchased) ...[
                      // --- شاشة تأكيد الشراء ---
                      const Icon(Icons.shopping_cart_checkout, size: 60, color: Colors.orange),
                      const SizedBox(height: 15),
                      const Text('تأكيد عملية الشراء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text('هل أنت متأكد من شراء كرت ($title)؟', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),
                      
                      // حقل إدخال كود الخصم 🎟️
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: appliedCouponDocId != null ? Colors.green : Colors.grey.shade300)
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: couponController,
                                enabled: appliedCouponDocId == null && !isApplyingCoupon,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: 'هل لديك كود خصم؟ (انسخه من الرئيسية)',
                                  hintStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
                                  border: InputBorder.none,
                                  icon: Icon(Icons.local_offer, color: appliedCouponDocId != null ? Colors.green : Colors.grey),
                                ),
                              ),
                            ),
                            if (appliedCouponDocId == null)
                              isApplyingCoupon
                                  ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                                  : TextButton(
                                      onPressed: _applyCoupon,
                                      child: const Text('تطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
                                    )
                            else
                              const Icon(Icons.check_circle, color: Colors.green),
                          ],
                        ),
                      ),
                      if (couponMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(couponMessage, style: TextStyle(color: couponMessageColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 15),

                      // رصيد المشتري
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('رصيدك المتاح لدى:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('الوكيل $agentName', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                if (isPos && creditLimit > 0)
                                  Text('+ دين مسموح: $creditLimit', style: const TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text('${totalPurchasingPower.toStringAsFixed(0)} ريال', style: TextStyle(fontWeight: FontWeight.bold, color: canAfford ? Colors.blue : Colors.red, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // المبلغ المطلوب خصمه (مع عرض التخفيض إن وجد)
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('المبلغ المطلوب خصمه:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (discountAmount > 0)
                                  Text('$originalPrice ريال', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 13)),
                                Text('$finalPrice ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
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
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: isSubmittingPurchase ? null : () async {
                              _play('click');
                              setModalState(() => isSubmittingPurchase = true); 
                              
                              try {
                                // الاتصال بالسيرفر لإجراء الشراء الحقيقي (بناءً على السعر النهائي المخفض)
                                String realPin = await systemProvider.executeRealPurchase(finalPrice, title, agentPhone);
                                
                                // 🎟️ تسجيل استخدام الكوبون في الفايربيز
                                if (appliedCouponDocId != null) {
                                  await _db.collection('coupons').doc(appliedCouponDocId).update({
                                    'currentUsage': FieldValue.increment(1)
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
                                setModalState(() => isSubmittingPurchase = false);
                                Navigator.pop(context); 
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString(), textDirection: TextDirection.rtl), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
                              }
                            },
                            child: isSubmittingPurchase 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('تأكيد وشراء الآن', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: () {
                               Navigator.pop(context);
                               _showRechargeDialog(agentPhone, agentName);
                            },
                            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                            label: const Text('رصيدك لا يكفي - اطلب شحن الآن', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ] else ...[
                      // --- شاشة نجاح الشراء وعرض الكرت الفعلي ---
                      const Icon(Icons.check_circle, size: 60, color: Colors.green),
                      const SizedBox(height: 15),
                      const Text('تم الشراء بنجاح! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.withOpacity(0.5))),
                        child: Column(
                          children: [
                            const Text('رقم الكرت (PIN)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Text(actualPinFetched, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              onPressed: () {
                                _play('click');
                                Clipboard.setData(ClipboardData(text: actualPinFetched));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكرت بنجاح! ✅'), backgroundColor: Colors.green));
                              },
                              icon: const Icon(Icons.copy, color: Colors.white),
                              label: const Text('نسخ الكرت', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () { _play('click'); Navigator.pop(context); },
                        child: const Text('إغلاق', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      )
                    ]
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    
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
              Container(
                color: isPos ? Colors.purple.shade800 : Colors.blue.shade800,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (value) => setState(() { _searchQuery = value.trim().toLowerCase(); }), 
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: isPos ? 'ابحث في شبكات مورديك...' : 'ابحث عن شبكة أو بقالة أو منطقة...',
                    prefixIcon: Icon(Icons.search, color: isPos ? Colors.purple : Colors.blue),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                ),
              ),

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
                    // --- التبويب الأول: الشبكات ---
                    StreamBuilder<QuerySnapshot>(
                      stream: (isPos && posAgents.isNotEmpty)
                          ? _db.collection('networks').where('agentPhone', whereIn: posAgents.take(10).toList()).snapshots()
                          : _db.collection('networks').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        
                        if (isPos && posAgents.isEmpty) return const Center(child: Text('لم يتم ربطك بأي وكيل حتى الآن.', style: TextStyle(color: Colors.grey)));

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد شبكات معروضة حالياً.', style: TextStyle(color: Colors.grey)));

                        var networks = snapshot.data!.docs.where((doc) {
                          var net = doc.data() as Map<String, dynamic>;
                          return (net['name']?.toString().toLowerCase().contains(_searchQuery) ?? false) || 
                                 (net['location']?.toString().toLowerCase().contains(_searchQuery) ?? false);
                        }).toList();

                        if (networks.isEmpty) return const Center(child: Text('لا توجد شبكات مطابقة للبحث'));

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: networks.length,
                          itemBuilder: (context, index) {
                            var net = networks[index].data() as Map<String, dynamic>;
                            return _buildNetworkCard(net, isPos, agentRelations);
                          },
                        );
                      },
                    ),
                    
                    // --- التبويب الثاني: نقاط البيع ---
                    StreamBuilder<QuerySnapshot>(
                      stream: _db.collection('points_of_sale').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد نقاط بيع معروضة حالياً.', style: TextStyle(color: Colors.grey)));

                        var posList = snapshot.data!.docs.where((doc) {
                          var pos = doc.data() as Map<String, dynamic>;
                          return (pos['name']?.toString().toLowerCase().contains(_searchQuery) ?? false) || 
                                 (pos['location']?.toString().toLowerCase().contains(_searchQuery) ?? false);
                        }).toList();

                        if (posList.isEmpty) return const Center(child: Text('لا توجد نقاط بيع مطابقة للبحث'));

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: posList.length,
                          itemBuilder: (context, index) {
                            var pos = posList[index].data() as Map<String, dynamic>;
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

  // ==========================================
  // تصميم بطاقة "الشبكة" 
  // ==========================================
  Widget _buildNetworkCard(Map<String, dynamic> network, bool isPos, Map<String, dynamic> agentRelations) {
    List categories = network['categories'] ?? [];
    String agentPhone = network['agentPhone'] ?? '';
    String agentName = network['agentName'] ?? 'مجهول';
    String networkName = network['name'] ?? ''; // لاستخدامها في التحقق من الكوبون

    if (isPos) {
      Map<String, dynamic> myRelationWithThisAgent = agentRelations[agentPhone] ?? {};
      List<dynamic> allowedCatsForThisAgent = myRelationWithThisAgent['allowedCategories'] ?? [];
      categories = categories.where((cat) => allowedCatsForThisAgent.contains(cat['id'])).toList();
    }

    if (categories.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 3,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: isPos ? Colors.purple : Colors.blue, child: const Icon(Icons.router, color: Colors.white)),
        title: Text(networkName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('📍 ${network['location'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.grey.shade50,
            child: Column(
              children: categories.map((cat) {
                double price = (cat['price'] ?? 0).toDouble();
                int stock = cat['stock'] ?? cat['available'] ?? 0;
                bool isAvailable = stock > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.withOpacity(0.3))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: isPos ? Colors.purple : Colors.orange)),
                          Text('السعة: ${cat['capacity']} | الوقت: ${cat['time']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          Text('المخزون: $stock كرت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAvailable ? Colors.green : Colors.red)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: isAvailable ? () => _showPurchaseBottomSheet(context, '${network['name']} - ${cat['name']}', price, agentPhone, agentName, isPos, networkName) : null,
                        style: ElevatedButton.styleFrom(backgroundColor: isAvailable ? (isPos ? Colors.purple : Colors.blue.shade800) : Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: Text(isAvailable ? 'شراء ($price)' : 'نفدت الكمية', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // تصميم بطاقة "نقطة البيع"
  // ==========================================
  Widget _buildPoSCard(Map<String, dynamic> pos, bool isCurrentPos) {
    List stock = pos['stock'] ?? [];
    String ownerName = pos['ownerName'] ?? 'مجهول';
    String ownerPhone = pos['ownerPhone'] ?? '';

    return Card(
      elevation: 3,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.teal.withOpacity(0.3))),
      child: ExpansionTile(
        leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.storefront, color: Colors.white)),
        title: Text(pos['name'] ?? 'بقالة بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('📍 ${pos['location'] ?? ''}\n👤 $ownerName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark ? Colors.teal.withOpacity(0.1) : Colors.teal.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الكروت المتاحة في هذه البقالة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                const SizedBox(height: 10),
                if (stock.isEmpty) const Text('لا يوجد كروت معروضة للبيع حالياً.', style: TextStyle(fontSize: 12, color: Colors.red)),
                ...stock.map((item) {
                  int available = item['available'] ?? 0;
                  double price = (item['price'] ?? 0).toDouble();
                  bool isAvailable = available > 0;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['network']} - ${item['category']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('المتاح: $available كرت', style: TextStyle(fontSize: 11, color: isAvailable ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isAvailable ? () => _showPurchaseBottomSheet(context, 'من ${pos['name']} (${item['network']})', price, ownerPhone, ownerName, isCurrentPos, item['network']) : null,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text(isAvailable ? 'شراء ($price)' : 'نفدت الكمية', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
}
