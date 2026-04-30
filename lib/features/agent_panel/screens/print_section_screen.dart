import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

// ========== طبقة الحسابات الموحدة (Single Source of Truth) ==========
class LayoutEngine {
  static const double mmToPx = 2.83465; // 1 mm = 2.83465 logical pixels

  static Offset calculateTextPosition({
    required double xPercent,
    required double yPercent,
    required double widthMM,
    required double heightMM,
  }) {
    return Offset(
      (xPercent / 100) * widthMM * mmToPx,
      (yPercent / 100) * heightMM * mmToPx,
    );
  }
}

class PrintSectionScreen extends StatefulWidget {
  const PrintSectionScreen({super.key});

  @override
  State<PrintSectionScreen> createState() => _PrintSectionScreenState();
}

class _PrintSectionScreenState extends State<PrintSectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late SystemProvider sys;

  // ========== الشبكات والفئات ==========
  List<QueryDocumentSnapshot> networks = [];
  Map<String, List<Map<String, dynamic>>> networkCategories = {};

  String? selectedNetworkId;
  final Set<String> selectedCategoryIds = {};
  final Map<String, Map<String, dynamic>> selectedCategories = {};
  List<QueryDocumentSnapshot> allPrintReadyCards = [];

  // ========== قوالب الفئات (مخزنة بشكل خاص) ==========
  final Map<String, Uint8List?> _categoryTemplates = {};

  Uint8List? getTemplate(String categoryId) {
    return _categoryTemplates[categoryId];
  }

  // ========== إعدادات النص (مشتركة) ==========
  final ValueNotifier<double> textX = ValueNotifier(50);
  final ValueNotifier<double> textY = ValueNotifier(50);
  final ValueNotifier<double> fontSize = ValueNotifier(14);
  final ValueNotifier<Color> textColor = ValueNotifier(Colors.black);

  // ========== إعدادات التخطيط (ثابتة) ==========
  final copiesPerCard = TextEditingController(text: "1");
  final perRow = TextEditingController(text: "3");
  final perColumn = TextEditingController(text: "17");
  final widthMM = TextEditingController(text: "70.0");
  final heightMM = TextEditingController(text: "17.4");

  // ========== الكميات لكل فئة ==========
  final Map<String, TextEditingController> categoryCountControllers = {};
  final totalCountController = TextEditingController();

  // ========== قوالب محفوظة ==========
  List<Map<String, dynamic>> savedTemplates = [];

  // ========== الأرشيف ==========
  List<QueryDocumentSnapshot> archivedCards = [];
  String archiveSearchQuery = '';
  final archiveDaysController = TextEditingController(text: "30");
  bool autoDeleteEnabled = false;

  // ========== سجل الطباعة ==========
  List<Map<String, dynamic>> printLogs = [];

  @override
  void initState() {
    super.initState();
    sys = Provider.of<SystemProvider>(context, listen: false);
    _tabController = TabController(length: 2, vsync: this);
    totalCountController.text = "0";
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    copiesPerCard.dispose();
    perRow.dispose();
    perColumn.dispose();
    widthMM.dispose();
    heightMM.dispose();
    totalCountController.dispose();
    archiveDaysController.dispose();
    textX.dispose();
    textY.dispose();
    fontSize.dispose();
    textColor.dispose();
    for (final c in categoryCountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ========== مزامنة المعاينة (Force UI Sync) ==========
  void _syncPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  // ========== لقطة الإعدادات (Snapshot Pattern) ==========
  Map<String, dynamic> _captureSnapshot() {
    return {
      "x": textX.value,
      "y": textY.value,
      "font": fontSize.value,
      "color": textColor.value,
      "row": int.tryParse(perRow.text) ?? 3,
      "col": int.tryParse(perColumn.text) ?? 17,
      "w": double.tryParse(widthMM.text) ?? 70.0,
      "h": double.tryParse(heightMM.text) ?? 17.4,
      "copies": int.tryParse(copiesPerCard.text) ?? 1,
    };
  }

  Future<void> _loadInitialData() async {
    final snapshot = await _firestore
        .collection('networks')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .get();
    setState(() {
      networks = snapshot.docs;
      for (var net in networks) {
        final data = net.data() as Map<String, dynamic>;
        networkCategories[net.id] =
            List<Map<String, dynamic>>.from(data['categories'] ?? []);
      }
    });
    await _loadAllPrintReadyCards();
    _loadTemplates();
    _loadArchive();
    _loadPrintLogs();
    _loadAutoDeleteSettings();
  }

  Future<void> _loadAllPrintReadyCards() async {
    final snapshot = await _firestore
        .collection('cards')
        .where('status', isEqualTo: 'print_ready')
        .get();
    setState(() => allPrintReadyCards = snapshot.docs);
  }

  void _rebuildCategoryCounts() {
    for (final catId in selectedCategoryIds) {
      if (!categoryCountControllers.containsKey(catId)) {
        final ready = allPrintReadyCards.where((c) => c['categoryId'] == catId).length;
        final ctrl = TextEditingController(text: ready.toString());
        categoryCountControllers[catId] = ctrl;
      }
    }
    final toRemove = categoryCountControllers.keys
        .toList()
        .where((k) => !selectedCategoryIds.contains(k));
    for (final k in toRemove) {
      categoryCountControllers[k]?.dispose();
      categoryCountControllers.remove(k);
    }
    _updateTotalCount();
  }

  void _updateTotalCount() {
    int total = 0;
    for (final catId in selectedCategoryIds) {
      final cnt = int.tryParse(categoryCountControllers[catId]?.text ?? '0') ?? 0;
      total += cnt;
    }
    totalCountController.text = total.toString();
  }

  // --- القوالب ---
  Future<void> _loadTemplates() async {
    final snap = await _firestore
        .collection('print_templates')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .get();
    setState(() => savedTemplates = snap.docs.map((d) => d.data()).toList());
  }

  Future<void> _saveCurrentAsTemplate(String name) async {
    await _firestore.collection('print_templates').add({
      'agentPhone': sys.currentUserPhone,
      'name': name,
      'textXPercent': textX.value,
      'textYPercent': textY.value,
      'fontSize': fontSize.value,
      'textColor': textColor.value.value,
      'copiesPerCard': copiesPerCard.text,
      'perRow': perRow.text,
      'perColumn': perColumn.text,
      'widthMM': widthMM.text,
      'heightMM': heightMM.text,
    });
    _loadTemplates();
  }

  void _applyTemplate(Map<String, dynamic> tmpl) {
    textX.value = (tmpl['textXPercent'] ?? 50).toDouble();
    textY.value = (tmpl['textYPercent'] ?? 50).toDouble();
    fontSize.value = (tmpl['fontSize'] ?? 14).toDouble();
    textColor.value = Color(tmpl['textColor'] ?? Colors.black.value);
    copiesPerCard.text = (tmpl['copiesPerCard'] ?? "1").toString();
    perRow.text = (tmpl['perRow'] ?? "3").toString();
    perColumn.text = (tmpl['perColumn'] ?? "17").toString();
    widthMM.text = (tmpl['widthMM'] ?? "70.0").toString();
    heightMM.text = (tmpl['heightMM'] ?? "17.4").toString();
    _syncPreview();
  }

  void _loadCategoryTemplate(String categoryId) {
    final cat = selectedCategories[categoryId];
    if (cat == null) return;
    final b64 = cat['templateBase64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      _categoryTemplates[categoryId] = base64Decode(b64);
    } else {
      _categoryTemplates.remove(categoryId);
    }
    _syncPreview();
  }

  // --- الأرشيف ---
  Future<void> _loadArchive() async {
    final snapshot = await _firestore
        .collection('cards')
        .where('status', isEqualTo: 'archived')
        .get();
    setState(() => archivedCards = snapshot.docs);
  }

  Future<void> _restoreCard(QueryDocumentSnapshot card) async {
    final ok = await _showConfirm("استرجاع الكرت", "هل تريد إعادة هذا الكرت إلى حالة الطباعة؟");
    if (!ok) return;
    await card.reference.update({'status': 'print_ready'});
    _loadArchive();
    _loadAllPrintReadyCards();
  }

  Future<void> _deleteCardPermanently(QueryDocumentSnapshot card) async {
    final ok = await _showConfirm("حذف نهائي", "سيتم حذف الكرت نهائياً. استمر؟");
    if (!ok) return;
    await card.reference.delete();
    _loadArchive();
  }

  Future<void> _editCardPin(QueryDocumentSnapshot card) async {
    final ctrl = TextEditingController(text: card['pin']);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تعديل الرقم"),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "الرقم الجديد")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text("حفظ")),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      await card.reference.update({'pin': res});
      _loadArchive();
    }
  }

  Future<void> _restoreAll() async {
    final ok = await _showConfirm("استرجاع الكل", "سيتم إعادة جميع الكروت في الأرشيف إلى حالة الطباعة. متأكد؟");
    if (!ok) return;
    final batch = _firestore.batch();
    for (final card in archivedCards) {
      batch.update(card.reference, {'status': 'print_ready'});
    }
    await batch.commit();
    _loadArchive();
    _loadAllPrintReadyCards();
  }

  Future<void> _deleteAllArchived() async {
    final ok = await _showConfirm("حذف الكل", "سيتم حذف جميع الكروت في الأرشيف نهائياً. متأكد؟");
    if (!ok) return;
    final batch = _firestore.batch();
    for (final card in archivedCards) {
      batch.delete(card.reference);
    }
    await batch.commit();
    _loadArchive();
  }

  Future<void> _loadAutoDeleteSettings() async {
    final doc = await _firestore.collection('settings').doc('archive_auto_delete').get();
    if (doc.exists) {
      setState(() {
        archiveDaysController.text = (doc['days'] ?? 30).toString();
        autoDeleteEnabled = doc['enabled'] ?? false;
      });
    }
  }

  Future<void> _saveAutoDeleteSettings() async {
    await _firestore.collection('settings').doc('archive_auto_delete').set({
      'days': int.tryParse(archiveDaysController.text) ?? 30,
      'enabled': autoDeleteEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ إعدادات الحذف التلقائي")));
    }
  }

  Future<bool> _showConfirm(String title, String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("تأكيد")),
            ],
          ),
        ) ??
        false;
  }

  // --- سجل الطباعة ---
  Future<void> _loadPrintLogs() async {
    final snap = await _firestore
        .collection('print_logs')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();
    setState(() => printLogs = snap.docs.map((d) => d.data()).toList());
  }

  Future<void> _logPrintAction(String type, int count) async {
    await _firestore.collection('print_logs').add({
      'agentPhone': sys.currentUserPhone,
      'networkId': selectedNetworkId ?? '',
      'categoryIds': selectedCategoryIds.toList(),
      'count': count,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _loadPrintLogs();
  }

  // --- طباعة PDF (تستخدم الـ Snapshot و LayoutEngine) ---
  Future<Uint8List> generatePdf(Map<String, dynamic> snap) async {
    final int perRowVal = snap["row"];
    final int perColVal = snap["col"];
    final double w = snap["w"];
    final double h = snap["h"];
    final int copies = snap["copies"];
    final cardsPerPage = perRowVal * perColVal;

    if (cardsPerPage <= 0) {
      throw Exception("إعدادات الطباعة غير صحيحة");
    }

    final pdf = pw.Document();

    List<QueryDocumentSnapshot> cardsToPrint = [];
    for (final catId in selectedCategoryIds) {
      final requested = int.tryParse(categoryCountControllers[catId]?.text ?? '0') ?? 0;
      final catCards = allPrintReadyCards
          .where((c) => c['categoryId'] == catId)
          .take(requested)
          .toList();
      for (var card in catCards) {
        for (int i = 0; i < copies; i++) {
          cardsToPrint.add(card);
        }
      }
    }

    final totalPages = (cardsToPrint.length / cardsPerPage).ceil();
    for (int page = 0; page < totalPages; page++) {
      final pageCards = cardsToPrint.skip(page * cardsPerPage).take(cardsPerPage).toList();
      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(10),
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.GridView(
              crossAxisCount: perRowVal,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: pageCards.map((card) {
                final catId = card['categoryId'] as String;
                final pin = card['pin'] ?? '---';
                final templateBytes = getTemplate(catId);
                // استخدام LayoutEngine لحساب الموضع في PDF
                final pos = LayoutEngine.calculateTextPosition(
                  xPercent: snap["x"],
                  yPercent: snap["y"],
                  widthMM: w,
                  heightMM: h,
                );
                return pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  width: w * PdfPageFormat.mm,
                  height: h * PdfPageFormat.mm,
                  child: pw.Stack(
                    children: [
                      if (templateBytes != null)
                        pw.Image(pw.MemoryImage(templateBytes), fit: pw.BoxFit.fill),
                      pw.Positioned(
                        left: pos.dx * PdfPageFormat.mm, // تحويل pixels -> mm للـ PDF
                        top: pos.dy * PdfPageFormat.mm,
                        child: pw.Text(
                          pin,
                          style: pw.TextStyle(
                            fontSize: snap["font"],
                            color: PdfColor.fromInt((snap["color"] as Color).value),
                          ),
                        ),
                      )
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }
    return pdf.save();
  }

  void showPrintDialog() {
    final total = int.tryParse(totalCountController.text) ?? 0;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرجاء تحديد عدد الكروت")),
      );
      return;
    }

    // التقاط لقطة لحظة الضغط على الزر
    final snapshot = _captureSnapshot();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تأكيد الطباعة"),
        content: Text("سيتم طباعة $total كرت. اختر الإجراء:"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            child: const Text("معاينة فقط"),
            onPressed: () async {
              Navigator.pop(context);
              final pdf = await generatePdf(snapshot);
              await Printing.layoutPdf(onLayout: (_) => pdf);
              _logPrintAction('view', total);
            },
          ),
          TextButton(
            child: const Text("طباعة فقط"),
            onPressed: () async {
              Navigator.pop(context);
              final pdf = await generatePdf(snapshot);
              await Printing.layoutPdf(onLayout: (_) => pdf);
              _logPrintAction('print_only', total);
            },
          ),
          TextButton(
            child: const Text("طباعة وأرشفة"),
            onPressed: () async {
              Navigator.pop(context);
              final pdf = await generatePdf(snapshot);
              await Printing.layoutPdf(onLayout: (_) => pdf);

              final batch = _firestore.batch();
              for (final catId in selectedCategoryIds) {
                final requested = int.tryParse(categoryCountControllers[catId]?.text ?? '0') ?? 0;
                final catCards = allPrintReadyCards
                    .where((c) => c['categoryId'] == catId)
                    .take(requested)
                    .toList();
                for (final c in catCards) {
                  batch.update(c.reference, {'status': 'archived'});
                }
                final netRef = _firestore.collection('networks').doc(selectedNetworkId);
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
              _loadArchive();
              _rebuildCategoryCounts();
              _logPrintAction('print_archive', total);
            },
          ),
        ],
      ),
    );
  }

  // --- اختصارات المواضع ---
  Widget _positionShortcuts() {
    return Wrap(
      spacing: 8,
      children: [
        _shortcutBtn("↖", 10, 10),
        _shortcutBtn("↑", 50, 10),
        _shortcutBtn("↗", 90, 10),
        _shortcutBtn("←", 10, 50),
        _shortcutBtn("●", 50, 50),
        _shortcutBtn("→", 90, 50),
        _shortcutBtn("↙", 10, 90),
        _shortcutBtn("↓", 50, 90),
        _shortcutBtn("↘", 90, 90),
      ],
    );
  }

  Widget _shortcutBtn(String label, double x, double y) {
    return GestureDetector(
      onTap: () {
        textX.value = x;
        textY.value = y;
        _syncPreview();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  // --- معاينة مطابقة 100% للطباعة (تستخدم LayoutEngine) ---
  Widget _buildEnhancedPreview() {
    if (selectedCategoryIds.isEmpty) return const SizedBox.shrink();

    final w = double.tryParse(widthMM.text) ?? 70.0;
    final h = double.tryParse(heightMM.text) ?? 17.4;
    final pRow = int.tryParse(perRow.text) ?? 3;
    final pCol = int.tryParse(perColumn.text) ?? 17;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("محاكاة صفحة (${pRow}x$pCol)", style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () => _showFullScreenPreview(),
                  tooltip: "معاينة كاملة",
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Container(
                  width: w * pRow * LayoutEngine.mmToPx,
                  height: h * pCol * LayoutEngine.mmToPx,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    color: Colors.white,
                  ),
                  child: _buildFakeGrid(pRow, pCol, w, h),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFakeGrid(int perRowVal, int perColVal, double wMM, double hMM) {
    final children = <Widget>[];
    for (int r = 0; r < perColVal; r++) {
      for (int c = 0; c < perRowVal; c++) {
        final left = c * wMM * LayoutEngine.mmToPx;
        final top = r * hMM * LayoutEngine.mmToPx;
        children.add(
          Positioned(
            left: left,
            top: top,
            width: wMM * LayoutEngine.mmToPx,
            height: hMM * LayoutEngine.mmToPx,
            child: _buildSingleFakeCard(wMM, hMM, "####"),
          ),
        );
      }
    }
    return Stack(children: children);
  }

  Widget _buildSingleFakeCard(double wMM, double hMM, String pin) {
    // استخدام القالب عبر الدالة الموحدة
    final templateBytes = getTemplate(selectedCategoryIds.isNotEmpty ? selectedCategoryIds.first : '');
    // استخدام LayoutEngine لحساب الموضع في المعاينة
    final pos = LayoutEngine.calculateTextPosition(
      xPercent: textX.value,
      yPercent: textY.value,
      widthMM: wMM,
      heightMM: hMM,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        image: templateBytes != null
            ? DecorationImage(image: MemoryImage(templateBytes), fit: BoxFit.fill)
            : null,
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size(wMM * LayoutEngine.mmToPx, hMM * LayoutEngine.mmToPx),
            painter: _GuidePainter(),
          ),
          Positioned(
            left: pos.dx,
            top: pos.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  textX.value += details.delta.dx / (wMM * LayoutEngine.mmToPx) * 100;
                  textY.value += details.delta.dy / (hMM * LayoutEngine.mmToPx) * 100;
                  textX.value = textX.value.clamp(0, 100);
                  textY.value = textY.value.clamp(0, 100);
                });
                _syncPreview();
              },
              child: Container(
                color: Colors.white.withOpacity(0.7),
                child: Text(
                  pin,
                  style: TextStyle(fontSize: fontSize.value * 0.8, color: textColor.value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenPreview() {
    final w = double.tryParse(widthMM.text) ?? 70.0;
    final h = double.tryParse(heightMM.text) ?? 17.4;
    final pRow = int.tryParse(perRow.text) ?? 3;
    final pCol = int.tryParse(perColumn.text) ?? 17;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("معاينة كاملة")),
          body: InteractiveViewer(
            minScale: 0.2,
            maxScale: 5.0,
            child: Container(
              width: w * pRow * LayoutEngine.mmToPx,
              height: h * pCol * LayoutEngine.mmToPx,
              color: Colors.white,
              child: _buildFakeGrid(pRow, pCol, w, h),
            ),
          ),
        ),
      ),
    );
  }

  // --- الأرشيف ---
  Widget _buildArchiveTab() {
    final filtered = archiveSearchQuery.isEmpty
        ? archivedCards
        : archivedCards
            .where((c) => (c['pin'] ?? '').toLowerCase().contains(archiveSearchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'بحث عن كرت',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => archiveSearchQuery = v),
          ),
        ),
        Row(
          children: [
            Expanded(child: Text('${filtered.length} كرت في الأرشيف')),
            TextButton.icon(
              onPressed: _showAutoDeleteSettings,
              icon: const Icon(Icons.timer),
              label: const Text("الحذف التلقائي"),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _restoreAll,
              icon: const Icon(Icons.restore),
              label: const Text("استرجاع الكل"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
            ElevatedButton.icon(
              onPressed: _deleteAllArchived,
              icon: const Icon(Icons.delete_sweep),
              label: const Text("حذف الكل"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, index) {
              final card = filtered[index];
              return ListTile(
                title: Text(card['pin'] ?? '---'),
                subtitle: Text(card['categoryId'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _editCardPin(card)),
                    IconButton(icon: const Icon(Icons.restore), onPressed: () => _restoreCard(card)),
                    IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteCardPermanently(card)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAutoDeleteSettings() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text("إعدادات الحذف التلقائي للأرشيف"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: autoDeleteEnabled,
                onChanged: (v) => setDialogState(() => autoDeleteEnabled = v),
                title: const Text("تفعيل الحذف التلقائي"),
              ),
              TextField(
                controller: archiveDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "عدد الأيام قبل الحذف"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(onPressed: () { _saveAutoDeleteSettings(); Navigator.pop(context); }, child: const Text("حفظ")),
          ],
        ),
      ),
    );
  }

  // --- تبويب الطباعة ---
  Widget _buildPrintTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section("اختيار الكروت", Column(children: [
            DropdownButtonFormField<String>(
              value: selectedNetworkId,
              items: networks.map((n) => DropdownMenuItem(value: n.id, child: Text(n['name']))).toList(),
              decoration: const InputDecoration(labelText: 'اختر الشبكة', border: OutlineInputBorder()),
              onChanged: (val) {
                setState(() {
                  selectedNetworkId = val;
                  selectedCategoryIds.clear();
                  selectedCategories.clear();
                  _categoryTemplates.clear();
                  categoryCountControllers.forEach((_, ctrl) => ctrl.dispose());
                  categoryCountControllers.clear();
                  totalCountController.text = "0";
                });
              },
            ),
            if (selectedNetworkId != null)
              ...(networkCategories[selectedNetworkId] ?? []).map((cat) {
                final ready = allPrintReadyCards.where((c) => c['categoryId'] == cat['id']).length;
                final selected = selectedCategoryIds.contains(cat['id']);
                return Column(
                  children: [
                    CheckboxListTile(
                      title: Text("${cat['name']} (مخزون: ${cat['stock'] ?? 0}، جاهز: $ready)"),
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            selectedCategoryIds.add(cat['id']);
                            selectedCategories[cat['id']] = cat;
                            _loadCategoryTemplate(cat['id']);
                          } else {
                            selectedCategoryIds.remove(cat['id']);
                            selectedCategories.remove(cat['id']);
                            _categoryTemplates.remove(cat['id']);
                          }
                          _rebuildCategoryCounts();
                        });
                      },
                    ),
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: categoryCountControllers[cat['id']],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "عدد الكروت من هذه الفئة",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _updateTotalCount(),
                        ),
                      ),
                  ],
                );
              }),
            const SizedBox(height: 8),
            TextField(
              controller: totalCountController,
              readOnly: true,
              decoration: const InputDecoration(labelText: "إجمالي الكروت المطلوبة", border: OutlineInputBorder()),
            ),
          ])),
          _section("المعاينة", _buildEnhancedPreview()),
          _section("التعديل والتحكم", Column(children: [
            _positionShortcuts(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: slider("الأفقي %", textX, 100)),
                const SizedBox(width: 10),
                Expanded(child: slider("الرأسي %", textY, 100)),
              ],
            ),
            slider("حجم الخط", fontSize, 40),
            const SizedBox(height: 8),
            _buildColorPickerButton(),
            const SizedBox(height: 12),
            Text("قوالب الطباعة", style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Wrap(
              children: savedTemplates.map((t) => TextButton(
                onPressed: () => _applyTemplate(t),
                child: Text(t['name'] ?? ''),
              )).toList(),
            ),
            TextButton.icon(
              onPressed: _saveTemplateDialog,
              icon: const Icon(Icons.save),
              label: const Text("حفظ الإعدادات الحالية كقالب"),
            ),
          ])),
          _section("إعدادات التخطيط", Column(children: [
            Row(
              children: [
                Expanded(child: _textField(copiesPerCard, "نسخ لكل كرت")),
                const SizedBox(width: 10),
                Expanded(child: _textField(perRow, "كروت/صف")),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _textField(perColumn, "كروت/عمود")),
                const SizedBox(width: 10),
                Expanded(child: _textField(widthMM, "عرض (مم)")),
              ],
            ),
            const SizedBox(height: 10),
            _textField(heightMM, "ارتفاع (مم)"),
          ])),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: showPrintDialog,
              icon: const Icon(Icons.print, color: Colors.white),
              label: const Text("بدء الطباعة"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _section("سجل آخر عمليات الطباعة", printLogs.isEmpty
              ? const Text("لا توجد عمليات بعد")
              : Column(
                  children: printLogs.take(5).map((log) => ListTile(
                    title: Text("${log['count']} كرت - ${_logType(log['type'])}"),
                    subtitle: Text(_logTime(log['timestamp'])),
                  )).toList(),
                )),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildColorPickerButton() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              Color tempColor = textColor.value;
              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("اختيار لون النص"),
                  content: ColorPicker(
                    pickerColor: textColor.value,
                    onColorChanged: (c) => tempColor = c,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إلغاء"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        textColor.value = tempColor;
                        _syncPreview();
                        Navigator.pop(context);
                      },
                      child: const Text("تعيين"),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.colorize, color: textColor.value),
            label: const Text("اختيار اللون"),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () {
            textColor.value = Colors.black;
            _syncPreview();
          },
          child: const Text("إلغاء التعيين"),
        ),
      ],
    );
  }

  void _saveTemplateDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("حفظ كقالب"),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "اسم القالب")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(onPressed: () { _saveCurrentAsTemplate(ctrl.text); Navigator.pop(context); }, child: const Text("حفظ")),
        ],
      ),
    );
  }

  String _logType(dynamic type) {
    switch (type) {
      case 'print_archive': return 'طباعة وأرشفة';
      case 'print_only': return 'طباعة فقط';
      case 'view': return 'معاينة';
      default: return '$type';
    }
  }

  String _logTime(dynamic ts) {
    if (ts is Timestamp) return ts.toDate().toString().substring(0, 19);
    return '';
  }

  Widget _textField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget slider(String label, ValueNotifier<double> notifier, double max) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (_, value, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$label: ${value.toStringAsFixed(1)}"),
            Slider(
              value: value,
              max: max,
              onChanged: (v) {
                notifier.value = v;
                _syncPreview(); // Force sync عند تحريك المنزلق
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(title: 'الطباعة والأرشيف'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.teal.shade700,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.orange,
              tabs: const [
                Tab(icon: Icon(Icons.print), text: "الطباعة"),
                Tab(icon: Icon(Icons.archive), text: "الأرشيف"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPrintTab(), _buildArchiveTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// رسّام خطوط إرشادية
class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 0.5;
    for (double p = 0.25; p <= 0.75; p += 0.25) {
      final x = size.width * p;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final y = size.height * p;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
