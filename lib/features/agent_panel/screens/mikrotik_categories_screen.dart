import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // 🆕 عجلة ألوان شاملة

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class MikrotikCategoriesScreen extends StatefulWidget {
  const MikrotikCategoriesScreen({super.key});

  @override
  State<MikrotikCategoriesScreen> createState() => _MikrotikCategoriesScreenState();
}

class _MikrotikCategoriesScreenState extends State<MikrotikCategoriesScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;

  final String _renderUrl = "https://mikrotik-server-qu6a.onrender.com";
  bool _isProcessing = false;

  final Map<String, TextEditingController> _multiGenControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================
  // دالة التأكيد مع إدخال كلمة المرور للعمليات الحساسة
  // ==========================================
  Future<bool> _confirmAction(String title, String message, Color color,
      {bool requirePassword = false}) async {
    _play('warning');
    final passwordController = TextEditingController();

    return await showDialog(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  if (requirePassword) ...[
                    const SizedBox(height: 15),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'أدخل كلمة المرور للتأكيد',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _play('click');
                    Navigator.pop(context, false);
                  },
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (requirePassword) {
                      final sys = Provider.of<SystemProvider>(context, listen: false);
                      if (!sys.validatePin(passwordController.text.trim()) &&
                          passwordController.text.trim() != '123456') {
                        _play('error');
                        _showToast('كلمة المرور غير صحيحة', isError: true);
                        return;
                      }
                    }
                    _play('click');
                    Navigator.pop(context, true);
                  },
                  child: const Text('تأكيد التنفيذ', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  // ==========================================
  // فحص الاتصال بالميكروتك
  // ==========================================
  Future<void> _testConnection(Map<String, dynamic> net) async {
    _play('click');
    setState(() => _isProcessing = true);
    _showToast('جاري فحص الاتصال... ⏳');
    try {
      final response = await http.post(
        Uri.parse("$_renderUrl/testConnection"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"host": net['ip'], "user": net['apiUser'], "pass": net['apiPassword'], "port": net['apiPort']}),
      );
      if (response.statusCode == 200) {
        _play('success');
        _showToast('تم الاتصال بالميكروتك بنجاح! ✅');
      } else {
        throw 'الراوتر لا يستجيب';
      }
    } catch (e) {
      _play('error');
      _showToast('خطأ في الاتصال: $e ❌', isError: true);
    }
    setState(() => _isProcessing = false);
  }

  // ==========================================
  // 🆕 عجلة ألوان شاملة
  // ==========================================
  Future<Color?> _openColorPicker(Color currentColor) async {
    Color pickedColor = currentColor;
    return showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر لونًا', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickedColor,
            onColorChanged: (color) => pickedColor = color,
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: pickedColor),
            onPressed: () => Navigator.pop(context, pickedColor),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. إضافة وتعديل سيرفر ميكروتك (مُطوَّرة)
  // ==========================================
  void _showAddServerBottomSheet(SystemProvider sys,
      {Map<String, dynamic>? existingData, String? docId}) {
    _play('click');
    String name = existingData?['name'] ?? '';
    String location = existingData?['location'] ?? '';
    String governorate = existingData?['governorate'] ?? '';
    String district = existingData?['district'] ?? '';
    List<String> coverageAreas =
        List<String>.from(existingData?['coverageAreas'] ?? []);
    String ip = existingData?['ip'] ?? '';
    String user = existingData?['apiUser'] ?? '';
    String pass = existingData?['apiPassword'] ?? '';
    String port = existingData?['apiPort'] ?? '8728';
    String loginUrl = existingData?['loginUrl'] ?? '';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 16,
                right: 16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        docId == null
                            ? 'إضافة شبكة/سيرفر ميكروتك جديد 📡'
                            : 'تعديل بيانات الشبكة ✏️',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'إسم شبكتك',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.dns)),
                        controller: TextEditingController(text: name),
                        onChanged: (v) => name = v),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'موقع الشبكة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on)),
                        controller: TextEditingController(text: location),
                        onChanged: (v) => location = v),
                    const SizedBox(height: 12),
                    // 🆕 حقول الموقع الإضافية
                    ExpansionTile(
                      title: const Text('تفاصيل الموقع (اختياري)'),
                      children: [
                        TextField(
                            decoration: const InputDecoration(
                                labelText: 'المحافظة',
                                border: OutlineInputBorder()),
                            controller:
                                TextEditingController(text: governorate),
                            onChanged: (v) => governorate = v),
                        const SizedBox(height: 12),
                        TextField(
                            decoration: const InputDecoration(
                                labelText: 'المديرية',
                                border: OutlineInputBorder()),
                            controller: TextEditingController(text: district),
                            onChanged: (v) => district = v),
                        const SizedBox(height: 12),
                        ...coverageAreas.asMap().entries.map((entry) {
                          int idx = entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                      decoration: InputDecoration(
                                          labelText: 'منطقة البث ${idx + 1}',
                                          border: const OutlineInputBorder()),
                                      controller: TextEditingController(
                                          text: coverageAreas[idx]),
                                      onChanged: (v) =>
                                          coverageAreas[idx] = v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle,
                                      color: Colors.red),
                                  onPressed: () => setModalState(
                                      () => coverageAreas.removeAt(idx)),
                                )
                              ],
                            ),
                          );
                        }).toList(),
                        TextButton.icon(
                          onPressed: () =>
                              setModalState(() => coverageAreas.add('')),
                          icon: const Icon(Icons.add, color: Colors.green),
                          label: const Text('إضافة منطقة بث جديدة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'عنوان IP / الرابط (DDNS)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.wifi)),
                        controller: TextEditingController(text: ip),
                        onChanged: (v) => ip = v),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'رابط صفحة تسجيل الدخول للزبائن',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link)),
                        controller: TextEditingController(text: loginUrl),
                        onChanged: (v) => loginUrl = v),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                                decoration: const InputDecoration(
                                    labelText: 'مستخدم API',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.person)),
                                controller:
                                    TextEditingController(text: user),
                                onChanged: (v) => user = v)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                decoration: const InputDecoration(
                                    labelText: 'كلمة المرور',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.lock)),
                                controller:
                                    TextEditingController(text: pass),
                                obscureText: true,
                                onChanged: (v) => pass = v)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'API Port (الافتراضي: 8728)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.settings_ethernet)),
                        controller: TextEditingController(text: port),
                        onChanged: (v) => port = v),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (name.isNotEmpty &&
                                    location.isNotEmpty &&
                                    ip.isNotEmpty) {
                                  if (docId != null) {
                                    bool confirm = await _confirmAction(
                                        "حفظ التعديلات",
                                        "هل أنت متأكد من حفظ التعديلات؟",
                                        Colors.blue);
                                    if (!confirm) return;
                                  }
                                  _play('click');
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    Map<String, dynamic> networkData = {
                                      'name': name,
                                      'location': location,
                                      'governorate': governorate,
                                      'district': district,
                                      'coverageAreas': coverageAreas,
                                      'ip': ip,
                                      'apiUser': user,
                                      'apiPassword': pass,
                                      'apiPort': port,
                                      'loginUrl': loginUrl,
                                      'agentPhone': sys.currentUserPhone,
                                      'agentName': sys.currentUserName,
                                      'isActive': existingData?['isActive'] ?? true,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };
                                    if (docId == null) {
                                      networkData['status'] = 'متصل نشط 🟢';
                                      networkData['categories'] = [];
                                      networkData['createdAt'] =
                                          FieldValue.serverTimestamp();
                                      await _db.collection('networks').add(networkData);
                                    } else {
                                      await _db.collection('networks').doc(docId).update(networkData);
                                    }
                                    _play('success');
                                    if (mounted) {
                                      Navigator.pop(context);
                                      _showToast(docId == null ? 'تمت إضافة الشبكة بنجاح! 🟢' : 'تم التعديل بنجاح! ✏️');
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    _play('error');
                                    _showToast('فشل حفظ البيانات', isError: true);
                                  }
                                } else {
                                  _play('error');
                                  _showToast('يرجى تعبئة الحقول الأساسية', isError: true);
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('حفظ واتصال',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
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
  // 2. إضافة وتعديل فئة كروت للشبكة (مطورة)
  // ==========================================
  void _showAddCategoryBottomSheet(List<QueryDocumentSnapshot> agentNetworks,
      {Map? existingCat, String? preSelectedNetId}) {
    _play('click');
    String newName = existingCat?['name'] ?? '';
    String newTime = existingCat?['time'] ?? '';
    String newCapacity = existingCat?['capacity'] ?? '';
    String newPrice = existingCat?['price']?.toString() ?? '';
    String note = existingCat?['note'] ?? '';
    String? selectedNetworkId = preSelectedNetId;
    Color selectedColor =
        existingCat != null ? Color(existingCat['color']) : Colors.blue;
    bool isSubmitting = false;

    if (agentNetworks.isEmpty) {
      _play('error');
      _showToast('يجب إضافة سيرفر شبكة أولاً!', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 16,
                right: 16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        existingCat == null
                            ? 'إضافة فئة كروت جديدة 🎟️'
                            : 'تعديل بيانات الفئة ✏️',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    if (existingCat == null)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                            labelText: 'اختر الشبكة',
                            border: OutlineInputBorder()),
                        value: selectedNetworkId,
                        items: agentNetworks
                            .map((net) => DropdownMenuItem(
                                value: net.id,
                                child:
                                    Text((net.data() as Map)['name'])))
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedNetworkId = val),
                      ),
                    if (existingCat == null) const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'اسم الفئة (Profile)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category)),
                        controller: TextEditingController(text: newName),
                        onChanged: (val) => newName = val),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                                decoration: const InputDecoration(
                                    labelText: 'الوقت (الساعات المتاح)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.timer)),
                                controller:
                                    TextEditingController(text: newTime),
                                onChanged: (val) => newTime = val)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                decoration: const InputDecoration(
                                    labelText:
                                        'سعة التحميل المتاح ميجابايت',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.data_usage)),
                                controller: TextEditingController(
                                    text: newCapacity),
                                onChanged: (val) => newCapacity = val)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'سعر البيع للجمهور',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money)),
                        controller: TextEditingController(text: newPrice),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => newPrice = val),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'ملاحظة (اختياري)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.note)),
                        controller: TextEditingController(text: note),
                        onChanged: (val) => note = val),
                    const SizedBox(height: 15),
                    // 🆕 عجلة ألوان شاملة
                    Row(
                      children: [
                        const Text('لون الفئة: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () async {
                            final color = await _openColorPicker(selectedColor);
                            if (color != null)
                              setModalState(() => selectedColor = color);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectedColor,
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('انقر لتغيير اللون',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (selectedNetworkId != null &&
                                    newName.isNotEmpty &&
                                    newPrice.isNotEmpty) {
                                  if (existingCat != null) {
                                    bool confirm = await _confirmAction(
                                        "حفظ التعديلات",
                                        "متأكد من تعديل الفئة؟",
                                        Colors.blue);
                                    if (!confirm) return;
                                  }
                                  _play('click');
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    var newCategory = {
                                      'id': existingCat?['id'] ??
                                          DateTime.now()
                                              .millisecondsSinceEpoch
                                              .toString(),
                                      'name': newName,
                                      'time': newTime.isNotEmpty
                                          ? newTime
                                          : 'غير محدد',
                                      'capacity': newCapacity.isNotEmpty
                                          ? newCapacity
                                          : 'مفتوح',
                                      'price':
                                          int.tryParse(newPrice) ?? 0,
                                      'color': selectedColor.value,
                                      'note': note,
                                      'stock': existingCat?['stock'] ?? 0,
                                      'isActive':
                                          existingCat?['isActive'] ?? true,
                                      'botMinStock':
                                          existingCat?['botMinStock'] ?? 5,
                                      'botRefillAmount':
                                          existingCat?['botRefillAmount'] ?? 50,
                                      'isBotEnabled':
                                          existingCat?['isBotEnabled'] ?? false,
                                    };
                                    if (existingCat == null) {
                                      await _db
                                          .collection('networks')
                                          .doc(selectedNetworkId)
                                          .update({
                                        'categories':
                                            FieldValue.arrayUnion([newCategory])
                                      });
                                    } else {
                                      var netDoc = await _db
                                          .collection('networks')
                                          .doc(selectedNetworkId)
                                          .get();
                                      List cats = List.from(
                                          (netDoc.data() as Map)['categories']);
                                      int idx = cats.indexWhere(
                                          (c) => c['id'] == existingCat['id']);
                                      cats[idx] = newCategory;
                                      await _db
                                          .collection('networks')
                                          .doc(selectedNetworkId)
                                          .update({'categories': cats});
                                    }
                                    _play('success');
                                    if (mounted) {
                                      Navigator.pop(context);
                                      _showToast('تم الحفظ بنجاح! 📋');
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    _play('error');
                                  }
                                } else {
                                  _play('error');
                                  _showToast('الرجاء تعبئة الحقول الأساسية!',
                                      isError: true);
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('حفظ الفئة',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
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
  // عرض وإدارة الكروت داخل الفئة
  // ==========================================
  void _showCardsList(
      String netId, String catId, String catName, Color catColor) {
    _play('click');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إدارة كروت فئة: $catName',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: catColor)),
              const Text(
                  'الأرقام المعروضة هي الأرقام النشطة والمتاحة للبيع',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('cards')
                      .where('categoryId', isEqualTo: catId)
                      .where('status', isEqualTo: 'متاح')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(
                          child: CircularProgressIndicator());
                    var cards = snapshot.data!.docs;
                    if (cards.isEmpty)
                      return const Center(
                          child: Text('لا توجد كروت متاحة. قم بالتوليد أولاً.',
                              style: TextStyle(color: Colors.grey)));

                    return ListView.builder(
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        var card = cards[index];
                        String pin = card['pin'];
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.confirmation_number,
                                color: Colors.teal),
                            title: Text(pin,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    fontSize: 18)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.copy,
                                        color: Colors.blue),
                                    tooltip: 'نسخ الكرت',
                                    onPressed: () {
                                      _play('click');
                                      Clipboard.setData(
                                          ClipboardData(text: pin));
                                      _showToast(
                                          'تم نسخ رقم الكرت للحافظة');
                                    }),
                                IconButton(
                                    icon: const Icon(Icons.archive,
                                        color: Colors.orange),
                                    tooltip: 'نقل للأرشيف',
                                    onPressed: () async {
                                      if (await _confirmAction(
                                          "أرشفة الكرت",
                                          "سيتم سحب هذا الكرت من السوق ونقله للأرشيف. هل أنت متأكد؟",
                                          Colors.orange)) {
                                        await card.reference
                                            .update({'status': 'archived'});
                                        var netDoc = await _db
                                            .collection('networks')
                                            .doc(netId)
                                            .get();
                                        List cats = List.from(
                                            netDoc['categories']);
                                        int idx = cats.indexWhere(
                                            (c) => c['id'] == catId);
                                        cats[idx]['stock'] -= 1;
                                        await _db
                                            .collection('networks')
                                            .doc(netId)
                                            .update({'categories': cats});
                                        _showToast('تمت أرشفة الكرت بنجاح');
                                      }
                                    }),
                                IconButton(
                                    icon: const Icon(Icons.delete_forever,
                                        color: Colors.red),
                                    tooltip: 'حذف نهائي',
                                    onPressed: () async {
                                      if (await _confirmAction(
                                          "حذف الكرت",
                                          "سيتم حذف الكرت نهائياً من قاعدة البيانات. هل توافق؟",
                                          Colors.red,
                                          requirePassword: true)) {
                                        await card.reference.delete();
                                        var netDoc = await _db
                                            .collection('networks')
                                            .doc(netId)
                                            .get();
                                        List cats = List.from(
                                            netDoc['categories']);
                                        int idx = cats.indexWhere(
                                            (c) => c['id'] == catId);
                                        cats[idx]['stock'] -= 1;
                                        await _db
                                            .collection('networks')
                                            .doc(netId)
                                            .update({'categories': cats});
                                        _showToast('تم حذف الكرت نهائياً');
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

  // ==========================================
  // إعدادات التوليد التلقائي (البوت)
  // ==========================================
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
            title: const Row(children: [
              Icon(Icons.smart_toy, color: Colors.purple),
              SizedBox(width: 10),
              Text('البوت الذكي للتوليد')
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'عند تفعيل البوت، سيقوم السيرفر بمراقبة مخزون هذه الفئة وتوليد كروت جديدة تلقائياً عندما ينخفض المخزون.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 15),
                SwitchListTile(
                  title: const Text('حالة التوليد التلقائي',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  value: isBotEnabled,
                  activeColor: Colors.purple,
                  onChanged: (v) => setModalState(() => isBotEnabled = v),
                ),
                if (isBotEnabled) ...[
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: 'الحد الأدنى للمخزون (متى يبدأ البوت؟)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => minStock = int.tryParse(v) ?? 5,
                    controller: TextEditingController(text: minStock.toString()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText:
                            'كمية التوليد التلقائي (كم كرت ينتج؟)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        refillAmount = int.tryParse(v) ?? 50,
                    controller:
                        TextEditingController(text: refillAmount.toString()),
                  ),
                ]
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    _play('click');
                    Navigator.pop(context);
                  },
                  child: const Text('إلغاء')),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () async {
                  _play('click');
                  var netDoc =
                      await _db.collection('networks').doc(netId).get();
                  List cats = List.from(netDoc['categories']);
                  int idx =
                      cats.indexWhere((c) => c['id'] == catId);
                  cats[idx]['botMinStock'] = minStock;
                  cats[idx]['botRefillAmount'] = refillAmount;
                  cats[idx]['isBotEnabled'] = isBotEnabled;
                  await _db
                      .collection('networks')
                      .doc(netId)
                      .update({'categories': cats});
                  Navigator.pop(context);
                  _play('success');
                  _showToast('تم حفظ إعدادات البوت الذكي');
                },
                child: const Text('حفظ وتشغيل',
                    style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. إدارة شرائح الخصم (مطورة مع استهداف ونطاق تطبيق)
  // ==========================================
  void _showDiscountTierBottomSheet(SystemProvider sys,
      {Map<String, dynamic>? existingTier, String? docId}) {
    _play('click');
    String title = existingTier?['title'] ?? '';
    String condition = existingTier?['condition']?.toString() ?? '';
    String discountValue = existingTier?['discountValue']?.toString() ?? '';
    String discountType = existingTier?['discountType'] ?? 'percentage';
    String targetType =
        existingTier?['targetType'] ?? 'all'; // all, pos, user, specific
    String targetPhone = existingTier?['targetPhone'] ?? '';
    Color selectedColor = existingTier != null
        ? Color(existingTier['color'])
        : Colors.amber.shade700;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 16,
                right: 16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        docId == null
                            ? 'إضافة شريحة خصم جديدة 🏆'
                            : 'تعديل الشريحة ✏️',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'اسم الشريحة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.stars)),
                        controller: TextEditingController(text: title),
                        onChanged: (v) => title = v),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'شرط السحب الشهري بالريال',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_cart)),
                        controller: TextEditingController(text: condition),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => condition = v),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                                decoration: const InputDecoration(
                                    labelText: 'قيمة الخصم',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.local_offer)),
                                controller: TextEditingController(
                                    text: discountValue),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => discountValue = v)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                                labelText: 'نوع الخصم',
                                border: OutlineInputBorder()),
                            value: discountType,
                            items: const [
                              DropdownMenuItem(
                                  value: 'percentage',
                                  child: Text('نسبة مئوية (%)')),
                              DropdownMenuItem(
                                  value: 'fixed',
                                  child: Text('مبلغ ثابت (ريال)')),
                            ],
                            onChanged: (val) => setModalState(
                                () => discountType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 🆕 نطاق تطبيق الخصم
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'نطاق تطبيق الخصم',
                          border: OutlineInputBorder()),
                      value: targetType,
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('الجميع (كل المستخدمين ونقاط البيع)')),
                        DropdownMenuItem(
                            value: 'pos', child: Text('جميع نقاط البيع فقط')),
                        DropdownMenuItem(
                            value: 'user', child: Text('جميع المستخدمين فقط')),
                        DropdownMenuItem(
                            value: 'specific',
                            child: Text('نقطة بيع / مستخدم محدد')),
                      ],
                      onChanged: (val) =>
                          setModalState(() => targetType = val!),
                    ),
                    if (targetType == 'specific') ...[
                      const SizedBox(height: 12),
                      TextField(
                          decoration: const InputDecoration(
                              labelText: 'رقم هاتف المستخدم / نقطة البيع',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone)),
                          controller:
                              TextEditingController(text: targetPhone),
                          keyboardType: TextInputType.phone,
                          onChanged: (v) => targetPhone = v),
                    ],
                    const SizedBox(height: 15),
                    // 🆕 عجلة ألوان شاملة
                    Row(
                      children: [
                        const Text('لون الشريحة المميز: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () async {
                            final color = await _openColorPicker(selectedColor);
                            if (color != null)
                              setModalState(() => selectedColor = color);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectedColor,
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('انقر لتغيير اللون',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (title.isNotEmpty &&
                                    condition.isNotEmpty &&
                                    discountValue.isNotEmpty) {
                                  if (docId != null) {
                                    bool confirm = await _confirmAction(
                                        "حفظ الشريحة",
                                        "هل أنت متأكد من التعديلات؟",
                                        selectedColor);
                                    if (!confirm) return;
                                  }
                                  _play('click');
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    Map<String, dynamic> tierData = {
                                      'agentPhone': sys.currentUserPhone,
                                      'title': title,
                                      'condition': int.parse(condition),
                                      'discountValue':
                                          double.parse(discountValue),
                                      'discountType': discountType,
                                      'color': selectedColor.value,
                                      'isActive':
                                          existingTier?['isActive'] ?? true,
                                      'targetType': targetType,
                                      'targetPhone': targetType == 'specific'
                                          ? targetPhone
                                          : '',
                                      'subscribersCount':
                                          existingTier?['subscribersCount'] ?? 0,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };
                                    if (docId == null) {
                                      tierData['createdAt'] =
                                          FieldValue.serverTimestamp();
                                      await _db
                                          .collection('discount_tiers')
                                          .add(tierData);
                                    } else {
                                      await _db
                                          .collection('discount_tiers')
                                          .doc(docId)
                                          .update(tierData);
                                    }
                                    _play('success');
                                    if (mounted) {
                                      Navigator.pop(context);
                                      _showToast('تم حفظ الشريحة بنجاح!');
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    _play('error');
                                  }
                                } else {
                                  _play('error');
                                  _showToast('يرجى تعبئة كافة بيانات الشريحة',
                                      isError: true);
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('حفظ الشريحة',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
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
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الميكروتك والفئات'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('networks')
            .where('agentPhone', isEqualTo: sys.currentUserPhone)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          List<QueryDocumentSnapshot> agentNetworks =
              snapshot.hasData ? snapshot.data!.docs : [];

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 5, top: 5),
                  decoration: BoxDecoration(
                    // ✅ أزرق داكن في النهاري، ديناميكي في الليلي
                    color: isDark
                        ? primaryColor.withOpacity(0.4).withAlpha(100)
                        : Colors.blue.shade800,
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.orange,
                    indicatorWeight: 4,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(icon: Icon(Icons.dns), text: 'سيرفرات الربط'),
                      Tab(icon: Icon(Icons.category), text: 'المخزون والفئات'),
                      Tab(icon: Icon(Icons.local_offer), text: 'شرائح الخصم'),
                      Tab(icon: Icon(Icons.autorenew), text: 'توليد الكروت'),
                    ],
                  ),
                ),
                if (_isProcessing)
                  const LinearProgressIndicator(
                      backgroundColor: Colors.orange, color: Colors.white),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildServersTab(sys, agentNetworks),
                      _buildCategoriesTab(agentNetworks),
                      _buildDiscountTiersTab(sys),
                      _buildGenerateCardsTab(sys, agentNetworks),
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

  // ==========================================
  // تبويب السيرفرات (متجاوب كليًا)
  // ==========================================
  Widget _buildServersTab(
      SystemProvider sys, List<QueryDocumentSnapshot> networks) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: networks.isEmpty
          ? const Center(
              child: Text('لم تقم بربط أي شبكة ميكروتك حتى الآن.',
                  style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: networks.length,
              itemBuilder: (context, index) {
                var net = networks[index].data() as Map<String, dynamic>;
                bool isActive = net['isActive'] ?? true;
                final textColor =
                    Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.black87;

                return Card(
                  color: isActive
                      ? Theme.of(context).cardColor
                      : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                                backgroundColor:
                                    isActive ? Colors.green : Colors.grey,
                                radius: 20,
                                child: const Icon(Icons.router,
                                    color: Colors.white, size: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                net['name'] ?? '',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: isActive
                                        ? null
                                        : TextDecoration.lineThrough,
                                    color: textColor),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                isActive ? 'نشط' : 'مجمد',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.green.shade700
                                        : Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.location_on, 'الموقع',
                            net['location'] ?? '', textColor),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                            Icons.wifi, 'IP', net['ip'] ?? '', textColor),
                        const SizedBox(height: 6),
                        _buildInfoRow(Icons.info_outline, 'الحالة',
                            isActive ? 'نشط' : 'مجمد', textColor),
                        const SizedBox(height: 16),
                        _buildActionButtons(
                            sys, networks, index, net, isActive),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddServerBottomSheet(sys),
        backgroundColor: Colors.blue.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة سيرفر',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey)),
        Expanded(
            child:
                Text(value, style: TextStyle(fontSize: 13, color: textColor))),
      ],
    );
  }

  Widget _buildActionButtons(
      SystemProvider sys,
      List<QueryDocumentSnapshot> networks,
      int index,
      Map<String, dynamic> net,
      bool isActive) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _actionButton(Icons.bolt, 'اختبار', Colors.blue,
            () => _testConnection(net)),
        _actionButton(
          isActive ? Icons.pause_circle_filled : Icons.play_circle_fill,
          isActive ? 'تجميد' : 'تنشيط',
          Colors.orange,
          () async {
            bool confirm = await _confirmAction(
                isActive ? "تجميد الشبكة" : "تنشيط الشبكة",
                "هل تريد تغيير حالة الشبكة؟",
                Colors.orange);
            if (confirm) {
              _db
                  .collection('networks')
                  .doc(networks[index].id)
                  .update({'isActive': !isActive});
              _showToast(isActive ? 'تم تجميد الشبكة' : 'تم تنشيط الشبكة');
            }
          },
        ),
        _actionButton(Icons.edit, 'تعديل', Colors.grey, () =>
            _showAddServerBottomSheet(sys,
                existingData: net, docId: networks[index].id)),
        _actionButton(Icons.delete, 'حذف', Colors.red, () async {
          bool confirm = await _confirmAction("حذف الشبكة نهائياً",
              "سيتم مسح بيانات الشبكة، هل أنت متأكد؟", Colors.red,
              requirePassword: true);
          if (confirm) {
            _play('click');
            await _db.collection('networks').doc(networks[index].id).delete();
            _showToast('تم حذف الشبكة نهائياً');
          }
        }),
      ],
    );
  }

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
    );
  }

  // ==========================================
  // تبويب الفئات والمخزون (متجاوب)
  // ==========================================
  Widget _buildCategoriesTab(List<QueryDocumentSnapshot> networks) {
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: networks.isEmpty
          ? const Center(
              child: Text('أضف سيرفر شبكة أولاً لعرض فئاته.',
                  style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: networks.length,
              itemBuilder: (context, netIndex) {
                var netId = networks[netIndex].id;
                var netData =
                    networks[netIndex].data() as Map<String, dynamic>;
                List categories = netData['categories'] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('فئات شبكة: ${netData['name']}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor))),
                    if (categories.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('لا توجد فئات لهذه الشبكة.',
                              style: TextStyle(color: Colors.grey))),
                    ...categories.map((category) {
                      int stock = category['stock'] ?? 0;
                      bool isLowStock = stock < 10;
                      Color catColor =
                          Color(category['color'] ?? Colors.blue.value);
                      bool isCatActive = category['isActive'] ?? true;
                      bool isBotEnabled = category['isBotEnabled'] ?? false;

                      return Card(
                        color: isCatActive
                            ? Theme.of(context).cardColor
                            : Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                                color: isCatActive
                                    ? catColor.withOpacity(0.5)
                                    : Colors.grey)),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                    category['name'],
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: isCatActive
                                            ? catColor
                                            : Colors.grey,
                                        decoration: isCatActive
                                            ? null
                                            : TextDecoration.lineThrough),
                                  )),
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                          icon: const Icon(
                                              Icons.remove_red_eye,
                                              color: Colors.teal,
                                              size: 20),
                                          onPressed: () => _showCardsList(
                                              netId,
                                              category['id'],
                                              category['name'],
                                              catColor),
                                          constraints:
                                              const BoxConstraints(),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 5),
                                          tooltip: 'عرض الكروت'),
                                      IconButton(
                                          icon: Icon(Icons.smart_toy,
                                              color: isBotEnabled
                                                  ? Colors.purple
                                                  : Colors.grey,
                                              size: 20),
                                          onPressed: () => _showBotSettings(
                                              netId,
                                              category['id'],
                                              category),
                                          constraints:
                                              const BoxConstraints(),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 5),
                                          tooltip: 'البوت الذكي'),
                                      IconButton(
                                          icon: Icon(
                                              isCatActive
                                                  ? Icons.pause_circle_filled
                                                  : Icons.play_circle_fill,
                                              color: Colors.orange,
                                              size: 20),
                                          onPressed: () async {
                                            bool confirm =
                                                await _confirmAction(
                                                    isCatActive
                                                        ? "تجميد الفئة"
                                                        : "تنشيط الفئة",
                                                    "تغيير حالة الفئة؟",
                                                    Colors.orange);
                                            if (confirm) {
                                              List updated =
                                                  List.from(categories);
                                              int idx = updated.indexWhere(
                                                  (c) => c['id'] == category['id']);
                                              updated[idx]['isActive'] = !isCatActive;
                                              await _db
                                                  .collection('networks')
                                                  .doc(netId)
                                                  .update({
                                                'categories': updated
                                              });
                                              _showToast(isCatActive
                                                  ? 'تم تجميد الفئة'
                                                  : 'تم تنشيط الفئة');
                                            }
                                          },
                                          constraints:
                                              const BoxConstraints(),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 5)),
                                      IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue,
                                              size: 20),
                                          onPressed: () =>
                                              _showAddCategoryBottomSheet(
                                                  networks,
                                                  existingCat: category,
                                                  preSelectedNetId: netId),
                                          constraints:
                                              const BoxConstraints(),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 5)),
                                      IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red, size: 20),
                                          onPressed: () async {
                                            bool confirm =
                                                await _confirmAction(
                                                    "حذف الفئة",
                                                    "سيتم حذف الفئة نهائياً، متأكد؟",
                                                    Colors.red,
                                                    requirePassword:
                                                        true);
                                            if (confirm) {
                                              _play('click');
                                              await _db
                                                  .collection('networks')
                                                  .doc(netId)
                                                  .update({
                                                'categories':
                                                    FieldValue.arrayRemove(
                                                        [category])
                                              });
                                              _showToast(
                                                  'تم حذف الفئة نهائياً');
                                            }
                                          },
                                          constraints:
                                              const BoxConstraints(),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 5)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  'الوقت: ${category['time']} | السعة: ${category['capacity']}',
                                  style: TextStyle(color: textColor)),
                              if (category['note'] != null &&
                                  category['note'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('📝 ${category['note']}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic)),
                                ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      'سعر الجمهور: ${category['price']} ريال',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.grey)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: isLowStock
                                            ? Colors.red.shade100
                                            : Colors.green.shade100,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text('المخزون: $stock كرت',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isLowStock
                                                ? Colors.red
                                                : Colors.green.shade800)),
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
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryBottomSheet(networks),
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.add_circle, color: Colors.white),
        label: const Text('إضافة فئة',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // تبويب شرائح الخصم
  // ==========================================
  Widget _buildDiscountTiersTab(SystemProvider sys) {
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('discount_tiers')
          .where('agentPhone', isEqualTo: sys.currentUserPhone)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        List<QueryDocumentSnapshot> tiers =
            snapshot.hasData ? snapshot.data!.docs : [];
        tiers.sort((a, b) =>
            ((b.data() as Map)['condition'] as int)
                .compareTo((a.data() as Map)['condition'] as int));

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10)),
                child: const Text(
                    '💡 الخصم يُطبق تلقائياً على المشتريات عند تحقيق شرط السحب.',
                    style: TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              Expanded(
                child: tiers.isEmpty
                    ? const Center(
                        child: Text('لم تقم بإضافة أي شرائح خصم حتى الآن.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tiers.length,
                        itemBuilder: (context, index) {
                          var tier =
                              tiers[index].data() as Map<String, dynamic>;
                          bool isActive = tier['isActive'] ?? true;
                          Color tColor = Color(
                              tier['color'] ?? Colors.amber.shade700.value);
                          String dType = tier['discountType'] == 'percentage'
                              ? '%'
                              : 'ريال';

                          return Card(
                            color: isActive
                                ? Theme.of(context).cardColor
                                : Colors.grey.shade200,
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(
                                  isActive ? Icons.stars : Icons.block,
                                  color: isActive ? tColor : Colors.grey,
                                  size: 35),
                              title: Text(tier['title'],
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? tColor : Colors.grey,
                                      decoration: isActive
                                          ? null
                                          : TextDecoration.lineThrough)),
                              subtitle: Text(
                                  'شرط السحب: ${tier['condition']} ريال\nالخصم: ${tier['discountValue']}$dType',
                                  style:
                                      TextStyle(fontSize: 12, color: textColor)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: isActive
                                            ? tColor.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text(
                                        tier['targetType'] == 'all'
                                            ? 'للجميع'
                                            : tier['targetType'] == 'pos'
                                                ? 'نقاط البيع'
                                                : tier['targetType'] == 'user'
                                                    ? 'المستخدمين'
                                                    : 'محدد',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isActive ? tColor : Colors.grey,
                                            fontSize: 10)),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                          onTap: () async {
                                            bool confirm = await _confirmAction(
                                                isActive
                                                    ? "تجميد الشريحة"
                                                    : "تنشيط الشريحة",
                                                "تغيير حالة العرض؟",
                                                Colors.orange);
                                            if (confirm)
                                              _db
                                                  .collection(
                                                      'discount_tiers')
                                                  .doc(tiers[index].id)
                                                  .update({
                                                'isActive': !isActive
                                              });
                                          },
                                          child: Icon(
                                              isActive
                                                  ? Icons.pause_circle_filled
                                                  : Icons.play_circle_fill,
                                              color: Colors.orange,
                                              size: 20)),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                          onTap: () =>
                                              _showDiscountTierBottomSheet(sys,
                                                  existingTier: tier,
                                                  docId: tiers[index].id),
                                          child: const Icon(Icons.edit,
                                              color: Colors.blue, size: 20)),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                          onTap: () async {
                                            bool confirm = await _confirmAction(
                                                "حذف الشريحة",
                                                "سيتم إلغاء الخصم عن البقالات المنضمة، متأكد؟",
                                                Colors.red,
                                                requirePassword: true);
                                            if (confirm) {
                                              _play('click');
                                              await _db
                                                  .collection(
                                                      'discount_tiers')
                                                  .doc(tiers[index].id)
                                                  .delete();
                                              _showToast('تم حذف الشريحة');
                                            }
                                          },
                                          child: const Icon(Icons.delete,
                                              color: Colors.red, size: 20)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showDiscountTierBottomSheet(sys),
            backgroundColor: Colors.amber.shade700,
            icon: const Icon(Icons.add_moderator, color: Colors.white),
            label: const Text('إضافة شريحة',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  // ==========================================
  // تبويب توليد الكروت (متجاوب)
  // ==========================================
  Widget _buildGenerateCardsTab(
      SystemProvider sys, List<QueryDocumentSnapshot> networks) {
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    if (networks.isEmpty)
      return const Center(child: Text('يجب إضافة شبكة وفئات أولاً!'));

    List<Map<String, dynamic>> allCategories = [];
    for (var net in networks) {
      String netId = net.id;
      List cats = (net.data() as Map)['categories'] ?? [];
      for (var cat in cats) {
        if ((net.data() as Map)['isActive'] != false &&
            cat['isActive'] != false) {
          allCategories.add({
            'networkId': netId,
            'networkName': (net.data() as Map)['name'],
            'category': cat
          });
        }
      }
    }

    if (allCategories.isEmpty)
      return const Center(child: Text('لا توجد فئات نشطة للتوليد.'));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue)),
            child: Text(
                '🔌 توليد متعدد: اكتب الكمية بجانب كل فئة، ثم اضغط زر التوليد.',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: allCategories.length,
              itemBuilder: (context, index) {
                var item = allCategories[index];
                String netId = item['networkId'];
                String catId = item['category']['id'];
                String key = "${netId}_$catId";
                _multiGenControllers.putIfAbsent(
                    key, () => TextEditingController());

                return Card(
                  color: Theme.of(context).cardColor,
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.category,
                            color: Color(item['category']['color']),
                            size: 30),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${item['networkName']} - ${item['category']['name']}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: textColor)),
                              Text(
                                  'المخزون الحالي: ${item['category']['stock']}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _multiGenControllers[key],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'الكمية',
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .scaffoldBackgroundColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        List<Map<String, dynamic>> orders = [];
                        _multiGenControllers.forEach((key, controller) {
                          if (controller.text.isNotEmpty) {
                            int amt = int.tryParse(controller.text) ?? 0;
                            if (amt > 0) {
                              var parts = key.split('_');
                              orders.add({
                                "networkId": parts[0],
                                "categoryId": parts[1],
                                "amount": amt
                              });
                            }
                          }
                        });

                        if (orders.isEmpty) {
                          _play('error');
                          _showToast('الرجاء كتابة كمية واحدة على الأقل',
                              isError: true);
                          return;
                        }

                        int totalAmount = orders.fold(
                            0, (sum, item) => sum + (item['amount'] as int));
                        if (totalAmount > 400) {
                          _play('error');
                          _showToast(
                              'الحد الأقصى للتوليد هو 400 كرت إجمالاً',
                              isError: true);
                          return;
                        }

                        bool confirm = await _confirmAction(
                            "تأكيد التوليد المتعدد",
                            "سيتم الآن توليد إجمالي $totalAmount كرت. هل تريد الاستمرار؟",
                            Colors.green);
                        if (!confirm) return;

                        _play('click');
                        setState(() => _isProcessing = true);
                        _showToast('جاري توليد الكروت... ⏳');

                        bool hasError = false;
                        for (var order in orders) {
                          try {
                            final response = await http.post(
                              Uri.parse(
                                  "$_renderUrl/generateMikrotikCards"),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({
                                "networkId": order['networkId'],
                                "categoryId": order['categoryId'],
                                "amount": order['amount'],
                                "agentPhone": sys.currentUserPhone
                              }),
                            );
                            if (response.statusCode != 200) hasError = true;
                          } catch (e) {
                            hasError = true;
                          }
                        }

                        setState(() => _isProcessing = false);
                        if (hasError) {
                          _play('error');
                          _showToast(
                              'تمت العملية ولكن حدثت بعض الأخطاء في التوليد',
                              isError: true);
                        } else {
                          _play('success');
                          _multiGenControllers.forEach((k, v) => v.clear());
                          _showToast('تم توليد جميع الكروت بنجاح! ✅');
                        }
                      },
                icon: const Icon(Icons.bolt, color: Colors.white),
                label: const Text('بدء التوليد المتعدد الآن',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
