import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentWalletScreen extends StatefulWidget {
  const AgentWalletScreen({super.key});

  @override
  State<AgentWalletScreen> createState() => _AgentWalletScreenState();
}

class _AgentWalletScreenState extends State<AgentWalletScreen> {
  String _selectedFilter = 'الكل';

  void _showSnack(String m, {bool isErr = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m, textDirection: TextDirection.rtl), backgroundColor: isErr ? Colors.red : Colors.green)
    );
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // نافذة 1: طلب رصيد حقيقي من الإدارة
  // ==========================================
  void _showRequestBalanceDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    String selectedBank = 'بنك الكريمي';
    final TextEditingController amountController = TextEditingController();
    final TextEditingController refController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('طلب تغذية رصيد', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الحد الأدنى للطلب: ${sys.minimumChargeLimit} ريال', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedBank,
                  decoration: const InputDecoration(labelText: 'البنك المُحوَّل إليه', border: OutlineInputBorder()),
                  items: ['بنك الكريمي', 'محفظة جوالي', 'بنك التضامن', 'شركة النجم'].map((bank) => DropdownMenuItem(value: bank, child: Text(bank))).toList(),
                  onChanged: (val) => selectedBank = val!,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ المحول', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refController,
                  decoration: const InputDecoration(labelText: 'رقم المرجع / العملية', prefixIcon: Icon(Icons.receipt), border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                double amount = double.tryParse(amountController.text) ?? 0;
                double minLimit = double.tryParse(sys.minimumChargeLimit) ?? 0;

                // ⚖️ تطبيق سياسة الحد الأدنى للشحن
                if (amount < minLimit) {
                  _play('error');
                  _showSnack('عذراً، المبلغ أقل من الحد الأدنى المسموح به ($minLimit)!', isErr: true);
                  return;
                }

                if (amount > 0 && refController.text.isNotEmpty) {
                  // ⚖️ تطبيق جبر الكسور آلياً إذا كان مفعلاً
                  if (sys.isCurrencyAutoRounding) amount = amount.ceilToDouble();

                  // 🚀 إرسال الطلب الفعلي لقاعدة البيانات
                  await FirebaseFirestore.instance.collection('recharge_requests').add({
                    'agentPhone': sys.currentUserPhone,
                    'agentName': sys.currentUserName,
                    'amount': amount,
                    'bankName': selectedBank,
                    'reference': refController.text,
                    'status': 'قيد الانتظار',
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _play('success');
                  _showSnack('تم إرسال طلب الشحن للإدارة بنجاح. ✅');
                } else {
                  _showSnack('يرجى إكمال البيانات بشكل صحيح', isErr: true);
                }
              },
              child: const Text('تأكيد الطلب', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // نافذة 2: تحويل رصيد حقيقي للوكلاء الفرعيين
  // ==========================================
  void _showTransferToSubAgentDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    String? selectedSubAgent;
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تحويل رصيد فرعي', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSubAgent,
                  hint: const Text('اختر الوكيل المستلم'),
                  items: sys.agentsList.where((a) => a['phone'] != sys.currentUserPhone).map((a) {
                    return DropdownMenuItem<String>(value: a['phone'], child: Text(a['name']));
                  }).toList(),
                  onChanged: (val) => setStateDialog(() => selectedSubAgent = val),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.send), border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  if (selectedSubAgent != null && amount > 0 && amount <= sys.currentUserBalance) {
                    
                    // تنفيذ عملية التحويل في السيرفر (Atomic Transaction)
                    WriteBatch batch = FirebaseFirestore.instance.batch();
                    batch.update(FirebaseFirestore.instance.collection('users').doc(sys.currentUserPhone), {'balance': FieldValue.increment(-amount)});
                    batch.update(FirebaseFirestore.instance.collection('users').doc(selectedSubAgent), {'balance': FieldValue.increment(amount)});
                    
                    // تسجيل العملية
                    batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
                      'fromPhone': sys.currentUserPhone,
                      'toPhone': selectedSubAgent,
                      'amount': amount,
                      'type': 'transfer',
                      'title': 'تحويل رصيد بين وكلاء',
                      'timestamp': FieldValue.serverTimestamp()
                    });

                    await batch.commit();
                    Navigator.pop(context);
                    _play('success');
                    _showSnack('تم التحويل بنجاح! 🎉');
                  } else {
                    _play('error');
                    _showSnack('المبلغ غير متاح في رصيدك!', isErr: true);
                  }
                },
                child: const Text('إرسال الآن', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final ui = Provider.of<UiProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // جلب العمليات الحقيقية من السيرفر وفلترتها
    final List<Map<String, dynamic>> realTransactions = sys.transactionsLedger.where((t) {
      if (t['agentPhone'] != sys.currentUserPhone && t['fromPhone'] != sys.currentUserPhone) return false;
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'إيداع/أرباح' && (t['type'] == 'income' || t['type'] == 'deposit')) return true;
      if (_selectedFilter == 'سحب/مصروفات' && (t['type'] == 'expense' || t['type'] == 'transfer')) return true;
      return false;
    }).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'المحفظة المالية'),
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
            // ترويسة الرصيد
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: isDark ? Colors.blueGrey.shade900 : Colors.teal.shade700,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
              ),
              child: Column(
                children: [
                  const Text('رصيدك المتاح', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text('${sys.currentUserBalance.toStringAsFixed(2)} ريال', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickBtn(Icons.add_to_photos, 'طلب رصيد', Colors.green, _showRequestBalanceDialog),
                      _buildQuickBtn(Icons.swap_horiz, 'تحويل رصيد', Colors.orange, _showTransferToSubAgentDialog),
                      _buildQuickBtn(Icons.history_edu, 'كشف حساب', Colors.blue, () => _play('click')),
                    ],
                  )
                ],
              ),
            ),
            
            // الفلتر والسجل
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('العمليات الأخيرة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  _buildFilterDropdown(isDark),
                ],
              ),
            ),

            Expanded(
              child: realTransactions.isEmpty
                  ? const Center(child: Text('لا توجد عمليات مسجلة حالياً'))
                  : ListView.builder(
                      itemCount: realTransactions.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final txn = realTransactions[index];
                        bool isPlus = txn['type'] == 'income' || txn['type'] == 'deposit';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPlus ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              child: Icon(isPlus ? Icons.add : Icons.remove, color: isPlus ? Colors.green : Colors.red),
                            ),
                            title: Text(txn['title'] ?? 'عملية مالية'),
                            subtitle: Text(txn['timestamp'] != null ? (txn['timestamp'] as Timestamp).toDate().toString().substring(0, 16) : 'الآن'),
                            trailing: Text('${isPlus ? '+' : '-'}${txn['amount']} ر.ي', style: TextStyle(fontWeight: FontWeight.bold, color: isPlus ? Colors.green : Colors.red)),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickBtn(IconData icon, String label, Color col, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(backgroundColor: Colors.white24, radius: 25, child: Icon(icon, color: Colors.white)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButton<String>(
        value: _selectedFilter,
        underline: const SizedBox(),
        items: ['الكل', 'إيداع/أرباح', 'سحب/مصروفات'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (v) { _play('click'); setState(() => _selectedFilter = v!); },
      ),
    );
  }
}
