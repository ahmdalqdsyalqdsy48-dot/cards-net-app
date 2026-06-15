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
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

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

  String _overviewFilter = 'اليوم';
  DateTime? _customStart;
  DateTime? _customEnd;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<UiProvider>().playSound('click');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _can(String permission) {
    final auth = context.read<AuthProvider>();
    return auth.currentUserRole == 'super_admin' || auth.hasPermission(permission);
  }

  void _showSnackBar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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

  Widget _buildFilterBar() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: 8),
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
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              color: isSelected ? colors.onPrimaryContainer : colors.onSurface,
              fontSize: isSmallScreen ? 12 : 14)),
      selected: isSelected,
      selectedColor: colors.primaryContainer,
      backgroundColor: colors.surfaceVariant.withOpacity(0.5),
      onSelected: (val) {
        context.read<UiProvider>().playSound('click');
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
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return TextButton.icon(
      onPressed: () async {
        context.read<UiProvider>().playSound('click');
        final picked = await showDatePicker(
          context: context,
          initialDate: current ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('ar'),
        );
        if (picked != null) onPick(picked);
      },
      icon: Icon(Icons.calendar_today, size: isSmallScreen ? 12 : 14, color: Theme.of(context).colorScheme.primary),
      label: Text(
        current != null ? DateFormat('yyyy/MM/dd', 'ar').format(current) : label,
        style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _timePickButton(String label, TimeOfDay? current, ValueChanged<TimeOfDay> onPick) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return TextButton.icon(
      onPressed: () async {
        context.read<UiProvider>().playSound('click');
        final picked = await showTimePicker(
          context: context,
          initialTime: current ?? TimeOfDay.now(),
        );
        if (picked != null) onPick(picked);
      },
      icon: Icon(Icons.access_time, size: isSmallScreen ? 12 : 14, color: Theme.of(context).colorScheme.primary),
      label: Text(
        current != null ? current.format(context) : label,
        style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadAgentExtraData(String phone) async {
    try {
      final netsSnap = await _db.collection('networks').where('agentPhone', isEqualTo: phone).get();
      final networks = netsSnap.docs.map((d) => d.data()).toList();
      final networkNames = networks.map((n) => n['name'] ?? 'بدون اسم').toList();
      final activeNetworks = networks.where((n) => n['isActive'] == true).length;

      final userDoc = await _db.collection('users').doc(phone).get();
      final userData = userDoc.data() ?? {};
      final accountNumber = userData['accountNumber'] as String?;
      final lastSeen = userData['lastSeen'];
      String lastSeenStr = 'غير معروف';
      if (lastSeen is Timestamp) {
        lastSeenStr = DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(lastSeen.toDate());
      }

      return {
        'networkNames': networkNames,
        'networkCount': networks.length,
        'activeNetworkCount': activeNetworks,
        'accountNumber': accountNumber,
        'lastSeen': lastSeenStr,
      };
    } catch (e) {
      return {
        'networkNames': [],
        'networkCount': 0,
        'activeNetworkCount': 0,
        'accountNumber': null,
        'lastSeen': 'غير معروف',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    final liveAgent = wallet.agentsList.firstWhere(
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
      appBar: const CustomHeader(title: 'الملف الشامل للوكيل'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: auth.currentUserRole == 'super_admin' ? 'مالك النظام' : 'موظف مخصص',
        balanceOrPoints: 'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 300));
          context.read<UiProvider>().playSound('success');
          _showSnackBar('تم تحديث الصفحة بنجاح ✅');
        },
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _loadAgentExtraData(agentPhone),
                  initialData: {
                    'networkNames': [],
                    'networkCount': 0,
                    'activeNetworkCount': 0,
                    'accountNumber': null,
                    'lastSeen': 'جار التحميل...',
                  },
                  builder: (context, snapshot) {
                    final extra = snapshot.data ?? {};
                    return _buildIdentityCard(
                      agentName,
                      nameInitial,
                      balance,
                      liveAgent,
                      extra,
                      isSmallScreen,
                    );
                  },
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: colors.primary,
                    unselectedLabelColor: colors.onSurfaceVariant,
                    indicatorColor: colors.primary,
                    indicatorWeight: 4,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 11 : 13),
                    tabs: [
                      Tab(icon: Icon(Icons.analytics, size: isSmallScreen ? 18 : 22), text: 'نظرة عامة'),
                      Tab(icon: Icon(Icons.inventory_2, size: isSmallScreen ? 18 : 22), text: 'المخزون'),
                      Tab(icon: Icon(Icons.store, size: isSmallScreen ? 18 : 22), text: 'البقالات'),
                      Tab(icon: Icon(Icons.receipt_long, size: isSmallScreen ? 18 : 22), text: 'المعاملات'),
                      Tab(icon: Icon(Icons.history, size: isSmallScreen ? 18 : 22), text: 'سجل التدقيق'),
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
              _buildTransactionsTab(agentPhone),
              _buildAuditLogTab(agentPhone),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityCard(String name, String initial, double balance, Map<String, dynamic> agent, Map<String, dynamic> extra, bool isSmallScreen) {
    final colors = Theme.of(context).colorScheme;
    final networkNames = (extra['networkNames'] as List?) ?? [];
    final networkCount = extra['networkCount'] as int? ?? 0;
    final accountNumber = extra['accountNumber'] as String?;
    final lastSeen = extra['lastSeen'] as String? ?? 'غير معروف';
    final profitMargin = agent['profitMargin'] ?? '0%';

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isSmallScreen ? 25 : 30,
                backgroundColor: colors.onPrimaryContainer.withOpacity(0.2),
                child: Text(initial,
                    style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 24,
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
                            fontSize: isSmallScreen ? 16 : 20,
                            fontWeight: FontWeight.bold)),
                    if (accountNumber != null)
                      Text('الحساب: $accountNumber',
                          style: TextStyle(color: colors.onPrimaryContainer.withOpacity(0.8), fontSize: isSmallScreen ? 11 : 13)),
                    Text('الهاتف: ${agent['phone']}',
                        style: TextStyle(color: colors.onPrimaryContainer.withOpacity(0.8), fontSize: isSmallScreen ? 11 : 13)),
                    Text('رسوم النظام: $profitMargin',
                        style: TextStyle(color: colors.onPrimaryContainer.withOpacity(0.8), fontSize: isSmallScreen ? 11 : 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet,
                            color: colors.primary, size: isSmallScreen ? 14 : 16),
                        const SizedBox(width: 5),
                        Text('الرصيد: $balance ريال',
                            style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 12 : 14)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                    vertical: isSmallScreen ? 4 : 6),
                decoration: BoxDecoration(
                  color: agent['status'] == 'نشط' ? Colors.green : colors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  agent['status'] ?? 'غير محدد',
                  style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.wifi, size: isSmallScreen ? 14 : 16, color: colors.onPrimaryContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  networkNames.isNotEmpty
                      ? networkNames.take(3).join(' | ')
                      : 'لم يضف شبكات بعد',
                  style: TextStyle(color: colors.onPrimaryContainer, fontSize: isSmallScreen ? 11 : 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (networkCount > 3)
                Text(' +${networkCount - 3}',
                    style: TextStyle(color: colors.onPrimaryContainer, fontSize: isSmallScreen ? 10 : 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.login, size: isSmallScreen ? 14 : 16, color: colors.onPrimaryContainer),
              const SizedBox(width: 6),
              Text('آخر دخول: $lastSeen',
                  style: TextStyle(color: colors.onPrimaryContainer.withOpacity(0.8), fontSize: isSmallScreen ? 10 : 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesOverviewTab(Map<String, dynamic> agent) {
    final range = _getDateRange();
    final String agentPhone = agent['phone'] ?? '';
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        _buildFilterBar(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _exportReport(agent, range, 'pdf'),
                icon: Icon(Icons.picture_as_pdf, size: isSmallScreen ? 16 : 18, color: colors.primary),
                label: Text('PDF', style: TextStyle(fontSize: isSmallScreen ? 11 : 13, color: colors.primary)),
              ),
              TextButton.icon(
                onPressed: () => _exportReport(agent, range, 'print'),
                icon: Icon(Icons.print, size: isSmallScreen ? 16 : 18, color: colors.primary),
                label: Text('طباعة', style: TextStyle(fontSize: isSmallScreen ? 11 : 13, color: colors.primary)),
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
                .limit(500)
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
                  String buyer = data['fromPhone'] ?? '';
                  posSales[buyer] = (posSales[buyer] ?? 0) + (data['amount'] ?? 0).toDouble();
                }
              }

              String bestCategory = 'غير متوفر';
              double bestCatAmount = 0;
              categorySales.forEach((name, amt) {
                if (amt > bestCatAmount) {
                  bestCategory = name;
                  bestCatAmount = amt;
                }
              });

              // 🆕 إذا لم تكن هناك أي معاملات على الإطلاق، نعرض رسالة واضحة
              if (transactions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'لا توجد أي معاملات مالية لهذا الوكيل في هذه الفترة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: isSmallScreen ? 12 : 14),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('إجمالي المبيعات', '${totalSales.toStringAsFixed(0)} ريال', Icons.monetization_on, colors.primary, isSmallScreen)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard('عدد الكروت المباعة', '$totalCards كرت', Icons.confirmation_number, colors.tertiary, isSmallScreen)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('أفضل فئة مبيعاً', bestCategory, Icons.star, Colors.amber.shade700, isSmallScreen)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard('عدد البقالات', '${posSales.length}', Icons.store, colors.secondary, isSmallScreen)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (posSales.isNotEmpty)
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('مبيعات البقالات', '${posSales.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)} ريال', Icons.store_mall_directory, colors.primary, isSmallScreen)),
                        ],
                      ),
                    const SizedBox(height: 20),
                    if (categorySales.isNotEmpty) ...[
                      Text('توزيع المبيعات حسب الفئة:', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface, fontSize: isSmallScreen ? 14 : 16)),
                      const SizedBox(height: 10),
                      ...categorySales.entries.map((entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: colors.surface,
                            child: ListTile(
                              leading: Icon(Icons.category, color: colors.primary, size: isSmallScreen ? 20 : 24),
                              title: Text(entry.key, style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: colors.onSurface)),
                              trailing: Text('${entry.value.toStringAsFixed(0)} ريال',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 12 : 14, color: colors.primary)),
                            ),
                          )),
                    ],
                    if (categorySales.isEmpty && posSales.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('لا توجد مبيعات في هذه الفترة.',
                              style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: isSmallScreen ? 12 : 14)),
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

  Widget _buildInventoryTab(Map<String, dynamic> agent) {
    final String agentPhone = agent['phone'] ?? '';
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('networks').where('agentPhone', isEqualTo: agentPhone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildSkeletonLoader();
        if (snapshot.hasError) return _buildErrorWidget('تعذر تحميل المخزون');
        final networks = snapshot.data!.docs;
        if (networks.isEmpty) return _buildEmptyState(Icons.inventory_2_outlined, 'لم يقم الوكيل برفع أي كروت.');

        // 🆕 تجميع الفئات مع اسم الشبكة
        List<Map<String, dynamic>> allCategoriesWithNetwork = [];
        for (var net in networks) {
          final data = net.data() as Map<String, dynamic>;
          final networkName = data['name'] ?? 'شبكة بدون اسم';
          final cats = List<Map<String, dynamic>>.from(data['categories'] ?? []);
          for (var cat in cats) {
            if ((cat['isActive'] ?? true) == true) {
              cat['networkName'] = networkName;
              allCategoriesWithNetwork.add(cat);
            }
          }
        }
        if (allCategoriesWithNetwork.isEmpty) return _buildEmptyState(Icons.inventory_2_outlined, 'لا توجد فئات نشطة.');

        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          itemCount: allCategoriesWithNetwork.length,
          itemBuilder: (context, index) {
            final cat = allCategoriesWithNetwork[index];
            final networkName = cat['networkName'] ?? 'غير معروف';
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              color: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat['name'] ?? 'فئة غير معروفة',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 14 : 16, color: colors.primary)),
                              Text('الشبكة: $networkName',
                                  style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: colors.onSurface.withOpacity(0.6))),
                            ],
                          ),
                        ),
                        Icon(Icons.category, color: Color(cat['color'] ?? colors.primary.value), size: isSmallScreen ? 20 : 24),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [
                          Text('المخزون الحقيقي', style: TextStyle(color: colors.onSurface.withOpacity(0.7), fontSize: isSmallScreen ? 10 : 12)),
                          Text('${cat['realStock'] ?? 0}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 16 : 18, color: Colors.green)),
                        ]),
                        Column(children: [
                          Text('المخزون الوهمي', style: TextStyle(color: colors.onSurface.withOpacity(0.7), fontSize: isSmallScreen ? 10 : 12)),
                          Text('${cat['simStock'] ?? 0}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 16 : 18, color: Colors.orange)),
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

  Widget _buildPosTab(Map<String, dynamic> agent) {
    final String agentPhone = agent['phone'] ?? '';
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').where('role', isEqualTo: 'pos').where('pos_agents', arrayContains: agentPhone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildSkeletonLoader();
        if (snapshot.hasError) return _buildErrorWidget('تعذر تحميل البقالات');
        final posList = snapshot.data!.docs;
        if (posList.isEmpty) return _buildEmptyState(Icons.storefront_outlined, 'لا توجد بقالات.');

        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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
              color: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ExpansionTile(
                iconColor: colors.primary,
                collapsedIconColor: colors.onSurface,
                title: Text(storeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 14 : 16, color: colors.onSurface)),
                subtitle: Text('الموقع: $location | الرصيد: $walletBalance ريال',
                    style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: colors.onSurface.withOpacity(0.7))),
                leading: CircleAvatar(backgroundColor: colors.primary, radius: isSmallScreen ? 16 : 20, child: Icon(Icons.store, color: colors.onPrimary, size: isSmallScreen ? 16 : 20)),
                onExpansionChanged: (expanded) {
                  if (expanded) context.read<UiProvider>().playSound('click');
                },
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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

  Widget _buildTransactionsTab(String agentPhone) {
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('transactions')
          .where('agentPhone', isEqualTo: agentPhone)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeletonLoader();
        if (snapshot.hasError) return _buildErrorWidget('تعذر تحميل المعاملات');
        final transactions = snapshot.data?.docs ?? [];
        if (transactions.isEmpty) return _buildEmptyState(Icons.receipt_long, 'لا توجد معاملات مالية.');

        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index].data() as Map<String, dynamic>;
            final String type = tx['type'] ?? 'عملية';
            final String title = tx['title'] ?? '';
            final double amount = (tx['amount'] ?? 0).toDouble();
            final date = (tx['timestamp'] as Timestamp?)?.toDate();
            final String dateStr = date != null ? DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(date) : '';
            final bool isIncoming = type == 'deposit' || type == 'credit_refund';
            final Color txColor = type == 'sale' ? Colors.blue : (isIncoming ? Colors.green : colors.error);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: colors.surface,
              child: ListTile(
                leading: Icon(
                  isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                  color: txColor,
                  size: isSmallScreen ? 20 : 24,
                ),
                title: Text(title.isNotEmpty ? title : type,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 12 : 14, color: colors.onSurface)),
                subtitle: Text(dateStr,
                    style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: colors.onSurface.withOpacity(0.7))),
                trailing: Text(
                  '$amount ريال',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 12 : 14,
                    color: txColor,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuditLogTab(String agentPhone) {
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('audit_logs')
          .where('phone', isEqualTo: agentPhone)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeletonLoader();
        if (snapshot.hasError) return _buildErrorWidget('تعذر تحميل سجل التدقيق');
        final logs = snapshot.data?.docs ?? [];
        if (logs.isEmpty) return _buildEmptyState(Icons.history, 'لا يوجد سجل تدقيق.');

        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            final String action = log['action'] ?? 'عملية';
            final String details = log['details'] ?? '';
            final String date = log['datetime'] ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: colors.surface,
              child: ListTile(
                leading: Icon(Icons.receipt_long, color: colors.primary, size: isSmallScreen ? 18 : 20),
                title: Text(action, style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: colors.onSurface)),
                subtitle: Text('$details\n$date', style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: colors.onSurface.withOpacity(0.7))),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportReport(Map<String, dynamic> agent, DateTimeRange range, String mode) async {
    context.read<UiProvider>().playSound('click');
    final pdf = await _generatePdf(agent, range);
    if (mode == 'pdf') {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/تقرير_الوكيل.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], subject: 'تقرير الوكيل');
    } else if (mode == 'print') {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    }
    context.read<UiProvider>().playSound('success');
    _showSnackBar(mode == 'pdf' ? 'تم تحميل التقرير ✅' : 'تم فتح نافذة الطباعة ✅');
  }

  Future<pw.Document> _generatePdf(Map<String, dynamic> agent, DateTimeRange range) async {
    final pdf = pw.Document();
    final transactions = await _fetchTransactions(agent['phone'] ?? '', range);
    double totalSales = 0; int totalCards = 0;
    for (var t in transactions) {
      if (t['type'] == 'sale') {
        totalSales += (t['amount'] ?? 0).toDouble();
        totalCards += (t['quantity'] as int?) ?? 1;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('تقرير مبيعات الوكيل', textDirection: pw.TextDirection.rtl)),
          pw.Text('الوكيل: ${agent['name']}', textDirection: pw.TextDirection.rtl),
          pw.Text('الفترة: ${DateFormat('yyyy/MM/dd').format(range.start)} - ${DateFormat('yyyy/MM/dd').format(range.end)}', textDirection: pw.TextDirection.rtl),
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

  Widget _infoRow(IconData icon, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: isSmallScreen ? 12 : 14, color: colors.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: colors.onSurface, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: colors.onSurface))),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isSmallScreen) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 14 : 16, color: color)),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(title, style: TextStyle(fontSize: isSmallScreen ? 10 : 11, color: colors.onSurfaceVariant)),
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
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: isSmallScreen ? 60 : 80, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: isSmallScreen ? 12 : 14)),
      ]),
    );
  }

  void _showLocationMap(double lat, double lng, String title) {
    context.read<UiProvider>().playSound('click');
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
