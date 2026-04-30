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

  // ========== قوالب الفئات (مخزنة) ==========
  final Map<String, Uint8List?> categoryTemplates = {};

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
  }

  void _loadCategoryTemplate(String categoryId) {
    final cat = selectedCategories[categoryId];
    if (cat == null) return;
    final b64 = cat['templateBase64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      categoryTemplates[categoryId] = base64Decode(b64);
    } else {
      categoryTemplates.remove(categoryId);
    }
    setState(() {});
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

  // --- طباعة PDF (مع pagination) ---
  Future<Uint8List> generatePdf(int totalCount) async {
    final pdf = pw.Document();
    final perRowVal = int.tryParse(perRow.text) ?? 3;
    final perColVal = int.tryParse(perColumn.text) ?? 17;
    final w = double.tryParse(widthMM.text) ?? 70.0;
    final h = double.tryParse(heightMM.text) ?? 17.4;
    final cardsPerPage = perRowVal * perColVal;

    // جمع الكروت المطلوبة
    List<QueryDocumentSnapshot> cardsToPrint = [];
    for (final catId in selectedCategoryIds) {
      final requested = int.tryParse(categoryCountControllers[catId]?.text ?? '0') ?? 0;
      final catCards = allPrintReadyCards
          .where((c) => c['categoryId'] == catId)
          .take(requested)
          .toList();
      cardsToPrint.addAll(catCards);
    }

    // تقسيم إلى صفحات
    final totalPages = (cardsToPrint.length / cardsPerPage).ceil();
    for (int page = 0; page < totalPages; page++) {
      final pageCards = cardsToPrint.skip(page * cardsPerPage).take(cardsPerPage).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.GridView(
              crossAxisCount: perRowVal,
              children: pageCards.map((card) {
                final catId = card['categoryId'] as String;
                final pin = card['pin'] ?? '---';
                final templateBytes = categoryTemplates[catId];
                return pw.Container(
                  width: w * PdfPageFormat.mm,
                  height: h * PdfPageFormat.mm,
                  child: pw.Stack(
                    children: [
                      if (templateBytes != null)
                        pw.Image(pw.MemoryImage(templateBytes), fit: pw.BoxFit.fill),
                      pw.Positioned(
                        left: (textX.value / 100) * w * PdfPageFormat.mm,
                        top: (textY.value / 100) * h * PdfPageFormat.mm,
                        child: pw.Text(
                          pin,
                          style: pw.TextStyle(
                            fontSize: fontSize.value,
                            color: PdfColor.fromInt(textColor.value.value),
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
              final pdf = await generatePdf(total);
              await Printing.layoutPdf(onLayout: (_) => pdf);
              _logPrintAction('view', total);
            },
          ),
          TextButton(
            child: const Text("طباعة فقط"),
            onPressed: () async {
              Navigator.pop(context);
              final pdf = await generatePdf(total);
              await Printing.layoutPdf(onLayout: (_) => pdf);
              _logPrintAction('print_only', total);
            },
          ),
          TextButton(
            child: const Text("طباعة وأرشفة"),
            onPressed: () async {
              Navigator.pop(context);
              final pdf = await generatePdf(total);
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

  // --- معاينة حقيقية محسّنة مع السحب ---
  Widget _buildEnhancedPreview() {
    if (selectedCategoryIds.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Text("المعاينة", style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.fullscreen),
              onPressed: () => _showFullScreenPreview(),
              tooltip: "معاينة كاملة",
            ),
          ],
        ),
        SizedBox(
          height: 280,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: selectedCategoryIds.map((catId) {
              final template = categoryTemplates[catId];
              return GestureDetector(
                onPanUpdate: (details) {
                  // السحب المباشر للنص
                  final RenderBox renderBox = context.findRenderObject() as RenderBox;
                  final localPos = renderBox.globalToLocal(details.globalPosition);
                  // تحويل إلى نسبة مئوية داخل مساحة المعاينة (سنأخذ child size لكن هنا تقريبي)
                  // سنستخدم الحجم التقريبي 150x120 كنسبة
                  setState(() {
                    textX.value = ((localPos.dx / 150) * 100).clamp(0, 100);
                    textY.value = ((localPos.dy / 120) * 100).clamp(0, 100);
                  });
                },
                child: Column(
                  children: [
                    Text(selectedCategories[catId]?['name'] ?? ''),
                    Stack(
                      children: [
                        Container(
                          width: 150,
                          height: 120,
                          decoration: template != null
                              ? BoxDecoration(
                                  image: DecorationImage(image: MemoryImage(template), fit: BoxFit.fill),
                                )
                              : BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  color: Colors.grey.shade200,
                                ),
                        ),
                        // خطوط إرشادية (وسط)
                        CustomPaint(
                          size: const Size(150, 120),
                          painter: _GuidePainter(),
                        ),
                        Positioned(
                          left: (textX.value / 100) * 150 - 20,
                          top: (textY.value / 100) * 120 - 15,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                textX.value = (textX.value + details.delta.dx / 150 * 100).clamp(0, 100);
                                textY.value = (textY.value + details.delta.dy / 120 * 100).clamp(0, 100);
                              });
                            },
                            child: Container(
                              color: Colors.white.withOpacity(0.7),
                              padding: const EdgeInsets.all(2),
                              child: Text(
                                "####",
                                style: TextStyle(
                                  fontSize: fontSize.value * 0.8,
                                  color: textColor.value,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showFullScreenPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("معاينة كاملة")),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Container(
              width: double.parse(widthMM.text) * 3,
              height: double.parse(heightMM.text) * 3,
              decoration: BoxDecoration(
                image: categoryTemplates.isNotEmpty
                    ? DecorationImage(
                        image: MemoryImage(categoryTemplates.values.first!),
                        fit: BoxFit.fill,
                      )
                    : null,
                color: Colors.grey.shade200,
              ),
              child: Stack(
                children: [
                  CustomPaint(size: Size(double.parse(widthMM.text) * 3, double.parse(heightMM.text) * 3), painter: _GuidePainter()),
                  Positioned(
                    left: (textX.value / 100) * double.parse(widthMM.text) * 3,
                    top: (textY.value / 100) * double.parse(heightMM.text) * 3,
                    child: Text("####", style: TextStyle(fontSize: fontSize.value * 2, color: textColor.value)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- الأرشيف (مع تحسينات) ---
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

  // --- تبويب الطباعة (منظم) ---
  Widget _buildPrintTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("اختيار الكروت"),
          DropdownButtonFormField<String>(
            value: selectedNetworkId,
            items: networks.map((n) => DropdownMenuItem(value: n.id, child: Text(n['name']))).toList(),
            decoration: const InputDecoration(labelText: 'اختر الشبكة', border: OutlineInputBorder()),
            onChanged: (val) {
              setState(() {
                selectedNetworkId = val;
                selectedCategoryIds.clear();
                selectedCategories.clear();
                categoryTemplates.clear();
                categoryCountControllers.forEach((_, ctrl) => ctrl.dispose());
                categoryCountControllers.clear();
                totalCountController.text = "0";
              });
            },
          ),
          const SizedBox(height: 12),
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
                          categoryTemplates.remove(cat['id']);
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
          TextField(
            controller: totalCountController,
            readOnly: true,
            decoration: const InputDecoration(labelText: "إجمالي الكروت المطلوبة", border: OutlineInputBorder()),
          ),
          const Divider(height: 30),
          _buildSectionTitle("المعاينة"),
          _buildEnhancedPreview(),
          const Divider(height: 30),
          _buildSectionTitle("التعديل"),
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
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  content: ColorPicker(pickerColor: textColor.value, onColorChanged: (c) => textColor.value = c),
                ),
              );
            },
            icon: Icon(Icons.colorize, color: textColor.value),
            label: const Text("لون النص"),
          ),
          const SizedBox(height: 12),
          Text("قوالب الطباعة", style: theme.textTheme.titleMedium),
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
          const Divider(height: 30),
          _buildSectionTitle("إعدادات الطباعة"),
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
          const SizedBox(height: 20),
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
          const Divider(height: 30),
          _buildSectionTitle("سجل آخر عمليات الطباعة"),
          if (printLogs.isEmpty)
            const Text("لا توجد عمليات بعد")
          else
            ...printLogs.take(5).map((log) => ListTile(
              title: Text("${log['count']} كرت - ${_logType(log['type'])}"),
              subtitle: Text(_logTime(log['timestamp'])),
            )),
        ],
      ),
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

  Widget _buildSectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold));
  }

  Widget slider(String label, ValueNotifier<double> notifier, double max) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (_, value, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$label: ${value.toStringAsFixed(1)}"),
            Slider(value: value, max: max, onChanged: (v) => notifier.value = v),
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

    // خطوط أفقية وعمودية عند 25%, 50%, 75%
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
