import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';

class UserTransactionsScreen extends StatelessWidget {
  const UserTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // قائمة وهمية بالعمليات المالية
    final List<Map<String, dynamic>> transactions = [
      {'title': 'شحن رصيد', 'date': 'اليوم 10:00 ص', 'amount': '+5000', 'isDeposit': true},
      {'title': 'شراء كرت شبكة الصقر', 'date': 'أمس 08:30 م', 'amount': '-1000', 'isDeposit': false},
      {'title': 'تحويل رصيد لصديق', 'date': '28 مارس 2026', 'amount': '-500', 'isDeposit': false},
    ];

    return Scaffold(
      appBar: const CustomHeader(title: 'سجل العمليات المالية'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final bool isDeposit = tx['isDeposit'];

            return Card(
              child: ListTile(
                // أيقونة خضراء للإيداع، وحمراء للسحب/الشراء
                leading: CircleAvatar(
                  backgroundColor: isDeposit ? Colors.green.shade100 : Colors.red.shade100,
                  child: Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward, color: isDeposit ? Colors.green : Colors.red),
                ),
                title: Text(tx['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(tx['date']),
                // تلوين المبلغ بناءً على نوع العملية
                trailing: Text(
                  '${tx['amount']} ريال',
                  style: TextStyle(color: isDeposit ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
