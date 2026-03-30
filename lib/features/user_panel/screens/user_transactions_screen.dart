import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
// 👇 1. استدعاء القائمة الجانبية الذكية
import '../widgets/custom_user_drawer.dart';

// 👇 2. تحويل الشاشة إلى StatefulWidget لكي نتمكن من برمجة التصفية (الفلترة)
class UserTransactionsScreen extends StatefulWidget {
  const UserTransactionsScreen({super.key});

  @override
  State<UserTransactionsScreen> createState() => _UserTransactionsScreenState();
}

class _UserTransactionsScreenState extends State<UserTransactionsScreen> {
  // متغير لحفظ حالة الفلتر الحالي (الافتراضي: عرض الكل)
  String _selectedFilter = 'الكل';

  // قاعدة بيانات تجريبية لسجل العمليات
  final List<Map<String, dynamic>> _transactions = [
    {'title': 'شحن رصيد من الإدارة', 'date': 'اليوم 10:00 ص', 'amount': '+5000', 'isDeposit': true},
    {'title': 'شراء كرت شبكة الصقر', 'date': 'أمس 08:30 م', 'amount': '-1000', 'isDeposit': false},
    {'title': 'تحويل رصيد لصديق', 'date': '28 مارس 2026', 'amount': '-500', 'isDeposit': false},
    {'title': 'مكافأة ولاء', 'date': '25 مارس 2026', 'amount': '+200', 'isDeposit': true},
  ];

  @override
  Widget build(BuildContext context) {
    // 👇 3. دالة ذكية لتصفية العمليات بناءً على الزر الذي يختاره المستخدم
    final filteredTransactions = _transactions.where((tx) {
      if (_selectedFilter == 'إيداع (+)') return tx['isDeposit'] == true;
      if (_selectedFilter == 'خصم (-)') return tx['isDeposit'] == false;
      return true; // عرض 'الكل'
    }).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'سجل العمليات المالية'),
      
      // 👇 4. تم إزالة السطر المتعارض لكي تعمل القائمة بذكاء وتجلب الرصيد بنفسها
      drawer: const CustomUserDrawer(
        userName: 'محمد أحمد',
        phoneNumber: '777123456',
      ),
      
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // شريط الفلترة (تصفية العمليات)
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Theme.of(context).cardColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterChip('الكل'),
                  _buildFilterChip('إيداع (+)'),
                  _buildFilterChip('خصم (-)'),
                ],
              ),
            ),
            const Divider(height: 1),

            // ==========================================
            // قائمة العمليات المالية
            // ==========================================
            Expanded(
              child: filteredTransactions.isEmpty
                  ? const Center(
                      child: Text('لا توجد عمليات مطابقة لهذا الفلتر.', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = filteredTransactions[index];
                        final bool isDeposit = tx['isDeposit'];

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            // الأيقونة (سهم أخضر للأسفل للإيداع، سهم أحمر للأعلى للخصم)
                            leading: CircleAvatar(
                              backgroundColor: isDeposit ? Colors.green.shade50 : Colors.red.shade50,
                              child: Icon(
                                isDeposit ? Icons.arrow_downward : Icons.arrow_upward, 
                                color: isDeposit ? Colors.green : Colors.red
                              ),
                            ),
                            title: Text(tx['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(tx['date'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                            // عرض المبلغ مع تلوينه حسب نوع العملية
                            trailing: Text(
                              '${tx['amount']} ريال',
                              style: TextStyle(
                                color: isDeposit ? Colors.green.shade700 : Colors.red.shade700, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 16
                              ),
                              textDirection: TextDirection.ltr, // لضمان ظهور علامة السالب/الموجب بشكل صحيح
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

  // ==========================================
  // دالة مساعدة لبناء أزرار التصفية (الكل، إيداع، خصم)
  // ==========================================
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: Colors.blue.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade800 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
      ),
    );
  }
}
