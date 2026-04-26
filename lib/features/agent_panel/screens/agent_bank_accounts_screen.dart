import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

  // ==================== 1. نافذة إضافة حساب جديد ====================
  void _showAddAccountDialog(SystemProvider provider) {
    _play(context, 'click');
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
                _buildTextField('اسم البنك / المحفظة', Icons.account_balance_wallet,
                    controller: bankNameController),
                _buildTextField('رقم الحساب / المحفظة', Icons.numbers,
                    controller: accountNumberController, isNumber: true),
                _buildTextField('الاسم الرباعي للمستفيد', Icons.person,
                    controller: beneficiaryController),
                _buildTextField('ملاحظات (اختياري)', Icons.notes,
                    controller: noteController),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E35B1).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF5E35B1).withOpacity(0.3)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.qr_code_scanner,
                          size: 40, color: Color(0xFF5E35B1)),
                      SizedBox(height: 5),
                      Text('يمكنك رفع صورة QR لاحقاً',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5E35B1))),
                      Text('تسهل على عملائك الدفع بالمسح',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
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
                    provider.currentUserNetwork,
                    provider.currentUserName,
                    bankNameController.text,
                    accountNumberController.text,
                    noteController.text,
                  )
                      .then((_) {
                    _play(context, 'success');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('تم حفظ الحساب بنجاح ✅',
                              textDirection: TextDirection.rtl),
                          backgroundColor: Colors.green));
                    }
                  }).catchError((e) {
                    _play(context, 'error');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('فشل الحفظ: $e',
                              textDirection: TextDirection.rtl),
                          backgroundColor: Colors.red));
                    }
                  });
                } else {
                  _play(context, 'error');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('يرجى إدخال اسم البنك ورقم الحساب',
                          textDirection: TextDirection.rtl),
                      backgroundColor: Colors.red));
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
                _buildTextField('اسم البنك / المحفظة', Icons.account_balance_wallet,
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
                  account['networkName'] ?? provider.currentUserNetwork,
                  account['agentName'] ?? provider.currentUserName,
                  bankNameController.text,
                  accountNumberController.text,
                  noteController.text,
                )
                    .then((_) {
                  _play(context, 'success');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('تم التعديل بنجاح ✏️',
                            textDirection: TextDirection.rtl),
                        backgroundColor: Colors.green));
                  }
                }).catchError((e) {
                  _play(context, 'error');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('فشل التعديل: $e',
                            textDirection: TextDirection.rtl),
                        backgroundColor: Colors.red));
                  }
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
      _play(context, 'success');
    }).catchError((e) {
      _play(context, 'error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('فشل تغيير الحالة: $e', textDirection: TextDirection.rtl),
            backgroundColor: Colors.red));
      }
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
          content:
              const Text('هل أنت متأكد من حذف هذا الحساب نهائياً من قاعدة البيانات؟'),
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
                  _play(context, 'success');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('تم الحذف بنجاح 🗑️',
                            textDirection: TextDirection.rtl),
                        backgroundColor: Colors.green));
                  }
                }).catchError((e) {
                  _play(context, 'error');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('فشل الحذف: $e', textDirection: TextDirection.rtl),
                        backgroundColor: Colors.red));
                  }
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم نسخ بيانات الحساب بنجاح، جاهزة للإرسال! 📋',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SystemProvider>(context);
    final accounts = provider.myAgentBankAccounts;

    return Scaffold(
      appBar: const CustomHeader(title: 'حساباتي البنكية'),
      drawer: CustomAgentDrawer(
        agentName: provider.currentUserName,
        phoneNumber: provider.currentUserPhone,
        role: 'وكيل معتمد',
        currentBalance: provider.currentUserBalance,
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
                  onPressed: () => _showAddAccountDialog(provider),
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
                          'يمكنك الضغط مطولاً على أي حساب وسحبه لإعادة ترتيب أولويات الظهور للعملاء.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF5E35B1)))),
                ],
              ),
            ),
            Expanded(
              child: accounts.isEmpty
                  ? const Center(
                      child: Text(
                          'لا توجد حسابات مضافة حالياً.\nاضغط على الزر أعلاه لإضافة حساب.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: accounts.length,
                      onReorder: (oldIndex, newIndex) {
                        provider.reorderAgentBankAccounts(oldIndex, newIndex);
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
                                                Text(
                                                    account['bankName'] ?? '',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color:
                                                            Color(0xFF5E35B1))),
                                                Text(
                                                    account['accountNumber'] ??
                                                        '',
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
                                      label: Text(
                                          account['status'] ?? '',
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
                                              provider, account),
                                        ),
                                        _buildSmallButton(
                                          isActive
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          isActive ? 'إيقاف' : 'تفعيل',
                                          isActive
                                              ? Colors.red
                                              : Colors.green,
                                          () => _toggleAccountStatus(
                                              provider, account),
                                        ),
                                        _buildSmallButton(
                                          Icons.delete,
                                          'حذف',
                                          Colors.red.shade800,
                                          () => _deleteAccount(
                                              provider, account['docId']),
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
