import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class MikrotikCategoriesScreen extends StatefulWidget {
  const MikrotikCategoriesScreen({super.key});

  @override
  State<MikrotikCategoriesScreen> createState() => _MikrotikCategoriesScreenState();
}

class _MikrotikCategoriesScreenState extends State<MikrotikCategoriesScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;
  
  // رابط السيرفر الخاص بك على Render
  final String _renderUrl = "https://mikrotik-server-qu6a.onrender.com";

  final TextEditingController _generateAmountController = TextEditingController();
  String? _selectedCategoryToGenerate;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ---------------------------------------------------------
  // نافذة التأكيد (حماية ضد الضغط الخاطئ)
  // ---------------------------------------------------------
  Future<bool> _confirmAction(String title, String message, Color color) async {
    _play('warning');
    return await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () { _play('click'); Navigator.pop(context, false); },
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () { _play('click'); Navigator.pop(context, true); },
              child: const Text('تأكيد التنفيذ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  // ---------------------------------------------------------
  // إدارة الشبكات: إضافة وتعديل
  // ---------------------------------------------------------
  void _showServerForm({Map<String, dynamic>? existingData, String? docId}) {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    
    final nameC = TextEditingController(text: existingData?['name'] ?? '');
    final ipC = TextEditingController(text: existingData?['ip'] ?? '');
    final userC = TextEditingController(text: existingData?['apiUser'] ?? '');
    final passC = TextEditingController(text: existingData?['apiPassword'] ?? '');
    final loginUrlC = TextEditingController(text: existingData?['loginUrl'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 16, right: 16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(docId == null ? 'إضافة شبكة ميكروتك جديدة 📡' : 'تعديل بيانات الشبكة ✏️', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: nameC, decoration: InputDecoration(labelText: 'اسم الشبكة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.dns))),
                const SizedBox(height: 12),
                TextField(controller: ipC, decoration: InputDecoration(labelText: 'IP الميكروتك / DDNS', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.wifi))),
                const SizedBox(height: 12),
                TextField(controller: loginUrlC, decoration: InputDecoration(labelText: 'رابط صفحة تسجيل الدخول (الزبائن سيفتحونه)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.link))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: userC, decoration: InputDecoration(labelText: 'مستخدم API', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: passC, obscureText: true, decoration: InputDecoration(labelText: 'الباسورد', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      if (nameC.text.isEmpty || ipC.text.isEmpty) { _play('error'); return; }
                      
                      bool confirm = await _confirmAction("حفظ التغييرات", "هل أنت متأكد من صحة البيانات المدخلة؟", Colors.blue);
                      if (!confirm) return;

                      final data = {
                        'name': nameC.text, 'ip': ipC.text, 'apiUser': userC.text, 'apiPassword': passC.text,
                        'loginUrl': loginUrlC.text, 'agentPhone': sys.currentUserPhone, 'isActive': existingData?['isActive'] ?? true,
                        'apiPort': '8728', 'updatedAt': FieldValue.serverTimestamp(),
                      };

                      if (docId == null) {
                        data['createdAt'] = FieldValue.serverTimestamp();
                        data['categories'] = [];
                        await _db.collection('networks').add(data);
                      } else {
                        await _db.collection('networks').doc(docId).update(data);
                      }
                      Navigator.pop(context);
                      _play('success');
                    },
                    child: const Text('حفظ البيانات والربط', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // اختبار الاتصال بالميكروتك (زر الفلاش)
  // ---------------------------------------------------------
  Future<void> _testConnection(Map<String, dynamic> net) async {
    _play('click');
    setState(() => _isProcessing = true);
    try {
      final response = await http.post(
        Uri.parse("$_renderUrl/testConnection"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"host": net['ip'], "user": net['apiUser'], "pass": net['apiPassword'], "port": net['apiPort']}),
      );
      if (response.statusCode == 200) {
        _play('success');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاتصال بالميكروتك بنجاح! ✅'), backgroundColor: Colors.green));
      } else { throw 'الراوتر لا يستجيب'; }
    } catch (e) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الاتصال: $e ❌'), backgroundColor: Colors.red));
    }
    setState(() => _isProcessing = false);
  }

  // ---------------------------------------------------------
  // إدارة الفئات (إضافة / تعديل / حذف / تجميد)
  // ---------------------------------------------------------
  void _showCategoryForm(String netId, List categories, {Map? existingCat}) {
    _play('click');
    final nameC = TextEditingController(text: existingCat?['name'] ?? '');
    final priceC = TextEditingController(text: existingCat?['price']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(existingCat == null ? 'إضافة فئة كروت' : 'تعديل الفئة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'اسم البروفايل في الميكروتك (Profile)')),
              TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع للجمهور')),
            ],
          ),
          actions: [
            TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameC.text.isEmpty || priceC.text.isEmpty) return;
                _play('click');
                List updatedCats = List.from(categories);
                final newCat = {
                  'id': existingCat?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': nameC.text, 'price': int.parse(priceC.text), 'stock': existingCat?['stock'] ?? 0,
                  'isActive': existingCat?['isActive'] ?? true, 'color': existingCat?['color'] ?? Colors.blue.value,
                };
                if (existingCat == null) { updatedCats.add(newCat); } 
                else {
                  int idx = updatedCats.indexWhere((c) => c['id'] == existingCat['id']);
                  updatedCats[idx] = newCat;
                }
                await _db.collection('networks').doc(netId).update({'categories': updatedCats});
                Navigator.pop(context);
                _play('success');
              },
              child: const Text('حفظ الفئة'),
            )
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // وظيفة توليد الكروت (الاتصال بـ Render)
  // ---------------------------------------------------------
  Future<void> _generateCards() async {
    if (_selectedCategoryToGenerate == null || _generateAmountController.text.isEmpty) return;
    int amount = int.parse(_generateAmountController.text);
    if (amount > 400 || amount <= 0) { _play('error'); return; }

    bool confirmed = await _confirmAction("تأكيد التوليد 🔌", "سيتم الآن توليد $amount كرت وإضافتها للراوتر وللتطبيق. هل تريد الاستمرار؟", Colors.green);
    if (!confirmed) return;

    setState(() => _isProcessing = true);
    _play('click');

    try {
      List parts = _selectedCategoryToGenerate!.split('_');
      final response = await http.post(
        Uri.parse("$_renderUrl/generateMikrotikCards"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"networkId": parts[0], "categoryId": parts[1], "amount": amount, "agentPhone": Provider.of<SystemProvider>(context, listen: false).currentUserPhone}),
      );

      if (response.statusCode == 200) {
        _play('success');
        _generateAmountController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت العملية بنجاح! الكروت جاهزة للبيع 🎟️'), backgroundColor: Colors.green));
      } else { throw jsonDecode(response.body)['error'] ?? 'خطأ غير معروف'; }
    } catch (e) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشلت العملية: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الميكروتك والفئات'),
      drawer: CustomAgentDrawer(agentName: sys.currentUserName, phoneNumber: sys.currentUserPhone, role: 'مدير شبكة', currentBalance: sys.currentUserBalance),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('networks').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var networks = snapshot.data!.docs;
          return Column(
            children: [
              Container(
                color: Colors.blue.shade800,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.orange, unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.orange, indicatorWeight: 3,
                  onTap: (index) { _play('click'); setState(() {}); },
                  tabs: const [Tab(text: 'الشبكات'), Tab(text: 'المخزون'), Tab(text: 'الخصومات'), Tab(text: 'توليد كروت')],
                ),
              ),
              if (_isProcessing) const LinearProgressIndicator(backgroundColor: Colors.orange, color: Colors.white),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNetworksTab(networks),
                    _buildInventoryTab(networks),
                    _buildDiscountsTab(),
                    _buildGenerateTab(networks),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _tabController.index == 0 
        ? FloatingActionButton(onPressed: () => _showServerForm(), backgroundColor: Colors.blue.shade800, child: const Icon(Icons.add, color: Colors.white))
        : null,
    );
  }

  // 1. تبويب الشبكات
  Widget _buildNetworksTab(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return const Center(child: Text('لم يتم ربط أي شبكة حتى الآن'));
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        var net = docs[i].data() as Map<String, dynamic>;
        bool active = net['isActive'] ?? true;
        return Card(
          elevation: 3, color: active ? Colors.white : Colors.grey.shade200,
          child: ListTile(
            leading: Icon(Icons.router, color: active ? Colors.green : Colors.grey),
            title: Text(net['name'], style: TextStyle(fontWeight: FontWeight.bold, decoration: active ? null : TextDecoration.lineThrough)),
            subtitle: Text("IP: ${net['ip']}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.bolt, color: Colors.blue), onPressed: () => _testConnection(net)),
                IconButton(icon: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline, color: Colors.orange), 
                  onPressed: () async {
                    bool c = await _confirmAction(active ? "تجميد الشبكة" : "تنشيط الشبكة", "هل تريد تغيير حالة الشبكة؟", Colors.orange);
                    if(c) {
                       _db.collection('networks').doc(docs[i].id).update({'isActive': !active});
                       _play('success');
                    }
                  }),
                IconButton(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: () => _showServerForm(existingData: net, docId: docs[i].id)),
                IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), 
                  onPressed: () async {
                    bool c = await _confirmAction("حذف الشبكة", "سيتم حذف الشبكة وكافة بياناتها نهائياً!", Colors.red);
                    if(c) {
                       _db.collection('networks').doc(docs[i].id).delete();
                       _play('success');
                    }
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  // 2. تبويب المخزون والفئات
  Widget _buildInventoryTab(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        var net = docs[i].data() as Map<String, dynamic>;
        List cats = net['categories'] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.all(8.0), child: Text("فئات شبكة: ${net['name']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
            ...cats.map((c) => Card(
              child: ListTile(
                title: Text(c['name'], style: TextStyle(decoration: c['isActive'] == false ? TextDecoration.lineThrough : null)),
                subtitle: Text("المخزون: ${c['stock']} كرت | السعر: ${c['price']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: Icon(c['isActive'] == false ? Icons.play_arrow : Icons.stop, color: Colors.orange), 
                      onPressed: () async {
                         bool res = await _confirmAction(c['isActive'] == false ? "تنشيط" : "تجميد", "تغيير حالة الفئة؟", Colors.orange);
                         if(res) {
                            List updated = List.from(cats);
                            int idx = updated.indexWhere((cat) => cat['id'] == c['id']);
                            updated[idx]['isActive'] = !(updated[idx]['isActive'] ?? true);
                            await _db.collection('networks').doc(docs[i].id).update({'categories': updated});
                            _play('success');
                         }
                      }),
                    IconButton(icon: const Icon(Icons.edit_note, color: Colors.blue), onPressed: () => _showCategoryForm(docs[i].id, cats, existingCat: c)),
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), 
                      onPressed: () async {
                        bool res = await _confirmAction("حذف الفئة", "سيتم حذف هذه الفئة من التطبيق نهائياً!", Colors.red);
                        if(res) {
                          List updated = List.from(cats);
                          updated.removeWhere((cat) => cat['id'] == c['id']);
                          await _db.collection('networks').doc(docs[i].id).update({'categories': updated});
                          _play('success');
                        }
                      }),
                  ],
                ),
              ),
            )),
            TextButton.icon(onPressed: () => _showCategoryForm(docs[i].id, cats), icon: const Icon(Icons.add), label: const Text("إضافة فئة جديدة لهذا الميكروتك")),
            const Divider(),
          ],
        );
      },
    );
  }

  // 3. تبويب التوليد
  Widget _buildGenerateTab(List<QueryDocumentSnapshot> networks) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Icon(Icons.autorenew, size: 80, color: Colors.green),
          const Text("محرك توليد الكروت الذكي", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'اختر الشبكة والفئة المراد توليدها', border: OutlineInputBorder()),
            items: networks.expand((net) {
              List cats = (net.data() as Map)['categories'] ?? [];
              return cats.map((c) => DropdownMenuItem(value: "${net.id}_${c['id']}", child: Text("${net['name']} - ${c['name']}")));
            }).toList(),
            onChanged: (v) { _play('click'); setState(() => _selectedCategoryToGenerate = v); },
          ),
          const SizedBox(height: 15),
          TextField(controller: _generateAmountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'كمية الكروت المطلوب توليدها', border: OutlineInputBorder())),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _generateCards,
              icon: const Icon(Icons.bolt, color: Colors.white),
              label: const Text('بدء التوليد والربط بالميكروتك', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDiscountsTab() => const Center(child: Text("قسم إدارة شرائح الخصم التلقائي للبقالات (قيد التطوير)"));
}
