import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String? _selectedServerToGenerate;
  String? _selectedCategoryToGenerate;
  final TextEditingController _generateAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // 1. إضافة سيرفر ميكروتك (ورفعه للسوق) 📡
  // ==========================================
  void _showAddServerBottomSheet(SystemProvider sys) {
    _play('click');
    String name = '', location = '', ip = '', user = '', pass = '', port = '8728';
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
                    const Text('إضافة شبكة/سيرفر ميكروتك جديد 📡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('سيتم عرض هذه الشبكة في "سوق الشبكات" للزبائن.', style: TextStyle(fontSize: 12, color: Colors.blue)),
                    const SizedBox(height: 20),
                    TextField(onChanged: (v) => name = v, decoration: InputDecoration(labelText: 'اسم الشبكة (مثال: شبكة الصقر)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.dns))),
                    const SizedBox(height: 12),
                    TextField(onChanged: (v) => location = v, decoration: InputDecoration(labelText: 'موقع الشبكة (مثال: صنعاء - حدة)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.location_on))),
                    const SizedBox(height: 12),
                    TextField(onChanged: (v) => ip = v, decoration: InputDecoration(labelText: 'عنوان IP / الرابط (DDNS)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.wifi))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(onChanged: (v) => user = v, decoration: InputDecoration(labelText: 'مستخدم API', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.person)))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(onChanged: (v) => pass = v, obscureText: true, decoration: InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.lock)))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(onChanged: (v) => port = v, decoration: InputDecoration(labelText: 'API Port (الافتراضي: 8728)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.settings_ethernet))),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting ? null : () async {
                          if (name.isNotEmpty && location.isNotEmpty && ip.isNotEmpty) {
                            _play('click');
                            setModalState(() => isSubmitting = true);
                            try {
                              // 👇 رفع الشبكة للسيرفر لكي تظهر للزبائن
                              await _db.collection('networks').add({
                                'name': name,
                                'location': location,
                                'ip': ip, 'apiUser': user, 'apiPassword': pass, 'apiPort': port,
                                'agentPhone': sys.currentUserPhone, // 👈 مهم جداً لكي تعود الأرباح لهذا الوكيل
                                'agentName': sys.currentUserName,
                                'status': 'متصل نشط 🟢',
                                'categories': [], // مصفوفة فارغة للفئات
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              _play('success');
                              if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الشبكة بنجاح! ستظهر الآن للزبائن 🟢', textDirection: TextDirection.rtl), backgroundColor: Colors.green)); }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              _play('error');
                            }
                          } else {
                            _play('error');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم الشبكة والموقع والـ IP', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                          }
                        },
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ واتصال', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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

  // ==========================================
  // 2. إضافة فئة كروت للشبكة 🎟️
  // ==========================================
  void _showAddCategoryBottomSheet(List<QueryDocumentSnapshot> agentNetworks) {
    _play('click');
    String newName = '', newTime = '', newCapacity = '', newPrice = '';
    String? selectedNetworkId;
    Color selectedColor = Colors.blue;
    final List<Color> colorOptions = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.red, Colors.teal];
    bool isSubmitting = false;

    if (agentNetworks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إضافة سيرفر شبكة أولاً قبل إضافة الفئات!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
      return;
    }

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
                    const Text('إضافة فئة كروت جديدة (Profile) 🎟️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'اختر الشبكة التابعة لها الفئة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      items: agentNetworks.map((net) => DropdownMenuItem(value: net.id, child: Text((net.data() as Map)['name']))).toList(),
                      onChanged: (val) => setModalState(() => selectedNetworkId = val),
                    ),
                    const SizedBox(height: 12),

                    TextField(onChanged: (val) => newName = val, decoration: InputDecoration(labelText: 'اسم الفئة (مثال: أبو 1000)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.category))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(onChanged: (val) => newTime = val, decoration: InputDecoration(labelText: 'الوقت (مثال: 24 ساعة)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.timer)))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(onChanged: (val) => newCapacity = val, decoration: InputDecoration(labelText: 'السعة (مثال: 1 جيجا)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.data_usage)))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(onChanged: (val) => newPrice = val, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'سعر البيع للجمهور (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.attach_money))),
                    const SizedBox(height: 15),
                    const Align(alignment: Alignment.centerRight, child: Text('اختر لون الفئة:', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: colorOptions.map((color) => GestureDetector(
                        onTap: () { _play('click'); setModalState(() => selectedColor = color); },
                        child: CircleAvatar(backgroundColor: color, radius: 20, child: selectedColor == color ? const Icon(Icons.check, color: Colors.white) : null),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: selectedColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting ? null : () async {
                          if (selectedNetworkId != null && newName.isNotEmpty && newPrice.isNotEmpty) {
                            _play('click');
                            setModalState(() => isSubmitting = true);
                            try {
                              // 👇 إضافة الفئة داخل مصفوفة الشبكة المحددة في فايربيز
                              var newCategory = {
                                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                'name': newName,
                                'time': newTime.isNotEmpty ? newTime : 'غير محدد',
                                'capacity': newCapacity.isNotEmpty ? newCapacity : 'مفتوح',
                                'price': int.tryParse(newPrice) ?? 0,
                                'color': selectedColor.value, // حفظ كود اللون
                                'stock': 0, // المخزون يبدأ بصفر حتى يتم التوليد
                              };

                              await _db.collection('networks').doc(selectedNetworkId).update({
                                'categories': FieldValue.arrayUnion([newCategory])
                              });

                              _play('success');
                              if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الفئة بنجاح! 📋', textDirection: TextDirection.rtl), backgroundColor: Colors.green)); }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              _play('error');
                            }
                          } else {
                            _play('error');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الشبكة وإدخال الاسم والسعر!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                          }
                        },
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ الفئة', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الميكروتك والفئات'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      // 👇 StreamBuilder رئيسي يجلب شبكات الوكيل الحالي لتغذية جميع التبويبات
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('networks').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          List<QueryDocumentSnapshot> agentNetworks = snapshot.hasData ? snapshot.data!.docs : [];

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 5, top: 5),
                  decoration: BoxDecoration(color: isDark ? Colors.grey.shade900 : Colors.blue.shade800, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.orange,
                    indicatorWeight: 4,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(icon: Icon(Icons.dns), text: 'سيرفرات الربط'),
                      Tab(icon: Icon(Icons.category), text: 'المخزون والفئات'),
                      Tab(icon: Icon(Icons.local_offer), text: 'شرائح الخصم'),
                      Tab(icon: Icon(Icons.autorenew), text: 'توليد الكروت'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildServersTab(sys, agentNetworks),
                      _buildCategoriesTab(agentNetworks),
                      _buildDiscountTiersTab(),
                      _buildGenerateCardsTab(agentNetworks),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  // ==========================================
  // تبويب السيرفرات (الشبكات)
  // ==========================================
  Widget _buildServersTab(SystemProvider sys, List<QueryDocumentSnapshot> networks) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: networks.isEmpty 
        ? const Center(child: Text('لم تقم بربط أي شبكة ميكروتك حتى الآن.', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: networks.length,
          itemBuilder: (context, index) {
            var net = networks[index].data() as Map<String, dynamic>;
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.router, color: Colors.white)),
                title: Text(net['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('الموقع: ${net['location']}\nIP: ${net['ip']}\nالحالة: ${net['status']}'),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                  _play('click');
                  await _db.collection('networks').doc(networks[index].id).delete();
                }),
              ),
            );
          }
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddServerBottomSheet(sys),
        backgroundColor: Colors.blue.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة سيرفر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // تبويب الفئات والمخزون
  // ==========================================
  Widget _buildCategoriesTab(List<QueryDocumentSnapshot> networks) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: networks.isEmpty 
        ? const Center(child: Text('أضف سيرفر شبكة أولاً لعرض فئاته.'))
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: networks.length,
          itemBuilder: (context, netIndex) {
            var netId = networks[netIndex].id;
            var netData = networks[netIndex].data() as Map<String, dynamic>;
            List categories = netData['categories'] ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('فئات شبكة: ${netData['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                ),
                if (categories.isEmpty)
                  const Padding(padding: EdgeInsets.all(8.0), child: Text('لا توجد فئات لهذه الشبكة.', style: TextStyle(color: Colors.grey))),
                ...categories.map((category) {
                  int stock = category['stock'] ?? 0;
                  bool isLowStock = stock < 10;
                  Color catColor = Color(category['color'] ?? Colors.blue.value);

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: catColor.withOpacity(0.5))),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(category['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: catColor)),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20), 
                                onPressed: () async {
                                  _play('click');
                                  await _db.collection('networks').doc(netId).update({'categories': FieldValue.arrayRemove([category])});
                                }, 
                                constraints: const BoxConstraints(), padding: EdgeInsets.zero
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('الوقت: ${category['time']} | السعة: ${category['capacity']}', style: const TextStyle(color: Colors.grey)),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('سعر الجمهور: ${category['price']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: isLowStock ? Colors.red.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                                child: Text('المخزون: $stock كرت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isLowStock ? Colors.red : Colors.green.shade800)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 20),
              ],
            );
          }
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryBottomSheet(networks),
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.add_circle, color: Colors.white),
        label: const Text('إضافة فئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // تبويب التوليد (محاكاة الاتصال بالمايكروتيك)
  // ==========================================
  Widget _buildGenerateCardsTab(List<QueryDocumentSnapshot> networks) {
    if (networks.isEmpty) return const Center(child: Text('يجب إضافة شبكة وفئات أولاً!'));

    // استخراج كل الفئات مع معرّف الشبكة الخاص بها ليظهر في القائمة
    List<Map<String, dynamic>> allCategories = [];
    for (var net in networks) {
      String netId = net.id;
      List cats = (net.data() as Map)['categories'] ?? [];
      for (var cat in cats) {
        allCategories.add({'networkId': netId, 'networkName': (net.data() as Map)['name'], 'category': cat});
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue)),
            child: const Text('🔌 عند الضغط على توليد، سيقوم النظام بالاتصال بسيرفر المايكروتيك الخاص بك لتوليد الكروت وسحبها لمحفظة المتجر لتصبح متاحة لزبائنك.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'اختر الفئة المطلوب توليدها', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            value: _selectedCategoryToGenerate,
            items: allCategories.map((item) => DropdownMenuItem(
              value: '${item['networkId']}_${item['category']['id']}', 
              child: Text('${item['networkName']} - ${item['category']['name']}')
            )).toList(),
            onChanged: (value) { _play('click'); setState(() => _selectedCategoryToGenerate = value); },
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _generateAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'الكمية المطلوب توليدها (مثال: 100)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.format_list_numbered)),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_selectedCategoryToGenerate != null && _generateAmountController.text.isNotEmpty) {
                  int amount = int.tryParse(_generateAmountController.text) ?? 0;
                  if (amount > 0) {
                    _play('click');
                    
                    // تحليل الـ ID المدمج لمعرفة الشبكة والفئة
                    List<String> parts = _selectedCategoryToGenerate!.split('_');
                    String netId = parts[0];
                    String catId = parts[1];

                    try {
                      // 1. جلب بيانات الشبكة لتحديث المخزون
                      DocumentReference netRef = _db.collection('networks').doc(netId);
                      DocumentSnapshot netDoc = await netRef.get();
                      List cats = List.from((netDoc.data() as Map)['categories']);
                      
                      // 2. تحديث المخزون للفئة المطلوبة
                      int index = cats.indexWhere((c) => c['id'] == catId);
                      if (index != -1) {
                        cats[index]['stock'] += amount;
                        await netRef.update({'categories': cats});
                        
                        _play('success');
                        _generateAmountController.clear();
                        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم توليد وإضافة $amount كرت بنجاح! متاحة الآن للزبائن ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      _play('error');
                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشلت العملية', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                    }
                  }
                } else {
                  _play('error');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الفئة وإدخال الكمية', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                }
              },
              icon: const Icon(Icons.autorenew, color: Colors.white),
              label: const Text('بدء الاتصال والتوليد', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }

  // تبويب شرائح الخصم (للعرض فقط)
  Widget _buildDiscountTiersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)), child: const Text('💡 يتم تطبيق هذا الخصم (سعر الجملة) تلقائياً للبقالات بناءً على حجم مسحوباتها.', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 12))),
        const SizedBox(height: 15),
        _buildTierCard('الشريحة الذهبية 🏆', 'للبقالات التي تسحب أكثر من 70,000 ريال', 'خصم: 30%', Colors.amber.shade700),
        _buildTierCard('الشريحة الفضية 🥈', 'للبقالات التي تسحب أكثر من 50,000 ريال', 'خصم: 20%', Colors.grey.shade600),
        _buildTierCard('الشريحة البرونزية 🥉', 'للبقالات التي تسحب أقل من 30,000 ريال', 'خصم: 10%', Colors.brown.shade400),
      ],
    );
  }

  Widget _buildTierCard(String title, String condition, String discount, Color color) {
    return Card(
      elevation: 2, margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.stars, color: color, size: 35),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)), subtitle: Text(condition, style: const TextStyle(fontSize: 12)),
        trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(discount, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
      ),
    );
  }
}
