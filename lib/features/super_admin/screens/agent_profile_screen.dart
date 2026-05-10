import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_header.dart';

class AgentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> agentData;
  const AgentProfileScreen({super.key, required this.agentData});
  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // فلاتر التبويب الأول
  String _overviewFilter = 'اليوم';
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- دوال مساعدة للتاريخ ---
  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_overviewFilter) {
      case 'اليوم':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );
      case 'الأسبوع':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: now,
        );
      case 'الشهر':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case 'مخصص':
        if (_customStart != null && _customEnd != null) {
          return DateTimeRange(start: _customStart!, end: _customEnd!);
        }
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      default:
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
    }
  }

  // --- بناء شريط الفلاتر الزمنية ---
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterChip('اليوم'),
          const SizedBox(width: 8),
          _filterChip('الأسبوع'),
          const SizedBox(width: 8),
          _filterChip('الشهر'),
          const SizedBox(width: 8),
          _filterChip('مخصص'),
          if (_overviewFilter == 'مخصص')
            TextButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('ar'),
                );
                if (picked != null) {
                  setState(() {
                    _customStart = picked.start;
                    _customEnd = picked.end;
                  });
                }
              },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _customStart != null
                    ? '${DateFormat('MM/dd').format(_customStart!)} - ${DateFormat('MM/dd').format(_customEnd!)}'
                    : 'اختر التاريخ',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _overviewFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _overviewFilter = label;
          if (label != 'مخصص') {
            _customStart = null;
            _customEnd = null;
          }
        });
      },
      selectedColor: Colors.blue.shade100,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<SystemProvider>(context);

    final liveAgent = provider.agentsList.firstWhere(
      (a) => a['phone'] == widget.agentData['phone'],
      orElse: () => widget.agentData,
    );

    final String agentName = liveAgent['name'] ?? 'غير معروف';
    final String nameInitial = agentName.trim().isNotEmpty
        ? agentName.trim().substring(0, 1)
        : '?';
    final double balance =
        double.parse((liveAgent['balance'] ?? 0).toString());
    final String agentPhone = liveAgent['phone'] ?? '';

    return Scaffold(
      appBar: const CustomHeader(title: 'الملف الشامل للوكيل'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // بطاقة الهوية العلوية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade900,
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Text(nameInitial,
                        style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(agentName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '${liveAgent['networkName'] ?? 'بدون شبكة'} | الهاتف: ${liveAgent['phone']}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet,
                                color: Colors.greenAccent, size: 16),
                            const SizedBox(width: 5),
                            Text('الرصيد: $balance ريال',
                                style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Chip(
                        label: Text(liveAgent['status'] ?? 'غير محدد',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        backgroundColor: liveAgent['status'] == 'نشط'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ],
                  )
                ],
              ),
            ),

            // شريط التبويبات
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
                  Tab(icon: Icon(Icons.dns), text: 'الشبكات'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSalesOverviewTab(liveAgent),
                  _buildInventoryTab(liveAgent),
                  _buildPosTab(liveAgent),
                  _buildNetworksTab(agentPhone),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== تبويب نظرة عامة (مُطور بالكامل) ==========
  Widget _buildSalesOverviewTab(Map<String, dynamic> agent) {
    final range = _getDateRange();
    final String agentPhone = agent['phone'] ?? '';

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('transactions')
                .where('agentPhone', isEqualTo: agentPhone)
                .where('timestamp',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
                .where('timestamp',
                    isLessThanOrEqualTo: Timestamp.fromDate(range.end))
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final transactions = snapshot.data?.docs ?? [];

              // حساب الإحصاءات
              double totalSales = 0;
              int totalCards = 0;
              Map<String, double> categorySales = {};

              for (var doc in transactions) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['type'] == 'sale') {
                  totalSales += (data['amount'] ?? 0).toDouble();
                  totalCards += (data['quantity'] as int?) ?? 1;
                  final catName = data['categoryName'] ?? 'غير معروف';
                  categorySales[catName] =
                      (categorySales[catName] ?? 0) + (data['amount'] ?? 0).toDouble();
                }
              }

              // أفضل فئة
              String bestCategory = 'غير متوفر';
              double bestCatAmount = 0;
              categorySales.forEach((name, amt) {
                if (amt > bestCatAmount) {
                  bestCategory = name;
                  bestCatAmount = amt;
                }
              });

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بطاقات الإحصاءات
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'إجمالي المبيعات',
                            '${totalSales.toStringAsFixed(0)} ريال',
                            Icons.monetization_on,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'عدد الكروت المباعة',
                            '$totalCards كرت',
                            Icons.confirmation_number,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'أفضل فئة مبيعاً',
                            bestCategory,
                            Icons.star,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'عدد البقالات',
                            '${agent['posCount'] ?? 0}',
                            Icons.store,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // جدول الفئات
                    if (categorySales.isNotEmpty) ...[
                      const Text('توزيع المبيعات حسب الفئة:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey)),
                      const SizedBox(height: 10),
                      ...categorySales.entries.map((entry) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading:
                                const Icon(Icons.category, color: Colors.teal),
                            title: Text(entry.key),
                            trailing: Text(
                              '${entry.value.toStringAsFixed(0)} ريال',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                            ),
                          ),
                        );
                      }),
                    ],

                    if (categorySales.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('لا توجد مبيعات في هذه الفترة.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ========== تبويب المخزون (من networks) ==========
  Widget _buildInventoryTab(Map<String, dynamic> agent) {
    final String agentPhone = agent['phone'] ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('networks')
          .where('agentPhone', isEqualTo: agentPhone)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final networks = snapshot.data!.docs;
        if (networks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text('لم يقم الوكيل برفع أي كروت للشبكة بعد.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // جمع جميع الفئات من جميع الشبكات
        List<Map<String, dynamic>> allCategories = [];
        for (var net in networks) {
          final data = net.data() as Map<String, dynamic>;
          final cats = List<Map<String, dynamic>>.from(data['categories'] ?? []);
          for (var cat in cats) {
            if ((cat['isActive'] ?? true) == true) {
              allCategories.add(cat);
            }
          }
        }

        if (allCategories.isEmpty) {
          return const Center(
              child: Text('لا توجد فئات نشطة.',
                  style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allCategories.length,
          itemBuilder: (context, index) {
            final cat = allCategories[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat['name'] ?? 'فئة غير معروفة',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue)),
                        Icon(Icons.category,
                            color: Color(cat['color'] ?? Colors.blue.value)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('المخزون الحقيقي',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            Text('${cat['realStock'] ?? 0}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.green)),
                          ],
                        ),
                        Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.withOpacity(0.3)),
                        Column(
                          children: [
                            const Text('المخزون الوهمي',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            Text('${cat['simStock'] ?? 0}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.orange)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'السعة: ${cat['capacity']} | الوقت: ${cat['time']}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ========== تبويب البقالات (من users) ==========
  Widget _buildPosTab(Map<String, dynamic> agent) {
    final String agentPhone = agent['phone'] ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .where('role', isEqualTo: 'pos')
          .where('pos_agents', arrayContains: agentPhone)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posList = snapshot.data!.docs;
        if (posList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined,
                    size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text('لم يقم الوكيل بإضافة أي نقاط بيع (بقالات) حتى الآن.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posList.length,
          itemBuilder: (context, index) {
            final pos = posList[index].data() as Map<String, dynamic>;
            final String storeName = pos['storeName'] ?? 'بقالة غير معروفة';
            final String location =
                pos['location'] ?? 'غير محدد';
            final Map<String, dynamic> wallets = pos['wallets'] ?? {};
            final double walletBalance =
                (wallets[agentPhone] ?? 0.0).toDouble();
            final Map<String, dynamic> relations =
                pos['agent_relations'] ?? {};
            final Map<String, dynamic> myRel =
                relations[agentPhone] ?? {};
            final double creditLimit =
                (myRel['creditLimit'] ?? 0.0).toDouble();
            final String commission = myRel['commission'] ?? '0%';

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: ExpansionTile(
                iconColor: Colors.blueAccent,
                collapsedIconColor: Colors.grey,
                title: Text(storeName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(
                    'الموقع: $location | الرصيد: $walletBalance ريال',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.blueGrey)),
                leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.store, color: Colors.white)),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black12
                          : Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(Icons.money, 'الرصيد الحالي',
                            '$walletBalance ريال'),
                        _infoRow(Icons.credit_card, 'الحد الائتماني',
                            '$creditLimit ريال'),
                        _infoRow(Icons.percent, 'العمولة', commission),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ========== تبويب الشبكات ==========
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
                Icon(Icons.dns_outlined,
                    size: 80, color: Colors.grey.shade300),
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
            final int catCount =
                (net['categories'] as List?)?.length ?? 0;
            final double? lat = net['latitude']?.toDouble();
            final double? lng = net['longitude']?.toDouble();

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.router,
                            color: isActive ? Colors.green : Colors.grey,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: isActive
                                      ? null
                                      : TextDecoration.lineThrough)),
                        ),
                        Chip(
                          label: Text(isActive ? 'نشط' : 'مجمد',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white)),
                          backgroundColor:
                              isActive ? Colors.green : Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoRow(Icons.location_on, 'الموقع', location),
                    _infoRow(Icons.wifi, 'IP', ip),
                    _infoRow(
                        Icons.category, 'عدد الفئات', '$catCount فئة'),
                    if (lat != null && lng != null)
                      TextButton.icon(
                        onPressed: () => _showLocationMap(lat, lng, name),
                        icon: const Icon(Icons.map, size: 16),
                        label: const Text('عرض على الخريطة'),
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

  void _showLocationMap(double lat, double lng, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('موقع: $title'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  // --- ويدجت مساعدة ---
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          Expanded(
              child:
                  Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
