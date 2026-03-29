import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import '../../../core/widgets/custom_header.dart';
// 👇 1. استدعاء القائمة الجانبية
import '../widgets/custom_user_drawer.dart'; 

class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> myCards = [
      {'network': 'شبكة الصقر للواي فاي', 'pin': '88229911', 'date': '2026/03/30', 'status': 'نشط', 'color': Colors.green},
      {'network': 'شبكة النور السريعة', 'pin': '44556677', 'date': '2026/03/25', 'status': 'منتهي', 'color': Colors.grey},
    ];

    return Scaffold(
      appBar: const CustomHeader(title: 'كروتي ومشترياتي'),
      // 👇 2. إضافة القائمة الجانبية لهيكل الشاشة ليظهر الزر
      drawer: const CustomUserDrawer(
        userName: 'محمد أحمد',
        phoneNumber: '777123456',
        walletBalance: 2500.0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl, 
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myCards.length,
          itemBuilder: (context, index) {
            final card = myCards[index];
            final isActive = card['status'] == 'نشط';

            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(card['network'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: card['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(card['status'], style: TextStyle(color: card['color'], fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('رقم الكرت (PIN):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(card['pin'], style: const TextStyle(fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (isActive)
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: card['pin']));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكرت ✅')));
                            },
                            icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                            label: const Text('نسخ', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
    );
  }
}
