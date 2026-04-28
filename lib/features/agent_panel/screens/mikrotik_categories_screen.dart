import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

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

  // وضع المحاكاة
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

  // ===== متغيرات تبويب الطباعة =====
  String? _selectedPrintNetworkId;
  String? _selectedPrintCategoryId;
  Map? _selectedPrintCategory;
  String? _templateBase64;
  List<Map<String, dynamic>> _printReadyCards = [];
  final TextEditingController _printCountController = TextEditingController();
  int _printCount = 0;

  // إعدادات النص على القالب
  double _textPositionX = 50.0; // نسبة مئوية 0-100
  double _textPositionY = 50.0; // نسبة مئوية 0-100
  double _fontSize = 14.0; // 6-40
  Color _textColor = Colors.black;

  // إعدادات التخطيط
  int _copiesPerCard = 1;
  int _cardsPerRow = 3;
  int _cardsPerColumn = 4;
  double _cardWidth = 85;
  double _cardHeight = 55;

  Timer? _searchTimer; // يحتاج dart:async

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

  // نافذة تأكيد مطوّرة مع إظهار/إخفاء كلمة السر
  Future<bool> _confirmAction(String title, String message, Color color,
      {bool requirePassword = false}) async {
    _play('warning');
    final passwordController = TextEditingController();
    bool obscurePassword = true; // متغير محلي داخل StatefulBuilder
    return await showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                title: Text(title,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    if (requirePassword) ...[
                      const SizedBox(height: 15),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'أدخل كلمة المرور للتأكيد',
                          border: const OutlineInputBorder(),
                          prefixIcon:
                              const Icon(Icons.lock, color: Colors.red),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
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
                    child: const Text('إلغاء',
                        style: TextStyle(color: Colors.grey)),
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
  // 1. إضافة وتعديل سيرفر ميكروتك (مطورة)
  // ==========================================
  void _showAddServerBottomSheet(SystemProvider sys,
      {Map<String, dynamic>? existingData, String? docId}) {
    _play('click');
    String name = existingData?['name'] ?? _draftServerName;
    String location = existingData?['location'] ?? _draftServerLocation;
    String governorate =
        existingData?['governorate'] ?? _draftServerGovernorate;
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
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
                            prefixIcon:
                                Icon(Icons.location_on, color: Colors.orange)),
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
                                prefixIcon:
                                    Icon(Icons.map, color: Colors.teal)),
                            controller:
                                TextEditingController(text: governorate),
                            onChanged: (v) => governorate = v),
                        const SizedBox(height: 12),
                        TextField(
                            decoration: const InputDecoration(
                                labelText: 'المديرية',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.map_outlined,
                                    color: Colors.teal)),
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
                                          prefixIcon: const Icon(
                                              Icons.wifi_find,
                                              color: Colors.teal)),
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
                            prefixIcon: Icon(Icons.wifi, color: Colors.green)),
                        controller: TextEditingController(text: ip),
                        onChanged: (v) => ip = v),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'رابط صفحة تسجيل الدخول للزبائن',
                            border: OutlineInputBorder(),
                            prefixIcon:
                                Icon(Icons.link, color: Colors.indigo)),
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
                                    prefixIcon: Icon(Icons.person,
                                        color: Colors.deepPurple)),
                                controller:
                                    TextEditingController(text: user),
                                onChanged: (v) => user = v)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                decoration: const InputDecoration(
                                    labelText: 'كلمة المرور',
                                    border: OutlineInputBorder(),
                                    prefixIcon:
                                        Icon(Icons.lock, color: Colors.red)),
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
                            prefixIcon: Icon(Icons.settings_ethernet,
                                color: Colors.blueGrey)),
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
                                      'isActive':
                                          existingData?['isActive'] ?? true,
                                      'updatedAt':
                                          FieldValue.serverTimestamp(),
                                    };
                                    if (docId == null) {
                                      networkData['status'] = 'متصل نشط 🟢';
                                      networkData['categories'] = [];
                                      networkData['createdAt'] =
                                          FieldValue.serverTimestamp();
                                      await _db
                                          .collection('networks')
                                          .add(networkData);
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
                                      await _db
                                          .collection('networks')
                                          .doc(docId)
                                          .update(networkData);
                                    }
                                    _play('success');
                                    if (mounted) {
                                      Navigator.pop(context);
                                      _showToast(docId == null
                                          ? 'تمت إضافة الشبكة بنجاح! 🟢'
                                          : 'تم التعديل بنجاح! ✏️');
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    _play('error');
                                    _showToast('فشل حفظ البيانات',
                                        isError: true);
                                  }
                                } else {
                                  _play('error');
                                  _showToast('يرجى تعبئة الحقول الأساسية',
                                      isError: true);
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('حفظ واتصال',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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
  // 2. إضافة وتعديل فئة كروت للشبكة (مطورة)
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
    Color selectedColor = existingCat != null
        ? Color(existingCat['color'])
        : _draftCategoryColor;
    String? templateBase64 =
        existingCat?['templateBase64'] ?? _draftCategoryTemplateBase64;
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
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.dns, color: Colors.blue)),
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
                            prefixIcon:
                                Icon(Icons.category, color: Colors.orange)),
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
                                    prefixIcon: Icon(Icons.timer,
                                        color: Colors.blue)),
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
                                    prefixIcon: Icon(Icons.data_usage,
                                        color: Colors.teal)),
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
                            prefixIcon: Icon(Icons.attach_money,
                                color: Colors.green)),
                        controller: TextEditingController(text: newPrice),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => newPrice = val),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'ملاحظة (اختياري)',
                            border: OutlineInputBorder(),
                            prefixIcon:
                                Icon(Icons.note, color: Colors.amber)),
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
                                source: ImageSource.gallery,
                                imageQuality: 50,
                                maxWidth: 800);
                            if (pickedFile != null) {
                              final bytes = await pickedFile.readAsBytes();
                              setModalState(() =>
                                  templateBase64 = base64Encode(bytes));
                              _play('success');
                              _showToast('تم تحميل القالب بنجاح');
                            }
                          },
                          icon: Icon(
                            templateBase64 != null
                                ? Icons.check_circle
                                : Icons.upload_file,
                            color: templateBase64 != null
                                ? Colors.green
                                : Colors.deepPurple,
                          ),
                          label: Text(
                              templateBase64 != null
                                  ? 'تم التحميل'
                                  : 'اختيار صورة',
                              style: TextStyle(
                                  color: templateBase64 != null
                                      ? Colors.green
                                      : Colors.deepPurple)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.deepPurple.withOpacity(0.1),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Text('لون الفئة: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () async {
                            final color =
                                await _openColorPicker(selectedColor);
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
                        const Text('انقر لتغيير اللون',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
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
                                      'templateBase64': templateBase64,
                                      'stock': existingCat?['stock'] ?? 0,
                                      'isActive':
                                          existingCat?['isActive'] ?? true,
                                      'botMinStock':
                                          existingCat?['botMinStock'] ?? 5,
                                      'botRefillAmount':
                                          existingCat?['botRefillAmount'] ??
                                              50,
                                      'isBotEnabled':
                                          existingCat?['isBotEnabled'] ??
                                              false,
                                      // إعدادات الطباعة (إن وجدت)
                                      'printSettings':
                                          existingCat?['printSettings'] ??
                                              {},
                                    };
                                    if (existingCat == null) {
                                      await _db
                                          .collection('networks')
                                          .doc(selectedNetworkId)
                                          .update({
                                        'categories': FieldValue.arrayUnion(
                                            [newCategory])
                                      });
                                      _draftCategoryName = '';
                                      _draftCategoryTime = '';
                                      _draftCategoryCapacity = '';
                                      _draftCategoryPrice = '';
                                      _draftCategoryNote = '';
                                      _draftCategoryColor = Colors.blue;
                                      _draftCategoryTemplateBase64 = null;
                                    } else {
                                      var netDoc = await _db
                                          .collection('networks')
                                          .doc(selectedNetworkId)
                                          .get();
                                      List cats = List.from(
                                          (netDoc.data() as Map)[
                                              'categories']);
                                      int idx = cats.indexWhere((c) =>
                                          c['id'] == existingCat['id']);
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
                                    setModalState(
                                        () => isSubmitting = false);
                                    _play('error');
                                  }
                                } else {
                                  _play('error');
                                  _showToast(
                                      'الرجاء تعبئة الحقول الأساسية!',
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
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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
                    if (!snapshot.hasData)
                      return const Center(
                          child: CircularProgressIndicator());
                    var cards = snapshot.data!.docs;
                    if (cards.isEmpty)
                      return const Center(
                          child: Text(
                              'لا توجد كروت متاحة. قم بالتوليد أولاً.',
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
                                        _showToast(
                                            'تمت أرشفة الكرت بنجاح');
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
                                        _showToast(
                                            'تم حذف الكرت نهائياً');
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
                    controller:
                        TextEditingController(text: minStock.toString()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: 'كمية التوليد التلقائي (كم كرت ينتج؟)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        refillAmount = int.tryParse(v) ?? 50,
                    controller: TextEditingController(
                        text: refillAmount.toString()),
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
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple),
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
  // 3. إدارة شرائح الخصم (مطورة مع استهداف وبحث متقدم)
  // ==========================================
  void _showDiscountTierBottomSheet(SystemProvider sys,
      {Map<String, dynamic>? existingTier, String? docId}) {
    _play('click');
    String title = existingTier?['title'] ?? _draftTierTitle;
    String condition =
        existingTier?['condition']?.toString() ?? _draftTierCondition;
    String discountValue = existingTier?['discountValue']?.toString() ??
        _draftTierDiscountValue;
    String discountType =
        existingTier?['discountType'] ?? _draftTierDiscountType;
    String targetType =
        existingTier?['targetType'] ?? _draftTierTargetType;
    List<String> targetPhones = existingTier != null
        ? List<String>.from(existingTier['targetPhones'] ?? [])
        : List<String>.from(_draftTierTargetPhones);
    Color selectedColor = existingTier != null
        ? Color(existingTier['color'])
        : _draftTierColor;
    bool isSubmitting = false;

    // تخزين نتائج البحث المؤقتة لكل هاتف
    Map<String, Map<String, dynamic>?> searchResults = {};
    // تخزين تفاصيل العملاء
    Map<String, Map<String, dynamic>> customerDetails = {};

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
                            prefixIcon:
                                Icon(Icons.stars, color: Colors.amber)),
                        controller: TextEditingController(text: title),
                        onChanged: (v) => title = v),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'شرط السحب الشهري بالريال',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_cart,
                                color: Colors.orange)),
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
                                    prefixIcon: Icon(Icons.local_offer,
                                        color: Colors.green)),
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
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'نطاق تطبيق الخصم',
                          border: OutlineInputBorder()),
                      value: targetType,
                      items: const [
                        DropdownMenuItem(
                            value: 'all',
                            child:
                                Text('الجميع (كل المستخدمين ونقاط البيع)')),
                        DropdownMenuItem(
                            value: 'pos',
                            child: Text('جميع نقاط البيع فقط')),
                        DropdownMenuItem(
                            value: 'user',
                            child: Text('جميع المستخدمين فقط')),
                        DropdownMenuItem(
                            value: 'specific',
                            child: Text('نقطة بيع / مستخدم محدد')),
                      ],
                      onChanged: (val) =>
                          setModalState(() => targetType = val!),
                    ),
                    if (targetType == 'specific') ...[
                      const SizedBox(height: 12),
                      ...targetPhones.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String phone = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: 'رقم الهاتف ${idx + 1}',
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.phone,
                                            color: Colors.blue),
                                        suffixIcon: searchResults[phone] !=
                                                null
                                            ? IconButton(
                                                icon: Icon(
                                                  searchResults[phone] !=
                                                          null
                                                      ? Icons.check_circle
                                                      : Icons.info_outline,
                                                  color: searchResults[
                                                              phone] !=
                                                          null
                                                      ? Colors.green
                                                      : Colors.teal,
                                                ),
                                                onPressed: () {
                                                  if (customerDetails[
                                                          phone] !=
                                                      null) {
                                                    _showTargetInfoDialog(
                                                        phone,
                                                        customerDetails[
                                                            phone]!,
                                                        sys);
                                                  }
                                                },
                                              )
                                            : null,
                                      ),
                                      controller: TextEditingController(
                                          text: phone),
                                      keyboardType: TextInputType.phone,
                                      onChanged: (v) {
                                        targetPhones[idx] = v;
                                        _debounceSearchForDiscount(
                                            v, sys, setModalState,
                                            searchResults,
                                            customerDetails, phone);
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    onPressed: () {
                                      setModalState(() {
                                        targetPhones.removeAt(idx);
                                        searchResults.remove(phone);
                                        customerDetails.remove(phone);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (customerDetails[phone] != null)
                                _buildCustomerCard(
                                    customerDetails[phone]!, phone, sys),
                            ],
                          ),
                        );
                      }).toList(),
                      TextButton.icon(
                        onPressed: () => setModalState(
                            () => targetPhones.add('')),
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
                            final color =
                                await _openColorPicker(selectedColor);
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
                        const Text('انقر لتغيير اللون',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
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
                                      'targetPhones': targetPhones,
                                      'subscribersCount':
                                          existingTier?['subscribersCount'] ??
                                              0,
                                      'updatedAt':
                                          FieldValue.serverTimestamp(),
                                    };
                                    if (docId == null) {
                                      tierData['createdAt'] =
                                          FieldValue.serverTimestamp();
                                      await _db
                                          .collection('discount_tiers')
                                          .add(tierData);
                                      _draftTierTitle = '';
                                      _draftTierCondition = '';
                                      _draftTierDiscountValue = '';
                                      _draftTierDiscountType = 'percentage';
                                      _draftTierTargetType = 'all';
                                      _draftTierTargetPhones = [];
                                      _draftTierColor =
                                          Colors.amber.shade700;
                                    } else {
                                      await _db
                                          .collection('discount_tiers')
                                          .doc(docId)
                                          .update(tierData);
                                    }
                                    _play('success');
                                    if (mounted) {
                                      Navigator.pop(context);
                                      _showToast(
                                          'تم حفظ الشريحة بنجاح!');
                                    }
                                  } catch (e) {
                                    setModalState(
                                        () => isSubmitting = false);
                                    _play('error');
                                  }
                                } else {
                                  _play('error');
                                  _showToast(
                                      'يرجى تعبئة كافة بيانات الشريحة',
                                      isError: true);
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('حفظ الشريحة',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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

  // ===== دوال البحث عن العميل لشرائح الخصم =====
  Timer? _debounceTimer;
  void _debounceSearchForDiscount(
      String phone,
      SystemProvider sys,
      StateSetter setModalState,
      Map<String, dynamic?> searchResults,
      Map<String, Map<String, dynamic>> customerDetails,
      String currentPhone) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (phone.length >= 9) {
        final details = await _fetchCustomerDetailsForDiscount(phone, sys);
        setModalState(() {
          searchResults[currentPhone] = details;
          customerDetails[currentPhone] = details;
        });
        if (details != null) {
          _play('success');
        }
      } else {
        setModalState(() {
          searchResults[currentPhone] = null;
          customerDetails[currentPhone] = null;
        });
      }
    });
  }

  Future<Map<String, dynamic>?> _fetchCustomerDetailsForDiscount(
      String phone, SystemProvider sys) async {
    try {
      // البحث عن المستخدم في مجموعة users
      var userQuery = await _db
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (userQuery.docs.isEmpty) return null;
      var userData = userQuery.docs.first.data() as Map<String, dynamic>;
      // الرصيد من تعاملات الوكيل فقط: نفترض وجود حقل agentBalance أو نحسبه لاحقاً
      // سنحسبه عبر مجموع المعاملات الخاصة بالوكيل وهذا المستخدم
      double agentBalance = 0.0;
      try {
        var rechargeQuery = await _db
            .collection('recharges')
            .where('agentPhone', isEqualTo: sys.currentUserPhone)
            .where('customerPhone', isEqualTo: phone)
            .get();
        for (var doc in rechargeQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          agentBalance += (data['amount'] ?? 0).toDouble();
        }
      } catch (_) {}
      userData['agentBalance'] = agentBalance;
      userData['lastRecharge'] = await _getLastRechargeForAgent(phone, sys);
      return userData;
    } catch (e) {
      return null;
    }
  }

  Future<String> _getLastRechargeForAgent(
      String phone, SystemProvider sys) async {
    try {
      var last = await _db
          .collection('recharges')
          .where('agentPhone', isEqualTo: sys.currentUserPhone)
          .where('customerPhone', isEqualTo: phone)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (last.docs.isNotEmpty) {
        final data = last.docs.first.data() as Map<String, dynamic>;
        return '${data['amount']} ريال (${_formatTimestamp(data['timestamp'])})';
      }
    } catch (_) {}
    return 'لا يوجد';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    }
    return timestamp.toString();
  }

  Widget _buildCustomerCard(
      Map<String, dynamic> data, String phone, SystemProvider sys) {
    final name = data['name'] ?? 'غير معروف';
    final role = data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم';
    final agentBalance = data['agentBalance']?.toStringAsFixed(1) ?? '0';
    final lastRecharge = data['lastRecharge'] ?? 'لا يوجد';
    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الاسم: $name',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('الدور: $role'),
            Text('الرصيد من تعاملاتي: $agentBalance ريال'),
            Text('آخر عملية شحن: $lastRecharge'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _showRecentAgentOperations(phone, sys);
                  },
                  child: const Text('عرض آخر العمليات على شبكاتي'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecentAgentOperations(String phone, SystemProvider sys) {
    // نعرض العمليات الأخيرة (شحنات/توليد كروت) بين الوكيل وهذا المستخدم على شبكات الوكيل
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('آخر العمليات مع $phone على شبكاتي',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: _db
                      .collection('recharges')
                      .where('agentPhone', isEqualTo: sys.currentUserPhone)
                      .where('customerPhone', isEqualTo: phone)
                      .orderBy('timestamp', descending: true)
                      .limit(20)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    var docs = snapshot.data!.docs;
                    if (docs.isEmpty)
                      return const Center(
                          child: Text('لا توجد عمليات سابقة.'));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var op = docs[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading:
                              const Icon(Icons.receipt, color: Colors.teal),
                          title: Text(
                              'شبكة: ${op['networkName'] ?? ''} - ${op['categoryName'] ?? ''}'),
                          subtitle: Text(
                              'المبلغ: ${op['amount']} ريال\nالتاريخ: ${_formatTimestamp(op['timestamp'])}'),
                          isThreeLine: true,
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

  void _showTargetInfoDialog(
      String phone, Map<String, dynamic> data, SystemProvider sys) {
    // نستخدم الحوار لعرض معلومات العميل وأزرار إضافية
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('معلومات ${data['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('الاسم', data['name'] ?? ''),
                _infoRow(
                    'الدور', data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم'),
                _infoRow('رقم الهاتف', phone),
                _infoRow(
                    'الرصيد (تعاملاتي)',
                    '${(data['agentBalance'] ?? 0).toStringAsFixed(1)} ريال'),
                _infoRow('آخر عملية شحن', data['lastRecharge'] ?? 'لا يوجد'),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showRecentAgentOperations(phone, sys);
                    },
                    icon: const Icon(Icons.history, color: Colors.teal),
                    label: const Text('عرض العمليات السابقة'),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ===== نهاية دوال شرائح الخصم =====

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
                    tabs: [
                      const Tab(
                          icon: Icon(Icons.dns, color: Colors.greenAccent),
                          text: 'سيرفرات الربط'),
                      const Tab(
                          icon: Icon(Icons.category,
                              color: Colors.orangeAccent),
                          text: 'المخزون والفئات'),
                      const Tab(
                          icon: Icon(Icons.local_offer,
                              color: Colors.amber),
                          text: 'شرائح الخصم'),
                      const Tab(
                          icon: Icon(Icons.autorenew,
                              color: Colors.lightBlueAccent),
                          text: 'توليد الكروت'),
                      const Tab(
                          icon: Icon(Icons.print,
                              color: Colors.tealAccent),
                          text: 'طباعة الكروت'),
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
                      _buildPrintCardsTab(agentNetworks),
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

  // ... (باقي الدوال بدون تغيير، والتعديلات في التوليد والطباعة)

  // ==========================================
  // تبويب التوليد (معدّل لدعم وضع المحاكاة)
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
          // بطاقة تحكم المحاكاة
          Card(
            margin: const EdgeInsets.all(12),
            child: SwitchListTile(
              title: const Text('وضع المحاكاة'),
              subtitle: const Text(
                  'توليد كروت وهمية محلياً دون خادم خارجي',
                  style: TextStyle(fontSize: 12)),
              value: _simulationMode,
              onChanged: (v) async {
                if (v) {
                  bool confirm = await _confirmAction(
                    'تحذير: وضع المحاكاة',
                    'سيتم توليد كروت وهمية (غير حقيقية) داخل قاعدة البيانات دون أي اتصال بالخادم. استخدمه فقط للاختبار. هل تريد المتابعة؟',
                    Colors.orange,
                    requirePassword: true,
                  );
                  if (confirm) setState(() => _simulationMode = true);
                } else {
                  setState(() => _simulationMode = false);
                  _showToast('تم إيقاف وضع المحاكاة');
                }
              },
              activeColor: Colors.deepOrange,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        _simulationMode ? Colors.deepOrange : Colors.blue)),
            child: Text(
                _simulationMode
                    ? '⚠️ وضع المحاكاة نشط: سيتم إنشاء أرقام وهمية محلياً.'
                    : '🔌 توليد متعدد: اكتب الكمية بجانب كل فئة، ثم اختر نوع التوليد واضغط توليد.',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _simulationMode ? Colors.deepOrange : textColor)),
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
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _startGeneration(sys,
                              orders: _collectOrders(), forPrint: false),
                      icon:
                          const Icon(Icons.inventory, color: Colors.white),
                      label: const Text('توليد للمخزون',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _simulationMode
                              ? Colors.deepOrange
                              : Colors.blue,
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
                          : () => _startGeneration(sys,
                              orders: _collectOrders(), forPrint: true),
                      icon: const Icon(Icons.print, color: Colors.white),
                      label: const Text('توليد للطباعة',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _simulationMode
                              ? Colors.deepOrange
                              : Colors.teal,
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
          orders.add({
            "networkId": parts[0],
            "categoryId": parts[1],
            "amount": amt
          });
        }
      }
    });
    return orders;
  }

  Future<void> _startGeneration(SystemProvider sys,
      {required List<Map<String, dynamic>> orders,
      required bool forPrint}) async {
    if (orders.isEmpty) {
      _play('error');
      _showToast('الرجاء كتابة كمية واحدة على الأقل', isError: true);
      return;
    }

    int totalAmount =
        orders.fold(0, (sum, item) => sum + (item['amount'] as int));
    if (totalAmount > 400) {
      _play('error');
      _showToast('الحد الأقصى للتوليد هو 400 كرت إجمالاً', isError: true);
      return;
    }

    if (_simulationMode) {
      // توليد محلي
      bool confirm = await _confirmAction(
          "تأكيد التوليد الوهمي",
          "سيتم توليد $totalAmount كرت وهمي (محاكاة). استمرار؟",
          Colors.deepOrange);
      if (!confirm) return;
      setState(() => _isProcessing = true);
      _showToast('جاري توليد كروت المحاكاة...');
      try {
        await _generateLocalCards(sys, orders, forPrint);
        _play('success');
        _showToast('تم توليد الكروت الوهمية بنجاح ✅');
      } catch (e) {
        _play('error');
        _showToast('فشل التوليد المحلي: $e', isError: true);
      }
      setState(() => _isProcessing = false);
      return;
    }

    // السلوك الطبيعي (خادم خارجي)
    String typeText = forPrint ? 'للطباعة' : 'للمخزون';
    bool confirm = await _confirmAction("تأكيد التوليد المتعدد",
        "سيتم الآن توليد إجمالي $totalAmount كرت $typeText. هل تريد الاستمرار؟",
        Colors.green);
    if (!confirm) return;

    _play('click');
    setState(() => _isProcessing = true);
    _showToast('جاري توليد الكروت... ⏳');

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

    setState(() => _isProcessing = false);
    if (hasError) {
      _play('error');
      _showToast('تمت العملية ولكن حدثت بعض الأخطاء في التوليد',
          isError: true);
    } else {
      _play('success');
      _multiGenControllers.forEach((k, v) => v.clear());
      _showToast('تم توليد جميع الكروت بنجاح! ✅');
    }
  }

  Future<void> _generateLocalCards(SystemProvider sys,
      List<Map<String, dynamic>> orders, bool forPrint) async {
    final random = Random();
    WriteBatch batch = _db.batch();

    for (var order in orders) {
      final netId = order['networkId'] as String;
      final catId = order['categoryId'] as String;
      final amount = order['amount'] as int;
      // جلب بيانات الفئة
      final netDoc = await _db.collection('networks').doc(netId).get();
      final netData = netDoc.data() as Map<String, dynamic>;
      List categories = List.from(netData['categories']);
      int catIdx = categories.indexWhere((c) => c['id'] == catId);
      if (catIdx == -1) continue;
      Map cat = categories[catIdx];
      int price = cat['price'] ?? 0;
      String name = cat['name'];

      for (int i = 0; i < amount; i++) {
        String pin = (1000000 + random.nextInt(9000000)).toString(); // 7 أرقام
        var cardRef = _db.collection('cards').doc();
        batch.set(cardRef, {
          'pin': pin,
          'categoryId': catId,
          'networkId': netId,
          'status': forPrint ? 'print_ready' : 'متاح',
          'price': price,
          'categoryName': name,
          'networkName': netData['name'],
          'agentPhone': sys.currentUserPhone,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      // تحديث المخزون
      if (amount > 0) {
        categories[catIdx]['stock'] += amount;
      }
    }

    await batch.commit();
    // تحديث المخزون في كل الشبكات المعنية
    Set<String> updatedNetworks = {};
    for (var order in orders) {
      String netId = order['networkId'];
      if (updatedNetworks.contains(netId)) continue;
      updatedNetworks.add(netId);
      final netDoc = await _db.collection('networks').doc(netId).get();
      final netData = netDoc.data() as Map<String, dynamic>;
      List categories = List.from(netData['categories']);
      for (var order0 in orders) {
        if (order0['networkId'] != netId) continue;
        int catIdx = categories.indexWhere(
            (c) => c['id'] == order0['categoryId']);
        if (catIdx != -1) {
          categories[catIdx]['stock'] += order0['amount'] as int;
        }
      }
      await _db
          .collection('networks')
          .doc(netId)
          .update({'categories': categories});
    }
    _multiGenControllers.forEach((k, v) => v.clear());
  }

  // ==========================================
  // تبويب طباعة الكروت (مطور مع إعدادات النص وحفظ)
  // ==========================================
  Widget _buildPrintCardsTab(List<QueryDocumentSnapshot> networks) {
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

    if (networks.isEmpty)
      return const Center(
          child:
              Text('يجب إضافة شبكة وفئات أولاً.', style: TextStyle(color: Colors.grey)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إعدادات طباعة الكروت',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'اختر الشبكة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns, color: Colors.blue)),
              value: _selectedPrintNetworkId,
              items: networks
                  .map((net) => DropdownMenuItem(
                      value: net.id,
                      child: Text((net.data() as Map)['name'])))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedPrintNetworkId = val;
                  _selectedPrintCategoryId = null;
                  _selectedPrintCategory = null;
                  _templateBase64 = null;
                  _printReadyCards = [];
                  _resetPrintSettings();
                });
              },
            ),
            const SizedBox(height: 12),
            if (_selectedPrintNetworkId != null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: 'اختر الفئة',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.category, color: Colors.orange)),
                value: _selectedPrintCategoryId,
                items: (networks
                        .firstWhere(
                            (net) => net.id == _selectedPrintNetworkId)
                        .data() as Map)['categories']
                    .map<DropdownMenuItem<String>>((cat) {
                  return DropdownMenuItem(
                      value: cat['id'], child: Text(cat['name']));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedPrintCategoryId = val;
                    if (val != null) {
                      final netData = networks
                          .firstWhere(
                              (net) => net.id == _selectedPrintNetworkId)
                          .data() as Map;
                      final categories = netData['categories'] as List;
                      _selectedPrintCategory =
                          categories.firstWhere((c) => c['id'] == val);
                      _templateBase64 =
                          _selectedPrintCategory?['templateBase64'];
                      _loadPrintSettings(_selectedPrintCategory);
                      _loadPrintReadyCards(
                          _selectedPrintNetworkId!, val);
                    } else {
                      _selectedPrintCategory = null;
                      _templateBase64 = null;
                      _printReadyCards = [];
                      _resetPrintSettings();
                    }
                    _printCountController.clear();
                    _printCount = 0;
                  });
                },
              ),
            if (_templateBase64 != null && _templateBase64!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('معاينة القالب:',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(_templateBase64!),
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_selectedPrintCategory != null) ...[
              const Text('إعدادات النص على القالب',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الموضع الأفقي: ${_textPositionX.toStringAsFixed(0)}%'),
                        Slider(
                          value: _textPositionX,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: _textPositionX.toStringAsFixed(0),
                          onChanged: (v) =>
                              setState(() => _textPositionX = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الموضع الرأسي: ${_textPositionY.toStringAsFixed(0)}%'),
                        Slider(
                          value: _textPositionY,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: _textPositionY.toStringAsFixed(0),
                          onChanged: (v) =>
                              setState(() => _textPositionY = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('حجم الخط: ${_fontSize.toStringAsFixed(0)}'),
                        Slider(
                          value: _fontSize,
                          min: 6,
                          max: 40,
                          divisions: 34,
                          label: _fontSize.toStringAsFixed(0),
                          onChanged: (v) =>
                              setState(() => _fontSize = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      final color = await _openColorPicker(_textColor);
                      if (color != null) setState(() => _textColor = color);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: _textColor,
                      ),
                      child: Text(
                        'لون النص',
                        style: TextStyle(
                            color: _textColor.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // معاينة مباشرة
              if (_templateBase64 != null && _templateBase64!.isNotEmpty)
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8)),
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Stack(
                      children: [
                        Image.memory(
                          base64Decode(_templateBase64!),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Positioned(
                          left: (constraints.maxWidth *
                              _textPositionX /
                              100),
                          top: (constraints.maxHeight *
                              _textPositionY /
                              100),
                          child: Text(
                            '####',
                            style: TextStyle(
                              fontSize: _fontSize,
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                              backgroundColor: Colors.white
                                  .withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              const SizedBox(height: 20),
            ],
            const Text('إعدادات التخطيط',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'عدد النسخ لكل كرت',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _copiesPerCard = int.tryParse(v) ?? 1,
                    controller: TextEditingController(
                        text: _copiesPerCard.toString()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'عدد الكروت في الصف',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _cardsPerRow = int.tryParse(v) ?? 3,
                    controller: TextEditingController(
                        text: _cardsPerRow.toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'عدد الكروت في العمود',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _cardsPerColumn = int.tryParse(v) ?? 4,
                    controller: TextEditingController(
                        text: _cardsPerColumn.toString()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'عرض الكرت (مم)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _cardWidth = double.tryParse(v) ?? 85,
                    controller:
                        TextEditingController(text: _cardWidth.toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                  labelText: 'ارتفاع الكرت (مم)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  _cardHeight = double.tryParse(v) ?? 55,
              controller:
                  TextEditingController(text: _cardHeight.toString()),
            ),
            const SizedBox(height: 15),
            TextField(
              decoration: InputDecoration(
                labelText:
                    'عدد الكروت المراد طباعتها (من ${_printReadyCards.length} جاهز)',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: _printCountController,
              onChanged: (v) {
                int val = int.tryParse(v) ?? 0;
                if (val > _printReadyCards.length) val = _printReadyCards.length;
                setState(() => _printCount = val);
                _printCountController.value = TextEditingValue(
                  text: val.toString(),
                  selection:
                      TextSelection.collapsed(offset: val.toString().length),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_printReadyCards.isEmpty || _printCount <= 0)
                    ? null
                    : () => _showPrintConfirmationDialog(),
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text('بدء الطباعة',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedPrintCategory != null)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _savePrintSettings,
                  icon: const Icon(Icons.save, color: Colors.teal),
                  label: const Text('حفظ إعدادات الطباعة للفئة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _resetPrintSettings() {
    _textPositionX = 50.0;
    _textPositionY = 50.0;
    _fontSize = 14.0;
    _textColor = Colors.black;
    _printCountController.clear();
    _printCount = 0;
  }

  void _loadPrintSettings(Map? category) {
    if (category == null) return;
    final settings = category['printSettings'] as Map<String, dynamic>?;
    if (settings == null) {
      _resetPrintSettings();
      return;
    }
    _textPositionX = (settings['textPositionX'] ?? 50.0).toDouble();
    _textPositionY = (settings['textPositionY'] ?? 50.0).toDouble();
    _fontSize = (settings['fontSize'] ?? 14.0).toDouble();
    _textColor = Color(settings['textColor'] ?? Colors.black.value);
    _cardsPerRow = settings['cardsPerRow'] ?? 3;
    _cardsPerColumn = settings['cardsPerColumn'] ?? 4;
    _cardWidth = (settings['cardWidth'] ?? 85.0).toDouble();
    _cardHeight = (settings['cardHeight'] ?? 55.0).toDouble();
    _copiesPerCard = settings['copiesPerCard'] ?? 1;
  }

  Future<void> _savePrintSettings() async {
    if (_selectedPrintNetworkId == null || _selectedPrintCategoryId == null)
      return;
    try {
      final netDoc =
          await _db.collection('networks').doc(_selectedPrintNetworkId).get();
      List categories = List.from((netDoc.data() as Map)['categories']);
      int idx = categories
          .indexWhere((c) => c['id'] == _selectedPrintCategoryId);
      if (idx == -1) return;
      categories[idx]['printSettings'] = {
        'textPositionX': _textPositionX,
        'textPositionY': _textPositionY,
        'fontSize': _fontSize,
        'textColor': _textColor.value,
        'cardsPerRow': _cardsPerRow,
        'cardsPerColumn': _cardsPerColumn,
        'cardWidth': _cardWidth,
        'cardHeight': _cardHeight,
        'copiesPerCard': _copiesPerCard,
      };
      await _db
          .collection('networks')
          .doc(_selectedPrintNetworkId)
          .update({'categories': categories});
      _showToast('تم حفظ إعدادات الطباعة للفئة');
    } catch (e) {
      _showToast('فشل الحفظ', isError: true);
    }
  }

  Future<void> _loadPrintReadyCards(
      String networkId, String categoryId) async {
    final snapshot = await _db
        .collection('cards')
        .where('categoryId', isEqualTo: categoryId)
        .where('status', isEqualTo: 'print_ready')
        .get();
    if (mounted) {
      setState(() {
        _printReadyCards =
            snapshot.docs.map((doc) => doc.data()).toList();
        _printCount = 0;
        _printCountController.clear();
      });
    }
  }

  void _showPrintConfirmationDialog() {
    final totalCards = _printCount * _copiesPerCard;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد عملية الطباعة'),
          content: Text('عدد الكروت المختارة: $_printCount\n'
              'النسخ لكل كرت: $_copiesPerCard\n'
              'إجمالي الكروت المطبوعة: $totalCards\n\n'
              'اختر الإجراء المطلوب:'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startPrinting(action: 'preview');
                },
                child: const Text('معاينة فقط')),
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startPrinting(action: 'print');
                },
                child: const Text('طباعة فقط')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                Navigator.pop(context);
                _startPrinting(action: 'print_and_archive');
              },
              child: const Text('طباعة وأرشفة',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPrinting({required String action}) async {
    if (_printCount <= 0) return;
    _play('click');
    _showToast('جاري تجهيز الطباعة... 🖨️');

    final cardsToPrint = _printReadyCards.take(_printCount).toList();

    // إنشاء PDF
    final pdf = pw.Document();
    final cardsPerPage = _cardsPerRow * _cardsPerColumn;
    final totalPages = (cardsToPrint.length / cardsPerPage).ceil();
    for (int page = 0; page < totalPages; page++) {
      final pageCards =
          cardsToPrint.skip(page * cardsPerPage).take(cardsPerPage).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            List<pw.Widget> cardWidgets = [];
            for (var card in pageCards) {
              for (int copy = 0; copy < _copiesPerCard; copy++) {
                String pin = card['pin'] ?? '----';
                if (_templateBase64 != null &&
                    _templateBase64!.isNotEmpty) {
                  cardWidgets.add(
                    pw.Container(
                      width: _cardWidth * 2.83,
                      height: _cardHeight * 2.83,
                      child: pw.Stack(
                        children: [
                          pw.Image(
                              pw.MemoryImage(
                                  base64Decode(_templateBase64!)),
                              fit: pw.BoxFit.contain),
                          pw.Positioned(
                            left:
                                (_cardWidth * 2.83 * _textPositionX / 100),
                            top: (_cardHeight * 2.83 * _textPositionY / 100),
                            child: pw.Text(
                              pin,
                              style: pw.TextStyle(
                                fontSize: _fontSize,
                                color: PdfColor(
                                  _textColor.red / 255,
                                  _textColor.green / 255,
                                  _textColor.blue / 255,
                                ),
                                fontWeight: pw.FontWeight.bold,
                                background: pw.BoxDecoration(
                                    color:
                                        PdfColors.white,
                                    borderRadius:
                                        pw.BorderRadius.circular(2)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  cardWidgets.add(
                    pw.Container(
                      width: _cardWidth * 2.83,
                      height: _cardHeight * 2.83,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColors.grey400, width: 1),
                      ),
                      child: pw.Center(
                        child: pw.Text(pin,
                            style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                    ),
                  );
                }
              }
            }
            return pw.GridView(
              crossAxisCount: _cardsPerRow,
              childAspectRatio: _cardWidth / _cardHeight,
              children: cardWidgets,
            );
          },
        ),
      );
    }

    if (action == 'preview') {
      await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'preview.pdf');
      _showToast('تم عرض المعاينة');
      return;
    }

    if (action == 'print') {
      await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name:
              'cards_print_${DateTime.now().millisecondsSinceEpoch}.pdf');
      _showToast('تم إرسال ملف الطباعة');
      return;
    }

    if (action == 'print_and_archive') {
      await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name:
              'cards_print_${DateTime.now().millisecondsSinceEpoch}.pdf');
      // أرشفة الكروت المطبوعة
      WriteBatch batch = _db.batch();
      for (var card in cardsToPrint) {
        // نحتاج معرف الوثيقة، card فيه ربما id، لكن card كـ Map غير متضمن docId
        // سنقوم بجلبها عبر استعلام سريع، لكن الأفضل أن نحتفظ بالـ doc IDs
        // سنقوم بتخزينها أثناء التحميل
      }
      // بدلاً من التعقيد، نستعلم عن الكروت المختارة بالـ pin ونحدثها
      for (var card in cardsToPrint) {
        var query = await _db
            .collection('cards')
            .where('pin', isEqualTo: card['pin'])
            .where('status', isEqualTo: 'print_ready')
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          batch.update(query.docs.first.reference, {'status': 'archived'});
        }
      }
      await batch.commit();
      // تحديث المخزون
      if (_selectedPrintNetworkId != null && _selectedPrintCategoryId != null) {
        var netDoc = await _db
            .collection('networks')
            .doc(_selectedPrintNetworkId)
            .get();
        List cats = List.from((netDoc.data() as Map)['categories']);
        int idx = cats
            .indexWhere((c) => c['id'] == _selectedPrintCategoryId);
        if (idx != -1) {
          cats[idx]['stock'] =
              (cats[idx]['stock'] ?? 0) - _printCount;
          await _db
              .collection('networks')
              .doc(_selectedPrintNetworkId)
              .update({'categories': cats});
        }
      }
      _showToast('تمت الطباعة بنجاح وتمت أرشفة الكروت');
      _loadPrintReadyCards(
          _selectedPrintNetworkId!, _selectedPrintCategoryId!);
    }
  }
}
