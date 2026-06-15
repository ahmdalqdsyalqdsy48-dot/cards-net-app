// lib/features/super_admin/screens/agent_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

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

class _AgentProfileScreenState extends State<AgentProfileScreen> with TickerProviderStateMixin {
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

  Future<Map<String, dynamic>> _loadAgentExtraData(String phone) async {
    try {
      final netsSnap = await _db.collection('networks').where('agentPhone', isEqualTo: phone).get();
      final networks = netsSnap.docs.map((d) => d.data()).toList();
      final userDoc = await _db.collection('users').doc(phone).get();
      final userData = userDoc.data() ?? {};
      
      return {
        'networkNames': networks.map((n) => n['name'] ?? 'بدون اسم').toList(),
        'networkCount': networks.length,
        'accountNumber': userData['accountNumber'],
        'lastSeen': userData['lastSeen'] is Timestamp 
            ? DateFormat('yyyy/MM/dd hh:mm a', 'ar').format((userData['lastSeen'] as Timestamp).toDate()) 
            : 'غير معروف',
      };
    } catch (_) {
      return {'networkNames': [], 'networkCount': 0, 'lastSeen': 'غير معروف'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final liveAgent = wallet.agentsList.firstWhere((a) => a['phone'] == widget.agentData['phone'], orElse: () => widget.agentData);
    final agentPhone = liveAgent['phone'] ?? '';

    return Scaffold(
      appBar: const CustomHeader(title: 'الملف الشامل للوكيل'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: auth.currentUserRole == 'super_admin' ? 'مالك النظام' : 'موظف مخصص',
        balanceOrPoints: 'أرباح: ${settings.adminMainBalance.toStringAsFixed(0)}',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _overviewKey.currentState?.refresh();
          _inventoryKey.currentState?.refresh();
          _posKey.currentState?.refresh();
          _transactionsKey.currentState?.refresh();
          _auditLogKey.currentState?.refresh();
          context.read<UiProvider>().playSound('success');
        },
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (ctx, inner) => [
            SliverToBoxAdapter(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _loadAgentExtraData(agentPhone),
                builder: (context, snap) => _buildIdentityCard(liveAgent, snap.data ?? {}),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Theme.of(context).colorScheme.primary,
                  tabs: const [
                    Tab(icon: Icon(Icons.analytics), text: 'نظرة عامة'),
                    Tab(icon: Icon(Icons.inventory_2), text: 'المخزون'),
                    Tab(icon: Icon(Icons.store), text: 'البقالات'),
                    Tab(icon: Icon(Icons.receipt_long), text: 'المعاملات'),
                    Tab(icon: Icon(Icons.history), text: 'سجل التدقيق'),
                  ],
                ),
                Theme.of(context).colorScheme.surface,
              ),
            ),
          ],
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

  Widget _buildIdentityCard(Map<String, dynamic> agent, Map<String, dynamic> extra) {
    final colors = Theme.of(context).colorScheme;
    final name = agent['name'] ?? 'غير معروف';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: colors.primary, child: Text(name[0])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colors.onPrimaryContainer)),
            Text('الرصيد: ${agent['balance']} ريال', style: TextStyle(color: colors.primary)),
          ])),
          Text(agent['status'] ?? 'غير محدد', style: TextStyle(fontWeight: FontWeight.bold, color: agent['status'] == 'نشط' ? Colors.green : Colors.red)),
        ]),
        const SizedBox(height: 8),
        Text('آخر دخول: ${extra['lastSeen']}', style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer.withOpacity(0.7))),
      ]),
    );
  }
}

// ==================== التبويبات ====================

class OverviewTab extends StatefulWidget {
  final Map<String, dynamic> agent;
  final FirebaseFirestore db;
  const OverviewTab({super.key, required this.agent, required this.db});
  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> with AutomaticKeepAliveClientMixin {
  String _filter = 'اليوم';
  @override
  bool get wantKeepAlive => true;
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Wrap(children: ['اليوم', 'الأسبوع', 'الشهر', 'الكل'].map((f) => ChoiceChip(
        label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f),
      )).toList()),
      Expanded(child: Center(child: Text('عرض البيانات للفترة: $_filter'))),
    ]);
  }
}

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
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db.collection('networks').where('agentPhone', isEqualTo: widget.agent['phone']).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (ctx, i) {
            final d = snap.data!.docs[i].data() as Map<String, dynamic>;
            return Card(child: ListTile(title: Text(d['name'] ?? 'شبكة')));
          },
        );
      },
    );
  }
}

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
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db.collection('users').where('role', isEqualTo: 'pos').where('pos_agents', arrayContains: widget.agent['phone']).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (ctx, i) {
            final p = snap.data!.docs[i].data() as Map<String, dynamic>;
            return Card(child: ListTile(title: Text(p['storeName'] ?? 'بقالة')));
          },
        );
      },
    );
  }
}

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
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db.collection('transactions').where('agentPhone', isEqualTo: widget.agentPhone).orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (ctx, i) {
            final tx = snap.data!.docs[i].data() as Map<String, dynamic>;
            return ListTile(title: Text(tx['title'] ?? 'معاملة'), trailing: Text('${tx['amount']}'));
          },
        );
      },
    );
  }
}

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
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db.collection('audit_logs').where('phone', isEqualTo: widget.agentPhone).orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (ctx, i) {
            final log = snap.data!.docs[i].data() as Map<String, dynamic>;
            return ListTile(title: Text(log['action'] ?? 'إجراء'));
          },
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _color;
  _SliverTabBarDelegate(this._tabBar, this._color);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(context, shrinkOffset, overlapsContent) => Material(color: _color, child: _tabBar);
  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate old) => true;
}
