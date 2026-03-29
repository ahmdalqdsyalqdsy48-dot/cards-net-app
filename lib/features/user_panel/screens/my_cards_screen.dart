import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // مكتبة لتمكين نسخ النصوص
import '../../../core/widgets/custom_header.dart'; // استدعاء الترويسة الموحدة

class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // قائمة بيانات وهمية للكروت السابقة
    final List<Map<String, dynamic>> myCards = [
      {'network': 'شبكة الصقر للواي فاي', 'pin': '88229911', 'date': '2026/03/30', 'status': 'نشط', 'color': Colors.green},
      {'network': 'شبكة النور السريعة', 'pin': '44556677', 'date': '2026/03/25', 'status': 'منتهي', 'color': Colors.grey},
    ];

    return Scaffold(
      appBar: const CustomHeader(title: 'كروتي ومشترياتي'), // ترويسة الشاشة
      body: Directionality(
        textDirection: TextDirection.rtl, // توجيه النص من اليمين لليسار
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
                    // السطر الأول: اسم الشبكة وحالتها
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
                    // السطر الثاني: رقم الكرت وزر النسخ
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
                        // زر نسخ الكرت يظهر فقط إذا كان الكرت نشطاً
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
