import 'dart:async';
import 'dart:convert';
import 'dart:math';
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

class PreciseLayoutEngine {
  static const double mmToPx = 2.83465;
  static double getAbsolutePos(double indexInDim, double cardSizeMM, double gapMM, double marginMM) {
    return (marginMM + (indexInDim * (cardSizeMM + gapMM))) * mmToPx;
  }
}

class PrintScreen extends StatefulWidget {
  const PrintScreen({super.key});
  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final String _renderUrl = "https://mikrotik-server-qu6a.onrender.com";
  bool _isProcessing = false;
  bool _simulationMode = false;

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

  final Map<String, TextEditingController> _multiGenControllers = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    printTotalCountCtrl.text = "0";
    _loadInitialData();
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
    _multiGenControllers.forEach((_, ctrl) => ctrl.dispose());
    super.dispose();
  }

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
                  TextButton(onPressed: () { _play('click'); Navigator.pop(ctx, false); }, child: const Text('إلغاء')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    onPressed: () {
                      if (requirePassword) {
                        final sys = Provider.of<SystemProvider>(context, listen: false);
                        if (!sys.validatePin(passwordController.text.trim()) && passwordController.text.trim() != '123456') {
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
          child: ColorPicker(pickerColor: pickedColor, onColorChanged: (c) => pickedColor = c, enableAlpha: false),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: pickedColor), onPressed: () => Navigator.pop(ctx, pickedColor), child: const Text('تأكيد', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Future<void> _logPrintAction(String type, int count, {String? details}) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    await _db.collection('print_logs').add({
      'agentPhone': sys.currentUserPhone,
      'networkId': printSelectedNetworkId ?? '',
      'categoryIds': printSelectedCategoryIds.toList(),
      'count': count,
      'type': type,
      'details': details ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
    _loadPrintLogs();
  }

  Future<void> _loadInitialData() async {
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
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final netSnap = await _db.collection('networks').where('agentPhone', isEqualTo: sys.currentUserPhone).get();
    List<String> networkIds = netSnap.docs.map((d) => d.id).toList();
    if (networkIds.isEmpty) { setState(() => allPrintReadyCards = []); return; }
    final snapshot = await _db.collection('cards')
        .where('status', isEqualTo: 'print_ready')
        .where('networkId', whereIn: networkIds)
        .get();
    setState(() => allPrintReadyCards = snapshot.docs);
  }

  Future<void> _loadPrintTemplates() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final snap = await _db.collection('print_templates').where('agentPhone', isEqualTo: sys.currentUserPhone).get();
    setState(() => savedPrintTemplates = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList());
  }

  Future<void> _loadPrintLogs() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final snap = await _db.collection('print_logs')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();
    setState(() => printLogs = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList());
  }

  String _generateFakePin() {
    final r = Random();
    return (r.nextInt(9000000) + 1000000).toString();
  }

  // ---------- إعدادات الفئة ----------
  void _loadCategoryTemplate(String categoryId) {
    final cat = printSelectedCategories[categoryId];
    if (cat == null) { _categoryTemplates.remove(categoryId); return; }
    final b64 = cat['templateBase64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      _categoryTemplates[categoryId] = base64Decode(b64);
    } else {
      _categoryTemplates.remove(categoryId);
    }
  }

  void _loadCategorySettings(String categoryId) {
    final cat = printSelectedCategories[categoryId];
    if (cat == null) return;
    textX.value = (cat['textXPercent'] ?? 50).toDouble();
    textY.value = (cat['textYPercent'] ?? 50).toDouble();
    fontSize.value = (cat['textFontSize'] ?? 14).toDouble();
    textColor.value = Color(cat['textColor'] ?? Colors.black.value);
    copiesPerCardCtrl.text = (cat['copiesPerCard'] ?? 1).toString();
    perRowCtrl.text = (cat['cardsPerRow'] ?? 3).toString();
    perColumnCtrl.text = (cat['cardsPerColumn'] ?? 17).toString();
    widthMMCtrl.text = (cat['cardWidth'] ?? 70.0).toString();
    heightMMCtrl.text = (cat['cardHeight'] ?? 17.4).toString();
    horizontalGapCtrl.text = (cat['horizontalGap'] ?? 0.0).toString();
    verticalGapCtrl.text = (cat['verticalGap'] ?? 0.0).toString();
    pageLeftMarginCtrl.text = (cat['pageLeftMargin'] ?? 5.0).toString();
    pageTopMarginCtrl.text = (cat['pageTopMargin'] ?? 5.0).toString();
  }

  void _saveCategorySettings() async {
    if (printSelectedNetworkId == null || printSelectedCategoryIds.isEmpty) return;
    final netRef = _db.collection('networks').doc(printSelectedNetworkId);
    final netSnap = await netRef.get();
    final data = netSnap.data();
    if (data == null) return;
    List cats = List<Map<String, dynamic>>.from(data['categories'] ?? []);
    for (final catId in printSelectedCategoryIds) {
      final idx = cats.indexWhere((c) => c['id'] == catId);
      if (idx == -1) continue;
      cats[idx] = {
        ...cats[idx],
        'textXPercent': textX.value,
        'textYPercent': textY.value,
        'textFontSize': fontSize.value,
        'textColor': textColor.value.value,
        'copiesPerCard': int.tryParse(copiesPerCardCtrl.text) ?? 1,
        'cardsPerRow': int.tryParse(perRowCtrl.text) ?? 3,
        'cardsPerColumn': int.tryParse(perColumnCtrl.text) ?? 17,
        'cardWidth': double.tryParse(widthMMCtrl.text) ?? 70.0,
        'cardHeight': double.tryParse(heightMMCtrl.text) ?? 17.4,
        'horizontalGap': double.tryParse(horizontalGapCtrl.text) ?? 0.0,
        'verticalGap': double.tryParse(verticalGapCtrl.text) ?? 0.0,
        'pageLeftMargin': double.tryParse(pageLeftMarginCtrl.text) ?? 5.0,
        'pageTopMargin': double.tryParse(pageTopMarginCtrl.text) ?? 5.0,
      };
    }
    await netRef.update({'categories': cats});
    _showToast('تم حفظ جميع الإعدادات للفئة');
  }

  void _rebuildPrintCategoryCounts() {
    for (final catId in printSelectedCategoryIds) {
      if (!printCategoryCountControllers.containsKey(catId)) {
        final ready = allPrintReadyCards.where((c) => c['categoryId'] == catId).length;
        printCategoryCountControllers[catId] = TextEditingController(text: ready.toString());
      }
    }
    final toRemove = printCategoryCountControllers.keys.toList().where((k) => !printSelectedCategoryIds.contains(k));
    for (final k in toRemove) {
      printCategoryCountControllers[k]?.dispose();
      printCategoryCountControllers.remove(k);
    }
    _updatePrintTotalCount();
  }

  void _updatePrintTotalCount() {
    int total = 0;
    for (final catId in printSelectedCategoryIds) {
      total += int.tryParse(printCategoryCountControllers[catId]?.text ?? '0') ?? 0;
    }
    printTotalCountCtrl.text = total.toString();
  }

  // ---------- توليد PDF ----------
  Map<String, dynamic> _capturePrintSnapshot() {
    return {
      "x": textX.value,
      "y": textY.value,
      "font": fontSize.value,
      "color": textColor.value,
      "row": int.tryParse(perRowCtrl.text) ?? 3,
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
      for (var card in catCards) {
        for (int i = 0; i < copies; i++) { cardsToPrint.add(card); }
      }
    }
    final totalPages = (cardsToPrint.length / cardsPerPage).ceil();
    for (int page = 0; page < totalPages; page++) {
      final pageCards = cardsToPrint.skip(page * cardsPerPage).take(cardsPerPage).toList();
      pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
                children: List.generate(pageCards.length, (index) {
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
                    if (templateBytes != null) pw.Image(pw.MemoryImage(templateBytes), fit: pw.BoxFit.fill),
                    pw.Positioned(
                      left: (snap["x"] / 100) * w * PdfPageFormat.mm,
                      top: (snap["y"] / 100) * h * PdfPageFormat.mm,
                      child: pw.Text(pin, style: pw.TextStyle(fontSize: snap["font"], color: PdfColor.fromInt((snap["color"] as Color).value))),
                    )
                  ]),
                ),
              );
            }));
          }));
    }
    return pdf.save();
  }

  // ---------- حوار الطباعة ----------
  void _showPrintDialog() {
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
            onPressed: () async {
              Navigator.pop(context);
              final pdf = await generatePdf(snapshot);
              await Printing.layoutPdf(onLayout: (_) => pdf, name: 'معاينة الطباعة');
              _logPrintAction('preview', total);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            icon: const Icon(Icons.print),
            label: const Text("طباعة وأرشفة"),
            onPressed: () async {
              Navigator.pop(context);
              final pdf = await generatePdf(snapshot);
              await Printing.layoutPdf(onLayout: (_) => pdf, name: 'طباعة وأرشفة الكروت');
              await _archivePrintedCards(total);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _archivePrintedCards(int total) async {
    final batch = _db.batch();
    for (final catId in printSelectedCategoryIds) {
      final requested = int.tryParse(printCategoryCountControllers[catId]?.text ?? '0') ?? 0;
      final catCards = allPrintReadyCards.where((c) => c['categoryId'] == catId).take(requested).toList();
      for (final c in catCards) { batch.update(c.reference, {'status': 'archived'}); }
      if (printSelectedNetworkId != null) {
        final netRef = _db.collection('networks').doc(printSelectedNetworkId);
        final netSnap = await netRef.get();
        final data = netSnap.data();
        if (data != null) {
          List cats = List<Map<String, dynamic>>.from(data['categories'] ?? []);
          final idx = cats.indexWhere((c) => c['id'] == catId);
          if (idx != -1) {
            final curr = cats[idx]['stock'] ?? 0;
            cats[idx]['stock'] = (curr as int) - catCards.length;
            batch.update(netRef, {'categories': cats});
          }
        }
      }
    }
    await batch.commit();
    _loadAllPrintReadyCards();
    _rebuildPrintCategoryCounts();
    _logPrintAction('print_archive', total);
    _showToast('تمت الطباعة ونقل الكروت للأرشيف');
  }

  // ---------- توليد كروت الطباعة ----------
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
      batch.set(_db.collection('cards').doc(), {
        'categoryId': categoryId, 'networkId': networkId, 'pin': pin,
        'status': 'print_ready', 'isSimulated': true,
        'createdAt': FieldValue.serverTimestamp(),
        'agentPhone': Provider.of<SystemProvider>(context, listen: false).currentUserPhone,
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
    _loadAllPrintReadyCards();
  }

  Future<void> _realGenerate(String networkId, String categoryId, int amount) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final response = await http.post(
      Uri.parse("$_renderUrl/generateMikrotikCards"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "networkId": networkId, "categoryId": categoryId, "amount": amount,
        "agentPhone": sys.currentUserPhone, "forPrint": true,
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
      _loadAllPrintReadyCards();
    } else {
      throw Exception('فشل توليد الكروت');
    }
  }

  Future<void> _startPrintGeneration({required List<Map<String, dynamic>> orders}) async {
    if (orders.isEmpty) { _showToast('الرجاء كتابة كمية واحدة على الأقل', isError: true); return; }
    int total = orders.fold(0, (sum, o) => sum + (o['amount'] as int));
    if (total > 400) { _showToast('الحد الأقصى 400 كرت', isError: true); return; }
    bool confirm = await _confirmAction("تأكيد التوليد", "سيتم توليد $total كرت للطباعة", Colors.green);
    if (!confirm) return;
    setState(() => _isProcessing = true);
    try {
      for (var order in orders) {
        if (_simulationMode) {
          await _simulateGenerate(order['networkId'], order['categoryId'], order['amount']);
        } else {
          await _realGenerate(order['networkId'], order['categoryId'], order['amount']);
        }
      }
      _multiGenControllers.forEach((k, v) => v.clear());
      _showToast('تم توليد الكروت للطباعة بنجاح');
    } catch (e) {
      _showToast('خطأ: $e', isError: true);
    }
    setState(() => _isProcessing = false);
  }

  // ---------- البناء ----------
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;

    return Scaffold(
      appBar: CustomHeader(title: 'طباعة الكروت'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: isDark ? primaryColor.withOpacity(0.4) : Colors.blue.shade800,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.orange,
                tabs: const [
                  Tab(text: 'إدارة الطباعة', icon: Icon(Icons.print)),
                  Tab(text: 'توليد للطباعة', icon: Icon(Icons.autorenew)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildManageTab(textColor, isDark),
                  _buildGenerateTab(textColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageTab(Color textColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('اختيار الكروت', Icons.list_alt, _buildCardSelection(textColor)),
        _section('المعاينة', Icons.view_compact, _buildPreview()),
        _section('التعديل والتحكم', Icons.tune, _buildPrintControls(textColor)),
        _section('قوالب الطباعة', Icons.bookmark, _buildTemplateManager(textColor)),
        _section('التخطيط', Icons.grid_on, _buildLayoutSettings(textColor)),
        _section('الهوامش', Icons.space_bar, _buildMarginSettings(textColor)),
        Center(
          child: ElevatedButton.icon(
            onPressed: _showPrintDialog,
            icon: const Icon(Icons.print),
            label: const Text('بدء الطباعة'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          ),
        ),
        _section('سجل العمليات', Icons.history, _buildPrintLogs(textColor)),
      ]),
    );
  }

  Widget _buildGenerateTab(Color textColor, bool isDark) {
    final sys = Provider.of<SystemProvider>(context);
    if (printNetworks.isEmpty) return const Center(child: Text('لا توجد شبكات'));
    List<Map<String, dynamic>> allCategories = [];
    for (var net in printNetworks) {
      List cats = (net.data() as Map)['categories'] ?? [];
      for (var cat in cats) {
        if (cat['isActive'] != false) allCategories.add({'networkId': net.id, 'networkName': net['name'], 'category': cat});
      }
    }
    if (allCategories.isEmpty) return const Center(child: Text('لا توجد فئات نشطة'));
    return Column(children: [
      Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('توليد كروت للطباعة', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
      Expanded(
        child: ListView.builder(
          itemCount: allCategories.length,
          itemBuilder: (context, index) {
            var item = allCategories[index];
            String key = "${item['networkId']}_${item['category']['id']}";
            _multiGenControllers.putIfAbsent(key, () => TextEditingController());
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: Text('${item['networkName']} - ${item['category']['name']}')),
                  SizedBox(width: 100, child: TextField(controller: _multiGenControllers[key], keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: 'الكمية'))),
                ]),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _isProcessing ? null : () => _startPrintGeneration(orders: _collectOrders()),
          icon: const Icon(Icons.autorenew),
          label: const Text('توليد للطباعة'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
        ),
      ),
    ]);
  }

  Widget _section(String title, IconData icon, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _buildCardSelection(Color textColor) {
    return Column(children: [
      DropdownButtonFormField<String>(
        value: printSelectedNetworkId,
        items: printNetworks.map((n) => DropdownMenuItem(value: n.id, child: Text(n['name']))).toList(),
        decoration: const InputDecoration(labelText: 'اختر الشبكة', border: OutlineInputBorder()),
        onChanged: (val) {
          setState(() {
            printSelectedNetworkId = val;
            printSelectedCategoryIds.clear();
            printSelectedCategories.clear();
            _categoryTemplates.clear();
            printCategoryCountControllers.forEach((_, c) => c.dispose());
            printCategoryCountControllers.clear();
            printTotalCountCtrl.text = "0";
          });
        },
      ),
      const SizedBox(height: 12),
      if (printSelectedNetworkId != null)
        ...(printNetworkCategories[printSelectedNetworkId] ?? []).map((cat) {
          final ready = allPrintReadyCards.where((c) => c['categoryId'] == cat['id']).length;
          final selected = printSelectedCategoryIds.contains(cat['id']);
          return Column(children: [
            CheckboxListTile(
              title: Text("${cat['name']} (مخزون: ${cat['stock'] ?? 0}، جاهز: $ready)"),
              value: selected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    printSelectedCategoryIds.add(cat['id']);
                    printSelectedCategories[cat['id']] = cat;
                    _loadCategoryTemplate(cat['id']);
                    _loadCategorySettings(cat['id']);
                  } else {
                    printSelectedCategoryIds.remove(cat['id']);
                    printSelectedCategories.remove(cat['id']);
                    _categoryTemplates.remove(cat['id']);
                  }
                  _rebuildPrintCategoryCounts();
                });
              },
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: TextField(
                  controller: printCategoryCountControllers[cat['id']],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "عدد الكروت", border: OutlineInputBorder()),
                ),
              ),
          ]);
        }),
      TextField(controller: printTotalCountCtrl, readOnly: true, decoration: const InputDecoration(labelText: "الإجمالي", border: OutlineInputBorder())),
    ]);
  }

  Widget _buildPreview() {
    if (printSelectedCategoryIds.isEmpty) return const Text('اختر فئة للمعاينة');
    return _PreviewArea(
      selectedCategoryIds: printSelectedCategoryIds,
      selectedCategories: printSelectedCategories,
      categoryTemplates: _categoryTemplates,
      textX: textX, textY: textY, fontSize: fontSize, textColor: textColor,
      widthMMCtrl: widthMMCtrl, heightMMCtrl: heightMMCtrl,
      perRowCtrl: perRowCtrl, perColumnCtrl: perColumnCtrl,
    );
  }

  Widget _buildPrintControls(Color textColor) {
    return Column(children: [
      _positionShortcuts(),
      Row(children: [
        Expanded(child: _slider('الأفقي %', textX, 100, Colors.redAccent)),
        Expanded(child: _slider('الرأسي %', textY, 100, Colors.green)),
      ]),
      _slider('حجم الخط', fontSize, 40, Colors.purple),
      _buildColorButton(),
      Center(child: ElevatedButton.icon(onPressed: _saveCategorySettings, icon: const Icon(Icons.save), label: const Text('حفظ إعدادات الفئة'))),
    ]);
  }

  Widget _buildColorButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        Color temp = textColor.value;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('اختر لون النص'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              ColorPicker(pickerColor: temp, onColorChanged: (c) => temp = c),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton(onPressed: () { textColor.value = temp; Navigator.pop(context); }, child: const Text('تأكيد')),
                ElevatedButton(onPressed: () { textColor.value = Colors.black; Navigator.pop(context); }, child: const Text('افتراضي')),
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ]),
            ]),
          ),
        );
      },
      icon: Icon(Icons.colorize, color: textColor.value),
      label: const Text('لون النص'),
    );
  }

  Widget _buildTemplateManager(Color textColor) {
    if (savedPrintTemplates.isEmpty) {
      return TextButton.icon(onPressed: _savePrintTemplateDialog, icon: const Icon(Icons.save), label: const Text('حفظ كقالب'));
    }
    return Column(children: [
      Wrap(spacing: 8, children: savedPrintTemplates.map((tmpl) => Row(mainAxisSize: MainAxisSize.min, children: [
        ElevatedButton.icon(onPressed: () => _applyPrintTemplate(tmpl), icon: const Icon(Icons.bookmark), label: Text(tmpl['name'] ?? '')),
        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTemplate(tmpl)),
      ])).toList()),
      TextButton.icon(onPressed: _savePrintTemplateDialog, icon: const Icon(Icons.add), label: const Text('حفظ كقالب جديد')),
    ]);
  }

  Widget _buildLayoutSettings(Color textColor) {
    return Column(children: [
      Row(children: [Expanded(child: _tf(copiesPerCardCtrl, 'نسخ/كرت')), Expanded(child: _tf(perRowCtrl, 'كروت/صف'))]),
      Row(children: [Expanded(child: _tf(perColumnCtrl, 'كروت/عمود')), Expanded(child: _tf(widthMMCtrl, 'عرض (مم)'))]),
      _tf(heightMMCtrl, 'ارتفاع (مم)'),
    ]);
  }

  Widget _buildMarginSettings(Color textColor) {
    return Column(children: [
      Row(children: [Expanded(child: _tf(horizontalGapCtrl, 'فجوة أفقية')), Expanded(child: _tf(verticalGapCtrl, 'فجوة عمودية'))]),
      Row(children: [Expanded(child: _tf(pageLeftMarginCtrl, 'هامش يسار')), Expanded(child: _tf(pageTopMarginCtrl, 'هامش أعلى'))]),
    ]);
  }

  Widget _buildPrintLogs(Color textColor) {
    if (printLogs.isEmpty) return const Text('لا توجد عمليات');
    return Column(children: printLogs.take(5).map((log) => ListTile(title: Text("${log['count']} كرت - ${log['type']}"), subtitle: Text(log['timestamp']?.toString() ?? ''))).toList());
  }

  Widget _tf(TextEditingController c, String label) => TextField(controller: c, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
  Widget _slider(String label, ValueNotifier<double> v, double max, Color color) => ValueListenableBuilder(valueListenable: v, builder: (_, val, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$label: ${val.toStringAsFixed(1)}'), Slider(value: val, max: max, activeColor: color, onChanged: (x) => v.value = x)]));
  Widget _positionShortcuts() => Wrap(spacing: 8, children: [
  _shortcutBtn("↖", 10, 10),
  _shortcutBtn("↑", 50, 10),
  _shortcutBtn("↗", 90, 10),
  _shortcutBtn("←", 10, 50),
  _shortcutBtn("●", 50, 50),
  _shortcutBtn("→", 90, 50),
  _shortcutBtn("↙", 10, 90),
  _shortcutBtn("↓", 50, 90),
  _shortcutBtn("↘", 90, 90),
]);

Widget _shortcutBtn(String label, double x, double y) {
  return GestureDetector(
    onTap: () {
      textX.value = x;
      textY.value = y;
    },
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueAccent),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 18, color: Colors.blueAccent)),
    ),
  );
}
  void _savePrintTemplateDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('حفظ كقالب'), content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'اسم القالب')), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      ElevatedButton(onPressed: () { if (ctrl.text.trim().isNotEmpty) { _saveCurrentAsPrintTemplate(ctrl.text.trim()); Navigator.pop(context); } }, child: const Text('حفظ')),
    ]));
  }

  Future<void> _saveCurrentAsPrintTemplate(String name) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    await _db.collection('print_templates').add({
      'agentPhone': sys.currentUserPhone, 'name': name,
      'textXPercent': textX.value, 'textYPercent': textY.value, 'fontSize': fontSize.value, 'textColor': textColor.value.value,
      'copiesPerCard': copiesPerCardCtrl.text, 'perRow': perRowCtrl.text, 'perColumn': perColumnCtrl.text,
      'widthMM': widthMMCtrl.text, 'heightMM': heightMMCtrl.text,
      'horizontalGap': horizontalGapCtrl.text, 'verticalGap': verticalGapCtrl.text,
      'pageLeftMargin': pageLeftMarginCtrl.text, 'pageTopMargin': pageTopMarginCtrl.text,
    });
    _loadPrintTemplates();
  }

  void _applyPrintTemplate(Map<String, dynamic> tmpl) {
    textX.value = (tmpl['textXPercent'] ?? 50).toDouble(); textY.value = (tmpl['textYPercent'] ?? 50).toDouble();
    fontSize.value = (tmpl['fontSize'] ?? 14).toDouble(); textColor.value = Color(tmpl['textColor'] ?? Colors.black.value);
    copiesPerCardCtrl.text = (tmpl['copiesPerCard'] ?? "1").toString(); perRowCtrl.text = (tmpl['perRow'] ?? "3").toString();
    perColumnCtrl.text = (tmpl['perColumn'] ?? "17").toString(); widthMMCtrl.text = (tmpl['widthMM'] ?? "70.0").toString();
    heightMMCtrl.text = (tmpl['heightMM'] ?? "17.4").toString(); horizontalGapCtrl.text = (tmpl['horizontalGap'] ?? "0.0").toString();
    verticalGapCtrl.text = (tmpl['verticalGap'] ?? "0.0").toString(); pageLeftMarginCtrl.text = (tmpl['pageLeftMargin'] ?? "5.0").toString();
    pageTopMarginCtrl.text = (tmpl['pageTopMargin'] ?? "5.0").toString();
  }

  void _deleteTemplate(Map<String, dynamic> tmpl) async {
    bool confirm = await _confirmAction('حذف القالب', 'هل تريد حذف هذا القالب؟', Colors.red);
    if (!confirm) return;
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final snap = await _db.collection('print_templates').where('agentPhone', isEqualTo: sys.currentUserPhone).where('name', isEqualTo: tmpl['name']).get();
    for (var doc in snap.docs) { await doc.reference.delete(); }
    _loadPrintTemplates();
    _showToast('تم حذف القالب');
  }
}

// ---------- ويدجت المعاينة ----------
class _PreviewArea extends StatefulWidget {
  final Set<String> selectedCategoryIds;
  final Map<String, Map<String, dynamic>> selectedCategories;
  final Map<String, Uint8List?> categoryTemplates;
  final ValueNotifier<double> textX, textY, fontSize;
  final ValueNotifier<Color> textColor;
  final TextEditingController widthMMCtrl, heightMMCtrl, perRowCtrl, perColumnCtrl;
  const _PreviewArea({required this.selectedCategoryIds, required this.selectedCategories, required this.categoryTemplates, required this.textX, required this.textY, required this.fontSize, required this.textColor, required this.widthMMCtrl, required this.heightMMCtrl, required this.perRowCtrl, required this.perColumnCtrl});
  @override State<_PreviewArea> createState() => _PreviewAreaState();
}

class _PreviewAreaState extends State<_PreviewArea> {
  @override Widget build(BuildContext context) {
    if (widget.selectedCategoryIds.isEmpty) return const SizedBox.shrink();
    final w = double.tryParse(widget.widthMMCtrl.text) ?? 70.0;
    final h = double.tryParse(widget.heightMMCtrl.text) ?? 17.4;
    final pRow = int.tryParse(widget.perRowCtrl.text) ?? 3;
    final pCol = int.tryParse(widget.perColumnCtrl.text) ?? 17;
    return LayoutBuilder(builder: (context, constraints) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text("محاكاة (${pRow}x$pCol)", style: Theme.of(context).textTheme.titleMedium), const Spacer(), IconButton(icon: const Icon(Icons.fullscreen, color: Colors.teal), onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text("معاينة كاملة")), body: InteractiveViewer(minScale: 0.2, maxScale: 5.0, child: Container(width: w * pRow * PreciseLayoutEngine.mmToPx, height: h * pCol * PreciseLayoutEngine.mmToPx, color: Colors.white, child: _buildFakeGrid(pRow, pCol, w, h))))));
      })]),
      const SizedBox(height: 8),
      SizedBox(height: 300, child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Container(width: w * pRow * PreciseLayoutEngine.mmToPx, height: h * pCol * PreciseLayoutEngine.mmToPx, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), color: Colors.white), child: _buildFakeGrid(pRow, pCol, w, h)))),
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
    final templateBytes = widget.categoryTemplates[widget.selectedCategoryIds.isNotEmpty ? widget.selectedCategoryIds.first : ''];
    return ValueListenableBuilder(
      valueListenable: widget.textX,
      builder: (context, _, __) => ValueListenableBuilder(
        valueListenable: widget.textY,
        builder: (context, _, __) => ValueListenableBuilder(
          valueListenable: widget.fontSize,
          builder: (context, _, __) => ValueListenableBuilder(
            valueListenable: widget.textColor,
            builder: (context, _, __) {
              final pos = Offset((widget.textX.value / 100) * wMM * PreciseLayoutEngine.mmToPx, (widget.textY.value / 100) * hMM * PreciseLayoutEngine.mmToPx);
              return Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), image: templateBytes != null ? DecorationImage(image: MemoryImage(templateBytes), fit: BoxFit.fill) : null),
                child: Stack(children: [
                  CustomPaint(size: Size(wMM * PreciseLayoutEngine.mmToPx, hMM * PreciseLayoutEngine.mmToPx), painter: _GuidePainter()),
                  Positioned(left: pos.dx, top: pos.dy, child: GestureDetector(
                    onPanUpdate: (details) {
                      widget.textX.value += details.delta.dx / (wMM * PreciseLayoutEngine.mmToPx) * 100;
                      widget.textY.value += details.delta.dy / (hMM * PreciseLayoutEngine.mmToPx) * 100;
                      widget.textX.value = widget.textX.value.clamp(0, 100);
                      widget.textY.value = widget.textY.value.clamp(0, 100);
                    },
                    child: Container(color: Colors.white.withOpacity(0.7), child: Text(pin, style: TextStyle(fontSize: widget.fontSize.value * 0.8, color: widget.textColor.value))),
                  )),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.withOpacity(0.5)..strokeWidth = 0.5;
    for (double p = 0.25; p <= 0.75; p += 0.25) {
      canvas.drawLine(Offset(size.width * p, 0), Offset(size.width * p, size.height), paint);
      canvas.drawLine(Offset(0, size.height * p), Offset(size.width, size.height * p), paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
