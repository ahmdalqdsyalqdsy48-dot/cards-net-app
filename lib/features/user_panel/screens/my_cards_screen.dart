import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // نحتاجها لميزة نسخ النص
import 'package:provider/provider.dart'; // 👈 1. استدعاء مكتبة العقل المدبر

import '../../../core/providers/system_provider.dart'; // 👈 2. استدعاء الخادم المحلي الشامل
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart'; 

class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 👇 3. الاتصال بالعقل المدبر لجلب الكروت الحقيقية التي اشتراها الزبون
    final systemProvider = Provider.of<SystemProvider>(context);
    final purchasedCards = systemProvider.userPurchasedCards;

    return Scaffold(
      appBar: const CustomHeader(title: 'كروتي ومشترياتي'),
      drawer: const CustomUserDrawer(
        userName: 'محمد أحمد',
        phoneNumber: '777123456',
        // 💡 تم إزالة سطر الرصيد من هنا ليتوافق مع القائمة الجانبية الذكية المحدثة
      ),
      body: Directionality(
        textDirection: TextDirection.rtl, 
        // 👇 4. نتحقق أولاً: هل الزبون اشترى كروتاً أم لا؟
        child: purchasedCards.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 15),
                  const Text(
                    'لم تقم بشراء أي كروت بعد.\nاذهب إلى سوق الشبكات لشراء كرتك الأول! 🛒', 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            )
          // 👇 5. إذا كان هناك كروت، نقوم بعرضها في قائمة
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: purchasedCards.length,
              itemBuilder: (context, index) {
                // نعكس الفهرس لكي يظهر الكرت الأحدث (آخر كرت تم شراؤه) في أعلى القائمة
                final reversedIndex = purchasedCards.length - 1 - index;
                final cardName = purchasedCards[reversedIndex];
                
                // توليد رقم PIN وهمي للكرت لغرض العرض
                final mockPin = '8472-9102-334$reversedIndex';

                return Card(
                  margin: const EdgeInsets.only(bottom: 15),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // اسم الكرت الذي تم حفظه في العقل المدبر
                            Expanded(child: Text(cardName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('جديد', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
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
                                Text(mockPin, style: const TextStyle(fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                // وظيفة نسخ الكرت إلى حافظة الهاتف
                                Clipboard.setData(ClipboardData(text: mockPin));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكرت بنجاح! ✅'), backgroundColor: Colors.green));
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
