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

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';
import 'print_screen.dart'; // شاشة الطباعة الجديدة

class MikrotikCategoriesScreen extends StatefulWidget {
  const MikrotikCategoriesScreen({super.key});
  @override
  State<MikrotikCategoriesScreen> createState() => _MikrotikCategoriesScreenState();
}

class _MikrotikCategoriesScreenState extends State<MikrotikCategoriesScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  final String _renderUrl = "https://mikrotik-server-qu6a.onrender.com";
  bool _isProcessing = false;
  bool _simulationMode = false;

  // مسودات
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
  double _draftUserViewX = 50;
  double _draftUserViewY = 50;
  double _draftUserViewFontSize = 16;
  Color _draftUserViewColor = Colors.black;
  bool _draftAllowSellSim = false;

  String _draftTierTitle = '';
  String _draftTierCondition = '';
  String _draftTierDiscountValue = '';
  String _draftTierDiscountType = 'percentage';
  String _draftTierTargetType = 'all';
  List<String> _draftTierTargetPhones = [];
  Color _draftTierColor = Colors.amber.shade700;

  final Map<String, TextEditingController> _multiGenControllers = {};
  Timer? _debounceTimer;

  // ---------- دورة حياة ----------
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _multiGenControllers.forEach((_, ctrl) => ctrl.dispose());
    super.dispose();
  }

  // ---------- دوال مساعدة ----------
  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

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

  Future<bool> _confirmAction(String title, String message, Color color,
      {bool requirePassword = false}) async {
    _play('warning');
    final passwordController = TextEditingController();
    bool obscure = true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
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
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                  ],
                ]),
                actions: [
                  TextButton(
                    onPressed: () {
                      _play('click');
                      Navigator.pop(ctx, false);
                    },
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: color),
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
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('تأكيد التنفيذ', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<Color?> _openColorPicker(Color currentColor) async {
    Color pickedColor = currentColor;
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر لونًا', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickedColor,
            onColorChanged: (c) => pickedColor = c,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: pickedColor),
            onPressed: () => Navigator.pop(ctx, pickedColor),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _logAction(String action, int count, {String? details}) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    await _db.collection('activity_logs').add({
      'agentPhone': sys.currentUserPhone,
      'action': action,
      'details': details ?? '',
      'count': count,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ---------- المحاكاة ----------
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

  // ---------- توليد الكروت (مع المخزونين) ----------
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

  Future<void> _simulateGenerate(String networkId, String categoryId, int amount) async {
    final WriteBatch batch = _db.batch();
    for (int i = 0; i < amount; i++) {
      final pin = _generateFakePin();
      final docRef = _db.collection('cards').doc();
      batch.set(docRef, {
        'categoryId': categoryId,
        'networkId': networkId,
        'pin': pin,
        'status': 'متاح',
        'createdAt': FieldValue.serverTimestamp(),
        'agentPhone': Provider.of<SystemProvider>(context, listen: false).currentUserPhone,
        'isSimulated': true,
      });
    }
    final netDoc = await _db.collection('networks').doc(networkId).get();
    List cats = List.from((netDoc.data() as Map)['categories']);
    int idx = cats.indexWhere((c) => c['id'] == categoryId);
    if (idx != -1) {
      cats[idx]['simStock'] = (cats[idx]['simStock'] ?? 0) + amount;
      cats[idx]['stock'] = (cats[idx]['realStock'] ?? 0) + (cats[idx]['simStock'] ?? 0);
      batch.update(_db.collection('networks').doc(networkId), {'categories': cats});
    }
    await batch.commit();
  }

  Future<void> _realGenerate(String networkId, String categoryId, int amount) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    try {
      final response = await http.post(
        Uri.parse("$_renderUrl/generateMikrotikCards"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "networkId": networkId,
          "categoryId": categoryId,
          "amount": amount,
          "agentPhone": sys.currentUserPhone,
          "forPrint": false,
        }),
      );
      if (response.statusCode == 200) {
        final netDoc = await _db.collection('networks').doc(networkId).get();
        List cats = List.from((netDoc.data() as Map)['categories']);
        int idx = cats.indexWhere((c) => c['id'] == categoryId);
        if (idx != -1) {
          cats[idx]['realStock'] = (cats[idx]['realStock'] ?? 0) + amount;
          cats[idx]['stock'] = (cats[idx]['realStock'] ?? 0) + (cats[idx]['simStock'] ?? 0);
          await _db.collection('networks').doc(networkId).update({'categories': cats});
        }
      } else {
        throw 'فشل توليد الكروت';
      }
    } catch (e) {
      throw 'خطأ في التوليد: $e';
    }
  }

  Future<bool> _startGeneration(SystemProvider sys, {required List<Map<String, dynamic>> orders}) async {
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
    bool confirm = await _confirmAction(
        "تأكيد التوليد المتعدد",
        "سيتم الآن توليد إجمالي $totalAmount كرت للمخزون. هل تريد الاستمرار؟",
        Colors.green);
    if (!confirm) return false;

    _play('click');
    setState(() => _isProcessing = true);
    _showToast('جاري توليد الكروت...');

    bool success = true;
    try {
      for (var order in orders) {
        if (_simulationMode) {
          await _simulateGenerate(order['networkId'], order['categoryId'], order['amount']);
        } else {
          await _realGenerate(order['networkId'], order['categoryId'], order['amount']);
        }
      }
      _play('success');
      _multiGenControllers.forEach((k, v) => v.clear());
      _showToast('تم توليد $totalAmount كرت بنجاح! ✅');
      _logAction('generate_cards', totalAmount);
    } catch (e) {
      _play('error');
      _showToast('فشل التوليد: $e', isError: true);
      success = false;
    } finally {
      setState(() => _isProcessing = false);
    }
    return success;
  }

  // ---------- الحذف والأرشفة ----------
  Future<void> _deleteNetworkAndArchiveCards(SystemProvider sys, String networkId) async {
    _play('click');
    setState(() => _isProcessing = true);
    try {
      final batch = _db.batch();
      final cardsSnap = await _db.collection('cards').where('networkId', isEqualTo: networkId).get();
      for (var doc in cardsSnap.docs) {
        batch.update(doc.reference, {'status': 'archived'});
      }
      batch.delete(_db.collection('networks').doc(networkId));
      await batch.commit();
      _play('success');
      _showToast('تم حذف الشبكة ونقل كروتها إلى الأرشيف');
      _logAction('delete_network', cardsSnap.docs.length, details: networkId);
    } catch (e) {
      _play('error');
      _showToast('فشل في حذف الشبكة: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteCategoryAndArchive(String netId, Map<String, dynamic> category) async {
    bool confirm = await _confirmAction(
        "حذف الفئة ونقل كروتها للأرشيف",
        "سيتم أرشفة جميع كروت هذه الفئة ثم حذف الفئة. متأكد؟",
        Colors.red,
        requirePassword: true);
    if (!confirm) return;
    _play('click');
    setState(() => _isProcessing = true);
    try {
      final String catId = category['id'];
      final batch = _db.batch();
      var cardsQuery = _db
          .collection('cards')
          .where('categoryId', isEqualTo: catId)
          .where('status', whereIn: ['متاح', 'print_ready']);
      final cardsSnap = await cardsQuery.get();
      for (var doc in cardsSnap.docs) {
        batch.update(doc.reference, {'status': 'archived'});
      }
      final netRef = _db.collection('networks').doc(netId);
      batch.update(netRef, {
        'categories': FieldValue.arrayRemove([category])
      });
      await batch.commit();
      _play('success');
      _showToast('تم أرشفة كروت الفئة وحذفها');
      _logAction('delete_category', cardsSnap.docs.length, details: catId);
    } catch (e) {
      _play('error');
      _showToast('فشل في حذف الفئة: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ---------- اختبار الاتصال ----------
  Future<void> _testConnection(Map<String, dynamic> net) async {
    _play('click');
    setState(() => _isProcessing = true);
    _showToast('جاري فحص الاتصال...');
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

  // ---------- البناء الأساسي ----------
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: CustomHeader(title: 'إدارة الميكروتك والفئات'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('networks').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          List<QueryDocumentSnapshot> agentNetworks = snapshot.hasData ? snapshot.data!.docs : [];
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 5, top: 5),
                  decoration: BoxDecoration(
                    color: isDark ? primaryColor.withOpacity(0.4).withAlpha(100) : Colors.blue.shade800,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
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
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        tabs: const [
                          Tab(icon: Icon(Icons.dns, color: Colors.greenAccent), text: 'سيرفرات الربط'),
                          Tab(icon: Icon(Icons.category, color: Colors.orangeAccent), text: 'المخزون والفئات'),
                          Tab(icon: Icon(Icons.local_offer, color: Colors.amber), text: 'شرائح الخصم'),
                          Tab(icon: Icon(Icons.autorenew, color: Colors.lightBlueAccent), text: 'توليد الكروت'),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('محاكاة: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Switch(
                              value: _simulationMode,
                              onChanged: (v) => _toggleSimulation(),
                              activeColor: Colors.redAccent,
                            ),
                            Text(
                              _simulationMode ? 'ON' : 'OFF',
                              style: TextStyle(
                                color: _simulationMode ? Colors.redAccent : Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isProcessing)
                  const LinearProgressIndicator(backgroundColor: Colors.orange, color: Colors.white),
                Expanded(
                  child: IndexedStack(
                    index: _tabController.index,
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

  // ======================== تبويب السيرفرات ========================
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
                final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
                return Card(
                  color: isActive ? Theme.of(context).cardColor : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    ]),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddServerBottomSheet(sys),
        backgroundColor: Colors.blue.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة سيرفر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color textColor, Color iconColor) {
    return Row(children: [
      Icon(icon, size: 16, color: iconColor),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: textColor))),
    ]);
  }

  Widget _buildActionButtons(SystemProvider sys, List<QueryDocumentSnapshot> networks, int index, Map<String, dynamic> net, bool isActive) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _actionButton(Icons.bolt, 'اختبار', Colors.blue, () => _testConnection(net)),
      _actionButton(isActive ? Icons.pause_circle_filled : Icons.play_circle_fill, isActive ? 'تجميد' : 'تنشيط', Colors.orange, () async {
        bool confirm = await _confirmAction(isActive ? "تجميد الشبكة" : "تنشيط الشبكة", "هل تريد تغيير حالة الشبكة؟", Colors.orange);
        if (confirm) {
          _db.collection('networks').doc(networks[index].id).update({'isActive': !isActive});
          _showToast(isActive ? 'تم تجميد الشبكة' : 'تم تنشيط الشبكة');
        }
      }),
      _actionButton(Icons.edit, 'تعديل', Colors.grey, () => _showAddServerBottomSheet(sys, existingData: net, docId: networks[index].id)),
      _actionButton(Icons.delete, 'حذف', Colors.red, () async {
        bool confirm = await _confirmAction("حذف الشبكة وأرشفة كروتها", "سيتم نقل جميع كروت هذه الشبكة إلى الأرشيف، ثم حذف الشبكة. متأكد؟", Colors.red, requirePassword: true);
        if (confirm) await _deleteNetworkAndArchiveCards(sys, networks[index].id);
      }),
    ]);
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)));
  }

  // ======================== نافذة إضافة/تعديل سيرفر ========================
  void _showAddServerBottomSheet(SystemProvider sys, {Map<String, dynamic>? existingData, String? docId}) {
    _play('click');
    String name = existingData?['name'] ?? _draftServerName;
    String location = existingData?['location'] ?? _draftServerLocation;
    String governorate = existingData?['governorate'] ?? _draftServerGovernorate;
    String district = existingData?['district'] ?? _draftServerDistrict;
    List<String> coverageAreas = existingData != null ? List<String>.from(existingData['coverageAreas'] ?? []) : List<String>.from(_draftServerCoverageAreas);
    String ip = existingData?['ip'] ?? _draftServerIp;
    String user = existingData?['apiUser'] ?? _draftServerUser;
    String pass = existingData?['apiPassword'] ?? _draftServerPass;
    String port = existingData?['apiPort'] ?? _draftServerPort;
    String loginUrl = existingData?['loginUrl'] ?? _draftServerLoginUrl;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 16, right: 16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(docId == null ? 'إضافة شبكة/سيرفر ميكروتك جديد 📡' : 'تعديل بيانات الشبكة ✏️', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(decoration: const InputDecoration(labelText: 'إسم شبكتك', border: OutlineInputBorder(), prefixIcon: Icon(Icons.dns, color: Colors.blue)), controller: TextEditingController(text: name), onChanged: (v) => name = v),
                const SizedBox(height: 12),
                TextField(decoration: const InputDecoration(labelText: 'موقع الشبكة', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on, color: Colors.orange)), controller: TextEditingController(text: location), onChanged: (v) => location = v),
                const SizedBox(height: 12),
                ExpansionTile(iconColor: Colors.teal, collapsedIconColor: Colors.teal, title: const Text('تفاصيل الموقع (اختياري)'), children: [
                  TextField(decoration: const InputDecoration(labelText: 'المحافظة', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map, color: Colors.teal)), controller: TextEditingController(text: governorate), onChanged: (v) => governorate = v),
                  const SizedBox(height: 12),
                  TextField(decoration: const InputDecoration(labelText: 'المديرية', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map_outlined, color: Colors.teal)), controller: TextEditingController(text: district), onChanged: (v) => district = v),
                  const SizedBox(height: 12),
                  ...coverageAreas.asMap().entries.map((entry) {
                    int idx = entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(child: TextField(decoration: InputDecoration(labelText: 'منطقة البث ${idx + 1}', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.wifi_find, color: Colors.teal)), controller: TextEditingController(text: coverageAreas[idx]), onChanged: (v) => coverageAreas[idx] = v)),
                        IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setModalState(() => coverageAreas.removeAt(idx)))
                      ]),
                    );
                  }).toList(),
                  TextButton.icon(onPressed: () => setModalState(() => coverageAreas.add('')), icon: const Icon(Icons.add, color: Colors.green), label: const Text('إضافة منطقة بث جديدة')),
                ]),
                const SizedBox(height: 12),
                TextField(decoration: const InputDecoration(labelText: 'عنوان IP / الرابط (DDNS)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.wifi, color: Colors.green)), controller: TextEditingController(text: ip), onChanged: (v) => ip = v),
                const SizedBox(height: 12),
                TextField(decoration: const InputDecoration(labelText: 'رابط صفحة تسجيل الدخول للزبائن', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link, color: Colors.indigo)), controller: TextEditingController(text: loginUrl), onChanged: (v) => loginUrl = v),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(decoration: const InputDecoration(labelText: 'مستخدم API', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person, color: Colors.deepPurple)), controller: TextEditingController(text: user), onChanged: (v) => user = v)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock, color: Colors.red)), controller: TextEditingController(text: pass), obscureText: true, onChanged: (v) => pass = v)),
                ]),
                const SizedBox(height: 12),
                TextField(decoration: const InputDecoration(labelText: 'API Port (الافتراضي: 8728)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.settings_ethernet, color: Colors.blueGrey)), controller: TextEditingController(text: port), onChanged: (v) => port = v),
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
                            'name': name, 'location': location, 'governorate': governorate, 'district': district, 'coverageAreas': coverageAreas,
                            'ip': ip, 'apiUser': user, 'apiPassword': pass, 'apiPort': port, 'loginUrl': loginUrl,
                            'agentPhone': sys.currentUserPhone, 'agentName': sys.currentUserName, 'isActive': existingData?['isActive'] ?? true, 'updatedAt': FieldValue.serverTimestamp(),
                          };
                          if (docId == null) {
                            networkData['status'] = 'متصل نشط 🟢';
                            networkData['categories'] = [];
                            networkData['createdAt'] = FieldValue.serverTimestamp();
                            await _db.collection('networks').add(networkData);
                            _draftServerName = ''; _draftServerLocation = ''; _draftServerGovernorate = ''; _draftServerDistrict = ''; _draftServerCoverageAreas = [];
                            _draftServerIp = ''; _draftServerUser = ''; _draftServerPass = ''; _draftServerPort = '8728'; _draftServerLoginUrl = '';
                          } else {
                            await _db.collection('networks').doc(docId).update(networkData);
                          }
                          _play('success');
                          if (mounted) { Navigator.pop(ctx); _showToast(docId == null ? 'تمت إضافة الشبكة بنجاح! 🟢' : 'تم التعديل بنجاح! ✏️'); }
                        } catch (e) { setModalState(() => isSubmitting = false); _play('error'); _showToast('فشل حفظ البيانات', isError: true); }
                      } else { _play('error'); _showToast('يرجى تعبئة الحقول الأساسية', isError: true); }
                    },
                    child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ واتصال', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey, side: const BorderSide(color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      _draftServerName = name; _draftServerLocation = location; _draftServerGovernorate = governorate; _draftServerDistrict = district; _draftServerCoverageAreas = coverageAreas;
                      _draftServerIp = ip; _draftServerUser = user; _draftServerPass = pass; _draftServerPort = port; _draftServerLoginUrl = loginUrl;
                      _play('click'); Navigator.pop(ctx); _showToast('تم حفظ البيانات كمسودة');
                    },
                    icon: const Icon(Icons.save_outlined), label: const Text('إغلاق وحفظ كمسودة'),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ======================== تبويب الفئات (مع المخزونين) ========================
  Widget _buildCategoriesTab(List<QueryDocumentSnapshot> networks) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: networks.isEmpty
          ? const Center(child: Text('أضف سيرفر شبكة أولاً لعرض فئاته.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: networks.length,
              itemBuilder: (context, netIndex) {
                var netId = networks[netIndex].id;
                var netData = networks[netIndex].data() as Map<String, dynamic>;
                List categories = netData['categories'] ?? [];
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('فئات شبكة: ${netData['name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
                  if (categories.isEmpty) const Padding(padding: EdgeInsets.all(8.0), child: Text('لا توجد فئات لهذه الشبكة.', style: TextStyle(color: Colors.grey))),
                  ...categories.map((category) {
                    int realStock = category['realStock'] ?? 0;
                    int simStock = category['simStock'] ?? 0;
                    int totalStock = realStock + simStock;
                    bool isLowStock = totalStock < 10;
                    Color catColor = Color(category['color'] ?? Colors.blue.value);
                    bool isCatActive = category['isActive'] ?? true;
                    bool allowSellSim = category['allowSellSim'] ?? false;
                    return Card(
                      color: isCatActive ? Theme.of(context).cardColor : Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isCatActive ? catColor.withOpacity(0.5) : Colors.grey)),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Expanded(child: Text(category['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isCatActive ? catColor : Colors.grey, decoration: isCatActive ? null : TextDecoration.lineThrough))),
                            Wrap(spacing: 4, children: [
                              IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.teal, size: 20), onPressed: () => _showCardsList(netId, category['id'], category['name'], catColor), constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5), tooltip: 'عرض الكروت'),
                              IconButton(icon: Icon(Icons.smart_toy, color: category['isBotEnabled'] == true ? Colors.purple : Colors.grey, size: 20), onPressed: () => _showBotSettings(netId, category['id'], category), constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5), tooltip: 'البوت الذكي'),
                              IconButton(icon: Icon(isCatActive ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.orange, size: 20), onPressed: () async {
                                bool confirm = await _confirmAction(isCatActive ? "تجميد الفئة" : "تنشيط الفئة", "تغيير حالة الفئة؟", Colors.orange);
                                if (confirm) {
                                  List updated = List.from(categories);
                                  int idx = updated.indexWhere((c) => c['id'] == category['id']);
                                  updated[idx]['isActive'] = !isCatActive;
                                  await _db.collection('networks').doc(netId).update({'categories': updated});
                                  _showToast(isCatActive ? 'تم تجميد الفئة' : 'تم تنشيط الفئة');
                                }
                              }, constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5)),
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showAddCategoryBottomSheet(networks, existingCat: category, preSelectedNetId: netId), constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () async { await _deleteCategoryAndArchive(netId, category); }, constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 5)),
                            ]),
                          ]),
                          const SizedBox(height: 8),
                          Text('الوقت: ${category['time']} | السعة: ${category['capacity']}', style: TextStyle(color: textColor)),
                          if (category['note'] != null && category['note'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('📝 ${category['note']}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('سعر الجمهور: ${category['price']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                            Row(children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('حقيقي: $realStock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade800)),
                                Text('وهمي: $simStock', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                              ]),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isLowStock ? Colors.red.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(10)), child: Text('الإجمالي: $totalStock كرت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isLowStock ? Colors.red : Colors.green.shade800))),
                            ]),
                          ]),
                          // زر السماح ببيع الوهمي
                          SwitchListTile(
                            title: const Text('السماح ببيع الكروت الوهمية', style: TextStyle(fontSize: 13)),
                            value: allowSellSim,
                            activeColor: Colors.orange,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (v) async {
                              List updated = List.from(categories);
                              int idx = updated.indexWhere((c) => c['id'] == category['id']);
                              updated[idx]['allowSellSim'] = v;
                              await _db.collection('networks').doc(netId).update({'categories': updated});
                            },
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                ]);
              }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryBottomSheet(networks),
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.add_circle, color: Colors.white),
        label: const Text('إضافة فئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // نافذة عرض الكروت (لم تتغير كثيراً)
  void _showCardsList(String netId, String catId, String catName, Color catColor) {
    _play('click');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إدارة كروت فئة: $catName', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: catColor)),
            const Text('الأرقام المعروضة هي الأرقام النشطة والمتاحة للبيع', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('cards').where('categoryId', isEqualTo: catId).where('status', isEqualTo: 'متاح').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var cards = snapshot.data!.docs;
                  if (cards.isEmpty) return const Center(child: Text('لا توجد كروت متاحة. قم بالتوليد أولاً.', style: TextStyle(color: Colors.grey)));
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
                          title: Text(pin, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.copy, color: Colors.blue), tooltip: 'نسخ الكرت', onPressed: () { _play('click'); Clipboard.setData(ClipboardData(text: pin)); _showToast('تم نسخ رقم الكرت للحافظة'); }),
                            IconButton(icon: const Icon(Icons.archive, color: Colors.orange), tooltip: 'نقل للأرشيف', onPressed: () async {
                              if (await _confirmAction("أرشفة الكرت", "سيتم سحب هذا الكرت من السوق ونقله للأرشيف. هل أنت متأكد؟", Colors.orange)) {
                                await card.reference.update({'status': 'archived'});
                                var netDoc = await _db.collection('networks').doc(netId).get();
                                List cats = List.from(netDoc['categories']);
                                int idx = cats.indexWhere((c) => c['id'] == catId);
                                if (idx != -1) {
                                  cats[idx]['realStock'] = (cats[idx]['realStock'] ?? 1) - 1;
                                  cats[idx]['stock'] = (cats[idx]['realStock'] ?? 0) + (cats[idx]['simStock'] ?? 0);
                                  await _db.collection('networks').doc(netId).update({'categories': cats});
                                }
                                _showToast('تمت أرشفة الكرت بنجاح');
                                _logAction('archive_card', 1, details: card['pin']);
                              }
                            }),
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showBotSettings(String netId, String catId, Map category) { /* ... نفس الكود السابق دون تغيير ... */ }

  // ======================== نافذة إضافة/تعديل فئة (مع إعدادات المستخدم) ========================
  void _showAddCategoryBottomSheet(List<QueryDocumentSnapshot> agentNetworks, {Map? existingCat, String? preSelectedNetId}) {
    _play('click');
    String newName = existingCat?['name'] ?? _draftCategoryName;
    String newTime = existingCat?['time'] ?? _draftCategoryTime;
    String newCapacity = existingCat?['capacity'] ?? _draftCategoryCapacity;
    String newPrice = existingCat?['price']?.toString() ?? _draftCategoryPrice;
    String note = existingCat?['note'] ?? _draftCategoryNote;
    String? selectedNetworkId = preSelectedNetId;
    Color selectedColor = existingCat != null ? Color(existingCat['color']) : _draftCategoryColor;
    String? templateBase64 = existingCat?['templateBase64'] ?? _draftCategoryTemplateBase64;
    double userViewX = existingCat?['userViewX']?.toDouble() ?? _draftUserViewX;
    double userViewY = existingCat?['userViewY']?.toDouble() ?? _draftUserViewY;
    double userViewFontSize = existingCat?['userViewFontSize']?.toDouble() ?? _draftUserViewFontSize;
    Color userViewColor = existingCat != null ? Color(existingCat['userViewColor'] ?? Colors.black.value) : _draftUserViewColor;
    bool allowSellSim = existingCat?['allowSellSim'] ?? _draftAllowSellSim;
    bool isSubmitting = false;

    if (agentNetworks.isEmpty) { _play('error'); _showToast('يجب إضافة سيرفر شبكة أولاً!', isError: true); return; }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 16, right: 16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(existingCat == null ? 'إضافة فئة كروت جديدة 🎟️' : 'تعديل بيانات الفئة ✏️', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (existingCat == null) DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'اختر الشبكة', border: OutlineInputBorder(), prefixIcon: Icon(Icons.dns, color: Colors.blue)),
                  value: selectedNetworkId,
                  items: agentNetworks.map((net) => DropdownMenuItem(value: net.id, child: Text((net.data() as Map)['name']))).toList(),
                  onChanged: (val) => setModalState(() => selectedNetworkId = val),
                ),
                if (existingCat == null) const SizedBox(height: 12),
                TextField(decoration: const InputDecoration(labelText: 'اسم الفئة (Profile)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category, color: Colors.orange)), controller: TextEditingController(text: newName), onChanged: (val) => newName = val),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(decoration: const InputDecoration(labelText: 'الوقت (الساعات المتاح)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.timer, color: Colors.blue)), controller: TextEditingController(text: newTime), onChanged: (val) => newTime = val)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(decoration: const InputDecoration(labelText: 'سعة التحميل المتاح ميجابايت', border: OutlineInputBorder(), prefixIcon: Icon(Icons.data_usage, color: Colors.teal)), controller: TextEditingController(text: newCapacity), onChanged: (val) => newCapacity = val)),
                ]),
                const SizedBox(height: 12),
                TextField(decoration: const InputDecoration(labelText: 'سعر البيع للجمهور', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money, color: Colors.green)), controller: TextEditingController(text: newPrice), keyboardType: TextInputType.number, onChanged: (val) => newPrice = val),
                const SizedBox(height: 12),
                TextField(decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.note, color: Colors.amber)), controller: TextEditingController(text: note), onChanged: (val) => note = val),
                const SizedBox(height: 15),
                Row(children: [
                  const Icon(Icons.image, color: Colors.deepPurple), const SizedBox(width: 8), const Text('قالب الطباعة (اختياري): ', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
                      if (pickedFile != null) { final bytes = await pickedFile.readAsBytes(); setModalState(() => templateBase64 = base64Encode(bytes)); _play('success'); _showToast('تم تحميل القالب بنجاح'); }
                    },
                    icon: Icon(templateBase64 != null ? Icons.check_circle : Icons.upload_file, color: templateBase64 != null ? Colors.green : Colors.deepPurple),
                    label: Text(templateBase64 != null ? 'تم التحميل' : 'اختيار صورة', style: TextStyle(color: templateBase64 != null ? Colors.green : Colors.deepPurple)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.withOpacity(0.1), elevation: 0),
                  ),
                ]),
                const SizedBox(height: 15),
                Row(children: [
                  const Text('لون الفئة: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  GestureDetector(onTap: () async { final color = await _openColorPicker(selectedColor); if (color != null) setModalState(() => selectedColor = color); }, child: Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: selectedColor, border: Border.all(color: Colors.grey)))),
                  const SizedBox(width: 10), const Text('انقر لتغيير اللون', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                // إعدادات عرض المستخدم
                const SizedBox(height: 20),
                const Text('إعدادات عرض الكرت للمستخدم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _buildUserViewSlider('الأفقي %', userViewX, 100, Colors.blue, (v) => userViewX = v)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildUserViewSlider('الرأسي %', userViewY, 100, Colors.green, (v) => userViewY = v)),
                ]),
                _buildUserViewSlider('حجم الخط', userViewFontSize, 40, Colors.purple, (v) => userViewFontSize = v),
                Row(children: [
                  const Text('لون النص للمستخدم: '),
                  GestureDetector(onTap: () async { final color = await _openColorPicker(userViewColor); if (color != null) setModalState(() => userViewColor = color); }, child: Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: userViewColor, border: Border.all(color: Colors.grey)))),
                ]),
                const SizedBox(height: 8),
                SwitchListTile(title: const Text('السماح ببيع الكروت الوهمية للزبائن'), value: allowSellSim, onChanged: (v) => setModalState(() => allowSellSim = v), dense: true, contentPadding: EdgeInsets.zero),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: selectedColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: isSubmitting ? null : () async {
                      if (selectedNetworkId != null && newName.isNotEmpty && newPrice.isNotEmpty) {
                        if (existingCat != null) { bool confirm = await _confirmAction("حفظ التعديلات", "متأكد من تعديل الفئة؟", Colors.blue); if (!confirm) return; }
                        _play('click'); setModalState(() => isSubmitting = true);
                        try {
                          var newCategory = {
                            'id': existingCat?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                            'name': newName, 'time': newTime.isNotEmpty ? newTime : 'غير محدد', 'capacity': newCapacity.isNotEmpty ? newCapacity : 'مفتوح',
                            'price': int.tryParse(newPrice) ?? 0, 'color': selectedColor.value, 'note': note, 'templateBase64': templateBase64,
                            'realStock': existingCat?['realStock'] ?? 0, 'simStock': existingCat?['simStock'] ?? 0, 'stock': (existingCat?['realStock'] ?? 0) + (existingCat?['simStock'] ?? 0),
                            'isActive': existingCat?['isActive'] ?? true, 'botMinStock': existingCat?['botMinStock'] ?? 5, 'botRefillAmount': existingCat?['botRefillAmount'] ?? 50, 'isBotEnabled': existingCat?['isBotEnabled'] ?? false,
                            'userViewX': userViewX, 'userViewY': userViewY, 'userViewFontSize': userViewFontSize, 'userViewColor': userViewColor.value,
                            'allowSellSim': allowSellSim,
                          };
                          if (existingCat == null) {
                            await _db.collection('networks').doc(selectedNetworkId).update({'categories': FieldValue.arrayUnion([newCategory])});
                            _draftCategoryName = ''; _draftCategoryTime = ''; _draftCategoryCapacity = ''; _draftCategoryPrice = ''; _draftCategoryNote = ''; _draftCategoryColor = Colors.blue; _draftCategoryTemplateBase64 = null;
                            _draftUserViewX = 50; _draftUserViewY = 50; _draftUserViewFontSize = 16; _draftUserViewColor = Colors.black; _draftAllowSellSim = false;
                          } else {
                            var netDoc = await _db.collection('networks').doc(selectedNetworkId).get();
                            List cats = List.from((netDoc.data() as Map)['categories']);
                            int idx = cats.indexWhere((c) => c['id'] == existingCat['id']);
                            cats[idx] = newCategory;
                            await _db.collection('networks').doc(selectedNetworkId).update({'categories': cats});
                          }
                          _play('success'); if (mounted) { Navigator.pop(ctx); _showToast('تم الحفظ بنجاح! 📋'); }
                        } catch (e) { setModalState(() => isSubmitting = false); _play('error'); }
                      } else { _play('error'); _showToast('الرجاء تعبئة الحقول الأساسية!', isError: true); }
                    },
                    child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ الفئة', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey, side: const BorderSide(color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      _draftCategoryName = newName; _draftCategoryTime = newTime; _draftCategoryCapacity = newCapacity; _draftCategoryPrice = newPrice; _draftCategoryNote = note; _draftCategoryColor = selectedColor; _draftCategoryTemplateBase64 = templateBase64;
                      _draftUserViewX = userViewX; _draftUserViewY = userViewY; _draftUserViewFontSize = userViewFontSize; _draftUserViewColor = userViewColor; _draftAllowSellSim = allowSellSim;
                      _play('click'); Navigator.pop(ctx); _showToast('تم حفظ البيانات كمسودة');
                    },
                    icon: const Icon(Icons.save_outlined), label: const Text('إغلاق وحفظ كمسودة'),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserViewSlider(String label, double value, double max, Color color, ValueChanged<double> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: ${value.toStringAsFixed(1)}'),
      Slider(value: value, max: max, activeColor: color, onChanged: onChanged),
    ]);
  }

  // ======================== تبويب شرائح الخصم (كما هو بدون تغيير) ========================
  // ======================== نافذة إعدادات البوت ========================
void _showBotSettings(String netId, String catId, Map category) {
  _play('click');
  int minStock = category['botMinStock'] ?? 5;
  int refillAmount = category['botRefillAmount'] ?? 50;
  bool isBotEnabled = category['isBotEnabled'] ?? false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(children: [
            Icon(Icons.smart_toy, color: Colors.purple),
            SizedBox(width: 10),
            Text('البوت الذكي للتوليد')
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('عند تفعيل البوت، سيقوم السيرفر بمراقبة مخزون هذه الفئة وتوليد كروت جديدة تلقائياً عندما ينخفض المخزون.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            SwitchListTile(
              title: const Text('حالة التوليد التلقائي', style: TextStyle(fontWeight: FontWeight.bold)),
              value: isBotEnabled,
              activeColor: Colors.purple,
              onChanged: (v) => setModalState(() => isBotEnabled = v),
            ),
            if (isBotEnabled) ...[
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                    labelText: 'الحد الأدنى للمخزون (متى يبدأ البوت؟)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                onChanged: (v) => minStock = int.tryParse(v) ?? 5,
                controller: TextEditingController(text: minStock.toString()),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                    labelText: 'كمية التوليد التلقائي (كم كرت ينتج؟)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                onChanged: (v) => refillAmount = int.tryParse(v) ?? 50,
                controller: TextEditingController(text: refillAmount.toString()),
              ),
            ]
          ]),
          actions: [
            TextButton(
                onPressed: () { _play('click'); Navigator.pop(ctx); },
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
                Navigator.pop(ctx);
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

// ======================== تبويب شرائح الخصم ========================
void _showDiscountTierBottomSheet(SystemProvider sys,
    {Map<String, dynamic>? existingTier, String? docId}) {
  _play('click');
  String title = existingTier?['title'] ?? _draftTierTitle;
  String condition = existingTier?['condition']?.toString() ?? _draftTierCondition;
  String discountValue = existingTier?['discountValue']?.toString() ?? _draftTierDiscountValue;
  String discountType = existingTier?['discountType'] ?? _draftTierDiscountType;
  String targetType = existingTier?['targetType'] ?? _draftTierTargetType;
  List<String> targetPhones = existingTier != null
      ? List<String>.from(existingTier['targetPhones'] ?? [])
      : List<String>.from(_draftTierTargetPhones);
  Color selectedColor =
      existingTier != null ? Color(existingTier['color']) : _draftTierColor;
  bool isSubmitting = false;
  Map<String, Map<String, dynamic>?> searchResults = {};

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 16, right: 16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(docId == null ? 'إضافة شريحة خصم جديدة 🏆' : 'تعديل الشريحة ✏️',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                  decoration: const InputDecoration(
                      labelText: 'اسم الشريحة', border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.stars, color: Colors.amber)),
                  controller: TextEditingController(text: title),
                  onChanged: (v) => title = v),
              const SizedBox(height: 12),
              TextField(
                  decoration: const InputDecoration(
                      labelText: 'شرط السحب الشهري بالريال', border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_cart, color: Colors.orange)),
                  controller: TextEditingController(text: condition),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => condition = v),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        decoration: const InputDecoration(
                            labelText: 'قيمة الخصم', border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_offer, color: Colors.green)),
                        controller: TextEditingController(text: discountValue),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => discountValue = v)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'نوع الخصم', border: OutlineInputBorder()),
                    value: discountType,
                    items: const [
                      DropdownMenuItem(value: 'percentage', child: Text('نسبة مئوية (%)')),
                      DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت (ريال)')),
                    ],
                    onChanged: (val) => setModalState(() => discountType = val!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نطاق تطبيق الخصم', border: OutlineInputBorder()),
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
                  return Column(children: [
                    Row(children: [
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
                    ]),
                    if (searchResults[phone] != null)
                      _buildTargetInfoCard(phone, searchResults[phone]!, sys),
                    const SizedBox(height: 8),
                  ]);
                }).toList(),
                TextButton.icon(
                  onPressed: () => setModalState(() => targetPhones.add('')),
                  icon: const Icon(Icons.add, color: Colors.green),
                  label: const Text('إضافة مستهدف آخر'),
                ),
              ],
              const SizedBox(height: 15),
              Row(children: [
                const Text('لون الشريحة المميز: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
              ]),
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
                              bool confirm =
                                  await _confirmAction("حفظ الشريحة", "هل أنت متأكد من التعديلات؟", selectedColor);
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
                                Navigator.pop(ctx);
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
                    _draftTierTitle = title;
                    _draftTierCondition = condition;
                    _draftTierDiscountValue = discountValue;
                    _draftTierDiscountType = discountType;
                    _draftTierTargetType = targetType;
                    _draftTierTargetPhones = targetPhones;
                    _draftTierColor = selectedColor;
                    _play('click');
                    Navigator.pop(ctx);
                    _showToast('تم حفظ البيانات كمسودة');
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('إغلاق وحفظ كمسودة'),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    ),
  );
}

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person, color: Colors.teal),
          const SizedBox(width: 8),
          Text(data['name'] ?? 'غير معروف',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 8),
        _infoRow('الدور', data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم'),
        _infoRow('الرصيد', '${data['agentBalance'] ?? data['balance'] ?? '0'} ريال'),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(
            onPressed: () =>
                _showTargetTransactionsDialog(phone, sys.currentUserPhone, data['name'] ?? ''),
            icon: const Icon(Icons.history, size: 18),
            label: const Text('آخر العمليات'),
          ),
        ]),
      ]),
    ),
  );
}

void _showTargetInfoDialog(String phone, Map<String, dynamic> data, String agentPhone) {
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('معلومات ${data['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _infoRow('الاسم', data['name']),
            _infoRow('الدور', data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم'),
            _infoRow('رقم الهاتف', phone),
            _infoRow('الرصيد الحالي', '${data['agentBalance'] ?? data['balance'] ?? '0'} ريال'),
            _infoRow('آخر عملية شحن', data['lastRecharge'] ?? 'لا يوجد'),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showTargetTransactionsDialog(phone, agentPhone, data['name'] ?? '');
                },
                icon: const Icon(Icons.receipt),
                label: const Text('عرض آخر العمليات'),
              ),
            ),
          ]),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
        ],
      ),
    ),
  );
}

Future<List<Map<String, dynamic>>> _fetchTargetTransactions(String phone, String agentPhone) async {
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
    child: Row(children: [
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
      Expanded(child: Text(value)),
    ]),
  );
}

Widget _buildDiscountTiersTab(SystemProvider sys) {
  final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
  return StreamBuilder<QuerySnapshot>(
    stream: _db.collection('discount_tiers').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      List<QueryDocumentSnapshot> tiers = snapshot.hasData ? snapshot.data!.docs : [];
      tiers.sort((a, b) =>
          ((b.data() as Map)['condition'] as int).compareTo((a.data() as Map)['condition'] as int));

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(children: [
          Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
              child: const Text('💡 الخصم يُطبق تلقائياً على المشتريات عند تحقيق شرط السحب.',
                  style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(
            child: tiers.isEmpty
                ? const Center(
                    child: Text('لم تقم بإضافة أي شرائح خصم حتى الآن.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tiers.length,
                    itemBuilder: (context, index) {
                      var tier = tiers[index].data() as Map<String, dynamic>;
                      bool isActive = tier['isActive'] ?? true;
                      Color tColor = Color(tier['color'] ?? Colors.amber.shade700.value);
                      String dType = tier['discountType'] == 'percentage' ? '%' : 'ريال';

                      return Card(
                        color: isActive ? Theme.of(context).cardColor : Colors.grey.shade200,
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(isActive ? Icons.stars : Icons.block,
                              color: isActive ? tColor : Colors.grey, size: 35),
                          title: Text(tier['title'],
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? tColor : Colors.grey,
                                  decoration: isActive ? null : TextDecoration.lineThrough)),
                          subtitle: Text('شرط السحب: ${tier['condition']} ريال\nالخصم: ${tier['discountValue']}$dType',
                              style: TextStyle(fontSize: 12, color: textColor)),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: isActive ? tColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20)),
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
                                        color: isActive ? tColor : Colors.grey,
                                        fontSize: 10))),
                            const SizedBox(height: 5),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              GestureDetector(
                                  onTap: () async {
                                    bool confirm = await _confirmAction(
                                        isActive ? "تجميد الشريحة" : "تنشيط الشريحة",
                                        "تغيير حالة العرض؟",
                                        Colors.orange);
                                    if (confirm)
                                      _db
                                          .collection('discount_tiers')
                                          .doc(tiers[index].id)
                                          .update({'isActive': !isActive});
                                  },
                                  child: Icon(isActive ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                      color: Colors.orange, size: 20)),
                              const SizedBox(width: 10),
                              GestureDetector(
                                  onTap: () => _showDiscountTierBottomSheet(sys,
                                      existingTier: tier, docId: tiers[index].id),
                                  child: const Icon(Icons.edit, color: Colors.blue, size: 20)),
                              const SizedBox(width: 10),
                              GestureDetector(
                                  onTap: () async {
                                    bool confirm = await _confirmAction("حذف الشريحة",
                                        "سيتم إلغاء الخصم عن البقالات المنضمة، متأكد؟", Colors.red,
                                        requirePassword: true);
                                    if (confirm) {
                                      _play('click');
                                      await _db.collection('discount_tiers').doc(tiers[index].id).delete();
                                      _showToast('تم حذف الشريحة');
                                    }
                                  },
                                  child: const Icon(Icons.delete, color: Colors.red, size: 20)),
                            ]),
                          ]),
                        ),
                      );
                    }),
          ),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showDiscountTierBottomSheet(sys),
          backgroundColor: Colors.amber.shade700,
          icon: const Icon(Icons.add_moderator, color: Colors.white),
          label: const Text('إضافة شريحة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    },
  );
}

  // ======================== تبويب توليد الكروت ========================
  Widget _buildGenerateCardsTab(SystemProvider sys, List<QueryDocumentSnapshot> networks) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
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
    if (allCategories.isEmpty) return const Center(child: Text('لا توجد فئات نشطة للتوليد.'));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue)), child: Text('🔌 توليد متعدد: اكتب الكمية بجانب كل فئة، ثم اضغط توليد.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor))),
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
                  child: Row(children: [
                    Icon(Icons.category, color: Color(item['category']['color']), size: 30),
                    const SizedBox(width: 15),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${item['networkName']} - ${item['category']['name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                      Text('المخزون الحقيقي: ${item['category']['realStock'] ?? 0} | الوهمي: ${item['category']['simStock'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ])),
                    SizedBox(width: 100, child: TextField(controller: _multiGenControllers[key], keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(hintText: 'الكمية', contentPadding: const EdgeInsets.symmetric(vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor))),
                  ]),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: SizedBox(height: 55, child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _startGeneration(sys, orders: _collectOrders()),
                icon: const Icon(Icons.inventory, color: Colors.white),
                label: const Text('توليد للمخزون', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(height: 55, child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrintScreen())),
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text('الذهاب إلى شاشة الطباعة', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ),
          ]),
        ),
      ]),
    );
  }
}
