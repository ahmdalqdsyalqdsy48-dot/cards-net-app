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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final colors = Theme.of(context).colorScheme;

    final liveAgent = wallet.agentsList.firstWhere(
      (a) => a['phone'] == widget.agentData['phone'],
      orElse: () => widget.agentData,
    );

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
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.onSurfaceVariant,
                  indicatorColor: colors.primary,
                  tabs: const [
                    Tab(icon: Icon(Icons.analytics), text: 'نظرة عامة'),
                    Tab(icon: Icon(Icons.inventory_2), text: 'المخزون'),
                    Tab(icon: Icon(Icons.store), text: 'البقالات'),
                    Tab(icon: Icon(Icons.receipt_long), text: 'المعاملات'),
                    Tab(icon: Icon(Icons.history), text: 'السجل'),
                  ],
                ),
                colors.surface,
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

  Future<Map<String, dynamic>> _loadAgentExtraData(String phone) async {
    try {
      final nets = await _db.collection('networks').where('agentPhone', isEqualTo: phone).get();
      final user = await _db.collection('users').doc(phone).get();
      final userData = user.data() ?? {};
      return {
        'networkNames': nets.docs.map((d) => d['name'] ?? 'بدون اسم').toList(),
        'networkCount': nets.size,
        'accountNumber': userData['accountNumber'] as String?,
        'lastSeen': userData['lastSeen'] is Timestamp
            ? DateFormat('yyyy/MM/dd hh:mm', 'ar').format((userData['lastSeen'] as Timestamp).toDate())
            : 'غير معروف',
      };
    } catch (_) {
      return {'networkNames': [], 'networkCount': 0, 'lastSeen': 'غير معروف'};
    }
  }

  Widget _buildIdentityCard(Map<String, dynamic> agent, Map<String, dynamic> extra) {
    final colors = Theme.of(context).colorScheme;
    final name = agent['name'] ?? 'غير معروف';
    final balance = double.tryParse((agent['balance'] ?? 0).toString()) ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
      child: Column(children: [
        Row(children: [
          CircleAvatar(backgroundColor: colors.primary, child: Text(name[0], style: TextStyle(color: colors.onPrimary))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.onPrimaryContainer)),
            Text('الرصيد: ${balance.toStringAsFixed(0)} ريال', style: TextStyle(color: colors.primary)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: agent['status'] == 'نشط' ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(12)), child: Text(agent['status'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 10))),
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
  @override
  bool get wantKeepAlive => true;
  void refresh() => setState(() {});
  @override
  Widget build(BuildContext context) { super.build(context); return const Center(child: Text('نظرة عامة')); }
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
        final docs = snap.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Card(child: ListTile(title: Text(data['name'] ?? 'بدون اسم'), subtitle: Text('الرصيد: ${data['balance'] ?? 0}')));
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
  Widget build(BuildContext context) { super.build(context); return const Center(child: Text('قائمة البقالات')); }
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
      stream: widget.db.collection('transactions').where('agentPhone', isEqualTo: widget.agentPhone).orderBy('timestamp', descending: true).limit(50).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) => ListTile(title: Text(snap.data!.docs[i]['title'] ?? 'معاملة')));
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
  Widget build(BuildContext context) { super.build(context); return const Center(child: Text('سجل التدقيق')); }
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
