import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart'; // 👈 استدعاء الترويسة المخصصة
import '../widgets/custom_agent_drawer.dart';

class AgentWalletScreen extends StatefulWidget {
  const AgentWalletScreen({super.key});

  @override
  State<AgentWalletScreen> createState() => _AgentWalletScreenState();
}

class _AgentWalletScreenState extends State<AgentWalletScreen> {
  // 👇 قمنا بإزالة كلمة final لنتمكن من تحديث الرصيد عند القيام بعمليات
  double _currentBalance = 125000.0;
  String _selectedFilter = 'الكل'; 

  // قاعدة بيانات وهمية للبقالات التابعة لهذا الوكيل (تستخدم في نافذة التحويل)
  final List<String> _mySubAgents = ['بقالة الأمانة', 'مركز السعادة للجوالات', 'سوبر ماركت النور'];

  // السجل المالي (أصبح ديناميكياً لاستقبال العمليات الجديدة)
  final List<Map<String, dynamic>> _transactions = [
    {'id': '1', 'title': 'بيع كاشير مباشر (5 كروت)', 'amount': 2500.0, 'type': 'income', 'date': 'اليوم 10:30 ص'},
    {'id': '2', 'title': 'تغذية بقالة (سوبر ماركت النور)', 'amount': 20000.0, 'type': 'expense', 'date': 'اليوم 09:15 ص'},
    {'id': '3', 'title': 'استلام رصيد من الإدارة', 'amount': 50000.0, 'type': 'income', 'date': 'أمس 08:00 م'},
    {'id': '4', 'title': 'تسديد دفعة للإدارة', 'amount': 10000.0, 'type': 'expense', 'date': 'أمس 04:20 م'},
    {'id': '5', 'title': 'بيع كاشير مباشر (1 كرت)', 'amount': 1000.0, 'type': 'income', 'date': '23 أكتوبر 02:10 م'},
  ];

  // ==========================================
  // نافذة 1: طلب رصيد من الإدارة (تغذية المحفظة)
  // ==========================================
  void _showRequestBalanceDialog() {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('قم بإيداع المبلغ في حساباتنا أولاً، ثم قدم الطلب هنا.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedBank,
                  decoration: InputDecoration(labelText: 'البنك المُحوَّل إليه', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.account_balance)),
                  items: ['بنك الكريمي', 'محفظة جوالي', 'بنك التضامن'].map((bank) => DropdownMenuItem(value: bank, child: Text(bank))).toList(),
                  onChanged: (val) => selectedBank = val!,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'المبلغ المحول (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.attach_money)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'رقم السند / المرجع', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.receipt)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                if (amountController.text.isNotEmpty && refController.text.isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الطلب للإدارة بنجاح، يرجى الانتظار.'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة المبلغ ورقم المرجع!'), backgroundColor: Colors.red));
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
  // نافذة 2: تحويل رصيد إلى بقالة تابعة
  // ==========================================
  void _showTransferToSubAgentDialog() {
    String? selectedAgent;
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تحويل رصيد لبقالة', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedAgent,
                  hint: const Text('اختر البقالة'),
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.storefront)),
                  items: _mySubAgents.map((agent) => DropdownMenuItem(value: agent, child: Text(agent))).toList(),
                  onChanged: (val) => setStateDialog(() => selectedAgent = val),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'المبلغ المراد تحويله', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.money_off)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  if (selectedAgent != null && amount > 0) {
                    if (amount <= _currentBalance) {
                      setState(() {
                        // خصم من الرصيد الحي
                        _currentBalance -= amount;
                        // إضافة العملية للسجل ليراها الوكيل فوراً
                        _transactions.insert(0, {
                          'id': DateTime.now().toString(),
                          'title': 'تغذية بقالة ($selectedAgent)',
                          'amount': amount,
                          'type': 'expense',
                          'date': 'الآن',
                        });
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحويل $amount ريال إلى $selectedAgent بنجاح.'), backgroundColor: Colors.green));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رصيدك لا يكفي لإتمام التحويل!'), backgroundColor: Colors.red));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار البقالة وتحديد مبلغ صحيح!'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('تحويل', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // نافذة 3: تسديد دين للإدارة
  // ==========================================
  void _showPayDebtDialog() {
    final double currentDebt = 35000.0; // دين وهمي مسجل على الوكيل
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('تسديد المستحقات', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إجمالي الديون المستحقة للإدارة: $currentDebt ريال', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ المراد سداده الآن (من المحفظة)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.payment),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () {
                double amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0 && amount <= _currentBalance) {
                  setState(() {
                    _currentBalance -= amount;
                    _transactions.insert(0, {
                      'id': DateTime.now().toString(),
                      'title': 'تسديد دفعة دين للإدارة',
                      'amount': amount,
                      'type': 'expense',
                      'date': 'الآن',
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسديد الدفعة من محفظتك بنجاح.'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرصيد غير كافٍ أو المبلغ غير صحيح!'), backgroundColor: Colors.red));
                }
              },
              child: const Text('سداد', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // فلترة السجل المالي
    List<Map<String, dynamic>> filteredTransactions = _transactions.where((txn) {
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'إيداع/أرباح' && txn['type'] == 'income') return true;
      if (_selectedFilter == 'سحب/مصروفات' && txn['type'] == 'expense') return true;
      return false;
    }).toList();

    // 👇 التعديل الجذري: الـ Scaffold أصبح في الخارج ليحفظ اتجاه القائمة الجانبية (Drawer)
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'المركز المالي والمحفظة'),
      drawer: const CustomAgentDrawer(
        agentName: 'شبكة الصقر للواي فاي',
        phoneNumber: '777777777',
        role: 'وكيل معتمد (Agent)',
        currentBalance: 125000.0,
      ),
      // 👇 الأمر الخاص باللغة العربية تم نقله ليغطي المحتوى الداخلي فقط
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // الحاوية العلوية المنحنية (الرصيد والأزرار السريعة)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, top: 15, right: 20, left: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.teal.shade700,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  const Text('الرصيد المتاح حالياً', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(
                    '${_currentBalance.toStringAsFixed(0)} ريال',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // أزرار العمليات السريعة (تم ربطها بالدوال الحقيقية)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickActionButton(Icons.add_circle, 'طلب رصيد', Colors.green, _showRequestBalanceDialog),
                      _buildQuickActionButton(Icons.send, 'تحويل لبقالة', Colors.orange, _showTransferToSubAgentDialog),
                      _buildQuickActionButton(Icons.payment, 'تسديد دين', Colors.blue, _showPayDebtDialog),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            
            // شريط فلترة السجل المالي
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('سجل العمليات المالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300)
                    ),
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.filter_list, color: Colors.teal, size: 20),
                      style: TextStyle(color: isDark ? Colors.white : Colors.teal, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                      items: ['الكل', 'إيداع/أرباح', 'سحب/مصروفات'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedFilter = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // قائمة السجل المالي (Transactions List)
            Expanded(
              child: filteredTransactions.isEmpty
                  ? const Center(child: Text('لا توجد عمليات تطابق هذا الفلتر', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final txn = filteredTransactions[index];
                        final isIncome = txn['type'] == 'income';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              child: Icon(
                                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                            title: Text(txn['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(txn['date'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            trailing: Text(
                              '${isIncome ? '+' : '-'}${txn['amount']} ريال',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                              ),
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

  // أداة بناء الأزرار العلوية السريعة
  Widget _buildQuickActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 25, // تكبير الزر قليلاً لسهولة اللمس
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
