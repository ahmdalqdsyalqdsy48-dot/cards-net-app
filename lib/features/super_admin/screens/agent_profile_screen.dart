// lib/features/super_admin/screens/agent_profile_screen.dart

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

  final GlobalKey<_OverviewTabState> _overviewKey = GlobalKey();
  final GlobalKey<_InventoryTabState> _inventoryKey = GlobalKey();
  final GlobalKey<_PosTabState> _posKey = GlobalKey();
  final GlobalKey<_TransactionsTabState> _transactionsKey = GlobalKey();
  final GlobalKey<_AuditLogTabState> _auditLogKey = GlobalKey();

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
          _overviewKey.currentState?.refresh();
          _inventoryKey.currentState?.refresh();
          _posKey.currentState?.refresh();
          _transactionsKey.currentState?.refresh();
          _auditLogKey.currentState?.refresh();
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            context.read<UiProvider>().playSound('success');
            _showSnackBar('تم تحديث الصفحة بنجاح ✅');
          }
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
              OverviewTab(key: _overviewKey, agent: liveAgent, db: _db),
              InventoryTab(key: _inventoryKey, agent: liveAgent, db: _db),
              PosTab(key: _posKey, agent: liveAgent, db: _db),
              TransactionsTab(key: _transactionsKey, agentPhone: agentPhone, db: _db),
              AuditLogTab(key: _auditLogKey, agentPhone: agentPhone, db: _db),
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
}

// ==================== تبويب نظرة عامة ====================
class OverviewTab extends StatefulWidget {
  final Map<String, dynamic> agent;
  final FirebaseFirestore db;
  const OverviewTab({super.key, required this.agent, required this.db});
  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> with AutomaticKeepAliveClientMixin {
  String _filter = 'اليوم';
  DateTime? _customStart;
  DateTime? _customEnd;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _filterExpanded = false;

  @override
  bool get wantKeepAlive => true;

  void refresh() => setState(() {});

  DateTimeRange _getRange() {
    final now = DateTime.now();
    switch (_filter) {
      case 'اليوم':
        DateTime start = DateTime(now.year, now.month, now.day);
        if (_startTime != null) start = DateTime(start.year, start.month, start.day, _startTime!.hour, _startTime!.minute);
        DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        if (_endTime != null) end = DateTime(end.year, end.month, end.day, _endTime!.hour, _endTime!.minute);
        return DateTimeRange(start: start, end: end);
      case 'الأسبوع':
        final s = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: DateTime(s.year, s.month, s.day), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
      case 'الشهر':
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
      case 'مخصص':
        if (_customStart != null && _customEnd != null) {
          DateTime s = _customStart!;
          DateTime e = _customEnd!;
          if (_startTime != null) s = DateTime(s.year, s.month, s.day, _startTime!.hour, _startTime!.minute);
          if (_endTime != null) e = DateTime(e.year, e.month, e.day, _endTime!.hour, _endTime!.minute);
          return DateTimeRange(start: s, end: e);
        }
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
      case 'الكل':
        return DateTimeRange(start: DateTime(2020), end: DateTime(2030));
      default:
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final range = _getRange();
    final String agentPhone = widget.agent['phone'] ?? '';

    return Column(
      children: [
        // شريط الفلترة قابل للطي
        ExpansionTile(
          title: Text(_filter == 'الكل' ? 'عرض الكل' : 'الفترة: $_filter', style: TextStyle(color: colors.onSurface)),
          leading: Icon(Icons.filter_list, color: colors.primary),
          initiallyExpanded: _filterExpanded,
          onExpansionChanged: (v) => _filterExpanded = v,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: 8),
              child: Row(
                children: [
                  _chip('الكل'),
                  const SizedBox(width: 6),
                  _chip('اليوم'),
                  const SizedBox(width: 6),
                  _chip('الأسبوع'),
                  const SizedBox(width: 6),
                  _chip('الشهر'),
                  const SizedBox(width: 6),
                  _chip('مخصص'),
                  if (_filter == 'مخصص') ...[
                    const SizedBox(width: 8),
                    _dateBtn('من', _customStart, (d) => setState(() => _customStart = d)),
                    const SizedBox(width: 4),
                    _dateBtn('إلى', _customEnd, (d) => setState(() => _customEnd = d)),
                    const SizedBox(width: 8),
                    _timeBtn('⏰', _startTime, (t) => setState(() => _startTime = t)),
                    const SizedBox(width: 4),
                    _timeBtn('⏰', _endTime, (t) => setState(() => _endTime = t)),
                  ],
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: () => _export('pdf'),
              icon: Icon(Icons.picture_as_pdf, size: isSmallScreen ? 16 : 18, color: colors.primary),
              label: Text('PDF', style: TextStyle(fontSize: isSmallScreen ? 11 : 13, color: colors.primary)),
            ),
            TextButton.icon(
              onPressed: () => _export('print'),
              icon: Icon(Icons.print, size: isSmallScreen ? 16 : 18, color: colors.primary),
              label: Text('طباعة', style: TextStyle(fontSize: isSmallScreen ? 11 : 13, color: colors.primary)),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.db
                .collection('transactions')
                .where('agentPhone', isEqualTo: agentPhone)
                .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
                .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(range.end))
                .limit(500)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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
                    int s = title.indexOf(':') + 1;
                    int e = title.indexOf('لـ');
                    if (s < e) catName = title.substring(s, e).trim();
                  }
                  categorySales[catName] = (categorySales[catName] ?? 0) + (data['amount'] ?? 0).toDouble();
                  String buyer = data['fromPhone'] ?? '';
                  posSales[buyer] = (posSales[buyer] ?? 0) + (data['amount'] ?? 0).toDouble();
                }
              }

              String bestCat = 'غير متوفر';
              double bestAmt = 0;
              categorySales.forEach((k, v) { if (v > bestAmt) { bestCat = k; bestAmt = v; } });

              if (transactions.isEmpty) {
                return Center(
                  child: Text('لا توجد معاملات مالية لهذا الوكيل في الفترة المحددة.',
                      style: TextStyle(color: colors.onSurface.withOpacity(0.6))),
                );
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _card('إجمالي المبيعات', '${totalSales.toStringAsFixed(0)} ريال', Icons.monetization_on, colors.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _card('عدد الكروت', '$totalCards كرت', Icons.confirmation_number, colors.tertiary)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _card('أفضل فئة', bestCat, Icons.star, Colors.amber.shade700)),
                    const SizedBox(width: 10),
                    Expanded(child: _card('عدد البقالات', '${posSales.length}', Icons.store, colors.secondary)),
                  ]),
                  if (posSales.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(children: [
                        Expanded(child: _card('مبيعات البقالات', '${posSales.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)} ريال', Icons.store_mall_directory, colors.primary)),
                      ]),
                    ),
                  const SizedBox(height: 20),
                  if (categorySales.isNotEmpty) ...[
                    Text('المبيعات حسب الفئة:', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                    ...categorySales.entries.map((e) => Card(
                      color: colors.surface,
                      child: ListTile(
                        leading: Icon(Icons.category, color: colors.primary),
                        title: Text(e.key, style: TextStyle(color: colors.onSurface)),
                        trailing: Text('${e.value.toStringAsFixed(0)} ريال', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                      ),
                    )),
                  ],
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label) {
    final isSel = _filter == label;
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSel ? colors.onPrimaryContainer : colors.onSurface)),
      selected: isSel,
      selectedColor: colors.primaryContainer,
      onSelected: (_) => setState(() => _filter = label),
    );
  }

  Widget _dateBtn(String label, DateTime? d, ValueChanged<DateTime> onPick) {
    return TextButton.icon(
      onPressed: () async {
        final p = await showDatePicker(context: context, initialDate: d ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now(), locale: const Locale('ar'));
        if (p != null) onPick(p);
      },
      icon: Icon(Icons.calendar_today, size: 14, color: Theme.of(context).colorScheme.primary),
      label: Text(d != null ? DateFormat('yyyy/MM/dd', 'ar').format(d) : label, style: TextStyle(fontSize: 12)),
    );
  }

  Widget _timeBtn(String label, TimeOfDay? t, ValueChanged<TimeOfDay> onPick) {
    return TextButton.icon(
      onPressed: () async {
        final p = await showTimePicker(context: context, initialTime: t ?? TimeOfDay.now());
        if (p != null) onPick(p);
      },
      icon: Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.primary),
      label: Text(t != null ? t.format(context) : label, style: TextStyle(fontSize: 12)),
    );
  }

  Widget _card(String title, String value, IconData icon, Color color) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(title, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
      ]),
    );
  }

  Future<void> _export(String mode) async {
    final pdf = pw.Document();
    final range = _getRange();
    final snap = await widget.db
        .collection('transactions')
        .where('agentPhone', isEqualTo: widget.agent['phone'] ?? '')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(range.end))
        .limit(200)
        .get();
    final txns = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    double sales = 0; int cards = 0;
    for (var t in txns) { if (t['type'] == 'sale') { sales += (t['amount'] ?? 0).toDouble(); cards += (t['quantity'] as int?) ?? 1; } }
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (ctx) => [
      pw.Header(level: 0, child: pw.Text('تقرير مبيعات', textDirection: pw.TextDirection.rtl)),
      pw.Text('الوكيل: ${widget.agent['name']}', textDirection: pw.TextDirection.rtl),
      pw.Text('الفترة: ${DateFormat('yyyy/MM/dd').format(range.start)} - ${DateFormat('yyyy/MM/dd').format(range.end)}', textDirection: pw.TextDirection.rtl),
      pw.Divider(),
      pw.Table(border: pw.TableBorder.all(), children: [
        pw.TableRow(children: [pw.Text('البيان'), pw.Text('القيمة')]),
        pw.TableRow(children: [pw.Text('إجمالي المبيعات'), pw.Text('$sales ريال')]),
        pw.TableRow(children: [pw.Text('عدد الكروت'), pw.Text('$cards')]),
      ]),
    ]));
    if (mode == 'pdf') {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/تقرير.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)]);
    } else {
      await Printing.layoutPdf(onLayout: (f) => pdf.save());
    }
  }
}

// ==================== تبويب المخزون ====================
class InventoryTab extends StatefulWidget {
  final Map<String, dynamic> agent;
  final FirebaseFirestore db;
  const InventoryTab({super.key, required this.agent, required this.db});
  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db.collection('networks').where('agentPhone', isEqualTo: widget.agent['phone'] ?? '').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final networks = snapshot.data!.docs;
        if (networks.isEmpty) return _empty('لم يقم الوكيل برفع أي كروت.');
        List<Map<String, dynamic>> cats = [];
        for (var net in networks) {
          final data = net.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'بدون اسم';
          for (var c in List<Map<String, dynamic>>.from(data['categories'] ?? [])) {
            if ((c['isActive'] ?? true) == true) { c['networkName'] = name; cats.add(c); }
          }
        }
        if (cats.isEmpty) return _empty('لا توجد فئات نشطة.');
        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          itemCount: cats.length,
          itemBuilder: (ctx, i) {
            final cat = cats[i];
            return Card(
              color: colors.surface,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cat['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                      Text('الشبكة: ${cat['networkName']}', style: TextStyle(fontSize: 12, color: colors.onSurface.withOpacity(0.6))),
                    ])),
                    Icon(Icons.category, color: Color(cat['color'] ?? colors.primary.value)),
                  ]),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    Column(children: [
                      Text('حقيقي', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                      Text('${cat['realStock'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ]),
                    Column(children: [
                      Text('وهمي', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                      Text('${cat['simStock'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ]),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _empty(String text) => Center(child: Text(text, style: TextStyle(color: Colors.grey)));
}

// ==================== تبويب البقالات ====================
class PosTab extends StatefulWidget {
  final Map<String, dynamic> agent;
  final FirebaseFirestore db;
  const PosTab({super.key, required this.agent, required this.db});
  @override
  State<PosTab> createState() => _PosTabState();
}

class _PosTabState extends State<PosTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    final phone = widget.agent['phone'] ?? '';
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db.collection('users').where('role', isEqualTo: 'pos').where('pos_agents', arrayContains: phone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!.docs;
        if (list.isEmpty) return const Center(child: Text('لا توجد بقالات.', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final p = list[i].data() as Map<String, dynamic>;
            final bal = ((p['wallets'] ?? {})[phone] ?? 0.0).toDouble();
            final limit = (((p['agent_relations'] ?? {})[phone] ?? {})['creditLimit'] ?? 0.0).toDouble();
            final comm = ((p['agent_relations'] ?? {})[phone] ?? {})['commission'] ?? '0%';
            return Card(
              color: colors.surface,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ExpansionTile(
                title: Text(p['storeName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                subtitle: Text('الرصيد: $bal ريال', style: TextStyle(color: colors.onSurfaceVariant)),
                leading: CircleAvatar(backgroundColor: colors.primary, child: Icon(Icons.store, color: colors.onPrimary)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _row('الرصيد الحالي', '$bal ريال'),
                      _row('الحد الائتماني', '$limit ريال'),
                      _row('العمولة', comm),
                    ]),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _row(String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.onSurface)),
        Text(value, style: TextStyle(fontSize: 12, color: colors.onSurface)),
      ]),
    );
  }
}

// ==================== تبويب المعاملات ====================
class TransactionsTab extends StatefulWidget {
  final String agentPhone;
  final FirebaseFirestore db;
  const TransactionsTab({super.key, required this.agentPhone, required this.db});
  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db
          .collection('transactions')
          .where('agentPhone', isEqualTo: widget.agentPhone)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data?.docs ?? [];
        if (list.isEmpty) return const Center(child: Text('لا توجد معاملات.', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final tx = list[i].data() as Map<String, dynamic>;
            final type = tx['type'] ?? '';
            final bool incoming = type == 'deposit' || type == 'credit_refund';
            final Color c = type == 'sale' ? Colors.blue : (incoming ? Colors.green : colors.error);
            final date = (tx['timestamp'] as Timestamp?)?.toDate();
            return Card(
              color: colors.surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(incoming ? Icons.arrow_downward : Icons.arrow_upward, color: c),
                title: Text(tx['title'] ?? type, style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                subtitle: Text(date != null ? DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(date) : '', style: TextStyle(color: colors.onSurfaceVariant)),
                trailing: Text('${tx['amount'] ?? 0} ريال', style: TextStyle(fontWeight: FontWeight.bold, color: c)),
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== تبويب سجل التدقيق ====================
class AuditLogTab extends StatefulWidget {
  final String agentPhone;
  final FirebaseFirestore db;
  const AuditLogTab({super.key, required this.agentPhone, required this.db});
  @override
  State<AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<AuditLogTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db
          .collection('audit_logs')
          .where('phone', isEqualTo: widget.agentPhone)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data?.docs ?? [];
        if (list.isEmpty) return const Center(child: Text('لا يوجد سجل تدقيق.', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final log = list[i].data() as Map<String, dynamic>;
            return Card(
              color: colors.surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.receipt_long, color: colors.primary),
                title: Text(log['action'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                subtitle: Text('${log['details'] ?? ''}\n${log['datetime'] ?? ''}', style: TextStyle(color: colors.onSurfaceVariant)),
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== مساعد شريط التبويبات ====================
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar, this.color);
  final TabBar _tabBar;
  final Color color;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
