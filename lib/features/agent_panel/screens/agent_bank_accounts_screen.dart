import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentBankAccountsScreen extends StatefulWidget {
  const AgentBankAccountsScreen({super.key});

  @override
  State<AgentBankAccountsScreen> createState() =>
      _AgentBankAccountsScreenState();
}

class _AgentBankAccountsScreenState extends State<AgentBankAccountsScreen> {
  void _play(BuildContext context, String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================== 1. نافذة إضافة حساب جديد ====================
  void _showAddAccountDialog(SystemProvider provider) {
    _play(context, 'click');
    final networkNameController =
        TextEditingController(text: provider.currentUserNetwork);
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final beneficiaryController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFF5E35B1)),
              SizedBox(width: 10),
              Text('إضافة حساب بنكي جديد',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('اسم الشبكة', Icons.wifi,
                    controller: networkNameController),
                _buildTextField('اسم البنك / المحفظة',
                    Icons.account_balance_wallet,
                    controller: bankNameController),
                _buildTextField('رقم الحساب / المحفظة', Icons.numbers,
                    controller: accountNumberController, isNumber: true),
                _buildTextField('الاسم الرباعي للمستفيد', Icons.person,
                    controller: beneficiaryController),
                _buildTextField('ملاحظات (اختياري)', Icons.notes,
                    controller: noteController),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  _play(context, 'click');
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E35B1)),
              onPressed: () {
                if (bankNameController.text.isNotEmpty &&
                    accountNumberController.text.isNotEmpty) {
                  Navigator.pop(ctx);
                  _play(context, 'click');
                  provider
                      .addAgentBankAccount(
                    networkNameController.text.trim(),
                    provider.currentUserName,
                    bankNameController.text.trim(),
                    accountNumberController.text.trim(),
                    noteController.text.trim(),
                  )
                      .then((_) {
                    _showSnack('تم حفظ الحساب بنجاح ✅');
                  }).catchError((e) {
                    _showSnack('فشل الحفظ: $e', error: true);
                  });
                } else {
                  _showSnack('يرجى إدخال اسم البنك ورقم الحساب', error: true);
                }
              },
              child: const Text('حفظ الحساب',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 2. نافذة تعديل حساب ====================
  void _showEditAccountDialog(
      SystemProvider provider, Map<String, dynamic> account) {
    _play(context, 'click');
    final networkNameController =
        TextEditingController(text: account['networkName'] ?? '');
    final bankNameController =
        TextEditingController(text: account['bankName']);
    final accountNumberController =
        TextEditingController(text: account['accountNumber']);
    final beneficiaryController =
        TextEditingController(text: account['beneficiary'] ?? '');
    final noteController =
        TextEditingController(text: account['note'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.orange),
              SizedBox(width: 10),
              Text('تعديل الحساب',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('اسم الشبكة', Icons.wifi,
                    controller: networkNameController),
                _buildTextField('اسم البنك / المحفظة',
                    Icons.account_balance_wallet,
                    controller: bankNameController),
                _buildTextField('رقم الحساب', Icons.numbers,
                    controller: accountNumberController, isNumber: true),
                _buildTextField('اسم المستفيد', Icons.person,
                    controller: beneficiaryController),
                _buildTextField('ملاحظات', Icons.notes,
                    controller: noteController),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  _play(context, 'click');
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(ctx);
                _play(context, 'click');
                provider
                    .updateAgentBankAccount(
                  account['docId'],
                  networkNameController.text.trim(),
                  provider.currentUserName,
                  bankNameController.text.trim(),
                  accountNumberController.text.trim(),
                  noteController.text.trim(),
                )
                    .then((_) {
                  _showSnack('تم التعديل بنجاح ✏️');
                }).catchError((e) {
                  _showSnack('فشل التعديل: $e', error: true);
                });
              },
              child: const Text('حفظ التعديلات',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 3. دوال التحكم (حالة / حذف / نسخ) ====================
  void _toggleAccountStatus(
      SystemProvider provider, Map<String, dynamic> account) {
    _play(context, 'click');
    provider
        .toggleAgentBankAccountStatus(account['docId'], account['status'])
        .then((_) {
      _showSnack('تم تغيير الحالة');
    }).catchError((e) {
      _showSnack('فشل تغيير الحالة: $e', error: true);
    });
  }

  void _deleteAccount(SystemProvider provider, String docId) {
    _play(context, 'click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تحذير الحذف ⚠️',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا الحساب نهائياً من قاعدة البيانات؟'),
          actions: [
            TextButton(
                onPressed: () {
                  _play(context, 'click');
                  Navigator.pop(ctx);
                },
                child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _play(context, 'click');
                provider.deleteAgentBankAccount(docId).then((_) {
                  _showSnack('تم الحذف بنجاح 🗑️');
                }).catchError((e) {
                  _showSnack('فشل الحذف: $e', error: true);
                });
              },
              child: const Text('نعم، احذف الحساب',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAccountDetails(Map<String, dynamic> account) {
    _play(context, 'success');
    String data = '''
🏦 ${account['bankName']}
🔢 الحساب: ${account['accountNumber']}
👤 باسم: ${account['beneficiary'] ?? ''}
''';
    Clipboard.setData(ClipboardData(text: data));
    _showSnack('تم نسخ بيانات الحساب بنجاح، جاهزة للإرسال! 📋');
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);

    return Scaffold(
      appBar: const CustomHeader(title: 'حساباتي البنكية'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد',
        currentBalance: sys.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddAccountDialog(sys),
                  icon: const Icon(Icons.add_card, color: Colors.white),
                  label: const Text('إضافة حساب بنكي جديد',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF5E35B1).withOpacity(0.05),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF5E35B1), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'يمكنك سحب أي حساب لإعادة ترتيب أولويات الظهور للعملاء.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF5E35B1)))),
                ],
              ),
            ),
            Expanded(
              // 🆕 استخدام StreamBuilder مباشرة لضمان التحديث الفوري
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('agent_bank_accounts')
                    .where('agentPhone', isEqualTo: sys.currentUserPhone)
                    .orderBy('order')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final accounts = snapshot.data?.docs.map((doc) {
                        return {'docId': doc.id, ...doc.data()};
                      }).toList() ??
                      [];

                  if (accounts.isEmpty) {
                    return const Center(
                        child: Text(
                            'لا توجد حسابات مضافة حالياً.\nاضغط على الزر أعلاه لإضافة حساب.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)));
                  }

                  return ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: accounts.length,
                    onReorder: (oldIndex, newIndex) {
                      sys.reorderAgentBankAccounts(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final isActive = account['status'] == 'نشط';

                      return Card(
                        key: ValueKey(account['docId']),
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                              color: isActive
                                  ? Colors.transparent
                                  : Colors.red.withOpacity(0.5),
                              width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.drag_indicator,
                                            color: Colors.grey),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (account['networkName'] !=
                                                      null &&
                                                  account['networkName']
                                                      .toString()
                                                      .isNotEmpty)
                                                Text(
                                                    'شبكة: ${account['networkName']}',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.teal)),
                                              Text(account['bankName'] ?? '',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color:
                                                          Color(0xFF5E35B1))),
                                              Text(account['accountNumber'] ?? '',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18),
                                                  textDirection:
                                                      TextDirection.ltr),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    label: Text(account['status'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11)),
                                    backgroundColor: isActive
                                        ? Colors.green
                                        : Colors.red.shade400,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          'المستفيد: ${account['beneficiary'] ?? ''}',
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12),
                                          overflow: TextOverflow.ellipsis)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildSmallButton(
                                        Icons.copy,
                                        'نسخ البيانات',
                                        const Color(0xFF5E35B1),
                                        () => _copyAccountDetails(account),
                                      ),
                                      _buildSmallButton(
                                        Icons.edit,
                                        'تعديل',
                                        Colors.orange,
                                        () => _showEditAccountDialog(
                                            sys, account),
                                      ),
                                      _buildSmallButton(
                                        isActive
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        isActive ? 'إيقاف' : 'تفعيل',
                                        isActive ? Colors.red : Colors.green,
                                        () => _toggleAccountStatus(
                                            sys, account),
                                      ),
                                      _buildSmallButton(
                                        Icons.delete,
                                        'حذف',
                                        Colors.red.shade800,
                                        () => _deleteAccount(
                                            sys, account['docId']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon,
      {TextEditingController? controller, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5E35B1)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildSmallButton(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(),
    );
  }
}
