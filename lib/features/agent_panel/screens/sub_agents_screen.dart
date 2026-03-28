import 'package:flutter/material.dart';
import '../widgets/custom_agent_drawer.dart';

class SubAgentsScreen extends StatefulWidget {
  const SubAgentsScreen({super.key});

  @override
  State<SubAgentsScreen> createState() => _SubAgentsScreenState();
}

class _SubAgentsScreenState extends State<SubAgentsScreen> {
  double _agentWalletBalance = 125000.0;

  final List<Map<String, dynamic>> _subAgents = [
    {'id': '1', 'name': 'بقالة الأمانة', 'phone': '771234567', 'balance': 15000.0, 'status': 'نشط'},
    {'id': '2', 'name': 'مركز السعادة للجوالات', 'phone': '779876543', 'balance': 2500.0, 'status': 'نشط'},
    {'id': '3', 'name': 'سوبر ماركت النور', 'phone': '774455667', 'balance': 500.0, 'status': 'رصيد منخفض'},
  ];

  final List<Map<String, dynamic>> _pendingRequests = [
    {'id': 'req1', 'agentId': '3', 'agentName': 'سوبر ماركت النور', 'amount': 20000.0, 'date': 'منذ 10 دقائق'},
    {'id': 'req2', 'agentId': '2', 'agentName': 'مركز السعادة للجوالات', 'amount': 10000.0, 'date': 'منذ ساعتين'},
  ];

  void _showTransferModal(Map<String, dynamic> agent) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text('تغذية حساب: ${agent['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('محفظتك الحالية: $_agentWalletBalance ريال', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المراد تحويله (ريال)',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  if (amount > 0 && amount <= _agentWalletBalance) {
                    setState(() {
                      _agentWalletBalance -= amount;
                      agent['balance'] += amount; 
                      if (agent['balance'] > 1000) agent['status'] = 'نشط';
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحويل $amount ريال إلى ${agent['name']} بنجاح! ✅'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المبلغ غير صالح أو الرصيد غير كافٍ! ❌'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('تحويل الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddSubAgentModal() {
    String name = '', phone = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 16, right: 16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('إضافة نقطة بيع جديدة (بقالة) 🏪', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (val) => name = val,
                  decoration: InputDecoration(labelText: 'اسم البقالة / المحل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.storefront)),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) => phone = val,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'رقم الهاتف (لتسجيل الدخول)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.phone)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      if (name.isNotEmpty && phone.isNotEmpty) {
                        setState(() {
                          _subAgents.add({'id': DateTime.now().toString(), 'name': name, 'phone': phone, 'balance': 0.0, 'status': 'جديد'});
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة نقطة البيع بنجاح، يمكنهم الآن تسجيل الدخول! ✅'), backgroundColor: Colors.green));
                      }
                    },
                    child: const Text('حفظ وإضافة', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          // 👇 تم إضافة القائمة الجانبية هنا
          drawer: const CustomAgentDrawer(
            agentName: 'شبكة الصقر للواي فاي',
            phoneNumber: '777777777',
            role: 'وكيل معتمد (Agent)',
            currentBalance: 125000.0,
          ),
          appBar: AppBar(
            title: const Text('إدارة نقاط البيع (البقالات)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            backgroundColor: Colors.purple.shade800,
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.orange,
              indicatorWeight: 4,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              tabs: [
                Tab(icon: Icon(Icons.storefront), text: 'البقالات النشطة'),
                Tab(icon: Icon(Icons.notifications_active), text: 'طلبات الشحن'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildSubAgentsTab(),
              _buildPendingRequestsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubAgentsTab() {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _subAgents.length,
        itemBuilder: (context, index) {
          final agent = _subAgents[index];
          bool isLow = agent['balance'] < 1000;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.purple.withOpacity(0.1), radius: 25, child: const Icon(Icons.store, color: Colors.purple)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(agent['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('الهاتف: ${agent['phone']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: isLow ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          isLow ? 'رصيد منخفض' : 'نشط',
                          style: TextStyle(color: isLow ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الرصيد المتاح لديهم:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('${agent['balance']} ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isLow ? Colors.red : Colors.black87)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showTransferModal(agent),
                        icon: const Icon(Icons.add_card, size: 18, color: Colors.white),
                        label: const Text('تغذية الرصيد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubAgentModal,
        backgroundColor: Colors.purple.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة بقالة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPendingRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return const Center(child: Text('لا توجد طلبات شحن معلقة حالياً. 🎉', style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.orange.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.orange.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(request['agentName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(request['date'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('يطلب تغذية رصيد بمبلغ: ', style: TextStyle(fontSize: 14)),
                    Text('${request['amount']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() { _pendingRequests.removeAt(index); });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب.'), backgroundColor: Colors.red));
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        child: const Text('رفض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_agentWalletBalance >= request['amount']) {
                            setState(() {
                              _agentWalletBalance -= request['amount'];
                              var agent = _subAgents.firstWhere((a) => a['id'] == request['agentId']);
                              agent['balance'] += request['amount'];
                              if (agent['balance'] > 1000) agent['status'] = 'نشط';
                              _pendingRequests.removeAt(index);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الموافقة وتغذية الرصيد بنجاح ✅'), backgroundColor: Colors.green));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رصيدك لا يكفي لتلبية هذا الطلب!'), backgroundColor: Colors.red));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('موافقة وتحويل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
