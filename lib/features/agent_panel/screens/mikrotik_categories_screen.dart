import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // 👈 ضرورية لتوليد أرقام الكروت العشوائية
import 'package:http/http.dart' as http; // 👈 الاتصال بالسيرفر
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

  String? _selectedServerToGenerate;
  String? _selectedCategoryToGenerate;
  final TextEditingController _generateAmountController = TextEditingController();

  final String _renderUrl = "https://mikrotik-server-qu6a.onrender.com";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // دالة التأكيد (موجودة في الهيكل المطور)
  // ==========================================
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
            TextButton(onPressed: () { _play('click'); Navigator.pop(context, false); }, child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
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

  // ==========================================
  // فحص الاتصال بالميكروتك (موجودة في الهيكل المطور)
  // ==========================================
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
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاتصال بالميكروتك بنجاح! ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
      } else { throw 'الراوتر لا يستجيب'; }
    } catch (e) {
      _play('error');
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الاتصال: $e ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
    }
    setState(() => _isProcessing = false);
  }

  // ==========================================
  // 1. إضافة وتعديل سيرفر ميكروتك (📡)
  // ==========================================
  void _showAddServerBottomSheet(SystemProvider sys, {Map<String, dynamic>? existingData, String? docId}) {
    _play('click');
    String name = existingData?['name'] ?? '';
    String location = existingData?['location'] ?? '';
    String ip = existingData?['ip'] ?? '';
    String user = existingData?['apiUser'] ?? '';
    String pass = existingData?['apiPassword'] ?? '';
    String port = existingData?['apiPort'] ?? '8728';
    String loginUrl = existingData?['loginUrl'] ?? ''; 
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
                    Text(docId == null ? 'إضافة شبكة/سيرفر ميكروتك جديد 📡' : 'تعديل بيانات الشبكة ✏️', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('سيتم عرض هذه الشبكة في "سوق الشبكات" للزبائن.', style: TextStyle(fontSize: 12, color: Colors.blue)),
                    const SizedBox(height: 20),
                    TextField(controller: TextEditingController(text: name), onChanged: (v) => name = v, decoration: InputDecoration(labelText: 'اسم الشبكة (مثال: شبكة الصقر)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.dns))),
                    const SizedBox(height: 12),
                    TextField(controller: TextEditingController(text: location), onChanged: (v) => location = v, decoration: InputDecoration(labelText: 'موقع الشبكة (مثال: صنعاء - حدة)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.location_on))),
                    const SizedBox(height: 12),
                    TextField(controller: TextEditingController(text: ip), onChanged: (v) => ip = v, decoration: InputDecoration(labelText: 'عنوان IP / الرابط (DDNS)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.wifi))),
                    const SizedBox(height: 12),
                    TextField(controller: TextEditingController(text: loginUrl), onChanged: (v) => loginUrl = v, decoration: InputDecoration(labelText: 'رابط صفحة تسجيل الدخول للزبائن', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.link))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: TextEditingController(text: user), onChanged: (v) => user = v, decoration: InputDecoration(labelText: 'مستخدم API', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.person)))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: TextEditingController(text: pass), onChanged: (v) => pass = v, obscureText: true, decoration: InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.lock)))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: TextEditingController(text: port), onChanged: (v) => port = v, decoration: InputDecoration(labelText: 'API Port (الافتراضي: 8728)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.settings_ethernet))),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting ? null : () async {
                          if (name.isNotEmpty && location.isNotEmpty && ip.isNotEmpty) {
                            if (docId != null) {
                              bool confirm = await _confirmAction("حفظ التعديلات", "هل أنت متأكد من حفظ التعديلات؟", Colors.blue);
                              if (!confirm) return;
                            }
                            _play('click');
                            setModalState(() => isSubmitting = true);
                            try {
                              Map<String, dynamic> networkData = {
                                'name': name, 'location': location, 'ip': ip, 'apiUser': user, 'apiPassword': pass, 'apiPort': port,
                                'loginUrl': loginUrl, 'agentPhone': sys.currentUserPhone, 'agentName': sys.currentUserName,
                                'isActive': existingData?['isActive'] ?? true, 'updatedAt': FieldValue.serverTimestamp(),
                              };
                              if (docId == null) {
                                networkData['status'] = 'متصل نشط 🟢';
                                networkData['categories'] = [];
                                networkData['createdAt'] = FieldValue.serverTimestamp();
                                await _db.collection('networks').add(networkData);
                              } else {
                                await _db.collection('networks').doc(docId).update(networkData);
                              }
                              _play('success');
                              if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(docId == null ? 'تمت إضافة الشبكة بنجاح! 🟢' : 'تم التعديل بنجاح! ✏️', textDirection: TextDirection.rtl), backgroundColor: Colors.green)); }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              _play('error');
                            }
                          } else {
                            _play('error');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة الحقول الأساسية', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
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
  // 2. إضافة وتعديل فئة كروت للشبكة 🎟️
  // ==========================================
  void _showAddCategoryBottomSheet(List<QueryDocumentSnapshot> agentNetworks, {Map? existingCat, String? preSelectedNetId}) {
    _play('click');
    String newName = existingCat?['name'] ?? '';
    String newTime = existingCat?['time'] ?? '';
    String newCapacity = existingCat?['capacity'] ?? '';
    String newPrice = existingCat?['price']?.toString() ?? '';
    String? selectedNetworkId = preSelectedNetId;
    Color selectedColor = existingCat != null ? Color(existingCat['color']) : Colors.blue;
    final List<Color> colorOptions = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.red, Colors.teal];
    bool isSubmitting = false;

    if (agentNetworks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إضافة سيرفر شبكة أولاً!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
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
                    Text(existingCat == null ? 'إضافة فئة كروت جديدة 🎟️' : 'تعديل بيانات الفئة ✏️', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    if (existingCat == null) DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'اختر الشبكة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      value: selectedNetworkId,
                      items: agentNetworks.map((net) => DropdownMenuItem(value: net.id, child: Text((net.data() as Map)['name']))).toList(),
                      onChanged: (val) => setModalState(() => selectedNetworkId = val),
                    ),
                    if (existingCat == null) const SizedBox(height: 12),
                    TextField(controller: TextEditingController(text: newName), onChanged: (val) => newName = val, decoration: InputDecoration(labelText: 'اسم الفئة (Profile)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.category))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: TextEditingController(text: newTime), onChanged: (val) => newTime = val, decoration: InputDecoration(labelText: 'الوقت (مثال: 24 ساعة)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.timer)))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: TextEditingController(text: newCapacity), onChanged: (val) => newCapacity = val, decoration: InputDecoration(labelText: 'السعة (مثال: 1 جيجا)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.data_usage)))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: TextEditingController(text: newPrice), onChanged: (val) => newPrice = val, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'سعر البيع للجمهور', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.attach_money))),
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
                            if (existingCat != null) {
                              bool confirm = await _confirmAction("حفظ التعديلات", "متأكد من تعديل الفئة؟", Colors.blue);
                              if (!confirm) return;
                            }
                            _play('click');
                            setModalState(() => isSubmitting = true);
                            try {
                              var newCategory = {
                                'id': existingCat?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                'name': newName, 'time': newTime.isNotEmpty ? newTime : 'غير محدد',
                                'capacity': newCapacity.isNotEmpty ? newCapacity : 'مفتوح',
                                'price': int.tryParse(newPrice) ?? 0, 'color': selectedColor.value, 
                                'stock': existingCat?['stock'] ?? 0, 'isActive': existingCat?['isActive'] ?? true, 
                              };
                              if (existingCat == null) {
                                await _db.collection('networks').doc(selectedNetworkId).update({'categories': FieldValue.arrayUnion([newCategory])});
                              } else {
                                var netDoc = await _db.collection('networks').doc(selectedNetworkId).get();
                                List cats = List.from((netDoc.data() as Map)['categories']);
                                int idx = cats.indexWhere((c) => c['id'] == existingCat['id']);
                                cats[idx] = newCategory;
                                await _db.collection('networks').doc(selectedNetworkId).update({'categories': cats});
                              }
                              _play('success');
                              if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح! 📋', textDirection: TextDirection.rtl), backgroundColor: Colors.green)); }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              _play('error');
                            }
                          } else {
                            _play('error');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة الحقول الأساسية!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
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

  // ==========================================
  // 3. إدارة شرائح الخصم الديناميكية (الجديدة) 🏆
  // ==========================================
  void _showDiscountTierBottomSheet(SystemProvider sys, {Map<String, dynamic>? existingTier, String? docId}) {
    _play('click');
    String title = existingTier?['title'] ?? '';
    String condition = existingTier?['condition']?.toString() ?? '';
    String discountValue = existingTier?['discountValue']?.toString() ?? '';
    String discountType = existingTier?['discountType'] ?? 'percentage'; // percentage أو fixed
    Color selectedColor = existingTier != null ? Color(existingTier['color']) : Colors.amber.shade700;
    
    final List<Color> colorOptions = [Colors.amber.shade700, Colors.grey.shade600, Colors.brown.shade400, Colors.blue, Colors.purple, Colors.redAccent];
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
                    Text(docId == null ? 'إضافة شريحة خصم جديدة 🏆' : 'تعديل الشريحة ✏️', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    TextField(controller: TextEditingController(text: title), onChanged: (v) => title = v, decoration: InputDecoration(labelText: 'اسم الشريحة (مثال: الشريحة الذهبية)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.stars))),
                    const SizedBox(height: 12),
                    TextField(controller: TextEditingController(text: condition), onChanged: (v) => condition = v, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'شرط السحب الشهري بالريال (مثال: 50000)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.shopping_cart))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: TextEditingController(text: discountValue), onChanged: (v) => discountValue = v, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'قيمة الخصم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.local_offer)))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'نوع الخصم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            value: discountType,
                            items: const [
                              DropdownMenuItem(value: 'percentage', child: Text('نسبة مئوية (%)')),
                              DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت (ريال)')),
                            ],
                            onChanged: (val) => setModalState(() => discountType = val!),
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Align(alignment: Alignment.centerRight, child: Text('لون الشريحة المميز:', style: TextStyle(fontWeight: FontWeight.bold))),
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
                          if (title.isNotEmpty && condition.isNotEmpty && discountValue.isNotEmpty) {
                            if (docId != null) {
                              bool confirm = await _confirmAction("حفظ الشريحة", "هل أنت متأكد من التعديلات؟", selectedColor);
                              if (!confirm) return;
                            }
                            _play('click');
                            setModalState(() => isSubmitting = true);
                            try {
                              Map<String, dynamic> tierData = {
                                'agentPhone': sys.currentUserPhone,
                                'title': title,
                                'condition': int.parse(condition),
                                'discountValue': double.parse(discountValue),
                                'discountType': discountType,
                                'color': selectedColor.value,
                                'isActive': existingTier?['isActive'] ?? true,
                                'subscribersCount': existingTier?['subscribersCount'] ?? 0, // عدد البقالات المنضمة
                                'updatedAt': FieldValue.serverTimestamp(),
                              };
                              if (docId == null) {
                                tierData['createdAt'] = FieldValue.serverTimestamp();
                                await _db.collection('discount_tiers').add(tierData);
                              } else {
                                await _db.collection('discount_tiers').doc(docId).update(tierData);
                              }
                              _play('success');
                              if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الشريحة بنجاح!', textDirection: TextDirection.rtl), backgroundColor: Colors.green)); }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              _play('error');
                            }
                          } else {
                            _play('error');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة كافة بيانات الشريحة', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                          }
                        },
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ الشريحة', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
        agentName: sys.currentUserName, phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)', currentBalance: sys.currentUserBalance,
      ),
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
                  width: double.infinity, padding: const EdgeInsets.only(bottom: 5, top: 5),
                  decoration: BoxDecoration(color: isDark ? Colors.grey.shade900 : Colors.blue.shade800, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
                  child: TabBar(
                    controller: _tabController, isScrollable: true,
                    labelColor: Colors.white, unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.orange, indicatorWeight: 4,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(icon: Icon(Icons.dns), text: 'سيرفرات الربط'),
                      Tab(icon: Icon(Icons.category), text: 'المخزون والفئات'),
                      Tab(icon: Icon(Icons.local_offer), text: 'شرائح الخصم'),
                      Tab(icon: Icon(Icons.autorenew), text: 'توليد الكروت'),
                    ],
                  ),
                ),
                if (_isProcessing) const LinearProgressIndicator(backgroundColor: Colors.orange, color: Colors.white),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildServersTab(sys, agentNetworks),
                      _buildCategoriesTab(agentNetworks),
                      _buildDiscountTiersTab(sys), // 👈 تمرير sys للتبويب الجديد
                      _buildGenerateCardsTab(sys, agentNetworks), 
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
  // تبويب السيرفرات (كما في الهيكل المطور)
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
            bool isActive = net['isActive'] ?? true; 
            return Card(
              color: isActive ? null : Colors.grey.shade300, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 3,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: isActive ? Colors.green : Colors.grey, child: const Icon(Icons.router, color: Colors.white)),
                title: Text(net['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, decoration: isActive ? null : TextDecoration.lineThrough)),
                subtitle: Text('الموقع: ${net['location']}\nIP: ${net['ip']}\nالحالة: ${isActive ? 'نشط' : 'مجمد'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.bolt, color: Colors.blue), onPressed: () => _testConnection(net)),
                    IconButton(icon: Icon(isActive ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.orange), 
                      onPressed: () async {
                        bool confirm = await _confirmAction(isActive ? "تجميد الشبكة" : "تنشيط الشبكة", "هل تريد تغيير حالة الشبكة؟", Colors.orange);
                        if(confirm) _db.collection('networks').doc(networks[index].id).update({'isActive': !isActive});
                      }),
                    IconButton(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: () => _showAddServerBottomSheet(sys, existingData: net, docId: networks[index].id)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                      bool confirm = await _confirmAction("حذف الشبكة نهائياً", "سيتم مسح بيانات الشبكة، هل أنت متأكد؟", Colors.red);
                      if(confirm) { _play('click'); await _db.collection('networks').doc(networks[index].id).delete(); }
                    }),
                  ],
                ),
              ),
            );
          }
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddServerBottomSheet(sys), backgroundColor: Colors.blue.shade800,
        icon: const Icon(Icons.add, color: Colors.white), label: const Text('إضافة سيرفر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // تبويب الفئات والمخزون (كما في الهيكل المطور)
  // ==========================================
  Widget _buildCategoriesTab(List<QueryDocumentSnapshot> networks) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: networks.isEmpty 
        ? const Center(child: Text('أضف سيرفر شبكة أولاً لعرض فئاته.'))
        : ListView.builder(
          padding: const EdgeInsets.all(16), itemCount: networks.length,
          itemBuilder: (context, netIndex) {
            var netId = networks[netIndex].id;
            var netData = networks[netIndex].data() as Map<String, dynamic>;
            List categories = netData['categories'] ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('فئات شبكة: ${netData['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey))),
                if (categories.isEmpty) const Padding(padding: EdgeInsets.all(8.0), child: Text('لا توجد فئات لهذه الشبكة.', style: TextStyle(color: Colors.grey))),
                ...categories.map((category) {
                  int stock = category['stock'] ?? 0; bool isLowStock = stock < 10;
                  Color catColor = Color(category['color'] ?? Colors.blue.value);
                  bool isCatActive = category['isActive'] ?? true; 

                  return Card(
                    color: isCatActive ? null : Colors.grey.shade200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isCatActive ? catColor.withOpacity(0.5) : Colors.grey)),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(category['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isCatActive ? catColor : Colors.grey, decoration: isCatActive ? null : TextDecoration.lineThrough)),
                              Row(
                                children: [
                                  IconButton(icon: Icon(isCatActive ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.orange, size: 20), 
                                    onPressed: () async {
                                      bool confirm = await _confirmAction(isCatActive ? "تجميد الفئة" : "تنشيط الفئة", "تغيير حالة الفئة؟", Colors.orange);
                                      if(confirm) {
                                        List updated = List.from(categories);
                                        int idx = updated.indexWhere((c) => c['id'] == category['id']);
                                        updated[idx]['isActive'] = !isCatActive;
                                        await _db.collection('networks').doc(netId).update({'categories': updated});
                                      }
                                    }, constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5)),
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showAddCategoryBottomSheet(networks, existingCat: category, preSelectedNetId: netId), constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), 
                                    onPressed: () async {
                                      bool confirm = await _confirmAction("حذف الفئة", "سيتم حذف الفئة نهائياً، متأكد؟", Colors.red);
                                      if(confirm) { _play('click'); await _db.collection('networks').doc(netId).update({'categories': FieldValue.arrayRemove([category])}); }
                                    }, constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5)
                                  ),
                                ],
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
        onPressed: () => _showAddCategoryBottomSheet(networks), backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.add_circle, color: Colors.white), label: const Text('إضافة فئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // 3. تبويب شرائح الخصم الديناميكي (المحرك الجديد 🏆)
  // ==========================================
  Widget _buildDiscountTiersTab(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('discount_tiers').where('agentPhone', isEqualTo: sys.currentUserPhone).orderBy('condition', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        List<QueryDocumentSnapshot> tiers = snapshot.hasData ? snapshot.data!.docs : [];

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12), margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)), 
                child: const Text('💡 قم بإعداد شرائح الخصم الخاصة بك. سيتم ترقية البقالات تلقائياً أو يدوياً بناءً على سياسة المبيعات التي تحددها هنا.', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 12))
              ),
              Expanded(
                child: tiers.isEmpty
                  ? const Center(child: Text('لم تقم بإضافة أي شرائح خصم حتى الآن.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: tiers.length,
                      itemBuilder: (context, index) {
                        var tier = tiers[index].data() as Map<String, dynamic>;
                        bool isActive = tier['isActive'] ?? true;
                        Color tColor = Color(tier['color'] ?? Colors.amber.shade700.value);
                        String dType = tier['discountType'] == 'percentage' ? '%' : 'ريال';
                        
                        return Card(
                          color: isActive ? Colors.white : Colors.grey.shade200,
                          elevation: 2, margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Icon(isActive ? Icons.stars : Icons.block, color: isActive ? tColor : Colors.grey, size: 35),
                            title: Text(tier['title'], style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? tColor : Colors.grey, decoration: isActive ? null : TextDecoration.lineThrough)), 
                            subtitle: Text('للبقالات التي تسحب أكثر من ${tier['condition']} ريال\nبقالات منضمة: ${tier['subscribersCount'] ?? 0} 🏪', style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                  decoration: BoxDecoration(color: isActive ? tColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), 
                                  child: Text('خصم: ${tier['discountValue']}$dType', style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? tColor : Colors.grey, fontSize: 12))
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        bool confirm = await _confirmAction(isActive ? "تجميد الشريحة" : "تنشيط الشريحة", "تغيير حالة العرض؟", Colors.orange);
                                        if (confirm) _db.collection('discount_tiers').doc(tiers[index].id).update({'isActive': !isActive});
                                      },
                                      child: Icon(isActive ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.orange, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () => _showDiscountTierBottomSheet(sys, existingTier: tier, docId: tiers[index].id),
                                      child: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () async {
                                        bool confirm = await _confirmAction("حذف الشريحة", "سيتم إلغاء الخصم عن البقالات المنضمة، متأكد؟", Colors.red);
                                        if (confirm) { _play('click'); await _db.collection('discount_tiers').doc(tiers[index].id).delete(); }
                                      },
                                      child: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    )
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showDiscountTierBottomSheet(sys),
            backgroundColor: Colors.amber.shade700,
            icon: const Icon(Icons.add_moderator, color: Colors.white),
            label: const Text('إضافة شريحة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
    );
  }

  // ==========================================
  // 4. تبويب التوليد (عبر سيرفر Render)
  // ==========================================
  Widget _buildGenerateCardsTab(SystemProvider sys, List<QueryDocumentSnapshot> networks) {
    if (networks.isEmpty) return const Center(child: Text('يجب إضافة شبكة وفئات أولاً!'));

    List<Map<String, dynamic>> allCategories = [];
    for (var net in networks) {
      String netId = net.id;
      List cats = (net.data() as Map)['categories'] ?? [];
      for (var cat in cats) {
        if ((net.data() as Map)['isActive'] != false && cat['isActive'] != false) {
           allCategories.add({'networkId': netId, 'networkName': (net.data() as Map)['name'], 'category': cat});
        }
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
            child: const Text('🔌 عند الضغط على توليد، سيقوم النظام بتوليد الكروت وحفظها في قاعدة البيانات لتكون متاحة للبيع الفوري في سوق الشبكات.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            controller: _generateAmountController, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'الكمية المطلوب توليدها (الحد الأقصى: 400)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.format_list_numbered)),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () async {
                if (_selectedCategoryToGenerate != null && _generateAmountController.text.isNotEmpty) {
                  int amount = int.tryParse(_generateAmountController.text) ?? 0;
                  if (amount > 400) {
                     _play('error');
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحد الأقصى للتوليد في الدفعة الواحدة هو 400 كرت!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                     return;
                  }
                  if (amount > 0) {
                    bool confirm = await _confirmAction("بدء التوليد 🔌", "سيتم الآن توليد $amount كرت عبر السيرفر. هل تريد الاستمرار؟", Colors.green);
                    if (!confirm) return;

                    _play('click');
                    setState(() => _isProcessing = true);
                    
                    List<String> parts = _selectedCategoryToGenerate!.split('_');
                    try {
                      final response = await http.post(
                        Uri.parse("$_renderUrl/generateMikrotikCards"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({"networkId": parts[0], "categoryId": parts[1], "amount": amount, "agentPhone": sys.currentUserPhone}),
                      );
                      if (response.statusCode == 200) {
                        _play('success'); _generateAmountController.clear();
                        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم توليد وإضافة $amount كرت حقيقي بنجاح! متاح الآن للزبائن ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                      } else { throw jsonDecode(response.body)['error'] ?? 'خطأ غير معروف'; }
                    } catch (e) {
                      _play('error');
                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشلت العملية: $e', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                    }
                    setState(() => _isProcessing = false);
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
}
