import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection; 
import 'package:pdf/pdf.dart'; 
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart';

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
  // 1. نافذة طلب رصيد حقيقي 
  // ==========================================
  void _showRequestBalanceDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final activeBanks = sys.bankAccounts.where((bank) => bank['status'] == 'نشط').toList();
    
    String? selectedBank;
    if (activeBanks.isNotEmpty) selectedBank = activeBanks.first['bankName']; 

    final amountController = TextEditingController();
    final refController = TextEditingController();

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
                Text('الحد الأدنى: ${sys.minimumChargeLimit} ريال', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                
                if (activeBanks.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    decoration: const InputDecoration(labelText: 'البنك المُحوَّل إليه', border: OutlineInputBorder()),
                    items: activeBanks.map((bank) => DropdownMenuItem(value: bank['bankName'].toString(), child: Text(bank['bankName'].toString()))).toList(),
                    onChanged: (val) { _play('click'); selectedBank = val!; },
                  )
                else
                  const Text('لا توجد حسابات بنكية نشطة حالياً.', style: TextStyle(color: Colors.red)),
                
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
            TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: activeBanks.isEmpty ? null : () async {
                double amount = double.tryParse(amountController.text) ?? 0;
                double minLimit = double.tryParse(sys.minimumChargeLimit) ?? 0;

                if (amount < minLimit) {
                  _play('error');
                  _showSnack('المبلغ أقل من الحد الأدنى المسموح به ($minLimit)!', isErr: true);
                  return;
                }

                if (amount > 0 && refController.text.isNotEmpty && selectedBank != null) {
                  if (sys.isCurrencyAutoRounding) amount = amount.ceilToDouble();

                  await FirebaseFirestore.instance.collection('recharge_requests').add({
                    'agentPhone': sys.currentUserPhone,
                    'agentName': sys.currentUserName,
                    'amount': amount,
                    'bankName': selectedBank,
                    'reference': refController.text,
                    'status': 'قيد الانتظار',
                    'hasReceipt': false, // حقل جديد لمعرفة هل أرفق صورة أم لا
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    _play('success');
                    _showSnack('تم إرسال الطلب، وهو الآن قيد المراجعة ⏳');
                  }
                } else {
                  _play('error');
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
  // 2. تعديل طلب معلق
  // ==========================================
  void _editPendingRequest(String docId, double currentAmount) {
    _play('click');
    final amountController = TextEditingController(text: currentAmount.toString());
    
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل مبلغ الطلب'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ الجديد', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                double newAmount = double.tryParse(amountController.text) ?? 0;
                if (newAmount > 0) {
                  await FirebaseFirestore.instance.collection('recharge_requests').doc(docId).update({'amount': newAmount});
                  if (mounted) {
                    Navigator.pop(context);
                    _play('success');
                    _showSnack('تم تعديل المبلغ بنجاح ✅');
                  }
                }
              },
              child: const Text('حفظ التعديل'),
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. تحويل رصيد (مع نظام حماية 2FA - طلب كلمة المرور) 🛡️
  // ==========================================
  void _showTransferToSubAgentDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    String? selectedSubAgent;
    final amountController = TextEditingController();
    final passwordController = TextEditingController();

    // استخراج كلمة مرور الوكيل الحالي للتحقق
    final myData = sys.agentsList.firstWhere((a) => a['phone'] == sys.currentUserPhone, orElse: () => {});
    final myPassword = myData['password'] ?? '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تحويل رصيد (مؤمن) 🛡️', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSubAgent,
                  hint: const Text('اختر الوكيل المستلم'),
                  items: sys.agentsList.where((a) => a['phone'] != sys.currentUserPhone).map((a) {
                    return DropdownMenuItem<String>(value: a['phone'], child: Text(a['name']));
                  }).toList(),
                  onChanged: (val) { _play('click'); setStateDialog(() => selectedSubAgent = val); },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.send), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور (للتأكيد)', prefixIcon: Icon(Icons.lock, color: Colors.red), border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  
                  if (passwordController.text != myPassword) {
                    _play('error');
                    _showSnack('كلمة المرور غير صحيحة! ❌', isErr: true);
                    return;
                  }

                  if (selectedSubAgent != null && amount > 0 && amount <= sys.currentUserBalance) {
                    WriteBatch batch = FirebaseFirestore.instance.batch();
                    batch.update(FirebaseFirestore.instance.collection('users').doc(sys.currentUserPhone), {'balance': FieldValue.increment(-amount)});
                    batch.update(FirebaseFirestore.instance.collection('users').doc(selectedSubAgent), {'balance': FieldValue.increment(amount)});
                    
                    batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
                      'fromPhone': sys.currentUserPhone, 'toPhone': selectedSubAgent,
                      'amount': amount, 'type': 'transfer', 'title': 'تحويل رصيد صادر', 'timestamp': FieldValue.serverTimestamp()
                    });

                    await batch.commit();
                    if (mounted) {
                      Navigator.pop(context);
                      _play('success');
                      _showSnack('تم التحويل بنجاح! 🎉');
                    }
                  } else {
                    _play('error');
                    _showSnack('المبلغ غير متاح أو البيانات ناقصة!', isErr: true);
                  }
                },
                child: const Text('تأكيد وإرسال', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 4. كشف حساب الوكيل (PDF) 📄
  // ==========================================
  Future<void> _generateMyStatement(SystemProvider sys, List<Map<String, dynamic>> realTransactions) async {
    _play('click');
    _showSnack('جاري تجهيز كشف الحساب... ⏳');
    
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl, 
        theme: pw.ThemeData.withFont(base: arabicFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('كشف حسابي - محفظة الوكيل', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),
              pw.Text('الاسم: ${sys.currentUserName}'),
              pw.Text('رقم الحساب: ${sys.currentUserPhone}'),
              pw.Text('الرصيد الحالي: ${sys.currentUserBalance} ريال'),
              pw.Text('تاريخ الكشف: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(font: arabicFont, fontWeight: pw.FontWeight.bold),
                cellStyle: pw.TextStyle(font: arabicFont),
                cellAlignment: pw.Alignment.center,
                data: <List<String>>[
                  <String>['التاريخ', 'البيان', 'المبلغ', 'النوع'], 
                  ...realTransactions.map((item) {
                    DateTime date = item['timestamp'] != null ? (item['timestamp'] as Timestamp).toDate() : DateTime.now();
                    bool isPlus = item['type'] == 'income' || item['type'] == 'deposit';
                    return [
                      DateFormat('yyyy-MM-dd HH:mm').format(date),
                      item['title'] ?? 'عملية',
                      item['amount'].toString(),
                      isPlus ? 'إيداع/أرباح (+)' : 'خصم/سحب (-)'
                    ];
                  })
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'My_Statement_${sys.currentUserPhone}.pdf');
    _play('success');
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // فلترة العمليات الخاصة بالوكيل
    final List<Map<String, dynamic>> realTransactions = sys.transactionsLedger.where((t) {
      if (t['agentPhone'] != sys.currentUserPhone && t['fromPhone'] != sys.currentUserPhone) return false;
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'إيداع/أرباح' && (t['type'] == 'income' || t['type'] == 'deposit')) return true;
      if (_selectedFilter == 'سحب/مصروفات' && (t['type'] == 'expense' || t['type'] == 'transfer')) return true;
      return false;
    }).toList();

    // 📊 حساب إحصائيات الدخل والمصروفات للشريط الذكي
    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in realTransactions) {
      double amt = double.tryParse(t['amount'].toString()) ?? 0;
      if (t['type'] == 'income' || t['type'] == 'deposit') {
        totalIncome += amt;
      } else {
        totalExpense += amt;
      }
    }
    double totalVolume = totalIncome + totalExpense;
    int incomeFlex = totalVolume == 0 ? 50 : ((totalIncome / totalVolume) * 100).toInt();
    int expenseFlex = totalVolume == 0 ? 50 : 100 - incomeFlex;

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
            // ==========================================
            // ترويسة الرصيد والإحصائيات البصرية
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 25, left: 25, right: 25, bottom: 15),
              decoration: BoxDecoration(
                color: isDark ? Colors.blueGrey.shade900 : Colors.teal.shade700,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
              ),
              child: Column(
                children: [
                  const Text('رصيدك المتاح', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text('${sys.currentUserBalance.toStringAsFixed(2)} ريال', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  // 📊 شريط الإحصائيات الذكي
                  Row(
                    children: [
                      const Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 14),
                      Text(' إيداع: ${totalIncome.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                      const Spacer(),
                      Text('سحب: ${totalExpense.toStringAsFixed(0)} ', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      const Icon(Icons.arrow_downward, color: Colors.redAccent, size: 14),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        Expanded(flex: incomeFlex > 0 ? incomeFlex : 1, child: Container(height: 6, color: Colors.greenAccent)),
                        Expanded(flex: expenseFlex > 0 ? expenseFlex : 1, child: Container(height: 6, color: Colors.redAccent)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickBtn(Icons.add_to_photos, 'طلب رصيد', Colors.green, _showRequestBalanceDialog),
                      _buildQuickBtn(Icons.swap_horiz, 'تحويل رصيد', Colors.orange, _showTransferToSubAgentDialog),
                      _buildQuickBtn(Icons.picture_as_pdf, 'كشف حساب', Colors.blue, () => _generateMyStatement(sys, realTransactions)),
                    ],
                  )
                ],
              ),
            ),
            
            // ==========================================
            // متتبع الطلبات المعلقة (Stream الحي) ⏳
            // ==========================================
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('recharge_requests')
                  .where('agentPhone', isEqualTo: sys.currentUserPhone)
                  .where('status', isEqualTo: 'قيد الانتظار')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                
                return Container(
                  color: Colors.orange.shade50,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: snapshot.data!.docs.map((doc) {
                      var req = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const CircularProgressIndicator(color: Colors.orange),
                        title: Text('طلب شحن بقيمة: ${req['amount']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('قيد المراجعة من الإدارة الماليـة ⏳', style: TextStyle(color: Colors.orange, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                              onPressed: () => _editPendingRequest(doc.id, double.tryParse(req['amount'].toString()) ?? 0),
                              tooltip: 'تعديل المبلغ',
                            ),
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.teal, size: 20),
                              onPressed: () { _play('click'); _showSnack('سيتم فتح الكاميرا لإرفاق السند قريباً 📸'); },
                              tooltip: 'إرفاق السند',
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                              onPressed: () async {
                                _play('click');
                                await FirebaseFirestore.instance.collection('recharge_requests').doc(doc.id).delete();
                                _showSnack('تم إلغاء الطلب.', isErr: true);
                              },
                              tooltip: 'إلغاء الطلب',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            // ==========================================
            // الفلتر والسجل
            // ==========================================
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPlus ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              child: Icon(isPlus ? Icons.arrow_downward : Icons.arrow_upward, color: isPlus ? Colors.green : Colors.red),
                            ),
                            title: Text(txn['title'] ?? 'عملية مالية', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(txn['timestamp'] != null ? DateFormat('yyyy-MM-dd hh:mm a').format((txn['timestamp'] as Timestamp).toDate()) : 'الآن', style: const TextStyle(fontSize: 12)),
                            trailing: Text('${isPlus ? '+' : '-'}${txn['amount']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isPlus ? Colors.green : Colors.red), textDirection: TextDirection.ltr),
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
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          CircleAvatar(backgroundColor: Colors.white24, radius: 25, child: Icon(icon, color: Colors.white)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
