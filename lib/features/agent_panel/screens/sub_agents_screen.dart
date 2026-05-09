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
  
  // إعدادات الترقية الآلية (VIP)
  double _vipThreshold = 50000.0;
  String _autoVipCommission = '5%';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // ⚙️ إعدادات الترقية التلقائية للزبائن
  // ==========================================
  void _showVipSettingsDialog() {
    _play('click');
    TextEditingController thresholdCtrl = TextEditingController(text: _vipThreshold.toString());
    TextEditingController commissionCtrl = TextEditingController(text: _autoVipCommission.replaceAll('%', ''));

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعدادات الترقية التلقائية 🌟', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('إذا طلب زبون عادي شحناً بهذا المبلغ أو أكثر، سيتم ترقيته تلقائياً لبقالة واعتماد هذا الخصم له.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 15),
              TextField(controller: thresholdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ الشحن المستهدف (ريال)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: commissionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'نسبة الخصم التلقائية (%)', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              onPressed: () {
                setState(() {
                  _vipThreshold = double.tryParse(thresholdCtrl.text) ?? 50000.0;
                  _autoVipCommission = '${commissionCtrl.text}%';
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الترقية التلقائية', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 💰 نافذة التغذية المباشرة للمحفظة
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
            title: Text('تغذية محفظة: $posName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رصيدك الحالي: $agentBalance ريال', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(controller: amountController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'المبلغ المراد تحويله (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: isSubmitting ? null : () async {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  if (amount > 0 && amount <= agentBalance) {
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرصيد غير كافٍ أو المبلغ غير صالح', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                  }
                },
                child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('تحويل', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ⚙️ نافذة الإضافة/التعديل (المطورة مع آلية الخصم)
  // ==========================================
  void _showAddOrEditPosModal(SystemProvider sys, {Map<String, dynamic>? existingPos, String? initialPhone}) async {
    _play('click');
    bool isEdit = existingPos != null;
    String phone = initialPhone ?? existingPos?['phone'] ?? '';
    String name = existingPos?['storeName'] ?? '';
    String location = existingPos?['location'] ?? '';

    Map<String, dynamic> relations = existingPos?['agent_relations'] ?? {};
    Map<String, dynamic> myRelation = relations[sys.currentUserPhone] ?? {};

    String commission = myRelation['commission']?.replaceAll('%', '') ?? '0';
    double limit = (myRelation['creditLimit'] ?? 0.0).toDouble();
    final double oldLimit = limit; // للرجوع إليه عند التعديل
    List<String> allowedCats = List<String>.from(myRelation['allowedCategories'] ?? []);
    bool isSubmitting = false;

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
                  const SizedBox(height: 10),
                  // 🆕 عرض الرصيد الحالي للوكيل
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('رصيدك: ${sys.currentUserBalance.toStringAsFixed(0)} ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(enabled: !isEdit && initialPhone == null, controller: TextEditingController(text: phone), onChanged: (v) => phone = v, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'رقم هاتف الزبون المسجل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 12),
                  TextField(controller: TextEditingController(text: name), onChanged: (v) => name = v, decoration: InputDecoration(labelText: 'اسم البقالة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 12),
                  TextField(controller: TextEditingController(text: location), onChanged: (v) => location = v, decoration: InputDecoration(labelText: 'الموقع/العنوان (إجباري)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: TextEditingController(text: limit.toString()),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        setModalState(() => limit = double.tryParse(v) ?? 0);
                      },
                      decoration: InputDecoration(
                        labelText: 'الحد الائتماني',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        // 🆕 تحذير عند تجاوز الرصيد المتاح
                        errorText: (limit > sys.currentUserBalance && !isEdit) ? 'أكبر من رصيدك!' : null,
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: TextEditingController(text: commission), keyboardType: TextInputType.number, onChanged: (v) => commission = v, decoration: InputDecoration(labelText: 'العمولة %', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                  ]),
                  // 🆕 تنبيه الخصم عند الإضافة
                  if (!isEdit && limit > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('سيتم خصم $limit ريال من رصيدك عند الترقية.', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 15),
                  const Align(alignment: Alignment.centerRight, child: Text('تحديد الفئات المسموح بيعها:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
                  if (allAvailableCats.isEmpty) const Text('لم تقم بإضافة فئات في قسم المايكروتيك بعد!', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ...allAvailableCats.map((cat) => CheckboxListTile(
                    title: Text(cat['name'], style: const TextStyle(fontSize: 13)),
                    value: allowedCats.contains(cat['id']),
                    activeColor: Colors.purple,
                    onChanged: (val) { setModalState(() { val! ? allowedCats.add(cat['id']) : allowedCats.remove(cat['id']); }); },
                  )),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    onPressed: (isSubmitting || (!isEdit && limit > sys.currentUserBalance)) ? null : () async {
                      if (phone.isEmpty || name.isEmpty || location.isEmpty) {
                        _play('error');
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرقم والاسم والموقع حقول إجبارية!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                        return;
                      }
                      setModalState(() => isSubmitting = true);
                      try {
                        if (isEdit) {
                          await sys.updatePosDetails(
                            posPhone: phone, storeName: name, location: location,
                            creditLimit: limit, commission: '$commission%',
                            allowedCategories: allowedCats,
                            oldCreditLimit: oldLimit, // للدالة الجديدة
                          );
                        } else {
                          await sys.upgradeUserToPos(
                            posPhone: phone, storeName: name, location: location,
                            creditLimit: limit, commission: '$commission%',
                            allowedCategories: allowedCats,
                            creditDeduction: limit, // يُخصم مباشرة
                          );
                        }
                        _play('success'); Navigator.pop(context);
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        _play('error');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString(), textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                      }
                    },
                    child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(isEdit ? 'حفظ التعديلات' : 'اعتماد وترقية', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  // 💵 نافذة استلام دفعة (سداد الديون)
  // ==========================================
  void _showRepaymentModal(SystemProvider sys, String posPhone, String posName) {
    _play('click');
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تسديد دين: $posName', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المستلم كاش (ريال)')),
                const SizedBox(height: 10),
                TextField(controller: noteController, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: isSubmitting ? null : () async {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  if (amount > 0) {
                    setStateDialog(() => isSubmitting = true);
                    try {
                      await sys.receivePosPayment(posPhone, amount, noteController.text);
                      _play('success');
                      if(mounted){
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل السداد بنجاح ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                      }
                    } catch(e) {
                      setStateDialog(() => isSubmitting = false);
                      _play('error');
                    }
                  }
                },
                child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('تأكيد الاستلام', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة نقاط البيع الذكية'),
      drawer: CustomAgentDrawer(agentName: sys.currentUserName, phoneNumber: sys.currentUserPhone, role: 'وكيل', currentBalance: sys.currentUserBalance),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: isDark ? Colors.grey.shade900 : Colors.purple.shade800,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(child: TextField(onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()), decoration: InputDecoration(hintText: 'بحث برقم أو اسم البقالة...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 15)))),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.filter_list, color: Colors.white),
                          onSelected: (v) => setState(() => _selectedFilter = v),
                          itemBuilder: (c) => [const PopupMenuItem(value: 'الكل', child: Text('الكل')), const PopupMenuItem(value: 'نشط', child: Text('النشطة 🟢')), const PopupMenuItem(value: 'مجمّد', child: Text('المجمدة 🔴')), const PopupMenuItem(value: 'منخفض', child: Text('رصيد منخفض ⚠️'))],
                        ),
                      ),
                    ]),
                  ),
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.white, 
                    unselectedLabelColor: Colors.white70, 
                    indicatorColor: Colors.orange, indicatorWeight: 4,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), 
                    tabs: const [Tab(text: 'البقالات 🏪'), Tab(text: 'طلبات الشحن 📥'), Tab(text: 'الديون (الآجل) 🧾')],
                  ),
                ],
              ),
            ),
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
        backgroundColor: Colors.purple.shade800, icon: const Icon(Icons.add_business, color: Colors.white), label: const Text('إضافة بقالة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // التبويب 1: البقالات النشطة (مُطوَّر)
  // ==========================================
  Widget _buildActivePosTab(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').where('role', isEqualTo: 'pos').where('pos_agents', arrayContains: sys.currentUserPhone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          String sName = (data['storeName'] ?? '').toLowerCase();
          String oName = (data['name'] ?? '').toLowerCase();
          String phone = data['phone'] ?? '';
          
          Map<String, dynamic> wallets = data['wallets'] ?? {};
          double posWalletBal = (wallets[sys.currentUserPhone] ?? 0.0).toDouble();

          String status = data['status'] ?? 'نشط';

          bool matchesSearch = _searchQuery.isEmpty || sName.contains(_searchQuery) || oName.contains(_searchQuery) || phone.contains(_searchQuery);
          
          bool matchesFilter = true;
          if (_selectedFilter == 'منخفض') { matchesFilter = posWalletBal < 1000; } 
          else if (_selectedFilter != 'الكل') { matchesFilter = status == _selectedFilter; }

          return matchesSearch && matchesFilter;
        }).toList();

        if (docs.isEmpty) return const Center(child: Text('لا توجد بيانات مطابقة.'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            var pos = docs[i].data() as Map<String, dynamic>;
            bool isFrozen = pos['status'] == 'مجمّد';
            
            Map<String, dynamic> wallets = pos['wallets'] ?? {};
            double posWalletBal = (wallets[sys.currentUserPhone] ?? 0.0).toDouble();
            bool isLow = posWalletBal < 1000;

            Map<String, dynamic> relations = pos['agent_relations'] ?? {};
            Map<String, dynamic> myRel = relations[sys.currentUserPhone] ?? {};
            double creditLimit = (myRel['creditLimit'] ?? 0.0).toDouble();
            String commission = myRel['commission'] ?? '0%';

            // 🆕 تحديد ما إذا تجاوزت الدين المسموح
            bool overLimit = posWalletBal < -creditLimit;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: overLimit ? Colors.red : (isFrozen ? Colors.red.shade300 : Colors.grey.shade200), width: overLimit ? 2 : 1),
              ),
              color: overLimit ? Colors.red.shade50 : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(backgroundColor: isFrozen ? Colors.red.shade100 : Colors.purple.shade100, radius: 25, child: Icon(Icons.store, color: isFrozen ? Colors.red : Colors.purple)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pos['storeName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isFrozen ? TextDecoration.lineThrough : null)),
                              Text('📍 ${pos['location'] ?? 'بدون عنوان'}', style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('المالك: ${pos['name']} | رقم: ${pos['phone']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              if (overLimit) const Text('⚠️ تجاوزت الحد الائتماني!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddOrEditPosModal(sys, existingPos: pos)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('رصيد المحفظة:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text('$posWalletBal ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isLow ? Colors.red : Colors.black87)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          const Text('الحد الائتماني:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text('$creditLimit ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Text('العمولة:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(commission, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(flex: 2, child: ElevatedButton.icon(onPressed: isFrozen ? null : () => _showTransferModal(sys, pos['phone'], pos['storeName'] ?? '', sys.currentUserBalance), icon: const Icon(Icons.add_card, size: 16, color: Colors.white), label: const Text('تغذية محفظتها', style: TextStyle(color: Colors.white, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple))),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: OutlinedButton(
                          onPressed: () => _showRepaymentModal(sys, pos['phone'], pos['storeName'] ?? ''),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                          child: const Text('استلام دفعة', style: TextStyle(fontSize: 11)),
                        )),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: OutlinedButton(
                          onPressed: () { _play('click'); _db.collection('users').doc(pos['phone']).update({'status': isFrozen ? 'نشط' : 'مجمّد'}); },
                          style: OutlinedButton.styleFrom(foregroundColor: isFrozen ? Colors.green : Colors.red, side: BorderSide(color: isFrozen ? Colors.green : Colors.red)),
                          child: Text(isFrozen ? 'تنشيط' : 'تجميد', style: const TextStyle(fontSize: 11)),
                        )),
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

  // ==========================================
  // التبويب 2: طلبات الشحن (مع تطوير VIP)
  // ==========================================
  Widget _buildRequestsTab(SystemProvider sys) {
    return Column(
      children: [
        Container(
          color: Colors.amber.shade50, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🌟 نظام الترقية التلقائية:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              TextButton.icon(
                onPressed: _showVipSettingsDialog, icon: const Icon(Icons.settings, size: 16, color: Colors.orange),
                label: Text('المستهدف: $_vipThreshold', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('user_recharges').where('targetPhone', isEqualTo: sys.currentUserPhone).where('status', isEqualTo: 'قيد الانتظار').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var requests = snapshot.data!.docs;
              if (requests.isEmpty) return const Center(child: Text('لا توجد طلبات شحن معلقة.', style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.all(12), itemCount: requests.length,
                itemBuilder: (context, i) {
                  var req = requests[i].data() as Map<String, dynamic>;
                  String reqId = requests[i].id;
                  double reqAmount = (req['amount'] ?? 0).toDouble();
                  bool isVip = reqAmount >= _vipThreshold; 

                  return Card(
                    color: isVip ? Colors.amber.shade50 : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isVip ? Colors.amber : Colors.blue.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${req['userName']} ${isVip ? "🌟" : ""}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(isVip ? 'يستحق الترقية!' : 'طلب عادي', style: TextStyle(color: isVip ? Colors.orange : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Align(alignment: Alignment.centerRight, child: Text('المبلغ: $reqAmount ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isVip ? Colors.amber.shade800 : Colors.blue))),
                          const Divider(),
                          Row(
                            children: [
                              Expanded(child: OutlinedButton(onPressed: () { _play('click'); _db.collection('user_recharges').doc(reqId).update({'status': 'مرفوض'}); }, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('رفض'))),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: ElevatedButton(
                                onPressed: () async {
                                  _play('click');
                                  if (isVip) {
                                    // 🆕 فتح نافذة تأكيدية لتعديل بيانات الترقية
                                    _confirmVipUpgrade(req);
                                  } else {
                                    try {
                                      await sys.agentAcceptUserRecharge(reqId, req['userPhone'], reqAmount);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الموافقة بنجاح ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString(), textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('موافقة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              )),
                            ],
                          )
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

  // 🆕 نافذة تأكيد الترقية التلقائية VIP
  void _confirmVipUpgrade(Map<String, dynamic> req) {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    String storeName = 'محل ${req['userName']}';
    String location = 'غير محدد';
    double creditLimit = (req['amount'] ?? 0).toDouble(); // افتراضاً يساوي مبلغ الشحن
    String commission = _autoVipCommission;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد الترقية التلقائية 🌟'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('سيتم ترقية ${req['userName']} إلى بقالة بالبيانات التالية. يمكنك تعديلها قبل الحفظ.'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: TextEditingController(text: storeName),
                    onChanged: (v) => storeName = v,
                    decoration: const InputDecoration(labelText: 'اسم البقالة', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: location),
                    onChanged: (v) => location = v,
                    decoration: const InputDecoration(labelText: 'الموقع', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: creditLimit.toString()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => creditLimit = double.tryParse(v) ?? 0,
                    decoration: const InputDecoration(labelText: 'الحد الائتماني', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await sys.agentAcceptUserRecharge(req['docId'] ?? '', req['userPhone'], (req['amount'] ?? 0).toDouble());
                    await sys.upgradeUserToPos(
                      posPhone: req['userPhone'],
                      storeName: storeName,
                      location: location,
                      creditLimit: creditLimit,
                      commission: commission,
                      allowedCategories: [],
                      creditDeduction: creditLimit, // يُخصم من الوكيل
                    );
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('تمت الموافقة والترقية بنجاح 🌟', textDirection: TextDirection.rtl),
                      backgroundColor: Colors.green,
                    ));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString(), textDirection: TextDirection.rtl),
                      backgroundColor: Colors.red,
                    ));
                  }
                },
                child: const Text('ترقية وإعتماد', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // التبويب 3: سجل الديون (مُطوَّر)
  // ==========================================
  Widget _buildDebtTab(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').where('role', isEqualTo: 'pos').where('pos_agents', arrayContains: sys.currentUserPhone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          Map<String, dynamic> wallets = data['wallets'] ?? {};
          double bal = (wallets[sys.currentUserPhone] ?? 0.0).toDouble();
          return bal < 0; 
        }).toList();

        if (docs.isEmpty) return const Center(child: Text('لا توجد ديون مسجلة. 👏', style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(12), itemCount: docs.length,
          itemBuilder: (context, i) {
            var pos = docs[i].data() as Map<String, dynamic>;
            Map<String, dynamic> wallets = pos['wallets'] ?? {};
            double debtAmount = (wallets[sys.currentUserPhone] ?? 0.0).toDouble().abs();

            return Card(
              shape: const Border(right: BorderSide(color: Colors.red, width: 4)),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(pos['storeName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                        Text('$debtAmount ريال', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('الموقع: ${pos['location'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showRepaymentModal(sys, pos['phone'], pos['storeName'] ?? ''),
                            icon: const Icon(Icons.money, size: 16, color: Colors.white),
                            label: const Text('استلام دفعة', style: TextStyle(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 🆕 زر إرسال تذكير (إشعار)
                        IconButton(
                          icon: const Icon(Icons.notifications_active, color: Colors.orange),
                          tooltip: 'إرسال تذكير',
                          onPressed: () {
                            _db.collection('notifications').add({
                              'targetPhones': [pos['phone']],
                              'title': 'تذكير بالسداد ⏰',
                              'body': 'الرجاء سداد المبلغ المستحق عليك ($debtAmount ريال) إلى الوكيل ${sys.currentUserName}.',
                              'timestamp': FieldValue.serverTimestamp(),
                              'isRead': false,
                              'readBy': [],
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال تذكير للبقالة.', textDirection: TextDirection.rtl)));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }
}
