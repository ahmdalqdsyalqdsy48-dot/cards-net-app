import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentClientListScreen extends StatefulWidget {
  const AgentClientListScreen({super.key});

  @override
  State<AgentClientListScreen> createState() => _AgentClientListScreenState();
}

class _AgentClientListScreenState extends State<AgentClientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _playSound() {
    Provider.of<UiProvider>(context, listen: false).playSound('click');
  }

  void _showClientDetails(Map<String, dynamic> client) {
    _playSound();
    final sys = Provider.of<SystemProvider>(context, listen: false);

    // استخراج البيانات قبل فتح النافذة لضمان عدم فقدانها
    final String clientPhone = client['phone'] ?? '';
    final String clientName = client['name'] ?? 'غير معروف';
    final String accountNumber =
        client['accountNumber']?.toString() ?? 'غير متوفر';
    final double balance = (client['wallets'] is Map
            ? (client['wallets'] as Map)[sys.currentUserPhone] ?? 0.0
            : 0.0)
        .toDouble();
    final String? storeName = client['role'] == 'pos'
        ? (client['storeName'] ?? 'غير محدد')
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        // استخدام StatefulBuilder منفصل لتجنب تداخل الحالة
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'تفاصيل العميل: $clientName',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _detailRow('رقم الحساب', accountNumber),
                    _detailRow(
                        'الرصيد لديّ', '${balance.toStringAsFixed(0)} ريال'),
                    if (storeName != null) _detailRow('المتجر', storeName),
                    const Divider(height: 24),
                    const Text('📜 آخر العمليات (مشتريات / تحويلات)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        // استخدام بيانات ثابتة لضمان استقرار الـ Stream
                        stream: FirebaseFirestore.instance
                            .collection('transactions')
                            .where('fromPhone', isEqualTo: clientPhone)
                            .where('agentPhone',
                                isEqualTo: sys.currentUserPhone)
                            .orderBy('timestamp', descending: true)
                            .limit(20)
                            .snapshots(),
                        builder: (context, txnSnapshot) {
                          if (txnSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final txns = txnSnapshot.data?.docs ?? [];
                          if (txns.isEmpty) {
                            return const Center(
                                child: Text('لا توجد عمليات سابقة',
                                    style: TextStyle(color: Colors.grey)));
                          }
                          return ListView.builder(
                            itemCount: txns.length,
                            itemBuilder: (context, i) {
                              final txn = txns[i].data()
                                  as Map<String, dynamic>;
                              final DateTime? ts =
                                  (txn['timestamp'] as Timestamp?)?.toDate();
                              final String timeStr = ts != null
                                  ? intl.DateFormat('yyyy/MM/dd - hh:mm a')
                                      .format(ts)
                                  : '';
                              final double amount =
                                  (txn['amount'] ?? 0.0).toDouble();
                              final String title =
                                  txn['title'] ?? 'عملية غير معروفة';
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  txn['type'] == 'sale'
                                      ? Icons.shopping_cart
                                      : Icons.swap_horiz,
                                  color: txn['type'] == 'sale'
                                      ? Colors.blue
                                      : Colors.orange,
                                ),
                                title: Text(title,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(timeStr,
                                    style: const TextStyle(fontSize: 11)),
                                trailing: Text(
                                  '${amount.toStringAsFixed(0)} ر.ي',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: amount > 0
                                          ? Colors.green
                                          : Colors.red),
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
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);

    final List<Map<String, dynamic>> clients = sys.usersList.where((user) {
      final wallets = user['wallets'] as Map<String, dynamic>? ?? {};
      return wallets.containsKey(sys.currentUserPhone);
    }).toList();

    final List<Map<String, dynamic>> posWithoutWallet =
        sys.usersList.where((user) {
      if (user['role'] != 'pos') return false;
      final agentRel =
          user['agent_relations'] as Map<String, dynamic>? ?? {};
      return agentRel.containsKey(sys.currentUserPhone) &&
          !(user['wallets'] as Map<String, dynamic>? ?? {})
              .containsKey(sys.currentUserPhone);
    }).toList();

    final Map<String, Map<String, dynamic>> mergedMap = {};
    for (var c in [...clients, ...posWithoutWallet]) {
      final phone = c['phone']?.toString() ?? '';
      if (phone.isNotEmpty) mergedMap[phone] = c;
    }
    final List<Map<String, dynamic>> allClients =
        mergedMap.values.toList();

    allClients.sort((a, b) => (a['name']?.toString() ?? '')
        .compareTo(b['name']?.toString() ?? ''));

    final filtered = _searchQuery.isEmpty
        ? allClients
        : allClients.where((c) {
            final name = c['name']?.toString().toLowerCase() ?? '';
            final acc =
                c['accountNumber']?.toString().toLowerCase() ?? '';
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || acc.contains(q);
          }).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'عملائي'),
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
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'ابحث عن عميل بالاسم أو رقم الحساب',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('عدد العملاء: ${filtered.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('لا يوجد عملاء مرتبطون بك بعد',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final client = filtered[index];
                        final clientName =
                            client['name'] ?? 'بدون اسم';
                        final accountNumber =
                            client['accountNumber']?.toString() ??
                                'غير متوفر';
                        final bool isPos = client['role'] == 'pos';
                        final double walletBalance =
                            (client['wallets'] is Map
                                    ? (client['wallets'] as Map)[sys
                                            .currentUserPhone] ??
                                        0.0
                                    : 0.0)
                                .toDouble();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  isPos ? Colors.teal : Colors.blue,
                              child: Icon(
                                isPos
                                    ? Icons.storefront
                                    : Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(clientName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('الحساب: $accountNumber'),
                                Text(
                                  'الرصيد لديّ: ${walletBalance.toStringAsFixed(0)} ريال',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.info_outline,
                                  color: Colors.teal),
                              onPressed: () =>
                                  _showClientDetails(client),
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
