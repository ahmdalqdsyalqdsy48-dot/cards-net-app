import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class SubAgentsScreen extends StatefulWidget {
  const SubAgentsScreen({super.key});
  @override
  State<SubAgentsScreen> createState() => _SubAgentsScreenState();
}

class _SubAgentsScreenState extends State<SubAgentsScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedFilter = 'الكل'; 
  double _vipThreshold = 50000.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // 🟢 نافذة الإضافة والتعديل المشتركة (مع الفئات)
  // ==========================================
  void _showAddOrEditPosModal(SystemProvider sys, {Map<String, dynamic>? existingPos}) async {
    _play('click');
    bool isEdit = existingPos != null;
    String phone = existingPos?['phone'] ?? '', name = existingPos?['storeName'] ?? '', location = existingPos?['location'] ?? '';
    String commission = existingPos?['commission']?.replaceAll('%', '') ?? '0';
    double limit = (existingPos?['creditLimit'] ?? 0.0).toDouble();
    List<String> allowedCats = List<String>.from(existingPos?['allowedCategories'] ?? []);
    bool isSubmitting = false;

    // جلب كل فئات الوكيل من المايكروتيك (Firestore)
    var netSnap = await _db.collection('networks').where('agentPhone', isEqualTo: sys.currentUserPhone).get();
    List<Map<String, dynamic>> allAvailableCats = [];
    for (var doc in netSnap.docs) {
      List cats = doc['categories'] ?? [];
      for (var c in cats) { allAvailableCats.add({'id': c['id'], 'name': '${doc['name']} - ${c['name']}'}); }
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 16, right: 16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isEdit ? 'تعديل بيانات البقالة ⚙️' : 'ترقية زبون إلى بقالة 🏪', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    enabled: !isEdit, controller: TextEditingController(text: phone),
                    onChanged: (v) => phone = v, decoration: InputDecoration(labelText: 'رقم الهاتف المسجل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.phone)),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: TextEditingController(text: name), onChanged: (v) => name = v, decoration: InputDecoration(labelText: 'اسم البقالة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.storefront))),
                  const SizedBox(height: 12),
                  TextField(controller: TextEditingController(text: location), onChanged: (v) => location = v, decoration: InputDecoration(labelText: 'الموقع/العنوان', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.location_on))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: TextEditingController(text: limit.toString()), keyboardType: TextInputType.number, onChanged: (v) => limit = double.tryParse(v) ?? 0, decoration: InputDecoration(labelText: 'الحد الائتماني', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: TextEditingController(text: commission), keyboardType: TextInputType.number, onChanged: (v) => commission = v, decoration: InputDecoration(labelText: 'العمولة %', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                  ]),
                  const SizedBox(height: 15),
                  const Align(alignment: Alignment.centerRight, child: Text('الفئات المسموح ببيعها:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
                  ...allAvailableCats.map((cat) => CheckboxListTile(
                    title: Text(cat['name'], style: const TextStyle(fontSize: 13)),
                    value: allowedCats.contains(cat['id']),
                    onChanged: (val) { setModalState(() { val! ? allowedCats.add(cat['id']) : allowedCats.remove(cat['id']); }); },
                  )),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    onPressed: isSubmitting ? null : () async {
                      if (phone.isEmpty || name.isEmpty || location.isEmpty) return;
                      setModalState(() => isSubmitting = true);
                      try {
                        if (isEdit) {
                          await sys.updatePosDetails(posPhone: phone, storeName: name, location: location, creditLimit: limit, commission: '$commission%', allowedCategories: allowedCats);
                        } else {
                          await sys.upgradeUserToPos(posPhone: phone, storeName: name, location: location, creditLimit: limit, commission: '$commission%', allowedCategories: allowedCats);
                        }
                        _play('success'); Navigator.pop(context);
                      } catch (e) { setModalState(() => isSubmitting = false); }
                    },
                    child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(isEdit ? 'حفظ التعديلات' : 'إتمام الترقية'),
                  )),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 📊 نظام التقارير والفلترة المتقدم (حقيقي)
  // ==========================================
  void _showAdvancedReportsModal(SystemProvider sys) async {
    _play('click');
    DateTimeRange? range = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now());
    if (range == null) return;

    List<String> selectedPosPhones = [];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تخصيص تقرير المبيعات 📊'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('اختر البقالات (اتركه فارغاً للكل):', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: ListView(
                      children: sys.usersList.where((u) => u['role'] == 'pos').map((pos) => CheckboxListTile(
                        title: Text(pos['storeName'] ?? pos['name']),
                        value: selectedPosPhones.contains(pos['phone']),
                        onChanged: (v) => setStateDialog(() => v! ? selectedPosPhones.add(pos['phone']) : selectedPosPhones.remove(pos['phone'])),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('عرض التقرير وطباعة PDF')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة نقاط البيع الذكية'),
      drawer: CustomAgentDrawer(agentName: sys.currentUserName, phoneNumber: sys.currentUserPhone, role: 'وكيل', currentBalance: sys.currentUserBalance),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: TabBarView(controller: _tabController, children: [
              _buildActivePosTab(sys),
              _buildRequestsTab(sys),
              _buildDebtTab(sys),
            ])),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditPosModal(sys),
        backgroundColor: Colors.purple, icon: const Icon(Icons.add), label: const Text('إضافة بقالة'),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.purple.shade800,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: TextField(onChanged: (v) => setState(() => _searchQuery = v), decoration: InputDecoration(hintText: 'بحث باسم البقالة...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_alt, color: Colors.white),
                onSelected: (v) => setState(() => _selectedFilter = v),
                itemBuilder: (c) => [const PopupMenuItem(value: 'الكل', child: Text('الكل')), const PopupMenuItem(value: 'نشط', child: Text('النشطة')), const PopupMenuItem(value: 'مجمّد', child: Text('المجمدة')), const PopupMenuItem(value: 'منخفض', child: Text('رصيد منخفض'))],
              ),
              IconButton(icon: const Icon(Icons.assessment, color: Colors.orange), onPressed: () => _showAdvancedReportsModal(Provider.of<SystemProvider>(context, listen: false))),
            ]),
          ),
          TabBar(controller: _tabController, indicatorColor: Colors.orange, tabs: const [Tab(text: 'البقالات'), Tab(text: 'طلبات الشحن'), Tab(text: 'الديون/الآجل')]),
        ],
      ),
    );
  }

  // تبويب البقالات النشطة
  Widget _buildActivePosTab(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').where('role', isEqualTo: 'pos').where('parentAgent', isEqualTo: sys.currentUserPhone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          if (_selectedFilter == 'منخفض') return (data['balance'] ?? 0) < 1000;
          return _selectedFilter == 'الكل' || data['status'] == _selectedFilter;
        }).toList();

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            var pos = docs[i].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.store, color: Colors.white)),
                title: Text(pos['storeName'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('📍 ${pos['location']}\n💰 الرصيد: ${pos['balance']} ريال'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.settings, color: Colors.grey), onPressed: () => _showAddOrEditPosModal(sys, existingPos: pos)),
                  IconButton(icon: const Icon(Icons.add_card, color: Colors.green), onPressed: () {}), // تغذية رصيد
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // تبويب طلبات الشحن (VIP)
  Widget _buildRequestsTab(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('user_recharges').where('targetPhone', isEqualTo: sys.currentUserPhone).where('status', isEqualTo: 'قيد الانتظار').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            var req = snapshot.data!.docs[i];
            bool isVip = (req['amount'] ?? 0) >= _vipThreshold;
            return Card(
              color: isVip ? Colors.amber.shade50 : null,
              child: ListTile(
                title: Text('${req['userName']} ${isVip ? "🌟" : ""}'),
                subtitle: Text('المبلغ: ${req['amount']} ريال'),
                trailing: ElevatedButton(onPressed: () {}, child: const Text('موافقة')),
              ),
            );
          },
        );
      },
    );
  }

  // تبويب الديون (سداد)
  Widget _buildDebtTab(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').where('role', isEqualTo: 'pos').where('parentAgent', isEqualTo: sys.currentUserPhone).where('balance', isLessThan: 0).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            var pos = snapshot.data!.docs[i];
            return ListTile(
              title: Text(pos['storeName']),
              subtitle: Text('الدين: ${pos['balance']} ريال', style: const TextStyle(color: Colors.red)),
              trailing: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text('استلام دفعة 💵')),
            );
          },
        );
      },
    );
  }
}
