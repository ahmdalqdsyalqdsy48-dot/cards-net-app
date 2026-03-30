import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 1. استدعاء العقل المدبر

import '../../../core/providers/system_provider.dart'; // 👈 2. استدعاء الخادم المحلي الشامل
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  // قائمة الحسابات (تم تحويلها لمتغير قابل للتعديل)
  final List<Map<String, dynamic>> _bankAccounts = [
    {'id': 1, 'bankName': 'بنك الكريمي', 'accountNumber': '3020104050', 'beneficiary': 'أحمد القدسي', 'status': 'نشط', 'hasQR': true},
    {'id': 2, 'bankName': 'محفظة جوالي', 'accountNumber': '774578241', 'beneficiary': 'أحمد القدسي', 'status': 'نشط', 'hasQR': false},
    {'id': 3, 'bankName': 'بنك التضامن', 'accountNumber': '1122334455', 'beneficiary': 'أحمد القدسي', 'status': 'موقوف', 'hasQR': true},
  ];

  // ==========================================
  // 1. نافذة إضافة حساب بنكي جديد ➕ (مفعلة برمجياً)
  // ==========================================
  void _showAddAccountDialog() {
    // متحكمات لقراءة النصوص التي سيدخلها المدير
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final beneficiaryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_balance, color: Colors.blue),
              SizedBox(width: 10),
              Text('إضافة حساب بنكي جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('اسم البنك / المحفظة (مثال: الكريمي)', Icons.account_balance_wallet, controller: bankNameController),
                _buildTextField('رقم الحساب / رقم المحفظة', Icons.numbers, controller: accountNumberController, isNumber: true),
                _buildTextField('الاسم الرباعي للمستفيد', Icons.person, controller: beneficiaryController),
                _buildTextField('ملاحظات التحويل (اختياري)', Icons.notes),
                const SizedBox(height: 10),
                
                // زر رفع الباركود QR
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 40, color: Colors.blueAccent),
                      const SizedBox(height: 5),
                      const Text('رفع صورة الباركود (QR Code)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      const Text('يسهل على الوكيل الدفع بالمسح مباشرة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم فتح المعرض لاختيار الصورة 📸', textDirection: TextDirection.rtl)));
                        },
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('اختيار صورة من المعرض'),
                        style: ElevatedButton.styleFrom(elevation: 0),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                // التحقق من إدخال البيانات الأساسية قبل الحفظ
                if (bankNameController.text.isNotEmpty && accountNumberController.text.isNotEmpty) {
                  setState(() {
                    _bankAccounts.add({
                      'id': DateTime.now().millisecondsSinceEpoch, // إنشاء ID فريد
                      'bankName': bankNameController.text,
                      'accountNumber': accountNumberController.text,
                      'beneficiary': beneficiaryController.text.isNotEmpty ? beneficiaryController.text : 'غير محدد',
                      'status': 'نشط',
                      'hasQR': false,
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الحساب بنجاح ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم البنك ورقم الحساب على الأقل ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                }
              },
              child: const Text('حفظ الحساب'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة تعديل حساب موجود ✏️ (جديدة)
  // ==========================================
  void _showEditAccountDialog(int index, Map<String, dynamic> account) {
    // تعبئة الحقول بالبيانات الحالية للحساب
    final bankNameController = TextEditingController(text: account['bankName']);
    final accountNumberController = TextEditingController(text: account['accountNumber']);
    final beneficiaryController = TextEditingController(text: account['beneficiary']);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.orange),
              SizedBox(width: 10),
              Text('تعديل بيانات الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('اسم البنك / المحفظة', Icons.account_balance_wallet, controller: bankNameController),
                _buildTextField('رقم الحساب', Icons.numbers, controller: accountNumberController, isNumber: true),
                _buildTextField('اسم المستفيد', Icons.person, controller: beneficiaryController),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                setState(() {
                  _bankAccounts[index]['bankName'] = bankNameController.text;
                  _bankAccounts[index]['accountNumber'] = accountNumberController.text;
                  _bankAccounts[index]['beneficiary'] = beneficiaryController.text;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل الحساب بنجاح ✏️', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
              },
              child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. دوال التحكم (الإيقاف المؤقت، والحذف) 👁️ 🗑️
  // ==========================================
  void _toggleAccountStatus(int index) {
    setState(() {
      _bankAccounts[index]['status'] = _bankAccounts[index]['status'] == 'نشط' ? 'موقوف' : 'نشط';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_bankAccounts[index]['status'] == 'نشط' ? 'تم تفعيل الحساب وسيظهر للوكلاء ▶️' : 'تم إيقاف الحساب وإخفاؤه عن الوكلاء ⏸️', textDirection: TextDirection.rtl),
      backgroundColor: _bankAccounts[index]['status'] == 'نشط' ? Colors.green : Colors.orange,
    ));
  }

  void _deleteAccount(int index) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تحذير الحذف ⚠️', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا الحساب نهائياً؟\n\n(ملاحظة: سيمنع النظام الحذف إذا كان هناك طلبات شحن معلقة مرتبطة بهذا الحساب لحماية أموالك).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  _bankAccounts.removeAt(index);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الحساب نهائياً 🗑️', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
              },
              child: const Text('نعم، احذف الحساب', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👈 قراءة رصيد النظام من العقل المدبر لعرضه في القائمة الجانبية
    final systemProvider = Provider.of<SystemProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;

    return Scaffold(
      appBar: const CustomHeader(title: 'الحسابات البنكية'),
      
      // 👈 تمرير الرصيد المتغير وإزالة const
      drawer: CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // === زر الإضافة العلوي ===
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showAddAccountDialog,
                  icon: const Icon(Icons.add_card, color: Colors.white),
                  label: const Text('إضافة حساب بنكي جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),

            // رسالة إرشادية لخاصية السحب والإفلات
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.yellow.shade50,
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('يمكنك الضغط مطولاً على أي حساب وسحبه للأعلى ↕️ لجعله الخيار الأول والأهم لدى الوكلاء.', style: TextStyle(fontSize: 12, color: Colors.brown))),
                ],
              ),
            ),

            // === قائمة الحسابات بتقنية السحب والإفلات (ReorderableListView) ===
            Expanded(
              child: _bankAccounts.isEmpty
                  ? const Center(child: Text('لا توجد حسابات مضافة حالياً.', style: TextStyle(color: Colors.grey)))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bankAccounts.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final account = _bankAccounts.removeAt(oldIndex);
                          _bankAccounts.insert(newIndex, account);
                        });
                      },
                      itemBuilder: (context, index) {
                        final account = _bankAccounts[index];
                        final isActive = account['status'] == 'نشط';

                        return Card(
                          key: ValueKey(account['id']), // المفتاح ضروري لعملية السحب والإفلات
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: isActive ? Colors.transparent : Colors.red.withOpacity(0.5), width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.drag_indicator, color: Colors.grey), // أيقونة السحب
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(account['bankName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                                            Text(account['accountNumber'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textDirection: TextDirection.ltr),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Chip(
                                          label: Text(account['status'], style: const TextStyle(color: Colors.white, fontSize: 11)),
                                          backgroundColor: isActive ? Colors.green : Colors.red,
                                          padding: EdgeInsets.zero,
                                        ),
                                        if (account['hasQR']) const Icon(Icons.qr_code_2, color: Colors.blueGrey, size: 20),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('المستفيد: ${account['beneficiary']}', style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
                                    Row(
                                      children: [
                                        // 👈 ربط زر التعديل بدالة التعديل
                                        _buildSmallButton(Icons.edit, 'تعديل', Colors.orange, () => _showEditAccountDialog(index, account)),
                                        _buildSmallButton(
                                          isActive ? Icons.visibility_off : Icons.visibility,
                                          isActive ? 'إيقاف' : 'تفعيل',
                                          isActive ? Colors.red : Colors.green,
                                          () => _toggleAccountStatus(index),
                                        ),
                                        _buildSmallButton(Icons.delete, 'حذف', Colors.red.shade900, () => _deleteAccount(index)),
                                      ],
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

  // ==========================================
  // دوال مساعدة للتصميم
  // ==========================================
  Widget _buildTextField(String label, IconData icon, {TextEditingController? controller, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildSmallButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(),
    );
  }
}
