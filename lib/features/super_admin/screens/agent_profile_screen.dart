import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_header.dart';

class AgentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> agentData;
  const AgentProfileScreen({super.key, required this.agentData});
  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  // فلاتر التبويب الأول (نظام متقدم)
  String _overviewFilter = 'اليوم';
  DateTime? _customStart;
  DateTime? _customEnd;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // عدد البقالات الحقيقي
  int _posCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- نطاق التاريخ المتقدم ---
  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_overviewFilter) {
      case 'اليوم':
        DateTime start = DateTime(now.year, now.month, now.day);
        if (_startTime != null) {
          start = DateTime(start.year, start.month, start.day,
              _startTime!.hour, _startTime!.minute);
        }
        DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        if (_endTime != null) {
          end = DateTime(end.year, end.month, end.day,
              _endTime!.hour, _endTime!.minute);
        }
        return DateTimeRange(start: start, end: end);
      case 'الأسبوع':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'الشهر':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'مخصص':
        if (_customStart != null && _customEnd != null) {
          DateTime start = _customStart!;
          DateTime end = _customEnd!;
          if (_startTime != null) {
            start = DateTime(start.year, start.month, start.day,
                _startTime!.hour, _startTime!.minute);
          }
          if (_endTime != null) {
            end = DateTime(end.year, end.month, end.day,
                _endTime!.hour, _endTime!.minute);
          }
          return DateTimeRange(start: start, end: end);
        }
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
      default:
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
    }
  }

  // --- بناء شريط الفلاتر (متقدم) ---
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _filterChip('اليوم'),
          const SizedBox(width: 6),
          _filterChip('الأسبوع'),
          const SizedBox(width: 6),
          _filterChip('الشهر'),
          const SizedBox(width: 6),
          _filterChip('مخصص'),
          if (_overviewFilter == 'مخصص') ...[
            const SizedBox(width: 8),
            _datePickButton('من', _customStart, (d) {
              setState(() => _customStart = d);
            }),
            const SizedBox(width: 4),
            _datePickButton('إلى', _customEnd, (d) {
              setState(() => _customEnd = d);
            }),
            const SizedBox(width: 8),
            _timePickButton('⏰', _startTime, (t) {
              setState(() => _startTime = t);
            }),
            const SizedBox(width: 4),
            _timePickButton('⏰', _endTime, (t) {
              setState(() => _endTime = t);
            }),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _overviewFilter == label;
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              color: isSelected ? colors.onPrimaryContainer : colors.onSurface)),
      selected: isSelected,
      selectedColor: colors.primaryContainer,
      backgroundColor: colors.surfaceVariant.withOpacity(0.5),
      onSelected: (val) {
        setState(() {
          _overviewFilter = label;
          if (label != 'مخصص') {
            _customStart = null;
            _customEnd = null;
            _startTime = null;
            _endTime = null;
          }
        });
      },
    );
  }

  Widget _datePickButton(String label, DateTime? current, ValueChanged<DateTime> onPick) {
    return TextButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: current ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('ar'),
        );
        if (picked != null) onPick(picked);
      },
      icon: Icon(Icons.calendar_today, size: 14, color: Theme.of(context).colorScheme.primary),
      label: Text(
        current != null ? DateFormat('yyyy/MM/dd', 'ar').format(current) : label,
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _timePickButton(String label, TimeOfDay? current, ValueChanged<TimeOfDay> onPick) {
    return TextButton.icon(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: current ?? TimeOfDay.now(),
        );
        if (picked != null) onPick(picked);
      },
      icon: Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.primary),
      label: Text(
        current != null ? current.format(context) : label,
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = Provider.of<SystemProvider>(context);

    final liveAgent = provider.agentsList.firstWhere(
      (a) => a['phone'] == widget.agentData['phone'],
      orElse: () => widget.agentData,
    );

    final String agentName = liveAgent['name'] ?? 'غير معروف';
    final String nameInitial = agentName.trim().isNotEmpty
        ? agentName.trim().substring(0, 1)
        : '?';
    final double balance = double.parse((liveAgent['balance'] ?? 0).toString());
    final String agentPhone = liveAgent['phone'] ?? '';

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text('الملف الشامل للوكيل',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              centerTitle: true,
              floating: true,
              pinned: false,
              snap: true,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              elevation: 0,
              expandedHeight: 0,
            ),
            SliverToBoxAdapter(
              child: _buildIdentityCard(agentName, nameInitial, balance, liveAgent),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelColor: colors.onPrimary,
                  unselectedLabelColor: colors.onSurface.withOpacity(0.7),
                  indicatorColor: colors.primary,
                  indicatorWeight: 4,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(icon: Icon(Icons.analytics, size: 22), text: 'نظرة عامة'),
                    Tab(icon: Icon(Icons.inventory_2, size: 22), text: 'المخزون'),
                    Tab(icon: Icon(Icons.store, size: 22), text: 'البقالات'),
                    Tab(icon: Icon(Icons.dns, size: 22), text: 'الشبكات'),
                    Tab(icon: Icon(Icons.history, size: 22), text: 'سجل العمليات'),
                  ],
                ),
                colors.surface,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSalesOverviewTab(liveAgent),
            _buildInventoryTab(liveAgent),
            _buildPosTab(liveAgent),
            _buildNetworksTab(agentPhone),
            _buildAuditLogTab(agentPhone),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(String name, String initial, double balance, Map<String, dynamic> agent) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: colors.onPrimaryContainer.withOpacity(0.2),
            child: Text(initial,
                style: TextStyle(
                    fontSize: 24,
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(
                    '${agent['networkName'] ?? 'بدون شبكة'} | الهاتف: ${agent['phone']}',
                    style: TextStyle(
                        color: colors.onPrimaryContainer, fontSize: 13)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: colors.primary, size: 16),
                    const SizedBox(width: 5),
                    Text('الرصيد: $balance ريال',
                        style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Chip(
            label: Text(agent['status'] ?? 'غير محدد',
                style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            backgroundColor: agent['status'] == 'نشط'
                ? Colors.green
                : Colors.red,
          ),
        ],
      ),
    );
  }

  // ========== تبويب نظرة عامة ==========
  Widget _buildSalesOverviewTab(Map<String, dynamic> agent) {
    final range = _getDateRange();
    final String agentPhone = agent['phone'] ?? '';
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildFilterBar(),
        // أزرار التقارير
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _printReport(agent, range),
                icon: Icon(Icons.print, color: colors.primary),
                label: Text('طباعة', style: TextStyle(color: colors.primary)),
              ),
              TextButton.icon(
                onPressed: () => _downloadReport(agent, range),
                icon: Icon(Icons.download, color: colors.primary),
                label: Text('تحميل PDF', style: TextStyle(color: colors.primary)),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('transactions')
                .where('agentPhone', isEqualTo: agentPhone)
                .where('timestamp',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
                .where('timestamp',
                    isLessThanOrEqualTo: Timestamp.fromDate(range.end))
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonLoader();
              }
              if (snapshot.hasError) {
                return _buildErrorWidget('تعذر تحميل المبيعات');
              }
              final transactions = snapshot.data?.docs ?? [];

              double totalSales = 0;
              int totalCards = 0;
              Map<String, double> categorySales = {};
              Map<String, double> posSales = {};

              for (var doc in transactions) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['type'] == 'sale') {
                  totalSales += (data['amount'] ?? 0).toDouble();
                  totalCards += (data['quantity'] as int?) ?? 1;
                  // استخراج اسم الفئة من title
                  String title = data['title'] ?? '';
                  String catName = 'فئة عامة';
                  if (title.contains(':') && title.contains('لـ')) {
                    int start = title.indexOf(':') + 1;
                    int end = title.indexOf('لـ');
                    if (start < end) {
                      catName = title.substring(start, end).trim();
                    }
                  }
                  categorySales[catName] = (categorySales[catName] ?? 0) + (data['amount'] ?? 0).toDouble();
                  // توزيع البقالات
                  String buyer = data['fromPhone'] ?? '';
                  posSales[buyer] = (posSales[buyer] ?? 0) + (data['amount'] ?? 0).toDouble();
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
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('إجمالي المبيعات', '${totalSales.toStringAsFixed(0)} ريال', Icons.monetization_on, colors.primary)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard('عدد الكروت المباعة', '$totalCards كرت', Icons.confirmation_number, colors.tertiary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('أفضل فئة مبيعاً', bestCategory, Icons.star, Colors.amber.shade700)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard('عدد البقالات', '$_posCount', Icons.store, colors.secondary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_posCount > 0)
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('إجمالي مبيعات البقالات', '${posSales.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)} ريال', Icons.store_mall_directory, colors.primary)),
                        ],
                      ),
                    const SizedBox(height: 20),
                    if (categorySales.isNotEmpty) ...[
                      Text('توزيع المبيعات حسب الفئة:', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                      const SizedBox(height: 10),
                      ...categorySales.entries.map((entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.category, color: colors.primary),
                              title: Text(entry.key, style: TextStyle(color: colors.onSurface)),
                              trailing: Text('${entry.value.toStringAsFixed(0)} ريال',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                            ),
                          )),
                    ],
                    if (posSales.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('مبيعات كل بقالة:', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                      const SizedBox(height: 10),
                      ...posSales.entries.map((entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.store, color: colors.secondary),
                              title: Text('بقالة ${entry.key}', style: TextStyle(color: colors.onSurface)),
                              trailing: Text('${entry.value.toStringAsFixed(0)} ريال',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                            ),
                          )),
                    ],
                    if (categorySales.isEmpty && posSales.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('لا توجد مبيعات في هذه الفترة.', style: TextStyle(color: colors.onSurface.withOpacity(0.6))),
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

  // ========== تبويب المخزون ==========
  Widget _buildInventoryTab(Map<String, dynamic> agent) {
    final String agentPhone = agent['phone'] ?? '';
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('networks').where('agentPhone', isEqualTo: agentPhone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildSkeletonLoader();
        if (snapshot.hasError) return _buildErrorWidget('تعذر تحميل المخزون');
        final networks = snapshot.data!.docs;
        if (networks.isEmpty) return _buildEmptyState(Icons.inventory_2_outlined, 'لم يقم الوكيل برفع أي كروت.');

        List<Map<String, dynamic>> allCategories = [];
        for (var net in networks) {
          final data = net.data() as Map<String, dynamic>;
          final cats = List<Map<String, dynamic>>.from(data['categories'] ?? []);
          for (var cat in cats) {
            if ((cat['isActive'] ?? true) == true) allCategories.add(cat);
          }
        }
        if (allCategories.isEmpty) return _buildEmptyState(Icons.inventory_2_outlined, 'لا توجد فئات نشطة.');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allCategories.length,
          itemBuilder: (context, index) {
            final cat = allCategories[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat['name'] ?? 'فئة غير معروفة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.primary)),
                        Icon(Icons.category, color: Color(cat['color'] ?? colors.primary.value)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [
                          Text('المخزون الحقيقي', style: TextStyle(color: colors.onSurface.withOpacity(0.7), fontSize: 12)),
                          Text('${cat['realStock'] ?? 0}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                        ]),
                        Column(children: [
                          Text('المخزون الوهمي', style: TextStyle(color: colors.onSurface.withOpacity(0.7), fontSize: 12)),
                          Text('${cat['simStock'] ?? 0}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                        ]),
                      ],
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

  // ========== تبويب البقالات ==========
  Widget _buildPosTab(Map<String, dynamic> agent) {
    final String agentPhone = agent['phone'] ?? '';
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').where('role', isEqualTo: 'pos').where('pos_agents', arrayContains: agentPhone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildSkeletonLoader();
        if (snapshot.hasError) return _buildErrorWidget('تعذر تحميل البقالات');
        final posList = snapshot.data!.docs;
        // تحديث عدد البقالات
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _posCount != posList.length) {
            setState(() => _posCount = posList.length);
          }
        });
        if (posList.isEmpty) return _buildEmptyState(Icons.storefront_outlined, 'لا توجد بقالات.');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posList.length,
          itemBuilder: (context, index) {
            final pos = posList[index].data() as Map<String, dynamic>;
            final String storeName = pos['storeName'] ?? 'بقالة غير معروفة';
            final String location = pos['location'] ?? 'غير محدد';
            final double walletBalance = ((pos['wallets'] ?? {})[agentPhone] ?? 0.0).toDouble();
            final double creditLimit = (((pos['agent_relations'] ?? {})[agentPhone] ?? {})['creditLimit'] ?? 0.0).toDouble();
            final String commission = ((pos['agent_relations'] ?? {})[agentPhone] ?? {})['commission'] ?? '0%';

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ExpansionTile(
                iconColor: colors.primary,
                collapsedIconColor: colors.onSurface,
                title: Text(storeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.onSurface)),
                subtitle: Text('الموقع: $location | الرصيد: $walletBalance ريال',
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.7))),
                leading: CircleAvatar(backgroundColor: colors.primary, child: Icon(Icons.store, color: colors.onPrimary)),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant.withOpacity(0.5),
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(Icons.money, 'الرصيد الحالي', '$walletBalance ريال'),
                        _infoRow(Icons.credit_card, 'الحد الائتماني', '$creditLimit ريال'),
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
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('networks').where('agentPhone', isEqualTo: agentPhone).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeletonLoader();
        if (snapshot.hasError) return _buildErrorWidget('تعذر تحميل الشبكات');
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return _buildEmptyState(Icons.dns_outlined, 'لا توجد شبكات ميكروتك.');

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
            final double? lat = net['latitude']?.toDouble();
            final double? lng = net['longitude']?.toDouble();

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
                        Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.onSurface))),
                        Chip(
                          label: Text(isActive ? 'نشط' : 'مجمد', style: TextStyle(fontSize: 11, color: colors.onPrimary)),
                          backgroundColor: isActive ? Colors.green : Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoRow(Icons.location_on, 'الموقع', location),
                    _infoRow(Icons.wifi, 'IP', ip),
                    _infoRow(Icons.category, 'عدد الفئات', '$catCount فئة'),
                    if (lat != null && lng != null)
                      TextButton.icon(
                        onPressed: () => _showLocationMap(lat, lng, name),
                        icon: Icon(Icons.map, size: 16, color: colors.primary),
                        label: Text('عرض على الخريطة', style: TextStyle(color: colors.primary)),
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

  // ========== تبويب سجل العمليات ==========
  Widget _buildAuditLogTab(String agentPhone) {
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('audit_logs')
          .where('phone', isEqualTo: agentPhone)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeletonLoader();
        if (snapshot.hasError) return _buildErrorWidget('تعذر تحميل سجل العمليات');
        final logs = snapshot.data?.docs ?? [];
        if (logs.isEmpty) return _buildEmptyState(Icons.history, 'لا يوجد سجل عمليات.');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            final String action = log['action'] ?? 'عملية';
            final String details = log['details'] ?? '';
            final String date = log['datetime'] ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.receipt_long, color: colors.primary),
                title: Text(action, style: TextStyle(color: colors.onSurface)),
                subtitle: Text('$details\n$date', style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.7))),
              ),
            );
          },
        );
      },
    );
  }

  // --- تقارير PDF ---
  Future<void> _printReport(Map<String, dynamic> agent, DateTimeRange range) async {
    final pdf = await _generatePdf(agent, range);
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _downloadReport(Map<String, dynamic> agent, DateTimeRange range) async {
    final pdf = await _generatePdf(agent, range);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/تقرير_الوكيل.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], subject: 'تقرير الوكيل');
  }

  Future<pw.Document> _generatePdf(Map<String, dynamic> agent, DateTimeRange range) async {
    final pdf = pw.Document();
    final transactions = await _fetchTransactions(agent['phone'] ?? '', range);
    // حساب إحصاءات مماثلة
    double totalSales = 0; int totalCards = 0;
    Map<String, double> catSales = {};
    for (var t in transactions) {
      if (t['type'] == 'sale') {
        totalSales += (t['amount'] ?? 0).toDouble();
        totalCards += (t['quantity'] as int?) ?? 1;
        String title = t['title'] ?? '';
        String cat = 'فئة عامة';
        if (title.contains(':') && title.contains('لـ')) {
          int s = title.indexOf(':') + 1;
          int e = title.indexOf('لـ');
          if (s < e) cat = title.substring(s, e).trim();
        }
        catSales[cat] = (catSales[cat] ?? 0) + (t['amount'] ?? 0).toDouble();
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('تقرير مبيعات الوكيل', textDirection: pw.TextDirection.rtl)),
          pw.Paragraph(text: 'الوكيل: ${agent['name']}', textDirection: pw.TextDirection.rtl),
          pw.Paragraph(text: 'الفترة: ${DateFormat('yyyy/MM/dd').format(range.start)} - ${DateFormat('yyyy/MM/dd').format(range.end)}', textDirection: pw.TextDirection.rtl),
          pw.Divider(),
          pw.Table(border: pw.TableBorder.all(), children: [
            pw.TableRow(children: [pw.Text('الإحصاء'), pw.Text('القيمة')]),
            pw.TableRow(children: [pw.Text('إجمالي المبيعات'), pw.Text('$totalSales ريال')]),
            pw.TableRow(children: [pw.Text('عدد الكروت'), pw.Text('$totalCards')]),
          ]),
        ],
      ),
    );
    return pdf;
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions(String agentPhone, DateTimeRange range) async {
    final snap = await _db
        .collection('transactions')
        .where('agentPhone', isEqualTo: agentPhone)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(range.end))
        .limit(200)
        .get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  // --- ودجات مساعدة ---
  Widget _infoRow(IconData icon, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, color: colors.onSurface, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: colors.onSurface))),
        ],
      ),
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

  Widget _buildSkeletonLoader() {
    return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 50, color: Colors.red.shade300),
        const SizedBox(height: 10),
        Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
      ]),
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      ]),
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
              options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15.0),
              children: [
                TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
                MarkerLayer(markers: [
                  Marker(point: LatLng(lat, lng), width: 40, height: 40,
                      child: Icon(Icons.location_pin, color: Colors.red, size: 40)),
                ]),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      ),
    );
  }
}

// --- Delegate لتثبيت TabBar داخل Sliver ---
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar, this.color);
  final TabBar _tabBar;
  final Color color;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: color, child: _tabBar);
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
