import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للنسخ للحافظة
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
  final String _renderUrl = "https://mikrotik-server-qu6a.onrender.com";

  // متحكمات الكمية للتوليد المتعدد
  final Map<String, TextEditingController> _quantityControllers = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ---------------------------------------------------------
  // نافذة التأكيد (الدرع الأمني)
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
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  // ---------------------------------------------------------
  // 1. عرض وإدارة الكروت داخل الفئة (إدارة حقيقية)
  // ---------------------------------------------------------
  void _showCardsList(String netId, String catId, String catName) {
    _play('click');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              Text('كروت فئة: $catName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('cards')
                      .where('categoryId', isEqualTo: catId)
                      .where('status', isEqualTo: 'متاح')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var cards = snapshot.data!.docs;
                    if (cards.isEmpty) return const Center(child: Text('لا توجد كروت متاحة حالياً'));

                    return ListView.builder(
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        var card = cards[index];
                        String pin = card['pin'];
                        return Card(
                          child: ListTile(
                            title: Text(pin, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.copy, color: Colors.blue), onPressed: () {
                                  Clipboard.setData(ClipboardData(text: pin));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكرت')));
                                }),
                                IconButton(icon: const Icon(Icons.archive, color: Colors.orange), onPressed: () async {
                                  if (await _confirmAction("أرشفة الكرت", "سيختفي الكرت من البيع، هل أنت متأكد؟", Colors.orange)) {
                                    await card.reference.update({'status': 'archived'});
                                  }
                                }),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                                  if (await _confirmAction("حذف الكرت", "سيتم حذف الكرت نهائياً من النظام، متأكد؟", Colors.red)) {
                                    await card.reference.delete();
                                  }
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 2. إعدادات البوت الذكي (Auto-Generation)
  // ---------------------------------------------------------
  void _showBotSettings(String netId, String catId, Map category) {
    _play('click');
    int minStock = category['botMinStock'] ?? 5;
    int refillAmount = category['botRefillAmount'] ?? 50;
    bool isBotEnabled = category['isBotEnabled'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إعدادات البوت الذكي 🤖'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('تفعيل التوليد التلقائي'),
                  value: isBotEnabled,
                  onChanged: (v) => setModalState(() => isBotEnabled = v),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'عندما يقل المخزون عن (كرت)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => minStock = int.parse(v),
                  controller: TextEditingController(text: minStock.toString()),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'قم بتوليد كمية (كرت)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => refillAmount = int.parse(v),
                  controller: TextEditingController(text: refillAmount.toString()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  var netDoc = await _db.collection('networks').doc(netId).get();
                  List cats = List.from(netDoc['categories']);
                  int idx = cats.indexWhere((c) => c['id'] == catId);
                  cats[idx]['botMinStock'] = minStock;
                  cats[idx]['botRefillAmount'] = refillAmount;
                  cats[idx]['isBotEnabled'] = isBotEnabled;
                  await _db.collection('networks').doc(netId).update({'categories': cats});
                  Navigator.pop(context);
                  _play('success');
                },
                child: const Text('حفظ الإعدادات'),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 3. التوليد المتعدد (إرسال الأوامر للسيرفر)
  // ---------------------------------------------------------
  Future<void> _generateMultiple() async {
    List<Map<String, dynamic>> orders = [];
    _quantityControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty && int.parse(controller.text) > 0) {
        var parts = key.split('_');
        orders.add({
          "networkId": parts[0],
          "categoryId": parts[1],
          "amount": int.parse(controller.text)
        });
      }
    });

    if (orders.isEmpty) return;

    bool confirm = await _confirmAction("تأكيد التوليد المتعدد", "سيتم الآن البدء بتوليد الكروت للفئات المحددة. استمرار؟", Colors.green);
    if (!confirm) return;

    setState(() => _isProcessing = true);
    _play('click');

    try {
      final sys = Provider.of<SystemProvider>(context, listen: false);
      for (var order in orders) {
        await http.post(
          Uri.parse("$_renderUrl/generateMikrotikCards"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "networkId": order['networkId'],
            "categoryId": order['categoryId'],
            "amount": order['amount'],
            "agentPhone": sys.currentUserPhone
          }),
        );
      }
      _play('success');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت عملية التوليد المتعدد بنجاح! 🎉'), backgroundColor: Colors.green));
      _quantityControllers.forEach((k, v) => v.clear());
    } catch (e) {
      _play('error');
    }
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الشبكات الذكية'),
      drawer: CustomAgentDrawer(agentName: sys.currentUserName, phoneNumber: sys.currentUserPhone, role: 'مدير نظام', currentBalance: sys.currentUserBalance),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('networks').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var networks = snapshot.data!.docs;

          return Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue,
                tabs: const [Tab(text: 'الشبكات'), Tab(text: 'المخزون'), Tab(text: 'الشرائح'), Tab(text: 'التوليد')],
              ),
              if (_isProcessing) const LinearProgressIndicator(color: Colors.orange),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNetworksTab(networks),
                    _buildInventoryTab(networks),
                    _buildDiscountTiersTab(sys),
                    _buildMultiGenTab(networks),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // تبويب المخزون مع ميزة إدارة الكروت الفردية والبوت
  Widget _buildInventoryTab(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, i) {
        var net = docs[i].data() as Map<String, dynamic>;
        List cats = net['categories'] ?? [];
        return Column(
          children: cats.map((c) => Card(
            child: ListTile(
              leading: Icon(Icons.category, color: Color(c['color'])),
              title: Text(c['name']),
              subtitle: Text('المخزون: ${c['stock']} كرت'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.visibility, color: Colors.blue), onPressed: () => _showCardsList(docs[i].id, c['id'], c['name'])),
                  IconButton(icon: const Icon(Icons.smart_toy, color: Colors.purple), onPressed: () => _showBotSettings(docs[i].id, c['id'], c)),
                ],
              ),
            ),
          )).toList(),
        );
      },
    );
  }

  // تبويب الشرائح مع حل مشكلة الاختفاء (ترتيب يدوي محلي)
  Widget _buildDiscountTiersTab(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('discount_tiers').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // 💡 الحل: الترتيب داخل الكود بدلاً من query الفايربيز لتجنب Index Error
        var tiers = snapshot.data!.docs;
        tiers.sort((a, b) => (b['condition'] as int).compareTo(a['condition'] as int));

        return ListView.builder(
          itemCount: tiers.length,
          itemBuilder: (context, index) {
            var tier = tiers[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: Icon(Icons.stars, color: Color(tier['color'])),
                title: Text(tier['title']),
                subtitle: Text('الشرط: ${tier['condition']} ريال | الخصم: ${tier['discountValue']}'),
              ),
            );
          },
        );
      },
    );
  }

  // تبويب التوليد المتعدد (ديناميكي فعلي)
  Widget _buildMultiGenTab(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> allCats = [];
    for (var d in docs) {
      List cats = (d.data() as Map)['categories'] ?? [];
      for (var c in cats) {
        allCats.add({"netId": d.id, "netName": d['name'], "cat": c});
      }
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('ادخل الكميات المراد توليدها لكل فئة:', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: allCats.length,
            itemBuilder: (context, index) {
              var item = allCats[index];
              String key = "${item['netId']}_${item['cat']['id']}";
              _quantityControllers.putIfAbsent(key, () => TextEditingController());

              return ListTile(
                title: Text("${item['netName']} - ${item['cat']['name']}"),
                subtitle: Text("المخزون الحالي: ${item['cat']['stock']}"),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _quantityControllers[key],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'الكمية'),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _generateMultiple,
            icon: const Icon(Icons.bolt),
            label: const Text('بدء توليد الكل الآن'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
          ),
        )
      ],
    );
  }

  // تبويب الشبكات (كما هو مع الحفاظ على الوظائف)
  Widget _buildNetworksTab(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, i) => Card(child: ListTile(title: Text(docs[i]['name']), subtitle: Text(docs[i]['ip']))),
    );
  }
}
