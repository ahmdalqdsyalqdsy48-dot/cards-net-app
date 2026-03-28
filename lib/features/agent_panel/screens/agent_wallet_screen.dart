import 'package:flutter/material.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentWalletScreen extends StatefulWidget {
  const AgentWalletScreen({super.key});

  @override
  State<AgentWalletScreen> createState() => _AgentWalletScreenState();
}

class _AgentWalletScreenState extends State<AgentWalletScreen> {
  final double _currentBalance = 125000.0;
  String _selectedFilter = 'الكل'; 

  final List<Map<String, dynamic>> _transactions = [
    {'id': '1', 'title': 'بيع كاشير مباشر (5 كروت)', 'amount': 2500.0, 'type': 'income', 'date': 'اليوم 10:30 ص'},
    {'id': '2', 'title': 'تغذية بقالة (سوبر ماركت النور)', 'amount': 20000.0, 'type': 'expense', 'date': 'اليوم 09:15 ص'},
    {'id': '3', 'title': 'استلام رصيد من الإدارة', 'amount': 50000.0, 'type': 'income', 'date': 'أمس 08:00 م'},
    {'id': '4', 'title': 'تسديد دفعة للإدارة', 'amount': 10000.0, 'type': 'expense', 'date': 'أمس 04:20 م'},
    {'id': '5', 'title': 'بيع كاشير مباشر (1 كرت)', 'amount': 1000.0, 'type': 'income', 'date': '23 أكتوبر 02:10 م'},
  ];

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredTransactions = _transactions.where((txn) {
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'إيداع/أرباح' && txn['type'] == 'income') return true;
      if (_selectedFilter == 'سحب/مصروفات' && txn['type'] == 'expense') return true;
      return false;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        // 👇 تم إضافة القائمة الجانبية هنا
        drawer: const CustomAgentDrawer(
          agentName: 'شبكة الصقر للواي فاي',
          phoneNumber: '777777777',
          role: 'وكيل معتمد (Agent)',
          currentBalance: 125000.0,
        ),
        appBar: AppBar(
          title: const Text('المركز المالي والمحفظة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, top: 20, right: 20, left: 20),
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickActionButton(Icons.add_circle, 'طلب رصيد', Colors.green, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم فتح نافذة لطلب رصيد من الإدارة')));
                      }),
                      _buildQuickActionButton(Icons.send, 'تحويل لبقالة', Colors.orange, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى التوجه لشاشة إدارة البقالات للتحويل')));
                      }),
                      _buildQuickActionButton(Icons.payment, 'تسديد دين', Colors.blue, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نافذة تسديد الديون للإدارة')));
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('سجل العمليات الأخير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                  DropdownButton<String>(
                    value: _selectedFilter,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.filter_list, color: Colors.teal),
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                    items: ['الكل', 'إيداع/أرباح', 'سحب/مصروفات'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedFilter = newValue!;
                      });
                    },
                  ),
                ],
              ),
            ),
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
                              backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
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

  Widget _buildQuickActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 22,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
