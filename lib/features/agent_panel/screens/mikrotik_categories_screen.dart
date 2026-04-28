import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
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

  // ===== متغيرات تبويب الطباعة =====
  String? _selectedPrintNetworkId;
  String? _selectedPrintCategoryId;
  Map? _selectedPrintCategory;
  String? _templateBase64;
  List<Map<String, dynamic>> _printReadyCards = [];
  int _copiesPerCard = 1;
  int _cardsPerRow = 3;
  int _cardsPerColumn = 4;
  double _cardWidth = 85;
  double _cardHeight = 55;

  // ===== إعدادات النص على القالب =====
  double _pinXPercent = 50;
  double _pinYPercent = 50;
  double _pinFontSize = 14;
  Color _pinColor = Colors.black;

  // ===== عدد الكروت المطلوب طباعتها =====
  int? _printCount;
  final TextEditingController _printCountController = TextEditingController();

  // وحدات تحكم خاصة بحقول إعدادات النص (مع FocusNode)
  late final TextEditingController _pinXController;
  late final TextEditingController _pinYController;
  late final TextEditingController _pinFontController;
  late final FocusNode _pinXFocus;
  late final FocusNode _pinYFocus;
  late final FocusNode _pinFontFocus;

  // وحدات تحكم إعدادات التخطيط
  late final TextEditingController _copiesController;
  late final TextEditingController _cardsPerRowController;
  late final TextEditingController _cardsPerColumnController;
  late final TextEditingController _cardWidthController;
  late final TextEditingController _cardHeightController;

  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _printCountController.addListener(() {
      int? val = int.tryParse(_printCountController.text);
      if (val != null && val >= 0) {
        _printCount = val;
      } else {
        _printCount = null;
      }
    });

    // تهيئة متحكمات النص
    _pinXController = TextEditingController(text: _pinXPercent.toStringAsFixed(1));
    _pinYController = TextEditingController(text: _pinYPercent.toStringAsFixed(1));
    _pinFontController = TextEditingController(text: _pinFontSize.toStringAsFixed(1));
    _pinXFocus = FocusNode();
    _pinYFocus = FocusNode();
    _pinFontFocus = FocusNode();

    _copiesController = TextEditingController(text: _copiesPerCard.toString());
    _cardsPerRowController = TextEditingController(text: _cardsPerRow.toString());
    _cardsPerColumnController = TextEditingController(text: _cardsPerColumn.toString());
    _cardWidthController = TextEditingController(text: _cardWidth.toStringAsFixed(1));
    _cardHeightController = TextEditingController(text: _cardHeight.toStringAsFixed(1));

    _pinXController.addListener(() {
      final v = double.tryParse(_pinXController.text);
      if (v != null) {
        _pinXPercent = v;
        _refreshPreview();
      }
    });
    _pinYController.addListener(() {
      final v = double.tryParse(_pinYController.text);
      if (v != null) {
        _pinYPercent = v;
        _refreshPreview();
      }
    });
    _pinFontController.addListener(() {
      final v = double.tryParse(_pinFontController.text);
      if (v != null) {
        _pinFontSize = v;
        _refreshPreview();
      }
    });
  }

  void _refreshPreview() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
          if (_pinXFocus.hasFocus) _pinXFocus.requestFocus();
          else if (_pinYFocus.hasFocus) _pinYFocus.requestFocus();
          else if (_pinFontFocus.hasFocus) _pinFontFocus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _printCountController.dispose();
    _pinXController.dispose();
    _pinYController.dispose();
    _pinFontController.dispose();
    _pinXFocus.dispose();
    _pinYFocus.dispose();
    _pinFontFocus.dispose();
    _copiesController.dispose();
    _cardsPerRowController.dispose();
    _cardsPerColumnController.dispose();
    _cardWidthController.dispose();
    _cardHeightController.dispose();
    super.dispose();
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

  // تم تعديل _confirmAction لإضافة أيقونة إظهار/إخفاء كلمة المرور
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
                            prefixIcon: Icon(Icons.location_on,
                                color: Colors.orange)),
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
                            controller:
                                TextEditingController(text: district),
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
                                          labelText:
                                              'منطقة البث ${idx + 1}',
                                          border:
                                              const OutlineInputBorder(),
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
                            prefixIcon:
                                Icon(Icons.wifi, color: Colors.green)),
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
                                    prefixIcon: Icon(Icons.lock,
                                        color: Colors.red)),
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
                                      networkData['status'] =
                                          'متصل نشط 🟢';
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
                                    setModalState(
                                        () => isSubmitting = false);
                                    _play('error');
                                    _showToast('فشل حفظ البيانات',
                                        isError: true);
                                  }
                                } else {
                                  _play('error');
                                  _showToast(
                                      'يرجى تعبئة الحقول الأساسية',
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
  // 2. إضافة وتعديل فئة كروت للشبكة
  // ==========================================
  void _showAddCategoryBottomSheet(List<QueryDocumentSnapshot> agentNetworks,
      {Map? existingCat, String? preSelectedNetId}) {
    _play('click');
    String newName = existingCat?['name'] ?? _draftCategoryName;
    String newTime = existingCat?['time'] ?? _draftCategoryTime;
    String newCapacity =
        existingCat?['capacity'] ?? _draftCategoryCapacity;
    String newPrice =
        existingCat?['price']?.toString() ?? _draftCategoryPrice;
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
                            prefixIcon:
                                Icon(Icons.dns, color: Colors.blue)),
                        value: selectedNetworkId,
                        items: agentNetworks
                            .map((net) => DropdownMenuItem(
                                value: net.id,
                                child: Text(
                                    (net.data() as Map)['name'])))
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedNetworkId = val),
                      ),
                    if (existingCat == null) const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'اسم الفئة (Profile)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category,
                                color: Colors.orange)),
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
                                controller: TextEditingController(
                                    text: newTime),
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
                        const Icon(Icons.image,
                            color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        const Text('قالب الطباعة (اختياري): ',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final pickedFile =
                                await _imagePicker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 50,
                                    maxWidth: 800);
                            if (pickedFile != null) {
                              final bytes =
                                  await pickedFile.readAsBytes();
                              setModalState(() => templateBase64 =
                                  base64Encode(bytes));
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
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
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
                                borderRadius:
                                    BorderRadius.circular(10))),
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
                                  setModalState(
                                      () => isSubmitting = true);
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
                                      'capacity':
                                          newCapacity.isNotEmpty
                                              ? newCapacity
                                              : 'مفتوح',
                                      'price': int.tryParse(
                                              newPrice) ??
                                          0,
                                      'color': selectedColor.value,
                                      'note': note,
                                      'templateBase64':
                                          templateBase64,
                                      'stock': existingCat?['stock'] ??
                                          0,
                                      'isActive':
                                          existingCat?['isActive'] ??
                                              true,
                                      'botMinStock':
                                          existingCat?[
                                                  'botMinStock'] ??
                                              5,
                                      'botRefillAmount':
                                          existingCat?[
                                                  'botRefillAmount'] ??
                                              50,
                                      'isBotEnabled':
                                          existingCat?[
                                                  'isBotEnabled'] ??
                                              false,
                                    };
                                    if (existingCat == null) {
                                      await _db
                                          .collection('networks')
                                          .doc(selectedNetworkId)
                                          .update({
                                        'categories':
                                            FieldValue.arrayUnion(
                                                [newCategory])
                                      });
                                      _draftCategoryName = '';
                                      _draftCategoryTime = '';
                                      _draftCategoryCapacity = '';
                                      _draftCategoryPrice = '';
                                      _draftCategoryNote = '';
                                      _draftCategoryColor =
                                          Colors.blue;
                                      _draftCategoryTemplateBase64 =
                                          null;
                                    } else {
                                      var netDoc = await _db
                                          .collection('networks')
                                          .doc(selectedNetworkId)
                                          .get();
                                      List cats = List.from(
                                          (netDoc.data()
                                                  as Map)[
                                              'categories']);
                                      int idx = cats.indexWhere((c) =>
                                          c['id'] ==
                                          existingCat['id']);
                                      cats[idx] = newCategory;
                                      await _db
                                          .collection('networks')
                                          .doc(selectedNetworkId)
                                          .update({
                                        'categories': cats
                                      });
                                    }
                                    _play('success');
                                    if (mounted) {
                                      Navigator.pop(context);
                                      _showToast(
                                          'تم الحفظ بنجاح! 📋');
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
                          side:
                              const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          _draftCategoryName = newName;
                          _draftCategoryTime = newTime;
                          _draftCategoryCapacity = newCapacity;
                          _draftCategoryPrice = newPrice;
                          _draftCategoryNote = note;
                          _draftCategoryColor = selectedColor;
                          _draftCategoryTemplateBase64 =
                              templateBase64;
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
                          margin:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(
                                Icons.confirmation_number,
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
                                        await card.reference.update(
                                            {'status': 'archived'});
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
                                            .update(
                                                {'categories': cats});
                                        _showToast(
                                            'تمت أرشفة الكرت بنجاح');
                                      }
                                    }),
                                IconButton(
                                    icon: const Icon(
                                        Icons.delete_forever,
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
                                            .update(
                                                {'categories': cats});
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
                  onChanged: (v) =>
                      setModalState(() => isBotEnabled = v),
                ),
                if (isBotEnabled) ...[
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText:
                            'الحد الأدنى للمخزون (متى يبدأ البوت؟)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        minStock = int.tryParse(v) ?? 5,
                    controller: TextEditingController(
                        text: minStock.toString()),
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
                  var netDoc = await _db
                      .collection('networks')
                      .doc(netId)
                      .get();
                  List cats = List.from(netDoc['categories']);
                  int idx = cats.indexWhere(
                      (c) => c['id'] == catId);
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
  // 3. إدارة شرائح الخصم
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
                        controller:
                            TextEditingController(text: condition),
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
                            child: Text(
                                'الجميع (كل المستخدمين ونقاط البيع)')),
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
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText:
                                          'رقم الهاتف ${idx + 1}',
                                      border:
                                          const OutlineInputBorder(),
                                      prefixIcon: const Icon(
                                          Icons.phone,
                                          color: Colors.blue),
                                      suffixIcon: searchResults[
                                                  phone] !=
                                              null
                                          ? IconButton(
                                              icon: const Icon(
                                                  Icons
                                                      .info_outline,
                                                  color:
                                                      Colors.teal),
                                              onPressed: () =>
                                                  _showTargetInfoDialog(
                                                      phone,
                                                      searchResults[
                                                              phone]!,
                                                      sys
                                                          .currentUserPhone),
                                            )
                                          : null,
                                    ),
                                    controller: TextEditingController(
                                        text: phone),
                                    keyboardType:
                                        TextInputType.phone,
                                    onChanged: (v) {
                                      targetPhones[idx] = v;
                                      _debounceSearch(
                                          v,
                                          sys,
                                          setModalState,
                                          searchResults,
                                          phone);
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red),
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
                              _buildTargetInfoCard(phone,
                                  searchResults[phone]!, sys),
                            const SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                      TextButton.icon(
                        onPressed: () =>
                            setModalState(() => targetPhones.add('')),
                        icon:
                            const Icon(Icons.add, color: Colors.green),
                        label: const Text('إضافة مستهدف آخر'),
                      ),
                    ],
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Text('لون الشريحة المميز: ',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () async {
                            final color =
                                await _openColorPicker(selectedColor);
                            if (color != null)
                              setModalState(
                                  () => selectedColor = color);
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
                                borderRadius:
                                    BorderRadius.circular(10))),
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
                                  setModalState(
                                      () => isSubmitting = true);
                                  try {
                                    Map<String, dynamic> tierData = {
                                      'agentPhone':
                                          sys.currentUserPhone,
                                      'title': title,
                                      'condition':
                                          int.parse(condition),
                                      'discountValue': double.parse(
                                          discountValue),
                                      'discountType': discountType,
                                      'color': selectedColor.value,
                                      'isActive':
                                          existingTier?['isActive'] ??
                                              true,
                                      'targetType': targetType,
                                      'targetPhones': targetPhones,
                                      'subscribersCount':
                                          existingTier?[
                                                  'subscribersCount'] ??
                                              0,
                                      'updatedAt': FieldValue
                                          .serverTimestamp(),
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
                                      _draftTierDiscountType =
                                          'percentage';
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
                          side:
                              const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
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
  void _debounceSearch(String phone, SystemProvider sys,
      StateSetter setModalState, Map<String, dynamic?> results,
      String currentPhone) {
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

  Widget _buildTargetInfoCard(
      String phone, Map<String, dynamic> data, SystemProvider sys) {
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
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(
                'الدور', data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم'),
            _infoRow('الرصيد العام', '${data['balance'] ?? '0'} ريال'),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showTargetTransactionsDialog(
                      phone, sys.currentUserPhone, data['name'] ?? ''),
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

  void _showTargetInfoDialog(
      String phone, Map<String, dynamic> data, String agentPhone) {
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
                _infoRow('الاسم', data['name']),
                _infoRow(
                    'الدور', data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم'),
                _infoRow('رقم الهاتف', phone),
                _infoRow('الرصيد الحالي', '${data['balance']} ريال'),
                _infoRow('آخر عملية شحن', data['lastRecharge'] ?? 'لا يوجد'),
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showTargetTransactionsDialog(
                          phone, agentPhone, data['name'] ?? '');
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
    final netSnap = await _db
        .collection('networks')
        .where('agentPhone', isEqualTo: agentPhone)
        .get();
    List<String> networkIds = netSnap.docs.map((d) => d.id).toList();
    if (networkIds.isEmpty) return [];

    final transSnap = await _db
        .collection('transactions')
        .where('userPhone', isEqualTo: phone)
        .where('networkId', whereIn: networkIds)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    return transSnap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();
  }

  void _showTargetTransactionsDialog(
      String phone, String agentPhone, String userName) async {
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
                if (list.isEmpty)
                  return const Center(child: Text('لا توجد عمليات'));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final t = list[i];
                    return ListTile(
                      leading: Icon(Icons.receipt_long,
                          color: Colors.orange),
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
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'))
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(child: Text(value)),
        ],
      ),
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
                    color: isDark
                        ? primaryColor.withOpacity(0.4).withAlpha(100)
                        : Colors.blue.shade800,
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                       TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        indicatorColor: Colors.orange,
                        indicatorWeight: 4,
                        labelStyle: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        tabs: [
                          Tab(
                              icon: Icon(Icons.dns,
                                  color: Colors.greenAccent),
                              text: 'سيرفرات الربط'),
                          Tab(
                              icon: Icon(Icons.category,
                                  color: Colors.orangeAccent),
                              text: 'المخزون والفئات'),
                          Tab(
                              icon: Icon(Icons.local_offer,
                                  color: Colors.amber),
                              text: 'شرائح الخصم'),
                          Tab(
                              icon: Icon(Icons.autorenew,
                                  color: Colors.lightBlueAccent),
                              text: 'توليد الكروت'),
                          Tab(
                              icon: Icon(Icons.print,
                                  color: Colors.tealAccent),
                              text: 'طباعة الكروت'),
                        ],
                      ),
                      // مفتاح المحاكاة
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'محاكاة: ',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            Switch(
                              value: _simulationMode,
                              onChanged: (v) => _toggleSimulation(),
                              activeColor: Colors.redAccent,
                            ),
                            Text(
                              _simulationMode ? 'ON' : 'OFF',
                              style: TextStyle(
                                  color: _simulationMode
                                      ? Colors.redAccent
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isProcessing)
                  const LinearProgressIndicator(
                      backgroundColor: Colors.orange,
                      color: Colors.white),
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

  // ==========================================
  // تبويب السيرفرات
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
                                backgroundColor: isActive
                                    ? Colors.green
                                    : Colors.grey,
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
                        _buildInfoRow(
                            Icons.location_on,
                            'الموقع',
                            net['location'] ?? '',
                            textColor,
                            Colors.orange),
                        const SizedBox(height: 6),
                        _buildInfoRow(Icons.wifi, 'IP', net['ip'] ?? '',
                            textColor, Colors.green),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                            Icons.info_outline,
                            'الحالة',
                            isActive ? 'نشط' : 'مجمد',
                            textColor,
                            isActive ? Colors.green : Colors.red),
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
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      Color textColor, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey)),
        Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 13, color: textColor))),
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
              _showToast(
                  isActive ? 'تم تجميد الشبكة' : 'تم تنشيط الشبكة');
            }
          },
        ),
        _actionButton(
            Icons.edit,
            'تعديل',
            Colors.grey,
            () => _showAddServerBottomSheet(sys,
                existingData: net, docId: networks[index].id)),
        _actionButton(Icons.delete, 'حذف', Colors.red, () async {
          bool confirm = await _confirmAction(
              "حذف الشبكة نهائياً",
              "سيتم مسح بيانات الشبكة، هل أنت متأكد؟",
              Colors.red,
              requirePassword: true);
          if (confirm) {
            _play('click');
            await _db
                .collection('networks')
                .doc(networks[index].id)
                .delete();
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
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
    );
  }

  // ==========================================
  // تبويب الفئات والمخزون
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
                      Color catColor = Color(
                          category['color'] ?? Colors.blue.value);
                      bool isCatActive =
                          category['isActive'] ?? true;
                      bool isBotEnabled =
                          category['isBotEnabled'] ?? false;

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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                                            : TextDecoration
                                                .lineThrough),
                                  )),
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                          icon: const Icon(
                                              Icons.remove_red_eye,
                                              color: Colors.teal,
                                              size: 20),
                                          onPressed: () =>
                                              _showCardsList(
                                                  netId,
                                                  category['id'],
                                                  category['name'],
                                                  catColor),
                                          constraints:
                                              const BoxConstraints(),
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 5),
                                          tooltip: 'عرض الكروت'),
                                      IconButton(
                                          icon: Icon(Icons.smart_toy,
                                              color: isBotEnabled
                                                  ? Colors.purple
                                                  : Colors.grey,
                                              size: 20),
                                          onPressed: () =>
                                              _showBotSettings(
                                                  netId,
                                                  category['id'],
                                                  category),
                                          constraints:
                                              const BoxConstraints(),
                                          padding: const EdgeInsets
                                              .symmetric(
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
                                              List updated = List.from(
                                                  categories);
                                              int idx = updated.indexWhere((c) =>
                                                  c['id'] ==
                                                  category['id']);
                                              updated[idx]['isActive'] =
                                                  !isCatActive;
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
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 5)),
                                      IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue,
                                              size: 20),
                                          onPressed: () =>
                                              _showAddCategoryBottomSheet(
                                                  networks,
                                                  existingCat:
                                                      category,
                                                  preSelectedNetId:
                                                      netId),
                                          constraints:
                                              const BoxConstraints(),
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 5)),
                                      IconButton(
                                          icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20),
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
                                                'categories': FieldValue
                                                    .arrayRemove([
                                                  category
                                                ])
                                              });
                                              _showToast(
                                                  'تم حذف الفئة نهائياً');
                                            }
                                          },
                                          constraints:
                                              const BoxConstraints(),
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 5)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  'الوقت: ${category['time']} | السعة: ${category['capacity']}',
                                  style: TextStyle(
                                      color: textColor)),
                              if (category['note'] != null &&
                                  category['note']
                                      .toString()
                                      .isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4),
                                  child: Text(
                                      '📝 ${category['note']}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontStyle:
                                              FontStyle.italic)),
                                ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      'سعر الجمهور: ${category['price']} ريال',
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.grey)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5),
                                    decoration: BoxDecoration(
                                        color: isLowStock
                                            ? Colors.red.shade100
                                            : Colors.green.shade100,
                                        borderRadius:
                                            BorderRadius.circular(
                                                10)),
                                    child: Text(
                                        'المخزون: $stock كرت',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 12,
                                            color: isLowStock
                                                ? Colors.red
                                                : Colors.green
                                                    .shade800)),
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
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
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
                        child: Text(
                            'لم تقم بإضافة أي شرائح خصم حتى الآن.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        itemCount: tiers.length,
                        itemBuilder: (context, index) {
                          var tier = tiers[index].data()
                              as Map<String, dynamic>;
                          bool isActive = tier['isActive'] ?? true;
                          Color tColor = Color(tier['color'] ??
                              Colors.amber.shade700.value);
                          String dType =
                              tier['discountType'] == 'percentage'
                                  ? '%'
                                  : 'ريال';

                          return Card(
                            color: isActive
                                ? Theme.of(context).cardColor
                                : Colors.grey.shade200,
                            elevation: 2,
                            margin:
                                const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(
                                  isActive
                                      ? Icons.stars
                                      : Icons.block,
                                  color: isActive
                                      ? tColor
                                      : Colors.grey,
                                  size: 35),
                              title: Text(tier['title'],
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? tColor
                                          : Colors.grey,
                                      decoration: isActive
                                          ? null
                                          : TextDecoration
                                              .lineThrough)),
                              subtitle: Text(
                                  'شرط السحب: ${tier['condition']} ريال\nالخصم: ${tier['discountValue']}$dType',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: textColor)),
                              trailing: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4),
                                    decoration: BoxDecoration(
                                        color: isActive
                                            ? tColor.withOpacity(0.1)
                                            : Colors.grey
                                                .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(
                                                20)),
                                    child: Text(
                                        tier['targetType'] == 'all'
                                            ? 'للجميع'
                                            : tier['targetType'] ==
                                                    'pos'
                                                ? 'نقاط البيع'
                                                : tier['targetType'] ==
                                                        'user'
                                                    ? 'المستخدمين'
                                                    : 'محدد',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            color: isActive
                                                ? tColor
                                                : Colors.grey,
                                            fontSize: 10)),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                          onTap: () async {
                                            bool confirm =
                                                await _confirmAction(
                                                    isActive
                                                        ? "تجميد الشريحة"
                                                        : "تنشيط الشريحة",
                                                    "تغيير حالة العرض؟",
                                                    Colors.orange);
                                            if (confirm)
                                              _db
                                                  .collection(
                                                      'discount_tiers')
                                                  .doc(tiers[index]
                                                      .id)
                                                  .update({
                                                'isActive':
                                                    !isActive
                                              });
                                          },
                                          child: Icon(
                                              isActive
                                                  ? Icons.pause_circle_filled
                                                  : Icons.play_circle_fill,
                                              color:
                                                  Colors.orange,
                                              size: 20)),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                          onTap: () =>
                                              _showDiscountTierBottomSheet(
                                                  sys,
                                                  existingTier:
                                                      tier,
                                                  docId: tiers[
                                                          index]
                                                      .id),
                                          child: const Icon(
                                              Icons.edit,
                                              color: Colors.blue,
                                              size: 20)),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                          onTap: () async {
                                            bool confirm =
                                                await _confirmAction(
                                                    "حذف الشريحة",
                                                    "سيتم إلغاء الخصم عن البقالات المنضمة، متأكد؟",
                                                    Colors.red,
                                                    requirePassword:
                                                        true);
                                            if (confirm) {
                                              _play('click');
                                              await _db
                                                  .collection(
                                                      'discount_tiers')
                                                  .doc(tiers[index]
                                                      .id)
                                                  .delete();
                                              _showToast(
                                                  'تم حذف الشريحة');
                                            }
                                          },
                                          child: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20)),
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
            icon: const Icon(Icons.add_moderator,
                color: Colors.white),
            label: const Text('إضافة شريحة',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  // ==========================================
  // تبويب توليد الكروت
  // ==========================================
  Widget _buildGenerateCardsTab(
      SystemProvider sys, List<QueryDocumentSnapshot> networks) {
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    if (networks.isEmpty)
      return const Center(
          child: Text('يجب إضافة شبكة وفئات أولاً!'));

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
      return const Center(
          child: Text('لا توجد فئات نشطة للتوليد.'));

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
                            color:
                                Color(item['category']['color']),
                            size: 30),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                                      fontSize: 12,
                                      color: Colors.grey)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller:
                                _multiGenControllers[key],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'الكمية',
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          10)),
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
                              orders: _collectOrders(),
                              forPrint: false),
                      icon: const Icon(Icons.inventory,
                          color: Colors.white),
                      label: const Text('توليد للمخزون',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10))),
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
                              orders: _collectOrders(),
                              forPrint: true),
                      icon: const Icon(Icons.print,
                          color: Colors.white),
                      label: const Text('توليد للطباعة',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10))),
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
    final netDoc =
        await _db.collection('networks').doc(networkId).get();
    List cats =
        List.from((netDoc.data() as Map)['categories']);
    int idx = cats.indexWhere((c) => c['id'] == categoryId);
    if (idx != -1) {
      cats[idx]['stock'] = (cats[idx]['stock'] ?? 0) + amount;
      batch.update(_db.collection('networks').doc(networkId),
          {'categories': cats});
    }
    await batch.commit();
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
      _showToast('الحد الأقصى للتوليد هو 400 كرت إجمالاً',
          isError: true);
      return;
    }

    String typeText = forPrint ? 'للطباعة' : 'للمخزون';
    bool confirm = await _confirmAction("تأكيد التوليد المتعدد",
        "سيتم الآن توليد إجمالي $totalAmount كرت $typeText. هل تريد الاستمرار؟",
        Colors.green);
    if (!confirm) return;

    _play('click');
    setState(() => _isProcessing = true);
    _showToast('جاري توليد الكروت... ⏳');

    if (_simulationMode) {
      try {
        for (var order in orders) {
          await _simulateGenerate(order['networkId'],
              order['categoryId'], order['amount'], forPrint);
        }
        _play('success');
        _multiGenControllers.forEach((k, v) => v.clear());
        _showToast(
            'تم توليد $totalAmount كرت (محاكاة) بنجاح! ✅');
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
        _showToast(
            'تمت العملية ولكن حدثت بعض الأخطاء في التوليد',
            isError: true);
      } else {
        _play('success');
        _multiGenControllers.forEach((k, v) => v.clear());
        _showToast('تم توليد جميع الكروت بنجاح! ✅');
      }
    }
    setState(() => _isProcessing = false);
  }

  // ==========================================
  // تبويب طباعة الكروت (مُحسَّن)
  // ==========================================
  Widget _buildPrintCardsTab(List<QueryDocumentSnapshot> networks) {
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: networks.isEmpty
          ? const Center(
              child: Text('يجب إضافة شبكة وفئات أولاً.',
                  style: TextStyle(color: Colors.grey)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إعدادات طباعة الكروت',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: 'اختر الشبكة',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.dns, color: Colors.blue)),
                    value: _selectedPrintNetworkId,
                    items: networks
                        .map((net) => DropdownMenuItem(
                            value: net.id,
                            child: Text(
                                (net.data() as Map)['name'])))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPrintNetworkId = val;
                        _selectedPrintCategoryId = null;
                        _selectedPrintCategory = null;
                        _templateBase64 = null;
                        _printReadyCards = [];
                        _printCount = null;
                        _printCountController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_selectedPrintNetworkId != null)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'اختر الفئة',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category,
                              color: Colors.orange)),
                      value: _selectedPrintCategoryId,
                      items: (networks
                              .firstWhere((net) =>
                                  net.id ==
                                  _selectedPrintNetworkId)
                              .data() as Map)['categories']
                          .map<DropdownMenuItem<String>>((cat) {
                        return DropdownMenuItem(
                            value: cat['id'],
                            child: Text(cat['name']));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPrintCategoryId = val;
                          if (val != null) {
                            final netData = networks
                                .firstWhere((net) =>
                                    net.id ==
                                    _selectedPrintNetworkId)
                                .data() as Map;
                            final categories = netData[
                                'categories'] as List;
                            _selectedPrintCategory = categories
                                .firstWhere(
                                    (c) => c['id'] == val);
                            _templateBase64 = _selectedPrintCategory?[
                                'templateBase64'];
                            _pinXPercent =
                                (_selectedPrintCategory?[
                                            'textXPercent'] ??
                                        50)
                                    .toDouble();
                            _pinYPercent =
                                (_selectedPrintCategory?[
                                            'textYPercent'] ??
                                        50)
                                    .toDouble();
                            _pinFontSize =
                                (_selectedPrintCategory?[
                                            'textFontSize'] ??
                                        14)
                                    .toDouble();
                            _pinColor = Color(
                                _selectedPrintCategory?[
                                        'textColor'] ??
                                    Colors.black.value);
                            _pinXController.text =
                                _pinXPercent.toStringAsFixed(1);
                            _pinYController.text =
                                _pinYPercent.toStringAsFixed(1);
                            _pinFontController.text =
                                _pinFontSize.toStringAsFixed(1);
                            _loadPrintReadyCards(
                                _selectedPrintNetworkId!,
                                val);
                          } else {
                            _selectedPrintCategory = null;
                            _templateBase64 = null;
                            _printReadyCards = [];
                            _printCount = null;
                            _printCountController.clear();
                          }
                        });
                      },
                    ),
                  if (_templateBase64 != null &&
                      _templateBase64!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('معاينة القالب:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
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
                    const Text('إعدادات النص على القالب ✍️',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    // معاينة مباشرة أعلى الحقول
                    if (_templateBase64 != null &&
                        _templateBase64!.isNotEmpty)
                      _buildLivePreview(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: _pinXFocus,
                            controller: _pinXController,
                            decoration: const InputDecoration(
                                labelText: 'الموقع الأفقي (%)',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            focusNode: _pinYFocus,
                            controller: _pinYController,
                            decoration: const InputDecoration(
                                labelText: 'الموقع الرأسي (%)',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: _pinFontFocus,
                            controller: _pinFontController,
                            decoration: const InputDecoration(
                                labelText: 'حجم الخط',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final color =
                                await _openColorPicker(_pinColor);
                            if (color != null)
                              setState(() => _pinColor = color);
                          },
                          icon: Icon(Icons.colorize,
                              color: _pinColor),
                          label: const Text('اختر اللون'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _pinColor.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('إعدادات التخطيط',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _copiesController,
                          decoration: const InputDecoration(
                              labelText: 'عدد النسخ لكل كرت',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _copiesPerCard =
                              int.tryParse(v) ?? 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _cardsPerRowController,
                          decoration: const InputDecoration(
                              labelText: 'عدد الكروت في الصف',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _cardsPerRow =
                              int.tryParse(v) ?? 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cardsPerColumnController,
                          decoration: const InputDecoration(
                              labelText: 'عدد الكروت في العمود',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _cardsPerColumn =
                              int.tryParse(v) ?? 4,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _cardWidthController,
                          decoration: const InputDecoration(
                              labelText: 'عرض الكرت (مم)',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _cardWidth =
                              double.tryParse(v) ?? 85,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cardHeightController,
                    decoration: const InputDecoration(
                        labelText: 'ارتفاع الكرت (مم)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _cardHeight = double.tryParse(v) ?? 55,
                  ),
                  const SizedBox(height: 20),
                  // زر حفظ كل الإعدادات (نصوص + تخطيط)
                  if (_selectedPrintCategory != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveAllSettings,
                        icon: const Icon(Icons.save),
                        label: const Text(
                            'حفظ جميع الإعدادات للفئة'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_printReadyCards.isNotEmpty) ...[
                    Text(
                        'الكروت المعدة للطباعة: ${_printReadyCards.length} كرت',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _printCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عدد الكروت المطلوب',
                        hintText: 'الكل',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (_printReadyCards.isEmpty)
                          ? null
                          : () => _showPrintConfirmationDialog(),
                      icon: const Icon(Icons.print,
                          color: Colors.white),
                      label: const Text('بدء الطباعة',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLivePreview() {
    if (_templateBase64 == null || _templateBase64!.isEmpty)
      return const SizedBox.shrink();
    final bytes = base64Decode(_templateBase64!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('معاينة مباشرة:',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.teal)),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  left: (200 * _pinXPercent / 100) - 20,
                  top: (150 * _pinYPercent / 100) - 10,
                  child: Text(
                    '####',
                    style: TextStyle(
                      fontSize: _pinFontSize * 0.7,
                      fontWeight: FontWeight.bold,
                      color: _pinColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
        _printReadyCards = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        _printCount = _printReadyCards.length;
        _printCountController.text = _printCount.toString();
      });
    }
  }

  Future<void> _saveAllSettings() async {
    if (_selectedPrintNetworkId == null ||
        _selectedPrintCategoryId == null) return;
    final netDoc = await _db
        .collection('networks')
        .doc(_selectedPrintNetworkId)
        .get();
    List cats =
        List.from((netDoc.data() as Map)['categories']);
    int idx = cats.indexWhere(
        (c) => c['id'] == _selectedPrintCategoryId);
    if (idx != -1) {
      cats[idx]['textXPercent'] = _pinXPercent;
      cats[idx]['textYPercent'] = _pinYPercent;
      cats[idx]['textFontSize'] = _pinFontSize;
      cats[idx]['textColor'] = _pinColor.value;
      cats[idx]['copiesPerCard'] = _copiesPerCard;
      cats[idx]['cardsPerRow'] = _cardsPerRow;
      cats[idx]['cardsPerColumn'] = _cardsPerColumn;
      cats[idx]['cardWidth'] = _cardWidth;
      cats[idx]['cardHeight'] = _cardHeight;
      await _db
          .collection('networks')
          .doc(_selectedPrintNetworkId)
          .update({'categories': cats});
      _play('success');
      _showToast('تم حفظ جميع الإعدادات للفئة');
    }
  }

  Future<void> _showPrintConfirmationDialog() async {
    final int available = _printReadyCards.length;
    final int requested = _printCount ?? available;
    final int printCount = requested > available ? available : requested;
    if (printCount <= 0) {
      _showToast('لا توجد كروت للطباعة', isError: true);
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الطباعة'),
          content: Text(
              'عدد الكروت المعدة للطباعة: $available\nسيتم طباعة: $printCount كرت.\nاختر الإجراء المناسب.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'view'),
              icon: const Icon(Icons.preview),
              label: const Text('معاينة فقط'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'print_only'),
              icon: const Icon(Icons.print),
              label: const Text('طباعة فقط'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pop(ctx, 'print_archive'),
              icon: const Icon(Icons.archive),
              label: const Text('طباعة وأرشفة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == 'cancel') return;

    final List<Map<String, dynamic>> cardsToPrint =
        _printReadyCards.take(printCount).toList();

    await _generateAndPrintPdf(cardsToPrint);

    if (result == 'print_archive') {
      await _archivePrintedCards(cardsToPrint);
      _loadPrintReadyCards(
          _selectedPrintNetworkId!, _selectedPrintCategoryId!);
    }
  }

  Future<void> _generateAndPrintPdf(
      List<Map<String, dynamic>> cards) async {
    final pdf = pw.Document();
    final cardsPerPage = _cardsPerRow * _cardsPerColumn;
    final totalPages = (cards.length / cardsPerPage).ceil();

    for (int page = 0; page < totalPages; page++) {
      final pageCards = cards
          .skip(page * cardsPerPage)
          .take(cardsPerPage)
          .toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            List<pw.Widget> cardWidgets = [];
            for (var card in pageCards) {
              String pin = card['pin'] ?? '----';
              pw.Widget cardContent;
              if (_templateBase64 != null &&
                  _templateBase64!.isNotEmpty) {
                final templateImage = pw.MemoryImage(
                    base64Decode(_templateBase64!));
                final double dx = _pinXPercent / 100;
                final double dy = _pinYPercent / 100;
                cardContent = pw.Container(
                  width: _cardWidth * 2.83,
                  height: _cardHeight * 2.83,
                  child: pw.Stack(
                    children: [
                      pw.Positioned.fill(
                          child: pw.Image(templateImage,
                              fit: pw.BoxFit.contain)),
                      pw.Positioned(
                        left: (_cardWidth * 2.83 * dx) - 50,
                        top: (_cardHeight * 2.83 * dy) - 15,
                        child: pw.Container(
                          width: 100,
                          height: 30,
                          child: pw.Center(
                            child: pw.Text(pin,
                                style: pw.TextStyle(
                                  fontSize: _pinFontSize,
                                  fontWeight:
                                      pw.FontWeight.bold,
                                  color: PdfColor(
                                    _pinColor.red / 255,
                                    _pinColor.green / 255,
                                    _pinColor.blue / 255,
                                  ),
                                )),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                cardContent = pw.Container(
                  width: _cardWidth * 2.83,
                  height: _cardHeight * 2.83,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColors.grey400, width: 1),
                  ),
                  child: pw.Center(
                    child: pw.Text(pin,
                        style: pw.TextStyle(
                            fontSize: _pinFontSize,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor(
                              _pinColor.red / 255,
                              _pinColor.green / 255,
                              _pinColor.blue / 255,
                            ))),
                  ),
                );
              }
              cardWidgets.add(cardContent);
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

    await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name:
            'cards_print_${DateTime.now().millisecondsSinceEpoch}.pdf');
    _play('success');
    _showToast('تم إرسال ملف الطباعة بنجاح');
  }

  Future<void> _archivePrintedCards(
      List<Map<String, dynamic>> cards) async {
    if (_selectedPrintNetworkId == null ||
        _selectedPrintCategoryId == null) return;
    final WriteBatch batch = _db.batch();

    for (var card in cards) {
      final querySnap = await _db
          .collection('cards')
          .where('pin', isEqualTo: card['pin'])
          .where('categoryId',
              isEqualTo: _selectedPrintCategoryId)
          .where('status', isEqualTo: 'print_ready')
          .limit(1)
          .get();
      if (querySnap.docs.isNotEmpty) {
        batch.update(querySnap.docs.first.reference,
            {'status': 'archived'});
      }
    }

    final netDoc = await _db
        .collection('networks')
        .doc(_selectedPrintNetworkId)
        .get();
    List cats =
        List.from((netDoc.data() as Map)['categories']);
    int idx = cats.indexWhere(
        (c) => c['id'] == _selectedPrintCategoryId);
    if (idx != -1) {
      cats[idx]['stock'] =
          (cats[idx]['stock'] ?? 0) - cards.length;
      batch.update(
          _db.collection('networks').doc(_selectedPrintNetworkId),
          {'categories': cats});
    }

    await batch.commit();
    _showToast('تمت أرشفة ${cards.length} كرت بنجاح');
  }
}
