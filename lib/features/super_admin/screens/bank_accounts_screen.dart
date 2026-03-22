import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  // قائمة وهمية للحسابات لتجربة ميزة السحب والإفلات وتغيير الحالة
  List<Map<String, dynamic>> accounts = [
    {'id': '1', 'bank': 'بنك الكريمي', 'number': '123456789', 'name': 'أحمد القدسي', 'isActive': true},
    {'id': '2', 'bank': 'جوالي', 'number': '774578241', 'name': 'أحمد القدسي', 'isActive': true},
    {'id': '3', 'bank': 'محفظة كاس', 'number': '987654321', 'name': 'أحمد القدسي', 'isActive': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(
        title: 'الحسابات البنكية',
        isOnline: true,
      ),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      // زر إضافة حساب جديد
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // نافذة إضافة حساب مع رفع صورة الـ QR Code
        },
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add_card, color: Colors.white),
        label: const Text('إضافة حساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط التنبيهات والتعليمات
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.withOpacity(0.1),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ميزة السحب والإفلات: اضغط مطولاً على أيقونة (≡) واسحب الحساب لترتيب عرض الحسابات الأهم للوكلاء.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            
            // قائمة الحسابات القابلة للسحب والإفلات
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: accounts.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = accounts.removeAt(oldIndex);
                    accounts.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final acc = accounts[index];
                  return Card(
                    key: ValueKey(acc['id']), // مفتاح إجباري للسحب والإفلات
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: acc['isActive'] ? Colors.transparent : Colors.red.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance, color: Colors.blueAccent),
                      ),
                      title: Text(
                        '${acc['bank']} - ${acc['name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text(
                            acc['number'],
                            style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: acc['isActive'] ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              acc['isActive'] ? 'حساب نشط 🟢' : 'موقوف مؤقتاً 🔴',
                              style: TextStyle(
                                color: acc['isActive'] ? Colors.green : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // زر الباركود QR
                          IconButton(
                            icon: const Icon(Icons.qr_code_2, color: Colors.grey),
                            tooltip: 'عرض الباركود',
                            onPressed: () {},
                          ),
                          // زر الإيقاف / التفعيل (زر الطوارئ المالي)
                          IconButton(
                            icon: Icon(
                              acc['isActive'] ? Icons.pause_circle : Icons.play_circle,
                              color: acc['isActive'] ? Colors.orange : Colors.green,
                              size: 28,
                            ),
                            tooltip: acc['isActive'] ? 'إيقاف الحساب' : 'تفعيل الحساب',
                            onPressed: () {
                              setState(() {
                                acc['isActive'] = !acc['isActive'];
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          // أيقونة السحب
                          const Icon(Icons.drag_handle, color: Colors.grey),
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
