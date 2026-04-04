import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 استدعاء مكتبة الحافظة (لخاصية النسخ السريع)
import 'package:provider/provider.dart'; 

import '../../../core/providers/system_provider.dart'; 
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  
  // ==========================================
  // 1. نافذة إضافة حساب بنكي جديد ➕ (مربوطة بالسحابة)
  // ==========================================
  void _showAddAccountDialog(SystemProvider provider) {
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
                _buildTextField('رقم الحساب / المحفظة', Icons.numbers, controller: accountNumberController, isNumber: true),
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
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة رفع الصور ستتوفر قريباً 📸', textDirection: TextDirection.rtl)));
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
                if (bankNameController.text.isNotEmpty && accountNumberController.text.isNotEmpty) {
                  // 👈 إرسال البيانات للعقل المدبر ليحفظها في السحابة
                  provider.addBankAccount(
                    bankNameController.text,
                    accountNumberController.text,
                    beneficiaryController.text,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الحساب للسحابة بنجاح ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
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
  // 2. نافذة تعديل حساب موجود ✏️ (مربوطة بالسحابة)
  // ==========================================
  void _showEditAccountDialog(SystemProvider provider, Map<String, dynamic> account) {
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
                // 👈 إرسال التعديل للعقل المدبر
                provider.updateBankAccount(
                  account['docId'],
                  bankNameController.text,
                  accountNumberController.text,
                  beneficiaryController.text,
                );
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
  // 3. دوال التحكم (حذف، تغيير حالة، نسخ سريع)
  // ==========================================
  void _toggleAccountStatus(SystemProvider provider, Map<String, dynamic> account) {
    provider.toggleBankAccountStatus(account['docId'], account['status']);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(account['status'] == 'موقوف' ? 'تم تفعيل الحساب وسيظهر للوكلاء ▶️' : 'تم إيقاف الحساب وإخفاؤه عن الوكلاء ⏸️', textDirection: TextDirection.rtl),
      backgroundColor: account['status'] == 'موقوف' ? Colors.green : Colors.orange,
    ));
  }

  void _deleteAccount(SystemProvider provider, String docId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تحذير الحذف ⚠️', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا الحساب نهائياً من قاعدة البيانات؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                provider.deleteBankAccount(docId); // 👈 حذف سحابي
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

  // 🎁 دالة النسخ السريع لمشاركة الحساب بسهولة
  void _copyAccountDetails(Map<String, dynamic> account) {
    String data = '''
🏦 ${account['bankName']}
🔢 الحساب: ${account['accountNumber']}
👤 باسم: ${account['beneficiary']}
''';
    Clipboard.setData(ClipboardData(text: data));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ بيانات الحساب بنجاح، جاهزة للإرسال! 📋', textDirection: TextDirection.rtl), backgroundColor: Colors.blueGrey));
  }

  @override
  Widget build(BuildContext context) {
    // 👈 قراءة البيانات الحية من العقل المدبر
    final systemProvider = Provider.of<SystemProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;
    final bankAccounts = systemProvider.bankAccounts; // 👈 جلب الحسابات السحابية

    return Scaffold(
      appBar: const CustomHeader(title: 'الحسابات البنكية'),
      drawer: CustomDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
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
                  onPressed: () => _showAddAccountDialog(systemProvider), // 👈 تمرير الـ Provider
                  icon: const Icon(Icons.add_card, color: Colors.white),
                  label: const Text('إضافة حساب بنكي جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),

            // رسالة إرشادية
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

            // === قائمة الحسابات السحابية (ReorderableListView) ===
            Expanded(
              child: bankAccounts.isEmpty
                  ? const Center(child: Text('لا توجد حسابات مضافة حالياً. اضغط على الزر أعلاه لإضافة حساب.', style: TextStyle(color: Colors.grey)))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bankAccounts.length,
                      onReorder: (oldIndex, newIndex) {
                        // 👈 إرسال الترتيب الجديد للسحابة
                        systemProvider.reorderBankAccounts(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final account = bankAccounts[index];
                        final isActive = account['status'] == 'نشط';

                        return Card(
                          key: ValueKey(account['docId']), // 👈 المفتاح السحابي
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
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.drag_indicator, color: Colors.grey),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(account['bankName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                                                Text(account['accountNumber'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textDirection: TextDirection.ltr),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Chip(
                                          label: Text(account['status'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                          backgroundColor: isActive ? Colors.green : Colors.red,
                                          padding: EdgeInsets.zero,
                                        ),
                                        if (account['hasQR'] == true) const Icon(Icons.qr_code_2, color: Colors.blueGrey, size: 20),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('المستفيد: ${account['beneficiary']}', style: const TextStyle(color: Colors.blueGrey, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 🎁 زر النسخ السريع
                                        _buildSmallButton(Icons.copy, 'نسخ البيانات', Colors.blueGrey, () => _copyAccountDetails(account)),
                                        // أزرار التحكم السحابية
                                        _buildSmallButton(Icons.edit, 'تعديل', Colors.orange, () => _showEditAccountDialog(systemProvider, account)),
                                        _buildSmallButton(
                                          isActive ? Icons.visibility_off : Icons.visibility,
                                          isActive ? 'إيقاف' : 'تفعيل',
                                          isActive ? Colors.red : Colors.green,
                                          () => _toggleAccountStatus(systemProvider, account),
                                        ),
                                        _buildSmallButton(Icons.delete, 'حذف', Colors.red.shade900, () => _deleteAccount(systemProvider, account['docId'])),
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
