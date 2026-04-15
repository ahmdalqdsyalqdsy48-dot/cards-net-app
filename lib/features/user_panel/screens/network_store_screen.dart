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
  // 2. نافذة إتمام الشراء المخصصة (تعالج الزبون والبقالة) 💳
  // ==========================================
  void _showPurchaseBottomSheet(BuildContext context, String title, double price, String agentPhone, String agentName, bool isPos) {
    _play('click');
    bool isPurchased = false;
    String generatedPin = '1234-5678-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}'; 
    
    final systemProvider = Provider.of<SystemProvider>(context, listen: false);
    
    // 👈 السحر المالي: إذا كان بقالة يقرأ الرصيد العام، وإذا زبون يقرأ محفظة الوكيل المحددة!
    double availableBalance = isPos ? systemProvider.currentUserBalance : systemProvider.getWalletBalance(agentPhone);
    bool canAfford = availableBalance >= price;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                      
                      // 👈 عرض الرصيد الصحيح بناءً على الهوية
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isPos ? 'رصيدك العام كبقالة:' : 'رصيدك المتاح لدى:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(isPos ? 'نقطة بيع معتمدة' : 'الوكيل $agentName', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                            Text('${availableBalance.toStringAsFixed(0)} ريال', style: TextStyle(fontWeight: FontWeight.bold, color: canAfford ? Colors.blue : Colors.red, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('المبلغ المطلوب خصمه:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('$price ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
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
                            onPressed: () {
                              _play('click');
                              bool success = systemProvider.userBuyCard(price, title, agentPhone);
                              
                              if (success) {
                                _play('success');
                                setModalState(() { isPurchased = true; }); 
                              } else {
                                _play('error');
                                Navigator.pop(context); 
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشلت العملية، تأكد من الرصيد أو المخزون!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                              }
                            },
                            child: const Text('تأكيد وشراء الآن', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
                      // --- شاشة نجاح الشراء وعرض الكرت ---
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
                            Text(generatedPin, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              onPressed: () {
                                _play('click');
                                Clipboard.setData(ClipboardData(text: generatedPin));
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
    
    // 👈 قراءة هوية الزائر (هل هو بقالة أم زبون عادي)
    final bool isPos = sys.currentUserRole == 'pos';
    
    // 👈 جلب بيانات المستخدم الحالي لفهم صلاحياته
    Map<String, dynamic> currentUserData = {};
    if (sys.currentUserPhone.isNotEmpty) {
      currentUserData = sys.usersList.firstWhere((u) => u['phone'] == sys.currentUserPhone, orElse: () => {});
    }
    
    final List<dynamic> allowedCats = currentUserData['allowedCategories'] ?? [];
    final String parentAgentPhone = currentUserData['parentAgent'] ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const CustomHeader(title: 'سوق الشبكات ونقاط البيع'),
        drawer: CustomUserDrawer(userName: sys.currentUserName, phoneNumber: sys.currentUserPhone),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // شريط البحث المطور
              Container(
                color: isPos ? Colors.purple.shade800 : Colors.blue.shade800,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (value) => setState(() { _searchQuery = value.trim().toLowerCase(); }), 
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: isPos ? 'ابحث في شبكتك المعتمدة...' : 'ابحث عن شبكة أو بقالة أو منطقة...',
                    prefixIcon: Icon(Icons.search, color: isPos ? Colors.purple : Colors.blue),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                ),
              ),

              Container(
                color: isPos ? Colors.purple.shade800 : Colors.blue.shade800,
                child: const TabBar(
                  labelColor: Colors.white, unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.orange, indicatorWeight: 4,
                  tabs: [
                    Tab(icon: Icon(Icons.wifi), text: 'الشبكات المتاحة 📡'),
                    Tab(icon: Icon(Icons.store), text: 'نقاط البيع 🏪'),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    // ==========================================
                    // التبويب الأول: الشبكات (مع فلترة البقالة)
                    // ==========================================
                    StreamBuilder<QuerySnapshot>(
                      // 👈 إذا كان بقالة، نجلب شبكات وكيله فقط. إذا زبون عادي، نجلب الكل.
                      stream: isPos 
                          ? _db.collection('networks').where('agentPhone', isEqualTo: parentAgentPhone).snapshots()
                          : _db.collection('networks').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
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
                            return _buildNetworkCard(net, isPos, allowedCats);
                          },
                        );
                      },
                    ),
                    
                    // ==========================================
                    // التبويب الثاني: نقاط البيع الأخرى
                    // ==========================================
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
  // تصميم بطاقة "الشبكة" المفلترة للبقالة
  // ==========================================
  Widget _buildNetworkCard(Map<String, dynamic> network, bool isPos, List allowedCats) {
    List categories = network['categories'] ?? [];
    
    // 👈 فلترة الفئات إذا كان الزائر بقالة (بحسب الصلاحيات التي منحها الوكيل)
    if (isPos) {
      categories = categories.where((cat) => allowedCats.contains(cat['id'])).toList();
    }
    
    // إذا لم يتبقَ أي فئات مسموحة، لا نظهر هذه الشبكة إطلاقاً
    if (categories.isEmpty) return const SizedBox.shrink();

    String agentPhone = network['agentPhone'] ?? '';
    String agentName = network['agentName'] ?? 'مجهول';

    return Card(
      elevation: 3,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: isPos ? Colors.purple : Colors.blue, child: const Icon(Icons.router, color: Colors.white)),
        title: Text(network['name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('📍 ${network['location'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.grey.shade50,
            child: Column(
              children: categories.map((cat) {
                double price = (cat['price'] ?? 0).toDouble();
                // 👈 قراءة المخزون الحقيقي من المايكروتيك
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
                          // 👈 عرض المخزون الحقيقي هنا
                          Text('المخزون: $stock كرت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAvailable ? Colors.green : Colors.red)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: isAvailable ? () => _showPurchaseBottomSheet(context, '${network['name']} - ${cat['name']}', price, agentPhone, agentName, isPos) : null,
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
  // تصميم بطاقة "نقطة البيع" للزبون العادي
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
                          onPressed: isAvailable ? () => _showPurchaseBottomSheet(context, 'من ${pos['name']} (${item['network']})', price, ownerPhone, ownerName, isCurrentPos) : null,
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
