import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class MarketingOffersScreen extends StatefulWidget {
  const MarketingOffersScreen({super.key});

  @override
  State<MarketingOffersScreen> createState() => _MarketingOffersScreenState();
}

class _MarketingOffersScreenState extends State<MarketingOffersScreen> {
  // قاعدة بيانات وهمية للكوبونات والعروض النشطة
  final List<Map<String, dynamic>> _activeOffers = [
    {'code': 'RAMADAN26', 'discount': 'خصم 15%', 'usage': '12 / 50', 'expiry': '2026-04-10', 'status': 'نشط 🟢', 'color': Colors.green},
    {'code': 'VIP-BAQALA', 'discount': 'رصيد إضافي 1000 ريال', 'usage': '5 / 10', 'expiry': '2026-03-30', 'status': 'ينتهي قريباً 🟠', 'color': Colors.orange},
    {'code': 'WELCOME', 'discount': 'خصم 5%', 'usage': '100 / 100', 'expiry': '2026-03-20', 'status': 'مكتمل (نفد) 🔴', 'color': Colors.red},
  ];

  // ==========================================
  // نافذة إنشاء عرض / كوبون جديد 🎟️
  // ==========================================
  void _showCreateOfferDialog() {
    String newCode = '';
    String newDiscount = '';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('إنشاء عرض ترويجي جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('قم بتوليد كوبون لعملائك أو البقالات التابعة لك لزيادة مبيعاتك.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 15),
                TextField(
                  onChanged: (val) => newCode = val,
                  decoration: InputDecoration(
                    labelText: 'كود الكوبون (مثال: OFFER50)',
                    prefixIcon: const Icon(Icons.local_offer, color: Colors.blueAccent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) => newDiscount = val,
                  decoration: InputDecoration(
                    labelText: 'نوع الخصم (مثال: خصم 10%)',
                    prefixIcon: const Icon(Icons.discount, color: Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'الحد الأقصى للاستخدام (مثال: 50 شخص)',
                    prefixIcon: const Icon(Icons.people, color: Colors.orange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
            ElevButtonCustom(
              text: 'توليد واعتماد',
              color: Colors.blueAccent,
              onPressed: () {
                if (newCode.isNotEmpty && newDiscount.isNotEmpty) {
                  setState(() {
                    _activeOffers.insert(0, {
                      'code': newCode,
                      'discount': newDiscount,
                      'usage': '0 / غير محدد',
                      'expiry': '2026-04-30',
                      'status': 'نشط 🟢',
                      'color': Colors.green,
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم توليد الكوبون بنجاح! 🎉'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة الكود والخصم!'), backgroundColor: Colors.red));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // نافذة مشاركة الكوبون عبر واتساب 📲
  // ==========================================
  void _shareOffer(String code, String discount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جاري فتح واتساب لمشاركة الكوبون: $code ...'),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 2),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'التسويق والعروض'),
      drawer: const CustomAgentDrawer(
        agentName: 'شبكة الصقر للواي فاي',
        phoneNumber: '777777777',
        role: 'وكيل معتمد (Agent)',
        currentBalance: 125000.0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // 1. بانر ترحيبي وزر الإضافة
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade900,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ضاعف مبيعاتك! 🚀', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('قم بإنشاء كوبونات وعروض خاصة لبقالاتك أو زبائنك لزيادة الولاء.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: _showCreateOfferDialog,
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                      label: const Text('إنشاء عرض جديد الآن', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // 2. عنوان القائمة
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('العروض والكوبونات الحالية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              ),
            ),

            // 3. قائمة العروض
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _activeOffers.length,
                itemBuilder: (context, index) {
                  final offer = _activeOffers[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: offer['color'].withOpacity(0.5), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: offer['color'].withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: offer['color'].withOpacity(0.5)),
                                ),
                                child: Text(offer['code'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: offer['color'], letterSpacing: 2)),
                              ),
                              Text(offer['status'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: offer['color'])),
                            ],
                          ),
                          const Divider(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(offer['discount'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('الاستخدام: ${offer['usage']} | ينتهي: ${offer['expiry']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                              IconButton(
                                onPressed: () => _shareOffer(offer['code'], offer['discount']),
                                icon: const Icon(Icons.share, color: Colors.teal),
                                tooltip: 'مشاركة العرض',
                                style: IconButton.styleFrom(backgroundColor: Colors.teal.withOpacity(0.1)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// أداة مساعدة لزر مخصص
class ElevButtonCustom extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;

  const ElevButtonCustom({super.key, required this.text, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      onPressed: onPressed,
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
