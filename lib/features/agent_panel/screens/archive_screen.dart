import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

// ========== نماذج البيانات ==========
class ArchiveStats {
  final int totalCards;
  final double totalFrozenValue;
  final int categoriesCount;
  final double averageAgeDays;
  final Map<String, int> cardsByNetwork;
  final Map<String, int> cardsByCategory;

  ArchiveStats({
    required this.totalCards,
    required this.totalFrozenValue,
    required this.categoriesCount,
    required this.averageAgeDays,
    required this.cardsByNetwork,
    required this.cardsByCategory,
  });
}

class ActivityLogEntry {
  final String id;
  final String action;
  final String details;
  final String agentPhone;
  final DateTime timestamp;

  ActivityLogEntry({
    required this.id,
    required this.action,
    required this.details,
    required this.agentPhone,
    required this.timestamp,
  });
}

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late SystemProvider sys;
  late UiProvider _ui;

  // ========== الأرشيف ==========
  List<QueryDocumentSnapshot> archivedCards = [];
  List<QueryDocumentSnapshot> _allArchivedCards = [];
  String archiveSearchQuery = '';
  final archiveDaysController = TextEditingController(text: "30");
  bool autoDeleteEnabled = false;
  bool _isLoading = false;
  final int _pageSize = 50;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // ========== الفلاتر والفرز ==========
  String? _filterNetworkId;
  String? _filterCategoryId;
  String? _selectedSortField = 'timestamp';
  bool _sortAscending = false;
  double? _priceFrom;
  double? _priceTo;
  List<Map<String, dynamic>> _availableNetworks = [];
  List<Map<String, dynamic>> _availableCategories = [];

  // ========== الفحص المجمع ==========
  final Set<String> _selectedCardIds = {};
  bool _isSelectionMode = false;

  // ========== التحليلات ==========
  ArchiveStats? _stats;

  // ========== سلة المهملات ==========
  List<QueryDocumentSnapshot> _recycleBinCards = [];
  final int _recycleBinDays = 30;

  // ========== سجل النشاطات ==========
  List<ActivityLogEntry> _activityLogs = [];

  void _play(String type) => _ui.playSound(type);

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _logActivity(String action, String details) async {
    await _firestore.collection('activity_logs').add({
      'agentPhone': sys.currentUserPhone,
      'action': action,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _loadActivityLogs();
  }

  Future<bool> _showConfirm(String title, String msg) async {
    _play('warning');
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("تأكيد")),
            ],
          ),
        ) ??
        false;
  }

  @override
  void initState() {
    super.initState();
    sys = Provider.of<SystemProvider>(context, listen: false);
    _ui = Provider.of<UiProvider>(context, listen: false);
    _mainTabController = TabController(length: 4, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadArchive(reset: true),
      _loadAvailableNetworks(),
      _loadAutoDeleteSettings(),
      _loadActivityLogs(),
      _loadRecycleBin(),
    ]);
    await _calculateStats();
    setState(() => _isLoading = false);
  }

  Future<void> _loadAvailableNetworks() async {
    final snap = await _firestore.collection('networks')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .get();
    setState(() {
      _availableNetworks = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      _availableCategories = [];
      for (var net in _availableNetworks) {
        final cats = net['categories'] as List? ?? [];
        _availableCategories.addAll(cats.cast<Map<String, dynamic>>());
      }
    });
  }

  Future<void> _loadArchive({bool reset = false}) async {
    if (reset) {
      _lastDocument = null;
      _hasMore = true;
      _allArchivedCards = [];
      archivedCards = [];
    }
    if (!_hasMore) return;

    var query = _firestore.collection('cards')
        .where('status', isEqualTo: 'archived')
        .orderBy('archivedAt', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) {
      setState(() => _hasMore = false);
      return;
    }

    setState(() {
      _lastDocument = snapshot.docs.last;
      _allArchivedCards = reset ? snapshot.docs.toList() : [..._allArchivedCards, ...snapshot.docs];
      _applyFiltersAndSort();
    });
  }

  void _applyFiltersAndSort() {
    var filtered = List<QueryDocumentSnapshot>.from(_allArchivedCards);

    if (archiveSearchQuery.isNotEmpty) {
      filtered = filtered.where((c) =>
          (c['pin'] ?? '').toLowerCase().contains(archiveSearchQuery.toLowerCase())).toList();
    }

    if (_filterNetworkId != null) {
      filtered = filtered.where((c) => c['networkId'] == _filterNetworkId).toList();
    }

    if (_filterCategoryId != null) {
      filtered = filtered.where((c) => c['categoryId'] == _filterCategoryId).toList();
    }

    if (_priceFrom != null) {
      filtered = filtered.where((c) => (c['price'] ?? 0) >= _priceFrom!).toList();
    }
    if (_priceTo != null) {
      filtered = filtered.where((c) => (c['price'] ?? 0) <= _priceTo!).toList();
    }

    filtered.sort((a, b) {
      dynamic valA, valB;
      switch (_selectedSortField) {
        case 'timestamp':
          valA = (a['archivedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          valB = (b['archivedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          break;
        case 'price':
          valA = a['price'] ?? 0;
          valB = b['price'] ?? 0;
          break;
        case 'pin':
          valA = a['pin'] ?? '';
          valB = b['pin'] ?? '';
          break;
        default:
          valA = a['pin'] ?? '';
          valB = b['pin'] ?? '';
      }
      return _sortAscending
          ? Comparable.compare(valA, valB)
          : Comparable.compare(valB, valA);
    });

    setState(() {
      archivedCards = filtered;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadArchive();
    }
  }

  Future<ArchiveStats> _calculateStats() async {
    final allCards = _allArchivedCards;
    double totalValue = 0;
    final networkMap = <String, int>{};
    final categoryMap = <String, int>{};
    double totalAge = 0;
    final now = DateTime.now();

    for (var card in allCards) {
      final price = (card['price'] ?? 0).toDouble();
      totalValue += price;
      
      final netId = card['networkId'] as String? ?? 'غير معروف';
      networkMap[netId] = (networkMap[netId] ?? 0) + 1;
      
      final catId = card['categoryId'] as String? ?? 'غير معروف';
      categoryMap[catId] = (categoryMap[catId] ?? 0) + 1;
      
      final ts = card['archivedAt'] as Timestamp?;
      if (ts != null) {
        totalAge += now.difference(ts.toDate()).inDays.toDouble();
      }
    }

    final stats = ArchiveStats(
      totalCards: allCards.length,
      totalFrozenValue: totalValue,
      categoriesCount: categoryMap.length,
      averageAgeDays: allCards.isEmpty ? 0 : totalAge / allCards.length,
      cardsByNetwork: networkMap,
      cardsByCategory: categoryMap,
    );

    setState(() => _stats = stats);
    return stats;
  }

  Future<void> _loadRecycleBin() async {
    final snap = await _firestore.collection('cards')
        .where('status', isEqualTo: 'recycle_bin')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .get();
    setState(() => _recycleBinCards = snap.docs);
  }

  Future<void> _loadActivityLogs() async {
    final snap = await _firestore.collection('activity_logs')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();
    setState(() {
      _activityLogs = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return ActivityLogEntry(
          id: d.id,
          action: data['action'] ?? '',
          details: data['details'] ?? '',
          agentPhone: data['agentPhone'] ?? '',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
    });
  }

  // ========== عمليات الكرت الواحد ==========
  Future<void> _restoreCard(QueryDocumentSnapshot card) async {
    _play('click');
    final ok = await _showConfirm("استرجاع الكرت", "هل تريد إعادة هذا الكرت إلى حالة الطباعة؟");
    if (!ok) return;
    await card.reference.update({
      'status': 'print_ready',
      'restoredAt': FieldValue.serverTimestamp(),
    });
    _play('success');
    _logActivity('restore_card', 'pin: ${card['pin']}');
    _loadArchive(reset: true);
  }

  Future<void> _moveToRecycleBin(QueryDocumentSnapshot card) async {
    _play('click');
    final ok = await _showConfirm("نقل إلى سلة المهملات", "سينتقل الكرت إلى سلة المهملات لمدة $_recycleBinDays يوماً قبل الحذف النهائي.");
    if (!ok) return;
    await card.reference.update({
      'status': 'recycle_bin',
      'movedToBinAt': FieldValue.serverTimestamp(),
    });
    _play('success');
    _logActivity('move_to_bin', 'pin: ${card['pin']}');
    _loadArchive(reset: true);
    _loadRecycleBin();
  }

  Future<void> _deleteCardPermanently(QueryDocumentSnapshot card) async {
    _play('click');
    final ok = await _showConfirm("حذف نهائي", "سيتم حذف الكرت نهائياً. استمر؟");
    if (!ok) return;
    await card.reference.delete();
    _play('success');
    _logActivity('delete_card_permanently', 'pin: ${card['pin']}');
    _loadArchive(reset: true);
    _loadRecycleBin();
  }

  Future<void> _editCardPin(QueryDocumentSnapshot card) async {
    _play('click');
    final ctrl = TextEditingController(text: card['pin']);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تعديل الرقم"),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "الرقم الجديد")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text("حفظ")),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      await card.reference.update({'pin': res});
      _play('success');
      _logActivity('edit_card', 'old: ${card['pin']}, new: $res');
      _loadArchive(reset: true);
    }
  }

  // ========== عمليات جماعية ==========
  Future<void> _restoreSelected() async {
    if (_selectedCardIds.isEmpty) return;
    final ok = await _showConfirm("استرجاع المحدد", "سيتم استرجاع ${_selectedCardIds.length} كرت. متأكد؟");
    if (!ok) return;
    final batch = _firestore.batch();
    for (var card in archivedCards) {
      if (_selectedCardIds.contains(card.id)) {
        batch.update(card.reference, {
          'status': 'print_ready',
          'restoredAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
    _play('success');
    _logActivity('restore_batch', '${_selectedCardIds.length} cards');
    _selectedCardIds.clear();
    _isSelectionMode = false;
    _loadArchive(reset: true);
  }

  Future<void> _deleteSelected() async {
    if (_selectedCardIds.isEmpty) return;
    final ok = await _showConfirm("حذف المحدد", "سيتم حذف ${_selectedCardIds.length} كرت نهائياً. متأكد؟");
    if (!ok) return;
    final batch = _firestore.batch();
    for (var card in archivedCards) {
      if (_selectedCardIds.contains(card.id)) {
        batch.delete(card.reference);
      }
    }
    await batch.commit();
    _play('success');
    _logActivity('delete_batch', '${_selectedCardIds.length} cards');
    _selectedCardIds.clear();
    _isSelectionMode = false;
    _loadArchive(reset: true);
  }

  Future<void> _restoreAll() async {
    _play('click');
    final ok = await _showConfirm("استرجاع الكل", "سيتم إعادة جميع الكروت في الأرشيف إلى حالة الطباعة. متأكد؟");
    if (!ok) return;
    final batch = _firestore.batch();
    for (final card in _allArchivedCards) {
      batch.update(card.reference, {'status': 'print_ready'});
    }
    await batch.commit();
    _play('success');
    _logActivity('restore_all', '${_allArchivedCards.length} cards');
    _loadArchive(reset: true);
  }

  Future<void> _deleteAllArchived() async {
    _play('click');
    final ok = await _showConfirm("حذف الكل", "سيتم حذف جميع الكروت في الأرشيف نهائياً. متأكد؟");
    if (!ok) return;
    final batch = _firestore.batch();
    for (final card in _allArchivedCards) {
      batch.delete(card.reference);
    }
    await batch.commit();
    _play('success');
    _logActivity('delete_all_archived', '${_allArchivedCards.length} cards');
    _loadArchive(reset: true);
  }

  // ========== تصدير CSV ==========
  Future<void> _exportToCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('رقم الكرت,الشبكة,الفئة,السعر,تاريخ الأرشفة');
    for (var card in archivedCards) {
      final pin = card['pin'] ?? '';
      final net = card['networkId'] ?? '';
      final cat = card['categoryId'] ?? '';
      final price = '${card['price'] ?? 0}';
      final date = ((card['archivedAt'] as Timestamp?)?.toDate() ?? DateTime.now()).toString();
      buffer.writeln('$pin,$net,$cat,$price,$date');
    }
    print(buffer.toString());
    _play('success');
    _showToast('تم تجهيز ملف CSV');
  }

  // ========== بطاقة تفاصيل الكرت ==========
  void _showCardDetail(QueryDocumentSnapshot card) {
    final pin = card['pin'] ?? '---';
    final networkId = card['networkId'] ?? 'غير معروف';
    final categoryId = card['categoryId'] ?? 'غير معروف';
    final price = card['price'] ?? 0;
    final createdAt = (card['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final archivedAt = (card['archivedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(pin, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3)),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _detailRow('الشبكة', networkId),
                      _detailRow('الفئة', categoryId),
                      _detailRow('السعر', '$price ريال'),
                      _detailRow('تاريخ التوليد', _formatDate(createdAt)),
                      _detailRow('تاريخ الأرشفة', _formatDate(archivedAt)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(onPressed: () { Navigator.pop(context); _restoreCard(card); }, icon: const Icon(Icons.restore), label: const Text('استرجاع')),
                          ElevatedButton.icon(onPressed: () { Navigator.pop(context); _deleteCardPermanently(card); }, icon: const Icon(Icons.delete), label: const Text('حذف'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  // ========== إعدادات الحذف التلقائي ==========
  Future<void> _loadAutoDeleteSettings() async {
    final doc = await _firestore.collection('settings').doc('archive_auto_delete').get();
    if (doc.exists) {
      setState(() {
        archiveDaysController.text = (doc['days'] ?? 30).toString();
        autoDeleteEnabled = doc['enabled'] ?? false;
      });
    }
  }

  Future<void> _saveAutoDeleteSettings() async {
    await _firestore.collection('settings').doc('archive_auto_delete').set({
      'days': int.tryParse(archiveDaysController.text) ?? 30,
      'enabled': autoDeleteEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ إعدادات الحذف التلقائي")));
    }
  }

  void _showAutoDeleteSettings() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text("إعدادات الحذف التلقائي للأرشيف"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: autoDeleteEnabled,
                onChanged: (v) => setDialogState(() => autoDeleteEnabled = v),
                title: const Text("تفعيل الحذف التلقائي"),
              ),
              TextField(
                controller: archiveDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "عدد الأيام قبل الحذف"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(onPressed: () { _saveAutoDeleteSettings(); Navigator.pop(context); }, child: const Text("حفظ")),
          ],
        ),
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ========== أيقونة المهملات الديناميكية ==========
  Widget _buildRecycleBinTabIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.delete),
        if (_recycleBinCards.isNotEmpty)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${_recycleBinCards.length}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ========== بناء الواجهة ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(title: 'الأرشيف المُتقدم'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Theme.of(context).primaryColor.withOpacity(0.8),
                  child: TabBar(
                    controller: _mainTabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    tabs: [
                      const Tab(icon: Icon(Icons.archive), text: "الأرشيف"),
                      const Tab(icon: Icon(Icons.analytics), text: "التحليلات"),
                      const Tab(icon: Icon(Icons.history), text: "سجل النشاطات"),
                      Tab(
                        icon: _buildRecycleBinTabIcon(),
                        text: "المهملات",
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _mainTabController,
                    children: [
                      _buildArchiveTab(),
                      _buildAnalyticsTab(),
                      _buildActivityLogTab(),
                      _buildRecycleBinTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ========== تبويب الأرشيف الرئيسي ==========
  Widget _buildArchiveTab() {
    return Column(
      children: [
        if (_stats != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('الإجمالي', '${_stats!.totalCards}', Icons.inventory),
                _statChip('القيمة', '${_stats!.totalFrozenValue.toStringAsFixed(0)} ر.ي', Icons.money),
                _statChip('الفئات', '${_stats!.categoriesCount}', Icons.category),
                _statChip('متوسط العمر', '${_stats!.averageAgeDays.toStringAsFixed(1)} يوم', Icons.timer),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'بحث عن كرت',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onChanged: (v) {
                  archiveSearchQuery = v;
                  _applyFiltersAndSort();
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('الشبكة', _filterNetworkId != null, () => _showNetworkFilter()),
                    const SizedBox(width: 8),
                    _filterChip('الفئة', _filterCategoryId != null, () => _showCategoryFilter()),
                    const SizedBox(width: 8),
                    _filterChip('السعر', _priceFrom != null || _priceTo != null, _showPriceFilter),
                    const SizedBox(width: 8),
                    _filterChip('التاريخ', false, _showDateRangeFilter),
                    const SizedBox(width: 8),
                    _sortChip(),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_isSelectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(onPressed: _restoreSelected, icon: const Icon(Icons.restore), label: Text('استرجاع (${_selectedCardIds.length})')),
                ElevatedButton.icon(onPressed: _deleteSelected, icon: const Icon(Icons.delete), label: Text('حذف (${_selectedCardIds.length})'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
                ElevatedButton.icon(onPressed: _exportToCsv, icon: const Icon(Icons.download), label: const Text('تصدير CSV')),
                TextButton(onPressed: () { setState(() { _selectedCardIds.clear(); _isSelectionMode = false; }); }, child: const Text('إلغاء')),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(onPressed: _restoreAll, icon: const Icon(Icons.restore), label: const Text("استرجاع الكل"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange)),
            ElevatedButton.icon(onPressed: _deleteAllArchived, icon: const Icon(Icons.delete_sweep), label: const Text("حذف الكل"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
            TextButton.icon(onPressed: _showAutoDeleteSettings, icon: const Icon(Icons.timer), label: const Text("الحذف التلقائي")),
            TextButton(onPressed: () => setState(() => _isSelectionMode = !_isSelectionMode), child: Text(_isSelectionMode ? 'إنهاء التحديد' : 'تحديد متعدد')),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadArchive(reset: true),
            child: archivedCards.isEmpty
                ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32), child: Text('لا توجد كروت في الأرشيف')))])
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: archivedCards.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index >= archivedCards.length) {
                        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      }
                      final card = archivedCards[index];
                      return ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: _selectedCardIds.contains(card.id),
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) _selectedCardIds.add(card.id);
                                    else _selectedCardIds.remove(card.id);
                                  });
                                },
                              )
                            : const Icon(Icons.confirmation_number, color: Colors.teal),
                        title: Text(card['pin'] ?? '---'),
                        subtitle: Text(card['categoryId'] ?? ''),
                        onTap: () => _isSelectionMode ? null : _showCardDetail(card),
                        trailing: _isSelectionMode ? null : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _editCardPin(card)),
                            IconButton(icon: const Icon(Icons.restore), onPressed: () => _restoreCard(card)),
                            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _moveToRecycleBin(card)),
                            IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () => _deleteCardPermanently(card)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ========== تبويب التحليلات ==========
  Widget _buildAnalyticsTab() {
    if (_stats == null) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ملخص الأرشيف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 24),
          const Text('توزيع الكروت حسب الشبكات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildHorizontalBarChart(_stats!.cardsByNetwork),
          const SizedBox(height: 24),
          const Text('توزيع الكروت حسب الفئات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildHorizontalBarChart(_stats!.cardsByCategory),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(child: _summaryCard('إجمالي الكروت', '${_stats!.totalCards}', Icons.inventory, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard('القيمة المجمدة', '${_stats!.totalFrozenValue.toStringAsFixed(0)} ر.ي', Icons.money, Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard('عدد الفئات', '${_stats!.categoriesCount}', Icons.category, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard('متوسط العمر', '${_stats!.averageAgeDays.toStringAsFixed(1)} يوم', Icons.timer, Colors.purple)),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalBarChart(Map<String, int> data) {
    if (data.isEmpty) return const Text('لا توجد بيانات');
    final maxVal = data.values.reduce(max).toDouble();
    return Column(
      children: data.entries.map((entry) {
        final ratio = maxVal > 0 ? entry.value / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 120, child: Text(entry.key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: ratio, minHeight: 20, backgroundColor: Colors.grey.shade200, color: Colors.teal),
                ),
              ),
              const SizedBox(width: 8),
              Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ========== تبويب سجل النشاطات ==========
  Widget _buildActivityLogTab() {
    if (_activityLogs.isEmpty) return const Center(child: Text('لا يوجد سجل نشاطات'));
    return ListView.builder(
      itemCount: _activityLogs.length,
      itemBuilder: (_, i) {
        final log = _activityLogs[i];
        return ListTile(
          leading: Icon(_getActionIcon(log.action), color: _getActionColor(log.action)),
          title: Text(_getActionName(log.action)),
          subtitle: Text('${log.details} - ${_formatDate(log.timestamp)}'),
        );
      },
    );
  }

  IconData _getActionIcon(String action) {
    if (action.startsWith('restore')) return Icons.restore;
    if (action.startsWith('delete')) return Icons.delete;
    if (action.startsWith('move_to_bin')) return Icons.delete_outline;
    if (action.startsWith('edit')) return Icons.edit;
    return Icons.info;
  }

  Color _getActionColor(String action) {
    if (action.startsWith('restore')) return Colors.green;
    if (action.startsWith('delete')) return Colors.red;
    if (action.startsWith('move_to_bin')) return Colors.orange;
    return Colors.blue;
  }

  String _getActionName(String action) {
    switch (action) {
      case 'restore_card': return 'استرجاع كرت';
      case 'restore_batch': return 'استرجاع مجموعة';
      case 'restore_all': return 'استرجاع الكل';
      case 'delete_card': return 'حذف كرت';
      case 'delete_batch': return 'حذف مجموعة';
      case 'delete_all_archived': return 'حذف الكل';
      case 'delete_card_permanently': return 'حذف نهائي';
      case 'move_to_bin': return 'نقل للمهملات';
      case 'edit_card': return 'تعديل كرت';
      default: return action;
    }
  }

  // ========== تبويب سلة المهملات ==========
  Widget _buildRecycleBinTab() {
    if (_recycleBinCards.isEmpty) return const Center(child: Text('سلة المهملات فارغة'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('الكروت في سلة المهملات (تحذف نهائياً بعد $_recycleBinDays يوم):', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recycleBinCards.length,
            itemBuilder: (_, i) {
              final card = _recycleBinCards[i];
              return ListTile(
                title: Text(card['pin'] ?? '---'),
                subtitle: Text(card['categoryId'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.restore), onPressed: () async {
                      await card.reference.update({'status': 'archived'});
                      _loadRecycleBin();
                      _loadArchive(reset: true);
                    }),
                    IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () async {
                      await card.reference.delete();
                      _loadRecycleBin();
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ========== ويدجتات مساعدة ==========
  Widget _statChip(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).primaryColor),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _filterChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.black87, fontSize: 12)),
        backgroundColor: isActive ? Theme.of(context).primaryColor : Colors.grey.shade200,
        deleteIcon: isActive ? const Icon(Icons.close, size: 16) : null,
        onDeleted: isActive ? () {
          setState(() {
            _filterNetworkId = null;
            _filterCategoryId = null;
            _priceFrom = null;
            _priceTo = null;
          });
          _applyFiltersAndSort();
        } : null,
      ),
    );
  }

  Widget _sortChip() {
    return PopupMenuButton<String>(
      child: Chip(
        label: Text('ترتيب: ${_selectedSortField == 'timestamp' ? "التاريخ" : _selectedSortField == 'price' ? "السعر" : "الرقم"}'),
        backgroundColor: Colors.grey.shade200,
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'timestamp', child: Text('حسب التاريخ')),
        const PopupMenuItem(value: 'price', child: Text('حسب السعر')),
        const PopupMenuItem(value: 'pin', child: Text('حسب الرقم')),
        const PopupMenuDivider(),
        PopupMenuItem(
          child: Text(_sortAscending ? 'تصاعدي ▲' : 'تنازلي ▼'),
          onTap: () => setState(() => _sortAscending = !_sortAscending),
        ),
      ],
      onSelected: (v) {
        _selectedSortField = v;
        _applyFiltersAndSort();
      },
    );
  }

  void _showNetworkFilter() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: [
          ListTile(title: const Text('الكل'), onTap: () { setState(() => _filterNetworkId = null); _applyFiltersAndSort(); Navigator.pop(context); }),
          ..._availableNetworks.map((net) => ListTile(
            title: Text(net['name'] ?? ''),
            onTap: () { setState(() => _filterNetworkId = net['id']); _applyFiltersAndSort(); Navigator.pop(context); },
          )),
        ],
      ),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: [
          ListTile(title: const Text('الكل'), onTap: () { setState(() => _filterCategoryId = null); _applyFiltersAndSort(); Navigator.pop(context); }),
          ..._availableCategories.map((cat) => ListTile(
            title: Text(cat['name'] ?? ''),
            onTap: () { setState(() => _filterCategoryId = cat['id']); _applyFiltersAndSort(); Navigator.pop(context); },
          )),
        ],
      ),
    );
  }

  void _showPriceFilter() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('نطاق السعر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: const InputDecoration(labelText: 'من'), keyboardType: TextInputType.number, onChanged: (v) => _priceFrom = double.tryParse(v)),
            TextField(decoration: const InputDecoration(labelText: 'إلى'), keyboardType: TextInputType.number, onChanged: (v) => _priceTo = double.tryParse(v)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () { _applyFiltersAndSort(); Navigator.pop(context); }, child: const Text('تطبيق')),
        ],
      ),
    );
  }

  void _showDateRangeFilter() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      setState(() {
        // يمكنك تخزين التاريخ إذا أردت
      });
      _applyFiltersAndSort();
    }
  }
}
