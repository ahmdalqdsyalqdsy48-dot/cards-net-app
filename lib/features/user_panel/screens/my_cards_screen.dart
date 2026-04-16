import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key});

  // دالة ذكية لتحويل صيغة التاريخ المعقدة إلى شكل مقروء وجميل
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return intl.DateFormat('yyyy/MM/dd - hh:mm a').format(date);
    } catch (e) {
      return dateStr; // إذا كان التاريخ قديماً أو بصيغة غريبة، يعرضه كما هو
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    
    // 👈 تحديد هوية الزائر
    final isPos = systemProvider.currentUserRole == 'pos';
    
    // 👈 قراءة المصفوفة التفصيلية من العقل المدبر، وعكسها ليظهر الأحدث أولاً
    final List<Map<String, dynamic>> purchasedCards = systemProvider.userPurchasedCards.reversed.toList(); 

    return Scaffold(
      // تغيير العنوان بناءً على الصلاحيات
      appBar: CustomHeader(title: isPos ? 'سجل المبيعات' : 'كروتي ومشترياتي'),
      drawer: CustomUserDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: purchasedCards.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      isPos ? 'لم تقم ببيع أي كروت حتى الآن.' : 'لم تقم بشراء أي كروت حتى الآن.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: purchasedCards.length,
                itemBuilder: (context, index) {
                  // استخراج بيانات الفاتورة الحقيقية
                  final cardData = purchasedCards[index];
                  final String title = cardData['title'] ?? 'كرت غير معروف';
                  final String pin = cardData['pin'] ?? 'غير متوفر';
                  final String price = cardData['price']?.toString() ?? '0';
                  final String date = cardData['date'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 👈 اسم الكرت والشبكة
                              Expanded(
                                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                              ),
                              // 👈 السعر الحقيقي 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('$price ريال', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الـ PIN:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              // 👈 الـ PIN الفعلي القادم من السيرفر
                              Text(pin, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 👈 تاريخ الشراء
                              Text(date.isNotEmpty ? _formatDate(date) : 'تاريخ غير معروف', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              
                              // 👈 زر النسخ المربوط بالـ PIN الفعلي
                              OutlinedButton.icon(
                                onPressed: () {
                                  Provider.of<UiProvider>(context, listen: false).playSound('success');
                                  Clipboard.setData(ClipboardData(text: pin));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الـ PIN ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('نسخ'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              )
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
