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
  String _selectedFilter = 'الكل'; // 👈 الفلتر المخفي
  double _vipThreshold = 50000.0; // 👈 حد الترقية التلقائية (VIP)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // 1. نافذة التغذية المباشرة 💰
  // ==========================================
  void _showTransferModal(SystemProvider sys, String posPhone, String posName, double agentBalance) {
    _play('click');
    final TextEditingController amountController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text('تغذية حساب: $posName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('محفظتك الحالية: $agentBalance ريال', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المراد تحويله للبقالة (ريال)',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              if (!isSubmitting)
                TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSubmitting ? null : () async {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  if (amount > 0 && amount <= agentBalance) {
                    _play('click');
                    setStateDialog(() => isSubmitting = true);
                    try {
                      await sys.fundSubAgent(posPhone, amount);
                      _play('success');
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحويل $amount ريال بنجاح! ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setStateDialog(() => isSubmitting = false);
                      _play('error');
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString(), textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                    }
                  } else {
                    _play('error');
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المبلغ غير صالح أو رصيدك غير كافٍ! ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                  }
                },
                child: isSubmitting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تحويل الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة الإحصائيات والطباعة الملونة 📊🖨️
  // ==========================================
  void _showStatsAndPrintModal(String posPhone, String posName) async {
    _play('click');
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.purple, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    );

    if (pickedRange == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        String fromDate = DateFormat('yyyy-MM-dd').format(pickedRange.start);
        String toDate = DateFormat('yyyy-MM-dd').format(pickedRange.end);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تقرير البقالة: $posName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
                    ElevatedButton.icon(
                      onPressed: () { _play('success'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تصدير التقرير للطباعة (PDF)...', textDirection: TextDirection.rtl), backgroundColor: Colors.blue)); },
                      icon: const Icon(Icons.print, color: Colors.white, size: 18),
                      label: const Text('طباعة', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
                    )
                  ],
                ),
                const SizedBox(height: 5),
                Text('الفترة: من $fromDate إلى $toDate', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Divider(height: 30),
                
                // جدول ملون وأنيق
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.purple.withOpacity(0.1)),
                        columns: const [
                          DataColumn(label: Text('البيان', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('المبلغ', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: [
                          DataRow(cells: [const DataCell(Text('مبيعات كروت فئة 500')), const DataCell(Text('15,000 ريال')), DataCell(Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(5)), child: const Text('أرباح 🟢', style: TextStyle(color: Colors.green, fontSize: 10))))]),
                          DataRow(cells: [const DataCell(Text('تغذية رصيد آجل')), const DataCell(Text('50,000 ريال')), DataCell(Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(5)), child: const Text('ديون 🔴', style: TextStyle(color: Colors.red, fontSize: 10))))]),
                          DataRow(cells: [const DataCell(Text('مبيعات كروت فئة 1000')), const DataCell(Text('8,000 ريال')), DataCell(Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(5)), child: const Text('أرباح 🟢', style: TextStyle(color: Colors.green, fontSize: 10))))]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 3. نافذة إضافة البقالة الذكية (الترقية) 🏪📍
  // ==========================================
  void _showAddSubAgentModal(SystemProvider sys, {String? initialPhone}) {
    _play('click');
    String phone = initialPhone ?? '', name = '', location = '', creditLimit = '', commission = '';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 16, right: 16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ترقية زبون إلى نقطة بيع (بقالة) 🏪', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('يجب أن يكون الزبون قد حمّل التطبيق وسجل رقمه مسبقاً', style: TextStyle(fontSize: 11, color: Colors.blue)),
                    const SizedBox(height: 20),
                    
                    TextField(
                      controller: TextEditingController(text: initialPhone)..selection = TextSelection.collapsed(offset: initialPhone?.length ?? 0),
                      onChanged: (val) => phone = val, keyboardType: TextInputType.phone, 
                      decoration: InputDecoration(labelText: 'رقم هاتف الزبون المسجل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.phone))
                    ),
                    const SizedBox(height: 12),
                    TextField(onChanged: (val) => name = val, decoration: InputDecoration(labelText: 'اسم البقالة الذي سيظهر للجمهور', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.storefront))),
                    const SizedBox(height: 12),
                    // 👈 حقل الموقع الذي اقترحته أنت
                    TextField(onChanged: (val) => location = val, decoration: InputDecoration(labelText: 'موقع البقالة (مثال: صنعاء - الدائري)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.location_on, color: Colors.red))),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(child: TextField(onChanged: (val) => creditLimit = val, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الحد الائتماني (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.account_balance_wallet)))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(onChanged: (val) => commission = val, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'نسبة العمولة (%)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.percent)))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting ? null : () async {
                          if (phone.isNotEmpty && name.isNotEmpty && location.isNotEmpty) {
                            _play('click');
                            setModalState(() => isSubmitting = true);
                            try {
                              // ترقية الزبون لبقالة
                              await sys.upgradeUserToPos(
                                posPhone: phone, 
                                storeName: name, 
                                creditLimit: double.tryParse(creditLimit) ?? 0.0, 
                                commission: commission.isNotEmpty ? '$commission%' : '0%'
                              );
                              
                              // إضافة الموقع في جدول نقاط البيع لمعرض الجمهور
                              await _db.collection('points_of_sale').doc(phone).update({'location': location});

                              _play('success');
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترقية الزبون وإضافته لسوق الشبكات بنجاح! ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              _play('error');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString(), textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                            }
                          } else {
                            _play('error');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة الرقم، الاسم، والموقع! ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                          }
                        },
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('ترقية وإضافة للسوق', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة نقاط البيع (البقالات)'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.only(bottom: 5, top: 5),
              decoration: BoxDecoration(color: isDark ? Colors.grey.shade900 : Colors.purple.shade800, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white, unselectedLabelColor: Colors.white54, indicatorColor: Colors.orange, indicatorWeight: 4,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.storefront), text: 'البقالات النشطة'),
                  Tab(icon: Icon(Icons.notifications_active), text: 'طلبات الشحن'),
                  Tab(icon: Icon(Icons.receipt_long), text: 'سجل الديون (آجل)'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSubAgentsTab(sys),
                  _buildPendingRequestsTab(sys),
                  _buildDebtsTab(sys),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Directionality(
        textDirection: TextDirection.rtl,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddSubAgentModal(sys),
          backgroundColor: Colors.purple.shade800,
          icon: const Icon(Icons.add_business, color: Colors.white),
          label: const Text('إضافة بقالة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ==========================================
  // تبويب 1: البقالات المعتمدة
  // ==========================================
  Widget _buildSubAgentsTab(SystemProvider sys) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن بقالة...',
                    prefixIcon: const Icon(Icons.search, color: Colors.purple),
                    filled: true, fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 👈 زر القائمة المنبثقة للفلترة (حسب طلبك)
              Container(
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list, color: Colors.purple),
                  tooltip: 'فلترة',
                  onSelected: (value) => setState(() => _selectedFilter = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'الكل', child: Text('الكل')),
                    const PopupMenuItem(value: 'نشط', child: Text('النشطة 🟢')),
                    const PopupMenuItem(value: 'مجمّد', child: Text('المجمدة 🔴')),
                    const PopupMenuItem(value: 'رصيد منخفض', child: Text('رصيد منخفض ⚠️')),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').where('role', isEqualTo: 'pos').where('parentAgent', isEqualTo: sys.currentUserPhone).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد بقالات تابعة لك حتى الآن.'));

              var agents = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String status = data['status'] ?? 'نشط';
                bool matchesSearch = (data['storeName']?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) || (data['phone']?.contains(_searchQuery) ?? false);
                bool matchesFilter = _selectedFilter == 'الكل' || status == _selectedFilter;
                return matchesSearch && matchesFilter;
              }).toList();

              if (agents.isEmpty) return const Center(child: Text('لا توجد نتائج مطابقة للبحث/الفلتر'));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: agents.length,
                itemBuilder: (context, index) {
                  final docId = agents[index].id;
                  final agent = agents[index].data() as Map<String, dynamic>;
                  bool isLow = (agent['balance'] ?? 0) < 1000;
                  bool isFrozen = agent['status'] == 'مجمّد';
                  String statusText = isFrozen ? 'مجمّد' : (isLow ? 'رصيد منخفض' : 'نشط');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isFrozen ? Colors.red.shade200 : Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(backgroundColor: isFrozen ? Colors.red.withOpacity(0.1) : Colors.purple.withOpacity(0.1), radius: 25, child: Icon(Icons.store, color: isFrozen ? Colors.red : Colors.purple)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(agent['storeName'] ?? 'بدون اسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isFrozen ? TextDecoration.lineThrough : null)),
                                    const SizedBox(height: 2),
                                    Text('📍 عبر: ${agent['name']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    Text('الهاتف: ${agent['phone']} | العمولة: ${agent['commission'] ?? '0%'}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.bar_chart, color: Colors.blue),
                                tooltip: 'الإحصائيات',
                                onPressed: () => _showStatsAndPrintModal(agent['phone'], agent['storeName'] ?? 'بقالة'),
                              )
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('الرصيد المتاح:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text('${agent['balance'] ?? 0} ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLow ? Colors.red : Colors.black87)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('الحد الائتماني:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text('${agent['creditLimit'] ?? 0} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: isFrozen ? null : () => _showTransferModal(sys, agent['phone'], agent['storeName'] ?? '', sys.currentUserBalance),
                                  icon: const Icon(Icons.add_card, size: 16, color: Colors.white),
                                  label: const Text('تغذية الرصيد', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed: () {
                                    _play('click');
                                    String newStatus = isFrozen ? 'نشط' : 'مجمّد';
                                    _db.collection('users').doc(docId).update({'status': newStatus});
                                  },
                                  style: OutlinedButton.styleFrom(foregroundColor: isFrozen ? Colors.green : Colors.red, side: BorderSide(color: isFrozen ? Colors.green : Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  child: Text(isFrozen ? 'تنشيط' : 'تجميد', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
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
          ),
        ),
      ],
    );
  }

  // ==========================================
  // تبويب 2: طلبات الشحن (مع رادار الـ VIP) 🌟
  // ==========================================
  Widget _buildPendingRequestsTab(SystemProvider sys) {
    return Column(
      children: [
        // 👈 زر التحكم بحد الترقية التلقائية
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.orange.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('💡 حد الـ VIP للزبائن:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              TextButton.icon(
                onPressed: () {
                  _play('click');
                  showDialog(context: context, builder: (c) => AlertDialog(
                    title: const Text('تحديد مبلغ الترقية (VIP)', textDirection: TextDirection.rtl),
                    content: TextField(keyboardType: TextInputType.number, onChanged: (v) => _vipThreshold = double.tryParse(v) ?? 50000.0, decoration: const InputDecoration(hintText: 'مثال: 50000')),
                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('حفظ'))],
                  ));
                },
                icon: const Icon(Icons.edit, size: 16, color: Colors.orange),
                label: Text('$_vipThreshold ريال', style: const TextStyle(color: Colors.orange)),
              )
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('user_recharges').where('targetPhone', isEqualTo: sys.currentUserPhone).where('status', isEqualTo: 'قيد الانتظار').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد طلبات شحن معلقة حالياً. 🎉', style: TextStyle(color: Colors.grey)));

              var requests = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  var req = requests[index].data() as Map<String, dynamic>;
                  String reqId = requests[index].id;
                  double reqAmount = (req['amount'] ?? 0).toDouble();
                  bool isVip = reqAmount >= _vipThreshold; // 👈 التحقق الذكي من المبلغ

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isVip ? Colors.amber.shade50 : Colors.blue.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isVip ? Colors.amber : Colors.blue.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if(isVip) const Icon(Icons.star, color: Colors.amber, size: 20),
                                  const SizedBox(width: 5),
                                  Text(req['userName'] ?? 'مجهول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              Text('طالب شحن', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text('المبلغ المطلوب: ', style: TextStyle(fontSize: 14)),
                              Text('$reqAmount ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isVip ? Colors.amber.shade800 : Colors.blue)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    _play('click');
                                    _db.collection('user_recharges').doc(reqId).update({'status': 'مرفوض'});
                                  },
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                  child: const Text('رفض'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    _play('click');
                                    if (isVip) {
                                      // 👈 إذا كان زبون VIP نفتح له رسالة الترقية!
                                      showDialog(context: context, builder: (c) => Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: AlertDialog(
                                          title: const Text('🌟 زبون تجاري (VIP)'),
                                          content: const Text('هذا الزبون يشتري بكميات الجملة! هل تريد ترقيته لنقطة بيع رسمية وإعطاءه عمولة أم الموافقة كزبون عادي؟'),
                                          actions: [
                                            TextButton(onPressed: () async { Navigator.pop(c); await sys.agentAcceptUserRecharge(reqId, req['userPhone'], reqAmount); }, child: const Text('موافقة فقط', style: TextStyle(color: Colors.grey))),
                                            ElevatedButton(onPressed: () { Navigator.pop(c); _showAddSubAgentModal(sys, initialPhone: req['userPhone']); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700), child: const Text('ترقية لبقالة', style: TextStyle(color: Colors.white))),
                                          ],
                                        ),
                                      ));
                                    } else {
                                      try {
                                        await sys.agentAcceptUserRecharge(reqId, req['userPhone'], reqAmount);
                                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الموافقة بنجاح ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                                      } catch(e) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString(), textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('موافقة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
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
          ),
        ),
      ],
    );
  }

  // ==========================================
  // تبويب 3: سجل الديون والمطالبات (آجل) 🧾
  // ==========================================
  Widget _buildDebtsTab(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      // 👈 نجلب البقالات التي رصيدها قليل وتحتاج تسديد
      stream: _db.collection('users').where('role', isEqualTo: 'pos').where('parentAgent', isEqualTo: sys.currentUserPhone).where('balance', isLessThan: 5000).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد بقالات مديونة حالياً. 👏', style: TextStyle(color: Colors.grey)));

        var agents = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: agents.length,
          itemBuilder: (context, index) {
            final agent = agents[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: Border(right: BorderSide(color: Colors.red.shade400, width: 4)),
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: Text(agent['storeName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('الرصيد المتبقي: ${agent['balance']} ريال\nالحد الائتماني: ${agent['creditLimit']} ريال', style: const TextStyle(fontSize: 12)),
                trailing: ElevatedButton(
                  onPressed: () => _showTransferModal(sys, agent['phone'], agent['storeName'] ?? '', sys.currentUserBalance),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(horizontal: 10)),
                  child: const Text('استلام دفعة', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            );
          }
        );
      }
    );
  }
}
