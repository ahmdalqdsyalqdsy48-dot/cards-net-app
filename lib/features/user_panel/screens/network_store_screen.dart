import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // نحتاجها لميزة نسخ النص (رقم الكرت)
import '../../../core/widgets/custom_header.dart'; // الترويسة الموحدة
import '../widgets/custom_user_drawer.dart'; // القائمة الجانبية

class NetworkStoreScreen extends StatefulWidget {
  const NetworkStoreScreen({super.key});

  @override
  State<NetworkStoreScreen> createState() => _NetworkStoreScreenState();
}

class _NetworkStoreScreenState extends State<NetworkStoreScreen> {
  // متغير لحفظ نص البحث
  String _searchQuery = '';

  // 1. قاعدة بيانات وهمية للشبكات المتاحة
  final List<Map<String, dynamic>> _networks = [
    {
      'name': 'شبكة الصقر للواي فاي',
      'location': 'صنعاء - شارع تعز',
      'agent': 'أحمد محمد',
      'categories': [
        {'name': 'فئة أبو 500', 'capacity': '500 ميجا', 'time': '12 ساعة', 'price': 500.0},
        {'name': 'فئة أبو 1000', 'capacity': '1 جيجا', 'time': '24 ساعة', 'price': 1000.0},
      ]
    },
    {
      'name': 'شبكة النور السريعة',
      'location': 'إب - شارع العدين',
      'agent': 'عبدالله صالح',
      'categories': [
        {'name': 'فئة أبو 200', 'capacity': '150 ميجا', 'time': 'ساعتين', 'price': 200.0},
        {'name': 'فئة أبو 1000', 'capacity': 'مفتوح', 'time': 'يوم كامل', 'price': 1000.0},
      ]
    },
  ];

  // 2. قاعدة بيانات وهمية لنقاط البيع (البقالات)
  final List<Map<String, dynamic>> _pointsOfSale = [
    {
      'name': 'بقالة التوفيق',
      'location': 'جوار جولة المصباحي',
      'owner': 'توفيق محمد',
      'stock': [
        {'network': 'شبكة الصقر', 'category': 'أبو 500', 'price': 500.0, 'available': 15},
        {'network': 'شبكة النور', 'category': 'أبو 1000', 'price': 1000.0, 'available': 5},
      ]
    },
  ];

  // ==========================================
  // دالة الشراء (تظهر نافذة منبثقة من الأسفل)
  // ==========================================
  void _showPurchaseBottomSheet(BuildContext context, String title, double price) {
    // متغير لتتبع حالة الشراء (هل تمت أم لا يزال في صفحة التأكيد؟)
    bool isPurchased = false;
    String generatedPin = '1234-5678-9101'; // كرت وهمي

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder( // نستخدم StatefulBuilder لتحديث النافذة من الداخل
          builder: (BuildContext context, StateSetter setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // تصميم شريط السحب العلوي للنافذة
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
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('المبلغ المطلوب خصمه:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('$price ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () {
                            // تغيير الحالة إلى "تم الشراء" لتحديث النافذة
                            setModalState(() { isPurchased = true; });
                          },
                          child: const Text('تأكيد وشراء الآن', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade300)),
                        child: Column(
                          children: [
                            const Text('رقم الكرت (PIN)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Text(generatedPin, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              onPressed: () {
                                // نسخ النص للحافظة
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
                        onPressed: () => Navigator.pop(context), // إغلاق النافذة
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
    // تصفية الشبكات حسب نص البحث
    final filteredNetworks = _networks.where((net) => net['name'].toString().contains(_searchQuery)).toList();
    // تصفية نقاط البيع حسب نص البحث
    final filteredPoS = _pointsOfSale.where((pos) => pos['name'].toString().contains(_searchQuery)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const CustomHeader(title: 'سوق الشبكات ونقاط البيع'),
        drawer: const CustomUserDrawer(
          userName: 'محمد أحمد', phoneNumber: '777123456', walletBalance: 2500.0,
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // ==========================================
              // 1. شريط البحث الذكي
              // ==========================================
              Container(
                color: Colors.blue.shade800,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (value) {
                    setState(() { _searchQuery = value; }); // تحديث البحث
                  },
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن شبكة أو بقالة...',
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                ),
              ),

              // ==========================================
              // 2. التبويبات (Tabs)
              // ==========================================
              Container(
                color: Colors.blue.shade800,
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

              // ==========================================
              // 3. محتوى التبويبات
              // ==========================================
              Expanded(
                child: TabBarView(
                  children: [
                    // تبويب الشبكات المتاحة
                    filteredNetworks.isEmpty 
                      ? const Center(child: Text('لا توجد شبكات مطابقة للبحث'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredNetworks.length,
                          itemBuilder: (context, index) {
                            final net = filteredNetworks[index];
                            return _buildNetworkCard(net);
                          },
                        ),
                    
                    // تبويب نقاط البيع
                    filteredPoS.isEmpty 
                      ? const Center(child: Text('لا توجد نقاط بيع مطابقة للبحث'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredPoS.length,
                          itemBuilder: (context, index) {
                            final pos = filteredPoS[index];
                            return _buildPoSCard(pos);
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
  // تصميم بطاقة "الشبكة المتاحة" (قابلة للتوسعة)
  // ==========================================
  Widget _buildNetworkCard(Map<String, dynamic> network) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.router, color: Colors.white)),
        title: Text(network['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('📍 ${network['location']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: (network['categories'] as List).map((cat) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                          Text('السعة: ${cat['capacity']} | الوقت: ${cat['time']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => _showPurchaseBottomSheet(context, '${network['name']} - ${cat['name']}', cat['price']),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: Text('شراء (${cat['price']})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  // تصميم بطاقة "نقطة البيع" (قابلة للتوسعة)
  // ==========================================
  Widget _buildPoSCard(Map<String, dynamic> pos) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.teal.shade200)),
      child: ExpansionTile(
        leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.storefront, color: Colors.white)),
        title: Text(pos['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('📍 ${pos['location']}\n👤 ${pos['owner']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الكروت المتاحة في هذه البقالة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                const SizedBox(height: 10),
                ...(pos['stock'] as List).map((item) {
                  bool isAvailable = item['available'] > 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['network']} - ${item['category']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('المخزون: ${item['available']} كرت', style: TextStyle(fontSize: 11, color: isAvailable ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isAvailable ? () => _showPurchaseBottomSheet(context, 'من ${pos['name']} (${item['network']})', item['price']) : null,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text(isAvailable ? 'شراء (${item['price']})' : 'نفد الكمية', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
