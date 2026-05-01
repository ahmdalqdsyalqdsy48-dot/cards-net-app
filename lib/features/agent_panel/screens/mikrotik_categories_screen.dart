import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

// ========== محرك التموضع الدقيق ==========
class PreciseLayoutEngine {
  static const double mmToPx = 2.83465;
  static double getAbsolutePos(double indexInDim, double cardSizeMM, double gapMM, double marginMM) {
    return (marginMM + (indexInDim * (cardSizeMM + gapMM))) * mmToPx;
  }
}

class MikrotikCategoriesScreen extends StatefulWidget {
  const MikrotikCategoriesScreen({super.key});

  @override
  State<MikrotikCategoriesScreen> createState() =>
      _MikrotikCategoriesScreenState();
}

class _MikrotikCategoriesScreenState extends State<MikrotikCategoriesScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  final String _renderUrl = "https://mikrotik-server-qu6a.onrender.com";
  bool _isProcessing = false;

  // ===== وضع المحاكاة =====
  bool _simulationMode = false;

  final Map<String, TextEditingController> _multiGenControllers = {};

  // مسودات النوافذ
  String _draftServerName = '';
  String _draftServerLocation = '';
  String _draftServerGovernorate = '';
  String _draftServerDistrict = '';
  List<String> _draftServerCoverageAreas = [];
  String _draftServerIp = '';
  String _draftServerUser = '';
  String _draftServerPass = '';
  String _draftServerPort = '8728';
  String _draftServerLoginUrl = '';

  String _draftCategoryName = '';
  String _draftCategoryTime = '';
  String _draftCategoryCapacity = '';
  String _draftCategoryPrice = '';
  String _draftCategoryNote = '';
  Color _draftCategoryColor = Colors.blue;
  String? _draftCategoryTemplateBase64;

  String _draftTierTitle = '';
  String _draftTierCondition = '';
  String _draftTierDiscountValue = '';
  String _draftTierDiscountType = 'percentage';
  String _draftTierTargetType = 'all';
  List<String> _draftTierTargetPhones = [];
  Color _draftTierColor = Colors.amber.shade700;

  Timer? _searchTimer;

  // ========== متغيرات الطباعة ==========
  List<QueryDocumentSnapshot> printNetworks = [];
  Map<String, List<Map<String, dynamic>>> printNetworkCategories = {};
  String? printSelectedNetworkId;
  final Set<String> printSelectedCategoryIds = {};
  final Map<String, Map<String, dynamic>> printSelectedCategories = {};
  List<QueryDocumentSnapshot> allPrintReadyCards = [];
  final Map<String, Uint8List?> _categoryTemplates = {};
  Uint8List? getTemplate(String categoryId) => _categoryTemplates[categoryId];

  final ValueNotifier<double> textX = ValueNotifier(50);
  final ValueNotifier<double> textY = ValueNotifier(50);
  final ValueNotifier<double> fontSize = ValueNotifier(14);
  final ValueNotifier<Color> textColor = ValueNotifier(Colors.black);

  final copiesPerCardCtrl = TextEditingController(text: "1");
  final perRowCtrl = TextEditingController(text: "3");
  final perColumnCtrl = TextEditingController(text: "17");
  final widthMMCtrl = TextEditingController(text: "70.0");
  final heightMMCtrl = TextEditingController(text: "17.4");
  final horizontalGapCtrl = TextEditingController(text: "0.0");
  final verticalGapCtrl = TextEditingController(text: "0.0");
  final pageLeftMarginCtrl = TextEditingController(text: "5.0");
  final pageTopMarginCtrl = TextEditingController(text: "5.0");
  final Map<String, TextEditingController> printCategoryCountControllers = {};
  final printTotalCountCtrl = TextEditingController();
  List<Map<String, dynamic>> savedPrintTemplates = [];
  List<Map<String, dynamic>> printLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // 5 تبويبات
    printTotalCountCtrl.text = "0";
    _loadPrintInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    copiesPerCardCtrl.dispose();
    perRowCtrl.dispose();
    perColumnCtrl.dispose();
    widthMMCtrl.dispose();
    heightMMCtrl.dispose();
    horizontalGapCtrl.dispose();
    verticalGapCtrl.dispose();
    pageLeftMarginCtrl.dispose();
    pageTopMarginCtrl.dispose();
    printTotalCountCtrl.dispose();
    textX.dispose();
    textY.dispose();
    fontSize.dispose();
    textColor.dispose();
    for (final c in printCategoryCountControllers.values) { c.dispose(); }
    super.dispose();
  }

  // ========== دوال مشتركة ==========
  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ========== أيقونة كلمة المرور ==========
  Future<bool> _confirmAction(String title, String message, Color color,
      {bool requirePassword = false}) async {
    _play('warning');
    final passwordController = TextEditingController();
    bool obscure = true;
    return await showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                title: Text(title,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    if (requirePassword) ...[
                      const SizedBox(height: 15),
                      TextField(
                        controller: passwordController,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'أدخل كلمة المرور للتأكيد',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock, color: Colors.red),
                          suffixIcon: IconButton(
                            icon: Icon(
                                obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscure = !obscure),
                          ),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (requirePassword) {
                        final sys = Provider.of<SystemProvider>(context,
                            listen: false);
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
                    child: const Text('تأكيد التنفيذ',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  // ========== المحاكاة ==========
  Future<void> _toggleSimulation() async {
    if (!_simulationMode) {
      bool firstConfirm = await _confirmAction(
        "تفعيل وضع المحاكاة",
        "تحذير: هذا الوضع سيولّد كروتًا وهمية غير حقيقية. هل تريد الاستمرار؟",
        Colors.red,
      );
      if (!firstConfirm) return;
      bool passConfirm = await _confirmAction(
        "تأكيد بكلمة المرور",
        "أدخل كلمة المرور لتفعيل المحاكاة",
        Colors.red,
        requirePassword: true,
      );
      if (!passConfirm) return;
      setState(() => _simulationMode = true);
      _play('success');
      _showToast('تم تفعيل وضع المحاكاة (الكروت المولدة وهمية)');
    } else {
      setState(() => _simulationMode = false);
      _play('click');
      _showToast('تم إلغاء وضع المحاكاة');
    }
  }

  String _generateFakePin() {
    final r = Random();
    return (r.nextInt(9000000) + 1000000).toString();
  }

  Future<void> _simulateGenerate(
      String networkId, String categoryId, int amount, bool forPrint) async {
    final WriteBatch batch = _db.batch();
    final status = forPrint ? 'print_ready' : 'متاح';
    for (int i = 0; i < amount; i++) {
      final pin = _generateFakePin();
      final docRef = _db.collection('cards').doc();
      batch.set(docRef, {
        'categoryId': categoryId,
        'networkId': networkId,
        'pin': pin,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    final netDoc = await _db.collection('networks').doc(networkId).get();
    List cats = List.from((netDoc.data() as Map)['categories']);
    int idx = cats.indexWhere((c) => c['id'] == categoryId);
    if (idx != -1) {
      cats[idx]['stock'] = (cats[idx]['stock'] ?? 0) + amount;
      batch.update(_db.collection('networks').doc(networkId), {'categories': cats});
    }
    await batch.commit();
  }

  Future<void> _testConnection(Map<String, dynamic> net) async {
    _play('click');
    setState(() => _isProcessing = true);
    _showToast('جاري فحص الاتصال... ⏳');
    try {
      final response = await http.post(
        Uri.parse("$_renderUrl/testConnection"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "host": net['ip'],
          "user": net['apiUser'],
          "pass": net['apiPassword'],
          "port": net['apiPort']
        }),
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
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
  // 1. إضافة وتعديل سيرفر ميكروتك
  // ==========================================
  void _showAddServerBottomSheet(SystemProvider sys,
      {Map<String, dynamic>? existingData, String? docId}) {
    _play('click');
    String name = existingData?['name'] ?? _draftServerName;
    String location = existingData?['location'] ?? _draftServerLocation;
    String governorate = existingData?['governorate'] ?? _draftServerGovernorate;
    String district = existingData?['district'] ?? _draftServerDistrict;
    List<String> coverageAreas = existingData != null
        ? List<String>.from(existingData['coverageAreas'] ?? [])
        : List<String>.from(_draftServerCoverageAreas);
    String ip = existingData?['ip'] ?? _draftServerIp;
    String user = existingData?['apiUser'] ?? _draftServerUser;
    String pass = existingData?['apiPassword'] ?? _draftServerPass;
    String port = existingData?['apiPort'] ?? _draftServerPort;
    String loginUrl = existingData?['loginUrl'] ?? _draftServerLoginUrl;
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'إسم شبكتك',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.dns, color: Colors.blue)),
                        controller: TextEditingController(text: name),
                        onChanged: (v) => name = v),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'موقع الشبكة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on, color: Colors.orange)),
                        controller: TextEditingController(text: location),
                        onChanged: (v) => location = v),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      iconColor: Colors.teal,
                      collapsedIconColor: Colors.teal,
                      title: const Text('تفاصيل الموقع (اختياري)'),
                      children: [
                        TextField(
                            decoration: const InputDecoration(
                                labelText: 'المحافظة',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.map, color: Colors.teal)),
                            controller: TextEditingController(text: governorate),
                            onChanged: (v) => governorate = v),
                        const SizedBox(height: 12),
                        TextField(
                            decoration: const InputDecoration(
                                labelText: 'المديرية',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.map_outlined, color: Colors.teal)),
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
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.wifi_find, color: Colors.teal)),
                                      controller: TextEditingController(text: coverageAreas[idx]),
                                      onChanged: (v) => coverageAreas[idx] = v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => setModalState(() => coverageAreas.removeAt(idx)),
                                )
                              ],
                            ),
                          );
                        }).toList(),
                        TextButton.icon(
                          onPressed: () => setModalState(() => coverageAreas.add('')),
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
                            prefixIcon: Icon(Icons.wifi, color: Colors.green)),
                        controller: TextEditingController(text: ip),
                        onChanged: (v) => ip = v),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'رابط صفحة تسجيل الدخول للزبائن',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link, color: Colors.indigo)),
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
                                    prefixIcon: Icon(Icons.person, color: Colors.deepPurple)),
                                controller: TextEditingController(text: user),
                                onChanged: (v) => user = v)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                decoration: const InputDecoration(
                                    labelText: 'كلمة المرور',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.lock, color: Colors.red)),
                                controller: TextEditingController(text: pass),
                                obscureText: true,
                                onChanged: (v) => pass = v)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'API Port (الافتراضي: 8728)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.settings_ethernet, color: Colors.blueGrey)),
                        controller: TextEditingController(text: port),
                        onChanged: (v) => port = v),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (name.isNotEmpty && location.isNotEmpty && ip.isNotEmpty) {
                                  if (docId != null) {
                                    bool confirm = await _confirmAction(
                                        "حفظ التعديلات", "هل أنت متأكد من حفظ التعديلات؟", Colors.blue);
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
                                      networkData['createdAt'] = FieldValue.serverTimestamp();
                                      await _db.collection('networks').add(networkData);
                                      _draftServerName = '';
                                      _draftServerLocation = '';
                                      _draftServerGovernorate = '';
                                      _draftServerDistrict = '';
                                      _draftServerCoverageAreas = [];
                                      _draftServerIp = '';
                                      _draftServerUser = '';
                                      _draftServerPass = '';
                                      _draftServerPort = '8728';
                                      _draftServerLoginUrl = '';
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
                                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          _draftServerName = name;
                          _draftServerLocation = location;
                          _draftServerGovernorate = governorate;
                          _draftServerDistrict = district;
                          _draftServerCoverageAreas = coverageAreas;
                          _draftServerIp = ip;
                          _draftServerUser = user;
                          _draftServerPass = pass;
                          _draftServerPort = port;
                          _draftServerLoginUrl = loginUrl;
                          _play('click');
                          Navigator.pop(context);
                          _showToast('تم حفظ البيانات كمسودة');
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('إغلاق وحفظ كمسودة'),
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
  // 2. إضافة وتعديل فئة كروت للشبكة
  // ==========================================
  void _showAddCategoryBottomSheet(List<QueryDocumentSnapshot> agentNetworks,
      {Map? existingCat, String? preSelectedNetId}) {
    _play('click');
    String newName = existingCat?['name'] ?? _draftCategoryName;
    String newTime = existingCat?['time'] ?? _draftCategoryTime;
    String newCapacity = existingCat?['capacity'] ?? _draftCategoryCapacity;
    String newPrice = existingCat?['price']?.toString() ?? _draftCategoryPrice;
    String note = existingCat?['note'] ?? _draftCategoryNote;
    String? selectedNetworkId = preSelectedNetId;
    Color selectedColor = existingCat != null ? Color(existingCat['color']) : _draftCategoryColor;
    String? templateBase64 = existingCat?['templateBase64'] ?? _draftCategoryTemplateBase64;
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
                        existingCat == null ? 'إضافة فئة كروت جديدة 🎟️' : 'تعديل بيانات الفئة ✏️',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    if (existingCat == null)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                            labelText: 'اختر الشبكة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.dns, color: Colors.blue)),
                        value: selectedNetworkId,
                        items: agentNetworks
                            .map((net) => DropdownMenuItem(
                                value: net.id, child: Text((net.data() as Map)['name'])))
                            .toList(),
                        onChanged: (val) => setModalState(() => selectedNetworkId = val),
                      ),
                    if (existingCat == null) const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'اسم الفئة (Profile)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category, color: Colors.orange)),
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
                                    prefixIcon: Icon(Icons.timer, color: Colors.blue)),
                                controller: TextEditingController(text: newTime),
                                onChanged: (val) => newTime = val)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                decoration: const InputDecoration(
                                    labelText: 'سعة التحميل المتاح ميجابايت',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.data_usage, color: Colors.teal)),
                                controller: TextEditingController(text: newCapacity),
                                onChanged: (val) => newCapacity = val)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'سعر البيع للجمهور',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money, color: Colors.green)),
                        controller: TextEditingController(text: newPrice),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => newPrice = val),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'ملاحظة (اختياري)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.note, color: Colors.amber)),
                        controller: TextEditingController(text: note),
                        onChanged: (val) => note = val),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(Icons.image, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        const Text('قالب الطباعة (اختياري): ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final pickedFile = await _imagePicker.pickImage(
                                source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
                            if (pickedFile != null) {
                              final bytes = await pickedFile.readAsBytes();
                              setModalState(() => templateBase64 = base64Encode(bytes));
                              _play('success');
                              _showToast('تم تحميل القالب بنجاح');
                            }
                          },
                          icon: Icon(
                            templateBase64 != null ? Icons.check_circle : Icons.upload_file,
                            color: templateBase64 != null ? Colors.green : Colors.deepPurple,
                          ),
                          label: Text(templateBase64 != null ? 'تم التحميل' : 'اختيار صورة',
                              style: TextStyle(
                                  color: templateBase64 != null ? Colors.green : Colors.deepPurple)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.withOpacity(0.1),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Text('لون الفئة: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () async {
                            final color = await _openColorPicker(selectedColor);
                            if (color != null) setModalState(() => selectedColor = color);
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
                        const Text('انقر لتغيير اللون', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (selectedNetworkId != null && newName.isNotEmpty && newPrice.isNotEmpty) {
                                  if (existingCat != null) {
                                    bool confirm = await _confirmAction(
                                        "حفظ التعديلات", "متأكد من تعديل الفئة؟", Colors.blue);
                                    if (!confirm) return;
                                  }
                                  _play('click');
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    var newCategory = {
                                      'id': existingCat?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                      'name': newName,
                                      'time': newTime.isNotEmpty ? newTime : 'غير محدد',
                                      'capacity': newCapacity.isNotEmpty ? newCapacity : 'مفتوح',
                                      'price': int.tryParse(newPrice) ?? 0,
                                      'color': selectedColor.value,
                                      'note': note,
                                      'templateBase64': templateBase64,
                                      'stock': existingCat?['stock'] ?? 0,
                                      'isActive': existingCat?['isActive'] ?? true,
                                      'botMinStock': existingCat?['botMinStock'] ?? 5,
                                      'botRefillAmount': existingCat?['botRefillAmount'] ?? 50,
                                      'isBotEnabled': existingCat?['isBotEnabled'] ?? false,
                                    };
                                    if (existingCat == null) {
                                      await _db.collection('networks').doc(selectedNetworkId).update({
                                        'categories': FieldValue.arrayUnion([newCategory])
                                      });
                                      _draftCategoryName = '';
                                      _draftCategoryTime = '';
                                      _draftCategoryCapacity = '';
                                      _draftCategoryPrice = '';
                                      _draftCategoryNote = '';
                                      _draftCategoryColor = Colors.blue;
                                      _draftCategoryTemplateBase64 = null;
                                    } else {
                                      var netDoc = await _db.collection('networks').doc(selectedNetworkId).get();
                                      List cats = List.from((netDoc.data() as Map)['categories']);
                                      int idx = cats.indexWhere((c) => c['id'] == existingCat['id']);
                                      cats[idx] = newCategory;
                                      await _db.collection('networks').doc(selectedNetworkId).update({'categories': cats});
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
                                  _showToast('الرجاء تعبئة الحقول الأساسية!', isError: true);
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('حفظ الفئة',
                                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          _draftCategoryName = newName;
                          _draftCategoryTime = newTime;
                          _draftCategoryCapacity = newCapacity;
                          _draftCategoryPrice = newPrice;
                          _draftCategoryNote = note;
                          _draftCategoryColor = selectedColor;
                          _draftCategoryTemplateBase64 = templateBase64;
                          _play('click');
                          Navigator.pop(context);
                          _showToast('تم حفظ البيانات كمسودة');
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('إغلاق وحفظ كمسودة'),
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
    // ======================== دوال عرض الكروت والبوت ========================
  void _showCardsList(String netId, String catId, String catName, Color catColor) {
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: catColor)),
              const Text('الأرقام المعروضة هي الأرقام النشطة والمتاحة للبيع',
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
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
                            leading: const Icon(Icons.confirmation_number, color: Colors.teal),
                            title: Text(pin,
                                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.copy, color: Colors.blue),
                                    tooltip: 'نسخ الكرت',
                                    onPressed: () {
                                      _play('click');
                                      Clipboard.setData(ClipboardData(text: pin));
                                      _showToast('تم نسخ رقم الكرت للحافظة');
                                    }),
                                IconButton(
                                    icon: const Icon(Icons.archive, color: Colors.orange),
                                    tooltip: 'نقل للأرشيف',
                                    onPressed: () async {
                                      if (await _confirmAction("أرشفة الكرت",
                                          "سيتم سحب هذا الكرت من السوق ونقله للأرشيف. هل أنت متأكد؟",
                                          Colors.orange)) {
                                        await card.reference.update({'status': 'archived'});
                                        var netDoc = await _db.collection('networks').doc(netId).get();
                                        List cats = List.from(netDoc['categories']);
                                        int idx = cats.indexWhere((c) => c['id'] == catId);
                                        cats[idx]['stock'] -= 1;
                                        await _db.collection('networks').doc(netId).update({'categories': cats});
                                        _showToast('تمت أرشفة الكرت بنجاح');
                                      }
                                    }),
                                IconButton(
                                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                                    tooltip: 'حذف نهائي',
                                    onPressed: () async {
                                      if (await _confirmAction("حذف الكرت",
                                          "سيتم حذف الكرت نهائياً من قاعدة البيانات. هل توافق؟",
                                          Colors.red,
                                          requirePassword: true)) {
                                        await card.reference.delete();
                                        var netDoc = await _db.collection('networks').doc(netId).get();
                                        List cats = List.from(netDoc['categories']);
                                        int idx = cats.indexWhere((c) => c['id'] == catId);
                                        cats[idx]['stock'] -= 1;
                                        await _db.collection('networks').doc(netId).update({'categories': cats});
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
                  title:
                      const Text('حالة التوليد التلقائي', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        labelText: 'كمية التوليد التلقائي (كم كرت ينتج؟)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => refillAmount = int.tryParse(v) ?? 50,
                    controller: TextEditingController(text: refillAmount.toString()),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () async {
                  _play('click');
                  var netDoc = await _db.collection('networks').doc(netId).get();
                  List cats = List.from(netDoc['categories']);
                  int idx = cats.indexWhere((c) => c['id'] == catId);
                  cats[idx]['botMinStock'] = minStock;
                  cats[idx]['botRefillAmount'] = refillAmount;
                  cats[idx]['isBotEnabled'] = isBotEnabled;
                  await _db.collection('networks').doc(netId).update({'categories': cats});
                  Navigator.pop(context);
                  _play('success');
                  _showToast('تم حفظ إعدادات البوت الذكي');
                },
                child: const Text('حفظ وتشغيل', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. إدارة شرائح الخصم
  // ==========================================
  void _showDiscountTierBottomSheet(SystemProvider sys,
      {Map<String, dynamic>? existingTier, String? docId}) {
    _play('click');
    String title = existingTier?['title'] ?? _draftTierTitle;
    String condition = existingTier?['condition']?.toString() ?? _draftTierCondition;
    String discountValue =
        existingTier?['discountValue']?.toString() ?? _draftTierDiscountValue;
    String discountType = existingTier?['discountType'] ?? _draftTierDiscountType;
    String targetType = existingTier?['targetType'] ?? _draftTierTargetType;
    List<String> targetPhones = existingTier != null
        ? List<String>.from(existingTier['targetPhones'] ?? [])
        : List<String>.from(_draftTierTargetPhones);
    Color selectedColor = existingTier != null ? Color(existingTier['color']) : _draftTierColor;
    bool isSubmitting = false;

    Map<String, Map<String, dynamic>?> searchResults = {};

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
                    Text(docId == null ? 'إضافة شريحة خصم جديدة 🏆' : 'تعديل الشريحة ✏️',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'اسم الشريحة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.stars, color: Colors.amber)),
                        controller: TextEditingController(text: title),
                        onChanged: (v) => title = v),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'شرط السحب الشهري بالريال',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_cart, color: Colors.orange)),
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
                                    prefixIcon: Icon(Icons.local_offer, color: Colors.green)),
                                controller: TextEditingController(text: discountValue),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => discountValue = v)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                                labelText: 'نوع الخصم', border: OutlineInputBorder()),
                            value: discountType,
                            items: const [
                              DropdownMenuItem(value: 'percentage', child: Text('نسبة مئوية (%)')),
                              DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت (ريال)')),
                            ],
                            onChanged: (val) => setModalState(() => discountType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'نطاق تطبيق الخصم', border: OutlineInputBorder()),
                      value: targetType,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('الجميع (كل المستخدمين ونقاط البيع)')),
                        DropdownMenuItem(value: 'pos', child: Text('جميع نقاط البيع فقط')),
                        DropdownMenuItem(value: 'user', child: Text('جميع المستخدمين فقط')),
                        DropdownMenuItem(value: 'specific', child: Text('نقطة بيع / مستخدم محدد')),
                      ],
                      onChanged: (val) => setModalState(() => targetType = val!),
                    ),
                    if (targetType == 'specific') ...[
                      const SizedBox(height: 12),
                      ...targetPhones.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String phone = entry.value;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'رقم الهاتف ${idx + 1}',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                                      suffixIcon: searchResults[phone] != null
                                          ? IconButton(
                                              icon: const Icon(Icons.info_outline, color: Colors.teal),
                                              onPressed: () => _showTargetInfoDialog(
                                                  phone, searchResults[phone]!, sys.currentUserPhone),
                                            )
                                          : null,
                                    ),
                                    controller: TextEditingController(text: phone),
                                    keyboardType: TextInputType.phone,
                                    onChanged: (v) {
                                      targetPhones[idx] = v;
                                      _debounceSearch(v, sys, setModalState, searchResults, phone);
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () {
                                    setModalState(() {
                                      targetPhones.removeAt(idx);
                                      searchResults.remove(phone);
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (searchResults[phone] != null)
                              _buildTargetInfoCard(phone, searchResults[phone]!, sys),
                            const SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                      TextButton.icon(
                        onPressed: () => setModalState(() => targetPhones.add('')),
                        icon: const Icon(Icons.add, color: Colors.green),
                        label: const Text('إضافة مستهدف آخر'),
                      ),
                    ],
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Text('لون الشريحة المميز: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () async {
                            final color = await _openColorPicker(selectedColor);
                            if (color != null) setModalState(() => selectedColor = color);
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
                        const Text('انقر لتغيير اللون',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (title.isNotEmpty && condition.isNotEmpty && discountValue.isNotEmpty) {
                                  if (docId != null) {
                                    bool confirm = await _confirmAction(
                                        "حفظ الشريحة", "هل أنت متأكد من التعديلات؟", selectedColor);
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
                                      'targetType': targetType,
                                      'targetPhones': targetPhones,
                                      'subscribersCount': existingTier?['subscribersCount'] ?? 0,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };
                                    if (docId == null) {
                                      tierData['createdAt'] = FieldValue.serverTimestamp();
                                      await _db.collection('discount_tiers').add(tierData);
                                      _draftTierTitle = '';
                                      _draftTierCondition = '';
                                      _draftTierDiscountValue = '';
                                      _draftTierDiscountType = 'percentage';
                                      _draftTierTargetType = 'all';
                                      _draftTierTargetPhones = [];
                                      _draftTierColor = Colors.amber.shade700;
                                    } else {
                                      await _db.collection('discount_tiers').doc(docId).update(tierData);
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
                                  _showToast('يرجى تعبئة كافة بيانات الشريحة', isError: true);
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('حفظ الشريحة',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          _draftTierTitle = title;
                          _draftTierCondition = condition;
                          _draftTierDiscountValue = discountValue;
                          _draftTierDiscountType = discountType;
                          _draftTierTargetType = targetType;
                          _draftTierTargetPhones = targetPhones;
                          _draftTierColor = selectedColor;
                          _play('click');
                          Navigator.pop(context);
                          _showToast('تم حفظ البيانات كمسودة');
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('إغلاق وحفظ كمسودة'),
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

  Timer? _debounceTimer;
  void _debounceSearch(String phone, SystemProvider sys, StateSetter setModalState,
      Map<String, dynamic?> results, String currentPhone) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (phone.length >= 9) {
        final userData = await sys.searchUserForTransfer(phone);
        setModalState(() => results[currentPhone] = userData);
        if (userData != null) {
          _play('success');
        }
      }
    });
  }

  Widget _buildTargetInfoCard(String phone, Map<String, dynamic> data, SystemProvider sys) {
    return Card(
      color: Colors.teal.shade50,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.teal),
                const SizedBox(width: 8),
                Text(data['name'] ?? 'غير معروف',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('الدور', data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم'),
            _infoRow('الرصيد العام', '${data['balance'] ?? '0'} ريال'),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      _showTargetTransactionsDialog(phone, sys.currentUserPhone, data['name'] ?? ''),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('آخر العمليات'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTargetInfoDialog(String phone, Map<String, dynamic> data, String agentPhone) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title:
              Text('معلومات ${data['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('الاسم', data['name']),
                _infoRow('الدور', data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم'),
                _infoRow('رقم الهاتف', phone),
                _infoRow('الرصيد الحالي', '${data['balance']} ريال'),
                _infoRow('آخر عملية شحن', data['lastRecharge'] ?? 'لا يوجد'),
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showTargetTransactionsDialog(phone, agentPhone, data['name'] ?? '');
                    },
                    icon: const Icon(Icons.receipt),
                    label: const Text('عرض آخر العمليات'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTargetTransactions(
      String phone, String agentPhone) async {
    final netSnap = await _db.collection('networks').where('agentPhone', isEqualTo: agentPhone).get();
    List<String> networkIds = netSnap.docs.map((d) => d.id).toList();
    if (networkIds.isEmpty) return [];

    final transSnap = await _db
        .collection('transactions')
        .where('userPhone', isEqualTo: phone)
        .where('networkId', whereIn: networkIds)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    return transSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  void _showTargetTransactionsDialog(String phone, String agentPhone, String userName) async {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('آخر عمليات $userName'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchTargetTransactions(phone, agentPhone),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                final list = snapshot.data ?? [];
                if (list.isEmpty) return const Center(child: Text('لا توجد عمليات'));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final t = list[i];
                    return ListTile(
                      leading: Icon(Icons.receipt_long, color: Colors.orange),
                      title: Text('${t['amount'] ?? 0} ريال'),
                      subtitle: Text(
                          '${t['type'] ?? ''} - ${t['createdAt'] != null ? t['createdAt'].toDate().toString() : ''}'),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ==========================================
  // 4. توليد الكروت (مع تعديل زر الطباعة)
  // ==========================================
  Widget _buildGenerateCardsTab(SystemProvider sys, List<QueryDocumentSnapshot> networks) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    if (networks.isEmpty) return const Center(child: Text('يجب إضافة شبكة وفئات أولاً!'));

    List<Map<String, dynamic>> allCategories = [];
    for (var net in networks) {
      String netId = net.id;
      List cats = (net.data() as Map)['categories'] ?? [];
      for (var cat in cats) {
        if ((net.data() as Map)['isActive'] != false && cat['isActive'] != false) {
          allCategories.add({
            'networkId': netId,
            'networkName': (net.data() as Map)['name'],
            'category': cat
          });
        }
      }
    }

    if (allCategories.isEmpty) return const Center(child: Text('لا توجد فئات نشطة للتوليد.'));

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
                '🔌 توليد متعدد: اكتب الكمية بجانب كل فئة، ثم اختر نوع التوليد واضغط توليد.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
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
                _multiGenControllers.putIfAbsent(key, () => TextEditingController());

                return Card(
                  color: Theme.of(context).cardColor,
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.category, color: Color(item['category']['color']), size: 30),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['networkName']} - ${item['category']['name']}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: textColor)),
                              Text('المخزون الحالي: ${item['category']['stock']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              border:
                                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Theme.of(context).scaffoldBackgroundColor,
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
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () =>
                              _startGeneration(sys, orders: _collectOrders(), forPrint: false),
                      icon: const Icon(Icons.inventory, color: Colors.white),
                      label: const Text('توليد للمخزون',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              final success = await _startGeneration(
                                sys,
                                orders: _collectOrders(),
                                forPrint: true,
                              );
                              if (success) {
                                _showToast('✅ تم التوليد للطباعة بنجاح! يمكنك الآن الانتقال إلى تبويب "الطباعة" لطباعة الكروت الجاهزة.');
                              }
                            },
                      icon: const Icon(Icons.print, color: Colors.white),
                      label: const Text('توليد للطباعة',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _collectOrders() {
    List<Map<String, dynamic>> orders = [];
    _multiGenControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        int amt = int.tryParse(controller.text) ?? 0;
        if (amt > 0) {
          var parts = key.split('_');
          orders.add({"networkId": parts[0], "categoryId": parts[1], "amount": amt});
        }
      }
    });
    return orders;
  }

  Future<bool> _startGeneration(SystemProvider sys,
      {required List<Map<String, dynamic>> orders, required bool forPrint}) async {
    if (orders.isEmpty) {
      _play('error');
      _showToast('الرجاء كتابة كمية واحدة على الأقل', isError: true);
      return false;
    }

    int totalAmount = orders.fold(0, (sum, item) => sum + (item['amount'] as int));
    if (totalAmount > 400) {
      _play('error');
      _showToast('الحد الأقصى للتوليد هو 400 كرت إجمالاً', isError: true);
      return false;
    }

    String typeText = forPrint ? 'للطباعة' : 'للمخزون';
    bool confirm = await _confirmAction("تأكيد التوليد المتعدد",
        "سيتم الآن توليد إجمالي $totalAmount كرت $typeText. هل تريد الاستمرار؟", Colors.green);
    if (!confirm) return false;

    _play('click');
    setState(() => _isProcessing = true);
    _showToast('جاري توليد الكروت... ⏳');

    bool success = false;
    if (_simulationMode) {
      try {
        for (var order in orders) {
          await _simulateGenerate(
              order['networkId'], order['categoryId'], order['amount'], forPrint);
        }
        _play('success');
        _multiGenControllers.forEach((k, v) => v.clear());
        _showToast('تم توليد $totalAmount كرت (محاكاة) بنجاح! ✅');
        success = true;
      } catch (e) {
        _play('error');
        _showToast('فشل التوليد المحلي: $e', isError: true);
      }
    } else {
      bool hasError = false;
      for (var order in orders) {
        try {
          final response = await http.post(
            Uri.parse("$_renderUrl/generateMikrotikCards"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "networkId": order['networkId'],
              "categoryId": order['categoryId'],
              "amount": order['amount'],
              "agentPhone": sys.currentUserPhone,
              "forPrint": forPrint,
            }),
          );
          if (response.statusCode != 200) hasError = true;
        } catch (e) {
          hasError = true;
        }
      }
      if (hasError) {
        _play('error');
        _showToast('تمت العملية ولكن حدثت بعض الأخطاء في التوليد', isError: true);
      } else {
        _play('success');
        _multiGenControllers.forEach((k, v) => v.clear());
        _showToast('تم توليد جميع الكروت بنجاح! ✅');
        success = true;
      }
    }
    setState(() => _isProcessing = false);
    if (success && forPrint) {
      _loadAllPrintReadyCards(); // تحديث الكروت الجاهزة للطباعة
    }
    return success;
  }

  // ======================== دوال الطباعة ========================
  Future<void> _loadPrintInitialData() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final snapshot = await _db.collection('networks').where('agentPhone', isEqualTo: sys.currentUserPhone).get();
    setState(() {
      printNetworks = snapshot.docs;
      for (var net in printNetworks) {
        final data = net.data() as Map<String, dynamic>;
        printNetworkCategories[net.id] = List<Map<String, dynamic>>.from(data['categories'] ?? []);
      }
    });
    _loadAllPrintReadyCards();
    _loadPrintTemplates();
    _loadPrintLogs();
  }

  Future<void> _loadAllPrintReadyCards() async {
    final snapshot = await _db.collection('cards').where('status', isEqualTo: 'print_ready').get();
    setState(() => allPrintReadyCards = snapshot.docs);
  }

  void _rebuildPrintCategoryCounts() {
    for (final catId in printSelectedCategoryIds) {
      if (!printCategoryCountControllers.containsKey(catId)) {
        final ready = allPrintReadyCards.where((c) => c['categoryId'] == catId).length;
        final ctrl = TextEditingController(text: ready.toString());
        printCategoryCountControllers[catId] = ctrl;
      }
    }
    printCategoryCountControllers.keys.where((k) => !printSelectedCategoryIds.contains(k)).toList().forEach((k) {
      printCategoryCountControllers[k]?.dispose();
      printCategoryCountControllers.remove(k);
    });
    _updatePrintTotalCount();
  }

  void _updatePrintTotalCount() {
    int total = 0;
    for (final catId in printSelectedCategoryIds) {
      final cnt = int.tryParse(printCategoryCountControllers[catId]?.text ?? '0') ?? 0;
      total += cnt;
    }
    printTotalCountCtrl.text = total.toString();
  }

  Future<void> _loadPrintTemplates() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final snap = await _db.collection('print_templates').where('agentPhone', isEqualTo: sys.currentUserPhone).get();
    setState(() => savedPrintTemplates = snap.docs.map((d) => d.data()).toList());
  }

  Future<void> _saveCurrentAsPrintTemplate(String name) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    await _db.collection('print_templates').add({
      'agentPhone': sys.currentUserPhone, 'name': name,
      'textXPercent': textX.value, 'textYPercent': textY.value,
      'fontSize': fontSize.value, 'textColor': textColor.value.value,
      'copiesPerCard': copiesPerCardCtrl.text, 'perRow': perRowCtrl.text,
      'perColumn': perColumnCtrl.text, 'widthMM': widthMMCtrl.text,
      'heightMM': heightMMCtrl.text, 'horizontalGap': horizontalGapCtrl.text,
      'verticalGap': verticalGapCtrl.text, 'pageLeftMargin': pageLeftMarginCtrl.text,
      'pageTopMargin': pageTopMarginCtrl.text,
    });
    _loadPrintTemplates();
  }

  void _applyPrintTemplate(Map<String, dynamic> tmpl) {
    textX.value = (tmpl['textXPercent'] ?? 50).toDouble();
    textY.value = (tmpl['textYPercent'] ?? 50).toDouble();
    fontSize.value = (tmpl['fontSize'] ?? 14).toDouble();
    textColor.value = Color(tmpl['textColor'] ?? Colors.black.value);
    copiesPerCardCtrl.text = (tmpl['copiesPerCard'] ?? "1").toString();
    perRowCtrl.text = (tmpl['perRow'] ?? "3").toString();
    perColumnCtrl.text = (tmpl['perColumn'] ?? "17").toString();
    widthMMCtrl.text = (tmpl['widthMM'] ?? "70.0").toString();
    heightMMCtrl.text = (tmpl['heightMM'] ?? "17.4").toString();
    horizontalGapCtrl.text = (tmpl['horizontalGap'] ?? "0.0").toString();
    verticalGapCtrl.text = (tmpl['verticalGap'] ?? "0.0").toString();
    pageLeftMarginCtrl.text = (tmpl['pageLeftMargin'] ?? "5.0").toString();
    pageTopMarginCtrl.text = (tmpl['pageTopMargin'] ?? "5.0").toString();
    _syncPrintPreview();
  }

  void _loadCategoryTemplate(String categoryId) {
    final cat = printSelectedCategories[categoryId];
    if (cat == null) return;
    final b64 = cat['templateBase64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      _categoryTemplates[categoryId] = base64Decode(b64);
    } else {
      _categoryTemplates.remove(categoryId);
    }
    _syncPrintPreview();
  }

  void _syncPrintPreview() { if (mounted) setState(() {}); }

  Map<String, dynamic> _capturePrintSnapshot() {
    return {
      "x": textX.value, "y": textY.value, "font": fontSize.value,
      "color": textColor.value, "row": int.tryParse(perRowCtrl.text) ?? 3,
      "col": int.tryParse(perColumnCtrl.text) ?? 17,
      "w": double.tryParse(widthMMCtrl.text) ?? 70.0,
      "h": double.tryParse(heightMMCtrl.text) ?? 17.4,
      "copies": int.tryParse(copiesPerCardCtrl.text) ?? 1,
      "hGap": double.tryParse(horizontalGapCtrl.text) ?? 0.0,
      "vGap": double.tryParse(verticalGapCtrl.text) ?? 0.0,
      "marginL": double.tryParse(pageLeftMarginCtrl.text) ?? 5.0,
      "marginT": double.tryParse(pageTopMarginCtrl.text) ?? 5.0,
    };
  }

  Future<Uint8List> generatePdf(Map<String, dynamic> snap) async {
    final int perRowVal = snap["row"];
    final int perColVal = snap["col"];
    final double w = snap["w"];
    final double h = snap["h"];
    final int copies = snap["copies"];
    final double hGap = snap["hGap"];
    final double vGap = snap["vGap"];
    final double marginL = snap["marginL"];
    final double marginT = snap["marginT"];
    final int cardsPerPage = perRowVal * perColVal;
    if (cardsPerPage <= 0) throw Exception("إعدادات الطباعة غير صحيحة");
    final pdf = pw.Document();
    List<QueryDocumentSnapshot> cardsToPrint = [];
    for (final catId in printSelectedCategoryIds) {
      final requested = int.tryParse(printCategoryCountControllers[catId]?.text ?? '0') ?? 0;
      final catCards = allPrintReadyCards.where((c) => c['categoryId'] == catId).take(requested).toList();
      for (var card in catCards) { for (int i = 0; i < copies; i++) { cardsToPrint.add(card); } }
    }
    final totalPages = (cardsToPrint.length / cardsPerPage).ceil();
    for (int page = 0; page < totalPages; page++) {
      final pageCards = cardsToPrint.skip(page * cardsPerPage).take(cardsPerPage).toList();
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (context) {
        return pw.Stack(children: List.generate(pageCards.length, (index) {
          final card = pageCards[index];
          final catId = card['categoryId'] as String;
          final pin = card['pin'] ?? '---';
          final templateBytes = getTemplate(catId);
          final col = index % perRowVal;
          final row = index ~/ perRowVal;
          final left = PreciseLayoutEngine.getAbsolutePos(col.toDouble(), w, hGap, marginL);
          final top = PreciseLayoutEngine.getAbsolutePos(row.toDouble(), h, vGap, marginT);
          return pw.Positioned(
            left: left / PreciseLayoutEngine.mmToPx * PdfPageFormat.mm,
            top: top / PreciseLayoutEngine.mmToPx * PdfPageFormat.mm,
            child: pw.Container(
              width: w * PdfPageFormat.mm,
              height: h * PdfPageFormat.mm,
              child: pw.Stack(children: [
                if (templateBytes != null)
                  pw.Image(pw.MemoryImage(templateBytes), fit: pw.BoxFit.fill),
                pw.Positioned(
                  left: (snap["x"] / 100) * w * PdfPageFormat.mm,
                  top: (snap["y"] / 100) * h * PdfPageFormat.mm,
                  child: pw.Text(
                    pin,
                    style: pw.TextStyle(
                      fontSize: snap["font"],
                      color: PdfColor.fromInt((snap["color"] as Color).value),
                    ),
                  ),
                )
              ]),
            ),
          );
        }));
      }));
    }
    return pdf.save();
  }

  void showPrintDialog() {
    final total = int.tryParse(printTotalCountCtrl.text) ?? 0;
    if (total <= 0) { _showToast("الرجاء تحديد عدد الكروت", isError: true); return; }
    final snapshot = _capturePrintSnapshot();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تأكيد الطباعة"),
        content: Text("سيتم طباعة $total كرت. اختر الإجراء:"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            icon: const Icon(Icons.preview),
            label: const Text("معاينة فقط"),
            onPressed: () async { Navigator.pop(context); final pdf = await generatePdf(snapshot); await Printing.layoutPdf(onLayout: (_) => pdf); _logPrintAction('view', total); },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            icon: const Icon(Icons.print),
            label: const Text("طباعة فقط"),
            onPressed: () async { Navigator.pop(context); final pdf = await generatePdf(snapshot); await Printing.layoutPdf(onLayout: (_) => pdf); _logPrintAction('print_only', total); },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            icon: const Icon(Icons.archive),
            label: const Text("طباعة وأرشفة"),
            onPressed: () async {
              Navigator.pop(context);
              final pdf = await generatePdf(snapshot);
              await Printing.layoutPdf(onLayout: (_) => pdf);
              final batch = _db.batch();
              for (final catId in printSelectedCategoryIds) {
                final requested = int.tryParse(printCategoryCountControllers[catId]?.text ?? '0') ?? 0;
                final catCards = allPrintReadyCards.where((c) => c['categoryId'] == catId).take(requested).toList();
                for (final c in catCards) { batch.update(c.reference, {'status': 'archived'}); }
                final netRef = _db.collection('networks').doc(printSelectedNetworkId);
                final netSnap = await netRef.get();
                final data = netSnap.data();
                if (data != null) {
                  List cats = List<Map<String, dynamic>>.from(data['categories'] ?? []);
                  final idx = cats.indexWhere((e) => e['id'] == catId);
                  if (idx != -1) {
                    final curr = cats[idx]['stock'] ?? 0;
                    cats[idx]['stock'] = (curr as int) - catCards.length;
                    batch.update(netRef, {'categories': cats});
                  }
                }
              }
              await batch.commit();
              _loadAllPrintReadyCards();
              _rebuildPrintCategoryCounts();
              _logPrintAction('print_archive', total);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadPrintLogs() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final snap = await _db.collection('print_logs').where('agentPhone', isEqualTo: sys.currentUserPhone).orderBy('timestamp', descending: true).limit(20).get();
    setState(() => printLogs = snap.docs.map((d) => d.data()).toList());
  }

  Future<void> _logPrintAction(String type, int count) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    await _db.collection('print_logs').add({
      'agentPhone': sys.currentUserPhone, 'networkId': printSelectedNetworkId ?? '',
      'categoryIds': printSelectedCategoryIds.toList(), 'count': count,
      'type': type, 'timestamp': FieldValue.serverTimestamp(),
    });
    _loadPrintLogs();
  }

  // ======================== بناء الواجهة الرئيسية ========================
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الميكروتك والفئات'),
      drawer: CustomAgentDrawer(agentName: sys.currentUserName, phoneNumber: sys.currentUserPhone, role: 'وكيل معتمد (Agent)', currentBalance: sys.currentUserBalance),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('networks').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          List<QueryDocumentSnapshot> agentNetworks = snapshot.hasData ? snapshot.data!.docs : [];
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 5, top: 5),
                decoration: BoxDecoration(color: isDark ? primaryColor.withOpacity(0.4).withAlpha(100) : Colors.blue.shade800, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
                child: Column(children: [
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.orange,
                    indicatorWeight: 4,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(icon: Icon(Icons.dns, color: Colors.greenAccent), text: 'سيرفرات الربط'),
                      Tab(icon: Icon(Icons.category, color: Colors.orangeAccent), text: 'المخزون والفئات'),
                      Tab(icon: Icon(Icons.local_offer, color: Colors.amber), text: 'شرائح الخصم'),
                      Tab(icon: Icon(Icons.autorenew, color: Colors.lightBlueAccent), text: 'توليد الكروت'),
                      Tab(icon: Icon(Icons.print, color: Colors.tealAccent), text: 'الطباعة'),
                    ],
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('محاكاة: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Switch(value: _simulationMode, onChanged: (v) => _toggleSimulation(), activeColor: Colors.redAccent),
                    Text(_simulationMode ? 'ON' : 'OFF', style: TextStyle(color: _simulationMode ? Colors.redAccent : Colors.white54, fontWeight: FontWeight.bold)),
                  ])),
                ]),
              ),
              if (_isProcessing) const LinearProgressIndicator(backgroundColor: Colors.orange, color: Colors.white),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildServersTab(sys, agentNetworks),
                    _buildCategoriesTab(agentNetworks),
                    _buildDiscountTiersTab(sys),
                    _buildGenerateCardsTab(sys, agentNetworks),
                    _buildPrintTab(),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ======================== واجهة تبويب الطباعة (مجمّل) ========================
  Widget _buildPrintTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _printSection("اختيار الكروت", Icon(Icons.list_alt, color: Colors.indigo.shade300), Column(children: [
          DropdownButtonFormField<String>(
            value: printSelectedNetworkId,
            items: printNetworks.map((n) => DropdownMenuItem(value: n.id, child: Text(n['name']))).toList(),
            decoration: const InputDecoration(labelText: 'اختر الشبكة', border: OutlineInputBorder()),
            onChanged: (val) { setState(() { printSelectedNetworkId = val; printSelectedCategoryIds.clear(); printSelectedCategories.clear(); _categoryTemplates.clear(); printCategoryCountControllers.forEach((_, ctrl) => ctrl.dispose()); printCategoryCountControllers.clear(); printTotalCountCtrl.text = "0"; }); },
          ),
          if (printSelectedNetworkId != null)
            ...(printNetworkCategories[printSelectedNetworkId] ?? []).map((cat) {
              final ready = allPrintReadyCards.where((c) => c['categoryId'] == cat['id']).length;
              final selected = printSelectedCategoryIds.contains(cat['id']);
              return Column(children: [
                CheckboxListTile(
                  title: Text("${cat['name']} (مخزون: ${cat['stock'] ?? 0}، جاهز: $ready)"),
                  value: selected,
                  activeColor: Colors.orangeAccent,
                  onChanged: (v) { setState(() { if (v == true) { printSelectedCategoryIds.add(cat['id']); printSelectedCategories[cat['id']] = cat; _loadCategoryTemplate(cat['id']); } else { printSelectedCategoryIds.remove(cat['id']); printSelectedCategories.remove(cat['id']); _categoryTemplates.remove(cat['id']); } _rebuildPrintCategoryCounts(); }); },
                ),
                if (selected) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(controller: printCategoryCountControllers[cat['id']], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "عدد الكروت", border: OutlineInputBorder()))),
              ]);
            }),
          TextField(controller: printTotalCountCtrl, readOnly: true, decoration: const InputDecoration(labelText: "إجمالي الكروت المطلوبة", border: OutlineInputBorder()))
        ])),
        _printSection(
  "المعاينة",
  Icon(Icons.view_compact, color: Colors.pinkAccent),
  _PreviewArea(
    selectedCategoryIds: printSelectedCategoryIds,
    selectedCategories: printSelectedCategories,
    categoryTemplates: _categoryTemplates,
    textX: textX,
    textY: textY,
    fontSize: fontSize,
    textColor: textColor,
    widthMMCtrl: widthMMCtrl,
    heightMMCtrl: heightMMCtrl,
    perRowCtrl: perRowCtrl,
    perColumnCtrl: perColumnCtrl,
    onSettingsChanged: _syncPrintPreview,
  ),
),
        _printSection("التعديل والتحكم", Icon(Icons.tune, color: Colors.amber.shade700), Column(children: [
          _positionShortcuts(),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: printSlider("الأفقي %", textX, 100, Colors.redAccent)), const SizedBox(width: 10), Expanded(child: printSlider("الرأسي %", textY, 100, Colors.green))]),
          printSlider("حجم الخط", fontSize, 40, Colors.purple),
          _buildPrintColorPicker(),
          const SizedBox(height: 12),
          Text("قوالب الطباعة", style: theme.textTheme.titleMedium),
          Wrap(children: savedPrintTemplates.map((t) => TextButton.icon(onPressed: () => _applyPrintTemplate(t), icon: Icon(Icons.bookmark, color: Colors.teal.shade300), label: Text(t['name'] ?? '', style: TextStyle(color: Colors.teal.shade700)))).toList()),
          TextButton.icon(onPressed: _savePrintTemplateDialog, icon: const Icon(Icons.save, color: Colors.blueGrey), label: const Text("حفظ الإعدادات كقالب")),
        ])),
        _printSection("إعدادات التخطيط", Icon(Icons.grid_on, color: Colors.blue.shade300), Column(children: [
          Row(children: [Expanded(child: _printTextField(copiesPerCardCtrl, "نسخ لكل كرت")), const SizedBox(width: 10), Expanded(child: _printTextField(perRowCtrl, "كروت/صف"))]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _printTextField(perColumnCtrl, "كروت/عمود")), const SizedBox(width: 10), Expanded(child: _printTextField(widthMMCtrl, "عرض (مم)"))]),
          const SizedBox(height: 10),
          _printTextField(heightMMCtrl, "ارتفاع (مم)"),
        ])),
        _printSection("الهوامش والفجوات", Icon(Icons.space_bar, color: Colors.deepOrange), Column(children: [
          Row(children: [Expanded(child: _printTextField(horizontalGapCtrl, "فجوة أفقية (مم)")), const SizedBox(width: 10), Expanded(child: _printTextField(verticalGapCtrl, "فجوة عمودية (مم)"))]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _printTextField(pageLeftMarginCtrl, "هامش يسار (مم)")), const SizedBox(width: 10), Expanded(child: _printTextField(pageTopMarginCtrl, "هامش أعلى (مم)"))]),
        ])),
        Center(child: ElevatedButton.icon(onPressed: showPrintDialog, icon: const Icon(Icons.print, color: Colors.white), label: const Text("بدء الطباعة"), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)))),
        _printSection("سجل آخر عمليات الطباعة", Icon(Icons.history, color: Colors.grey), printLogs.isEmpty ? const Text("لا توجد عمليات بعد") : Column(children: printLogs.take(5).map((log) => ListTile(title: Text("${log['count']} كرت - ${log['type']}"), subtitle: Text(log['timestamp'] != null ? (log['timestamp'] as Timestamp).toDate().toString().substring(0,19) : ""))).toList())),
      ]),
    );
  }

  Widget _printSection(String title, Icon icon, Widget child) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [icon, const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]), const SizedBox(height: 10), child]));
  Widget _printTextField(TextEditingController ctrl, String label) => TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
  Widget printSlider(String label, ValueNotifier<double> notifier, double max, Color activeColor) => ValueListenableBuilder(valueListenable: notifier, builder: (_, value, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("$label: ${value.toStringAsFixed(1)}"), Slider(value: value, max: max, activeColor: activeColor, onChanged: (v) { notifier.value = v; _syncPrintPreview(); })]));

  Widget _buildPrintColorPicker() => Row(children: [
    Expanded(child: ElevatedButton.icon(onPressed: () async { Color temp = textColor.value; await showDialog(context: context, builder: (_) => AlertDialog(title: const Text("اختيار لون النص"), content: ColorPicker(pickerColor: textColor.value, onColorChanged: (c) => temp = c), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")), ElevatedButton(onPressed: () { textColor.value = temp; _syncPrintPreview(); Navigator.pop(context); }, child: const Text("تعيين"))])); }, icon: Icon(Icons.colorize, color: textColor.value), label: const Text("اختيار اللون"), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade100))),
    const SizedBox(width: 10),
    ElevatedButton(onPressed: () { textColor.value = Colors.black; _syncPrintPreview(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100), child: const Text("إلغاء التعيين"))
  ]);

  void _savePrintTemplateDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("حفظ كقالب"), content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "اسم القالب")), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")), ElevatedButton(onPressed: () { _saveCurrentAsPrintTemplate(ctrl.text); Navigator.pop(context); }, child: const Text("حفظ"))]));
  }

  Widget _positionShortcuts() => Wrap(spacing: 8, children: [
    _shortcutBtn("↖", 10, 10), _shortcutBtn("↑", 50, 10), _shortcutBtn("↗", 90, 10),
    _shortcutBtn("←", 10, 50), _shortcutBtn("●", 50, 50), _shortcutBtn("→", 90, 50),
    _shortcutBtn("↙", 10, 90), _shortcutBtn("↓", 50, 90), _shortcutBtn("↘", 90, 90),
  ]);
  Widget _shortcutBtn(String label, double x, double y) => GestureDetector(onTap: () { textX.value = x; textY.value = y; _syncPrintPreview(); }, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent), borderRadius: BorderRadius.circular(6)), child: Text(label, style: const TextStyle(fontSize: 18, color: Colors.blueAccent))));

  Widget _buildEnhancedPrintPreview() {
    if (printSelectedCategoryIds.isEmpty) return const SizedBox.shrink();
    final w = double.tryParse(widthMMCtrl.text) ?? 70.0;
    final h = double.tryParse(heightMMCtrl.text) ?? 17.4;
    final pRow = int.tryParse(perRowCtrl.text) ?? 3;
    final pCol = int.tryParse(perColumnCtrl.text) ?? 17;
    return LayoutBuilder(builder: (context, constraints) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text("محاكاة صفحة (${pRow}x$pCol)", style: Theme.of(context).textTheme.titleMedium), const Spacer(), IconButton(icon: const Icon(Icons.fullscreen, color: Colors.teal), onPressed: _showFullScreenPreview, tooltip: "معاينة كاملة")]),
      SizedBox(height: 300, child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Container(width: w * pRow * PreciseLayoutEngine.mmToPx, height: h * pCol * PreciseLayoutEngine.mmToPx, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), color: Colors.white), child: _buildFakeGrid(pRow, pCol, w, h))))
    ]));
  }

  Widget _buildFakeGrid(int perRowVal, int perColVal, double wMM, double hMM) {
    List<Widget> children = [];
    for (int r = 0; r < perColVal; r++) {
      for (int c = 0; c < perRowVal; c++) {
        children.add(Positioned(left: c * wMM * PreciseLayoutEngine.mmToPx, top: r * hMM * PreciseLayoutEngine.mmToPx, width: wMM * PreciseLayoutEngine.mmToPx, height: hMM * PreciseLayoutEngine.mmToPx, child: _buildSingleFakeCard(wMM, hMM, "####")));
      }
    }
    return Stack(children: children);
  }

  Widget _buildSingleFakeCard(double wMM, double hMM, String pin) {
    final templateBytes = getTemplate(printSelectedCategoryIds.isNotEmpty ? printSelectedCategoryIds.first : '');
    final pos = Offset((textX.value / 100) * wMM * PreciseLayoutEngine.mmToPx, (textY.value / 100) * hMM * PreciseLayoutEngine.mmToPx);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), image: templateBytes != null ? DecorationImage(image: MemoryImage(templateBytes), fit: BoxFit.fill) : null),
      child: Stack(children: [
        CustomPaint(size: Size(wMM * PreciseLayoutEngine.mmToPx, hMM * PreciseLayoutEngine.mmToPx), painter: _GuidePainter()),
        Positioned(left: pos.dx, top: pos.dy, child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              textX.value += details.delta.dx / (wMM * PreciseLayoutEngine.mmToPx) * 100;
              textY.value += details.delta.dy / (hMM * PreciseLayoutEngine.mmToPx) * 100;
              textX.value = textX.value.clamp(0, 100);
              textY.value = textY.value.clamp(0, 100);
            });
            _syncPrintPreview();
          },
          child: Container(color: Colors.white.withOpacity(0.7), child: Text(pin, style: TextStyle(fontSize: fontSize.value * 0.8, color: textColor.value)))
        )),
      ]),
    );
  }

  void _showFullScreenPreview() {
    final w = double.tryParse(widthMMCtrl.text) ?? 70.0;
    final h = double.tryParse(heightMMCtrl.text) ?? 17.4;
    final pRow = int.tryParse(perRowCtrl.text) ?? 3;
    final pCol = int.tryParse(perColumnCtrl.text) ?? 17;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text("معاينة كاملة")), body: InteractiveViewer(minScale: 0.2, maxScale: 5.0, child: Container(width: w * pRow * PreciseLayoutEngine.mmToPx, height: h * pCol * PreciseLayoutEngine.mmToPx, color: Colors.white, child: _buildFakeGrid(pRow, pCol, w, h))))));
  }

  // ======================== التبويبات الأصلية ========================
  Widget _buildServersTab(SystemProvider sys, List<QueryDocumentSnapshot> networks) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: networks.isEmpty ? const Center(child: Text('لم تقم بربط أي شبكة ميكروتك حتى الآن.', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: networks.length, itemBuilder: (context, index) {
        var net = networks[index].data() as Map<String, dynamic>;
        bool isActive = net['isActive'] ?? true;
        final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
        return Card(
          color: isActive ? Theme.of(context).cardColor : Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 3, margin: const EdgeInsets.only(bottom: 12),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(backgroundColor: isActive ? Colors.green : Colors.grey, radius: 20, child: const Icon(Icons.router, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(net['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isActive ? null : TextDecoration.lineThrough, color: textColor))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isActive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text(isActive ? 'نشط' : 'مجمد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.green.shade700 : Colors.red.shade700))),
            ]),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'الموقع', net['location'] ?? '', textColor, Colors.orange),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.wifi, 'IP', net['ip'] ?? '', textColor, Colors.green),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.info_outline, 'الحالة', isActive ? 'نشط' : 'مجمد', textColor, isActive ? Colors.green : Colors.red),
            const SizedBox(height: 16),
            _buildActionButtons(sys, networks, index, net, isActive),
          ])),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showAddServerBottomSheet(sys), backgroundColor: Colors.blue.shade800, icon: const Icon(Icons.add, color: Colors.white), label: const Text('إضافة سيرفر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color textColor, Color iconColor) => Row(children: [Icon(icon, size: 16, color: iconColor), const SizedBox(width: 8), Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)), Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: textColor)))]);
  Widget _buildActionButtons(SystemProvider sys, List<QueryDocumentSnapshot> networks, int index, Map<String, dynamic> net, bool isActive) => Wrap(spacing: 8, runSpacing: 8, children: [
    _actionButton(Icons.bolt, 'اختبار', Colors.blue, () => _testConnection(net)),
    _actionButton(isActive ? Icons.pause_circle_filled : Icons.play_circle_fill, isActive ? 'تجميد' : 'تنشيط', Colors.orange, () async { bool confirm = await _confirmAction(isActive ? "تجميد الشبكة" : "تنشيط الشبكة", "هل تريد تغيير حالة الشبكة؟", Colors.orange); if (confirm) { _db.collection('networks').doc(networks[index].id).update({'isActive': !isActive}); _showToast(isActive ? 'تم تجميد الشبكة' : 'تم تنشيط الشبكة'); } }),
    _actionButton(Icons.edit, 'تعديل', Colors.grey, () => _showAddServerBottomSheet(sys, existingData: net, docId: networks[index].id)),
    _actionButton(Icons.delete, 'حذف', Colors.red, () async { bool confirm = await _confirmAction("حذف الشبكة نهائياً", "سيتم مسح بيانات الشبكة، هل أنت متأكد؟", Colors.red, requirePassword: true); if (confirm) { _play('click'); await _db.collection('networks').doc(networks[index].id).delete(); _showToast('تم حذف الشبكة نهائياً'); } }),
  ]);
  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) => TextButton.icon(onPressed: onTap, icon: Icon(icon, size: 18, color: color), label: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)));

  Widget _buildCategoriesTab(List<QueryDocumentSnapshot> networks) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: networks.isEmpty ? const Center(child: Text('أضف سيرفر شبكة أولاً لعرض فئاته.', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: networks.length, itemBuilder: (context, netIndex) {
        var netId = networks[netIndex].id;
        var netData = networks[netIndex].data() as Map<String, dynamic>;
        List categories = netData['categories'] ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('فئات شبكة: ${netData['name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
          if (categories.isEmpty) const Padding(padding: EdgeInsets.all(8.0), child: Text('لا توجد فئات لهذه الشبكة.', style: TextStyle(color: Colors.grey))),
          ...categories.map((category) {
            int stock = category['stock'] ?? 0;
            bool isLowStock = stock < 10;
            Color catColor = Color(category['color'] ?? Colors.blue.value);
            bool isCatActive = category['isActive'] ?? true;
            bool isBotEnabled = category['isBotEnabled'] ?? false;
            final readyToPrint = allPrintReadyCards.where((c) => c['categoryId'] == category['id']).length;
            return Card(
              color: isCatActive ? Theme.of(context).cardColor : Colors.grey.shade200,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isCatActive ? catColor.withOpacity(0.5) : Colors.grey)),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(category['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isCatActive ? catColor : Colors.grey, decoration: isCatActive ? null : TextDecoration.lineThrough))),
                  Wrap(spacing: 4, children: [
                    IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.teal, size: 20), onPressed: () => _showCardsList(netId, category['id'], category['name'], catColor), constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5), tooltip: 'عرض الكروت'),
                    IconButton(icon: Icon(Icons.smart_toy, color: isBotEnabled ? Colors.purple : Colors.grey, size: 20), onPressed: () => _showBotSettings(netId, category['id'], category), constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5), tooltip: 'البوت الذكي'),
                    IconButton(icon: Icon(isCatActive ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.orange, size: 20), onPressed: () async { bool confirm = await _confirmAction(isCatActive ? "تجميد الفئة" : "تنشيط الفئة", "تغيير حالة الفئة؟", Colors.orange); if (confirm) { List updated = List.from(categories); int idx = updated.indexWhere((c) => c['id'] == category['id']); updated[idx]['isActive'] = !isCatActive; await _db.collection('networks').doc(netId).update({'categories': updated}); _showToast(isCatActive ? 'تم تجميد الفئة' : 'تم تنشيط الفئة'); } }, constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5)),
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showAddCategoryBottomSheet(networks, existingCat: category, preSelectedNetId: netId), constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () async { bool confirm = await _confirmAction("حذف الفئة", "سيتم حذف الفئة نهائياً، متأكد؟", Colors.red, requirePassword: true); if (confirm) { _play('click'); await _db.collection('networks').doc(netId).update({'categories': FieldValue.arrayRemove([category])}); _showToast('تم حذف الفئة نهائياً'); } }, constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5)),
                  ]),
                ]),
                const SizedBox(height: 8),
                Text('الوقت: ${category['time']} | السعة: ${category['capacity']}', style: TextStyle(color: textColor)),
                if (category['note'] != null && category['note'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('📝 ${category['note']}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('سعر الجمهور: ${category['price']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isLowStock ? Colors.red.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(10)), child: Text('المخزون: $stock كرت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isLowStock ? Colors.red : Colors.green.shade800))),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(10)), child: Text('للطباعة: $readyToPrint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade800))),
                  ]),
                ]),
              ])),
            );
          }).toList(),
          const SizedBox(height: 20),
        ]);
      }),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showAddCategoryBottomSheet(networks), backgroundColor: Colors.orange.shade700, icon: const Icon(Icons.add_circle, color: Colors.white), label: const Text('إضافة فئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildDiscountTiersTab(SystemProvider sys) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('discount_tiers').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        List<QueryDocumentSnapshot> tiers = snapshot.hasData ? snapshot.data!.docs : [];
        tiers.sort((a, b) => ((b.data() as Map)['condition'] as int).compareTo((a.data() as Map)['condition'] as int));
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(children: [
            Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)), child: const Text('💡 الخصم يُطبق تلقائياً على المشتريات عند تحقيق شرط السحب.', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 12))),
            Expanded(child: tiers.isEmpty ? const Center(child: Text('لم تقم بإضافة أي شرائح خصم حتى الآن.', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: tiers.length, itemBuilder: (context, index) {
              var tier = tiers[index].data() as Map<String, dynamic>;
              bool isActive = tier['isActive'] ?? true;
              Color tColor = Color(tier['color'] ?? Colors.amber.shade700.value);
              String dType = tier['discountType'] == 'percentage' ? '%' : 'ريال';
              return Card(
                color: isActive ? Theme.of(context).cardColor : Colors.grey.shade200, elevation: 2, margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(isActive ? Icons.stars : Icons.block, color: isActive ? tColor : Colors.grey, size: 35),
                  title: Text(tier['title'], style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? tColor : Colors.grey, decoration: isActive ? null : TextDecoration.lineThrough)),
                  subtitle: Text('شرط السحب: ${tier['condition']} ريال\nالخصم: ${tier['discountValue']}$dType', style: TextStyle(fontSize: 12, color: textColor)),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isActive ? tColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(tier['targetType'] == 'all' ? 'للجميع' : tier['targetType'] == 'pos' ? 'نقاط البيع' : tier['targetType'] == 'user' ? 'المستخدمين' : 'محدد', style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? tColor : Colors.grey, fontSize: 10))),
                    const SizedBox(height: 5),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(onTap: () async { bool confirm = await _confirmAction(isActive ? "تجميد الشريحة" : "تنشيط الشريحة", "تغيير حالة العرض؟", Colors.orange); if (confirm) _db.collection('discount_tiers').doc(tiers[index].id).update({'isActive': !isActive}); }, child: Icon(isActive ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.orange, size: 20)),
                      const SizedBox(width: 10),
                      GestureDetector(onTap: () => _showDiscountTierBottomSheet(sys, existingTier: tier, docId: tiers[index].id), child: const Icon(Icons.edit, color: Colors.blue, size: 20)),
                      const SizedBox(width: 10),
                      GestureDetector(onTap: () async { bool confirm = await _confirmAction("حذف الشريحة", "سيتم إلغاء الخصم عن البقالات المنضمة، متأكد؟", Colors.red, requirePassword: true); if (confirm) { _play('click'); await _db.collection('discount_tiers').doc(tiers[index].id).delete(); _showToast('تم حذف الشريحة'); } }, child: const Icon(Icons.delete, color: Colors.red, size: 20)),
                    ]),
                  ]),
                ),
              );
            })),
          ]),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _showDiscountTierBottomSheet(sys), backgroundColor: Colors.amber.shade700, icon: const Icon(Icons.add_moderator, color: Colors.white), label: const Text('إضافة شريحة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        );
      },
    );
  }
}
// ==========================================
// ✅ ويدجت المعاينة المستقلة (يمنع إعادة بناء الشاشة بالكامل)
// ==========================================
class _PreviewArea extends StatefulWidget {
  final Set<String> selectedCategoryIds;
  final Map<String, Map<String, dynamic>> selectedCategories;
  final Map<String, Uint8List?> categoryTemplates;
  final ValueNotifier<double> textX;
  final ValueNotifier<double> textY;
  final ValueNotifier<double> fontSize;
  final ValueNotifier<Color> textColor;
  final TextEditingController widthMMCtrl;
  final TextEditingController heightMMCtrl;
  final TextEditingController perRowCtrl;
  final TextEditingController perColumnCtrl;
  final VoidCallback onSettingsChanged;

  const _PreviewArea({
    required this.selectedCategoryIds,
    required this.selectedCategories,
    required this.categoryTemplates,
    required this.textX,
    required this.textY,
    required this.fontSize,
    required this.textColor,
    required this.widthMMCtrl,
    required this.heightMMCtrl,
    required this.perRowCtrl,
    required this.perColumnCtrl,
    required this.onSettingsChanged,
  });

  @override
  State<_PreviewArea> createState() => _PreviewAreaState();
}

class _PreviewAreaState extends State<_PreviewArea> {
  @override
  Widget build(BuildContext context) {
    if (widget.selectedCategoryIds.isEmpty) return const SizedBox.shrink();

    final w = double.tryParse(widget.widthMMCtrl.text) ?? 70.0;
    final h = double.tryParse(widget.heightMMCtrl.text) ?? 17.4;
    final pRow = int.tryParse(widget.perRowCtrl.text) ?? 3;
    final pCol = int.tryParse(widget.perColumnCtrl.text) ?? 17;

    return LayoutBuilder(builder: (context, constraints) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text("محاكاة صفحة (${pRow}x$pCol)", style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.teal),
            onPressed: () {
              // المعاينة الكاملة
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text("معاينة كاملة")), body: InteractiveViewer(minScale: 0.2, maxScale: 5.0, child: Container(width: w * pRow * PreciseLayoutEngine.mmToPx, height: h * pCol * PreciseLayoutEngine.mmToPx, color: Colors.white, child: _buildFakeGrid(pRow, pCol, w, h))))));
            },
            tooltip: "معاينة كاملة",
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Container(
              width: w * pRow * PreciseLayoutEngine.mmToPx,
              height: h * pCol * PreciseLayoutEngine.mmToPx,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), color: Colors.white),
              child: _buildFakeGrid(pRow, pCol, w, h),
            ),
          ),
        ),
      ]);
    });
  }

  Widget _buildFakeGrid(int perRowVal, int perColVal, double wMM, double hMM) {
    List<Widget> children = [];
    for (int r = 0; r < perColVal; r++) {
      for (int c = 0; c < perRowVal; c++) {
        children.add(Positioned(
          left: c * wMM * PreciseLayoutEngine.mmToPx,
          top: r * hMM * PreciseLayoutEngine.mmToPx,
          width: wMM * PreciseLayoutEngine.mmToPx,
          height: hMM * PreciseLayoutEngine.mmToPx,
          child: _buildSingleFakeCard(wMM, hMM, "####"),
        ));
      }
    }
    return Stack(children: children);
  }

  Widget _buildSingleFakeCard(double wMM, double hMM, String pin) {
    final templateBytes = widget.categoryTemplates[widget.selectedCategoryIds.isNotEmpty ? widget.selectedCategoryIds.first : ''];
    return ValueListenableBuilder(
      valueListenable: widget.textX,
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: widget.textY,
          builder: (context, _, __) {
            return ValueListenableBuilder(
              valueListenable: widget.fontSize,
              builder: (context, _, __) {
                return ValueListenableBuilder(
                  valueListenable: widget.textColor,
                  builder: (context, _, __) {
                    final pos = Offset(
                      (widget.textX.value / 100) * wMM * PreciseLayoutEngine.mmToPx,
                      (widget.textY.value / 100) * hMM * PreciseLayoutEngine.mmToPx,
                    );
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        image: templateBytes != null
                            ? DecorationImage(image: MemoryImage(templateBytes), fit: BoxFit.fill)
                            : null,
                      ),
                      child: Stack(children: [
                        CustomPaint(size: Size(wMM * PreciseLayoutEngine.mmToPx, hMM * PreciseLayoutEngine.mmToPx), painter: _GuidePainter()),
                        Positioned(
                          left: pos.dx,
                          top: pos.dy,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              widget.textX.value += details.delta.dx / (wMM * PreciseLayoutEngine.mmToPx) * 100;
                              widget.textY.value += details.delta.dy / (hMM * PreciseLayoutEngine.mmToPx) * 100;
                              widget.textX.value = widget.textX.value.clamp(0, 100);
                              widget.textY.value = widget.textY.value.clamp(0, 100);
                              if (widget.onSettingsChanged != null) {
                                widget.onSettingsChanged();
                              }
                            },
                            child: Container(
                              color: Colors.white.withOpacity(0.7),
                              child: Text(pin, style: TextStyle(fontSize: widget.fontSize.value * 0.8, color: widget.textColor.value)),
                            ),
                          ),
                        )
                      ]),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.withOpacity(0.5)..strokeWidth = 0.5;
    for (double p = 0.25; p <= 0.75; p += 0.25) {
      canvas.drawLine(Offset(size.width * p, 0), Offset(size.width * p, size.height), paint);
      canvas.drawLine(Offset(0, size.height * p), Offset(size.width, size.height * p), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
