import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_header.dart'; 

class AgentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> agentData; 

  const AgentProfileScreen({super.key, required this.agentData});

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // زدنا تبويب للشبكات
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<SystemProvider>(context);
    
    // بيانات الوكيل الحية من القائمة المركزية
    final liveAgent = provider.agentsList.firstWhere(
      (a) => a['phone'] == widget.agentData['phone'], 
      orElse: () => widget.agentData
    );

    final String agentName = liveAgent['name'] ?? 'غير معروف';
    final String nameInitial = agentName.trim().isNotEmpty ? agentName.trim().substring(0, 1) : '?';
    
    final List posList = liveAgent['posList'] ?? [];
    final List inventoryList = liveAgent['inventory'] ?? [];
    final double balance = double.parse((liveAgent['balance'] ?? 0).toString());
    final String agentPhone = liveAgent['phone'] ?? '';

    return Scaffold(
      appBar: const CustomHeader(title: 'الملف الشامل للوكيل'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // بطاقة هوية الوكيل العلوية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade900,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Text(nameInitial, style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(agentName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${liveAgent['networkName'] ?? 'بدون شبكة'} | الهاتف: ${liveAgent['phone']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.greenAccent, size: 16),
                            const SizedBox(width: 5),
                            Text('الرصيد: $balance ريال', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Chip(
                        label: Text(liveAgent['status'] ?? 'غير محدد', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: liveAgent['status'] == 'نشط' ? Colors.green : Colors.red,
                      ),
                    ],
                  )
                ],
              ),
            ),

            // شريط التبويبات مع إضافة "الشبكات"
            Container(
              color: Colors.transparent,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.analytics), text: 'نظرة عامة'),
                  Tab(icon: Icon(Icons.inventory_2), text: 'المخزون'),
                  Tab(icon: Icon(Icons.store), text: 'البقالات'),
                  Tab(icon: Icon(Icons.dns), text: 'الشبكات'),   // 🆕 تبويب الشبكات
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSalesOverviewTab(liveAgent),
                  _buildInventoryTab(inventoryList),
                  _buildPosTab(posList),
                  _buildNetworksTab(agentPhone),    // 🆕 محتوى تبويب الشبكات
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== تبويب الشبكات (الجديد) ==========
  Widget _buildNetworksTab(String agentPhone) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('networks')
          .where('agentPhone', isEqualTo: agentPhone)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dns_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text('لم يقم الوكيل بإضافة أي شبكة ميكروتك بعد.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final networks = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: networks.length,
          itemBuilder: (context, index) {
            final net = networks[index].data() as Map<String, dynamic>;
            final bool isActive = net['isActive'] ?? true;
            final String name = net['name'] ?? 'بدون اسم';
            final String location = net['location'] ?? 'غير محدد';
            final String ip = net['ip'] ?? 'غير محدد';
            final int catCount = (net['categories'] as List?)?.length ?? 0;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.router, color: isActive ? Colors.green : Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: isActive ? null : TextDecoration.lineThrough)),
                        ),
                        Chip(
                          label: Text(isActive ? 'نشط' : 'مجمد',
                              style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: isActive ? Colors.green : Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoRow(Icons.location_on, 'الموقع', location),
                    _infoRow(Icons.wifi, 'IP', ip),
                    _infoRow(Icons.category, 'عدد الفئات', '$catCount فئة'),
                    if (net['latitude'] != null && net['longitude'] != null)
                      _infoRow(Icons.map, 'الإحداثيات',
                          '${net['latitude'].toStringAsFixed(4)}, ${net['longitude'].toStringAsFixed(4)}'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  // ========== باقي التبويبات (كما هي دون تغيير) ==========
  Widget _buildSalesOverviewTab(Map<String, dynamic> agent) {
    final String profitMargin = agent['profitMargin'] ?? '0%';
    final int totalSales = agent['totalSales'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي الكروت المباعة', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 5),
                    Text('$totalSales كرت', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Icon(Icons.stacked_line_chart, color: Colors.white54, size: 40),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('تفاصيل إضافية:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatCard('نسبة عمولة النظام', profitMargin, Icons.percent, Colors.green)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('موقع الشبكة', agent['location'] ?? 'غير محدد', Icons.location_on, Colors.orange)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 10),
                Expanded(child: Text('سيتم تفعيل الإحصائيات المالية الدقيقة تلقائياً بمجرد بدء الوكيل في بيع الكروت للمستخدمين.', style: TextStyle(fontSize: 12, color: Colors.blue))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInventoryTab(List inventoryList) {
    if (inventoryList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text('لم يقم الوكيل برفع أي كروت للشبكة بعد.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inventoryList.length,
      itemBuilder: (context, index) {
        final cat = inventoryList[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(cat['name'] ?? 'فئة غير معروفة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    const Icon(Icons.category, color: Colors.blue),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('المتوفر حالياً', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text('${cat['available'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                      ],
                    ),
                    Container(height: 30, width: 1, color: Colors.grey.withOpacity(0.3)),
                    Column(
                      children: [
                        const Text('المباع', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text('${cat['sold'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
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
  }

  Widget _buildPosTab(List posList) {
    if (posList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text('لم يقم الوكيل بإضافة أي نقاط بيع (بقالات) حتى الآن.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posList.length,
      itemBuilder: (context, index) {
        final pos = posList[index];
        final List inventory = pos['inventory'] ?? [];

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile( 
            iconColor: Colors.blueAccent,
            collapsedIconColor: Colors.grey,
            title: Text(pos['name'] ?? 'بقالة غير معروفة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('الموقع: ${pos['location'] ?? 'غير محدد'} | المبيعات: ${pos['totalSales'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.store, color: Colors.white)),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تفاصيل الفئات المتوفرة في هذه النقطة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    if (inventory.isEmpty)
                      const Text('لا يوجد مخزون مخصص لهذه البقالة.', style: TextStyle(fontSize: 12, color: Colors.grey))
                    else
                      Table(
                        border: TableBorder.all(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1)),
                            children: const [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('الفئة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('متوفر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('مباع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                            ],
                          ),
                          ...inventory.map((inv) {
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(8.0), child: Text(inv['cat'] ?? 'فئة', style: const TextStyle(fontSize: 12))),
                                Padding(padding: const EdgeInsets.all(8.0), child: Text('${inv['available'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Padding(padding: const EdgeInsets.all(8.0), child: Text('${inv['sold'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
