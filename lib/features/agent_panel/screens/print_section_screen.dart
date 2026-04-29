import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:ui' as ui;

import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

// ========== نموذج سجل الطباعة ==========
class PrintLog {
  final String id;
  final String networkId;
  final String categoryId;
  final int count;
  final String type; // 'print_only', 'print_archive', 'view'
  final DateTime timestamp;

  PrintLog({
    required this.id,
    required this.networkId,
    required this.categoryId,
    required this.count,
    required this.type,
    required this.timestamp,
  });
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
  final sys = Provider.of<SystemProvider>(context, listen: false);

  // ========== قوائم عامة ==========
  List<QueryDocumentSnapshot> networks = [];
  Map<String, List<Map<String, dynamic>>> networkCategories = {};
  Map<String, String> networkNames = {};

  // ========== تبويب الطباعة ==========
  String? selectedNetworkId;
  Map<String, dynamic>? selectedCategory;
  List<String> selectedCategoryIds = []; // للطباعة المجمعة
  List<QueryDocumentSnapshot> cards = [];
  List<QueryDocumentSnapshot> allPrintReadyCards = []; // جميع الكروت الجاهزة بغض النظر عن الفئة

  final textX = ValueNotifier<double>(50);
  final textY = ValueNotifier<double>(50);
  final fontSize = ValueNotifier<double>(14);
  final textColor = ValueNotifier<Color>(Colors.black);
  final copiesPerCard = TextEditingController(text: "1");
  final perRow = TextEditingController(text: "3");
  final perColumn = TextEditingController(text: "4");
  final widthMM = TextEditingController(text: "85");
  final heightMM = TextEditingController(text: "55");
  final printCountController = TextEditingController();
  Uint8List? templateImage;

  // قوالب الطباعة
  List<Map<String, dynamic>> savedTemplates = [];

  // ========== تبويب الأرشيف ==========
  List<QueryDocumentSnapshot> archivedCards = [];
  String archiveSearchQuery = '';

  // ========== سجل الطباعة ==========
  List<PrintLog> printLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final snapshot = await _firestore.collection('networks').get();
    setState(() {
      networks = snapshot.docs;
      for (var net in networks) {
        final data = net.data() as Map<String, dynamic>;
        networkNames[net.id] = data['name'] ?? '';
        networkCategories[net.id] = List<Map<String, dynamic>>.from(
            data['categories'] ?? []);
      }
    });
    _loadTemplates();
    _loadArchive();
    _loadPrintLogs();
  }

  Future<void> _loadTemplates() async {
    final snap = await _firestore
        .collection('print_templates')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .get();
    setState(() {
      savedTemplates = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    });
  }

  Future<void> _saveCurrentAsTemplate(String name) async {
    final template = {
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
    };
    await _firestore.collection('print_templates').add(template);
    _loadTemplates();
  }

  void _applyTemplate(Map<String, dynamic> tmpl) {
    textX.value = (tmpl['textXPercent'] ?? 50).toDouble();
    textY.value = (tmpl['textYPercent'] ?? 50).toDouble();
    fontSize.value = (tmpl['fontSize'] ?? 14).toDouble();
    textColor.value = Color(tmpl['textColor'] ?? Colors.black.value);
    copiesPerCard.text = (tmpl['copiesPerCard'] ?? "1").toString();
    perRow.text = (tmpl['perRow'] ?? "3").toString();
    perColumn.text = (tmpl['perColumn'] ?? "4").toString();
    widthMM.text = (tmpl['widthMM'] ?? "85").toString();
    heightMM.text = (tmpl['heightMM'] ?? "55").toString();
  }

  Future<void> _loadCards() async {
    if (selectedCategory == null && selectedCategoryIds.isEmpty) return;
    final Query query = _firestore
        .collection('cards')
        .where('status', isEqualTo: 'print_ready');
    if (selectedCategoryIds.isNotEmpty) {
      // طباعة مجمعة: نستخدم whereIn (يحتاج فهرس في Firestore)
      // لكن حيث أن Firestore لا يدعم whereIn مع استعلامات متعددة بسهولة بدون فهرس،
      // سنستخدم طريقة بديلة أو نطلب إنشاء فهرس. للتبسيط، سنفترض أن المستخدم يختار فئة واحدة للطباعة.
      // يمكن تطويرها لاحقًا.
    }
    if (selectedCategory != null) {
      // old single category
      final snapshot = await _firestore
          .collection('cards')
          .where('categoryId', isEqualTo: selectedCategory!['id'])
          .where('status', isEqualTo: 'print_ready')
          .get();
      setState(() {
        cards = snapshot.docs;
        if (cards.isNotEmpty) {
          printCountController.text = cards.length.toString();
        } else {
          printCountController.text = '0';
        }
      });
    }
  }

  Future<void> _loadArchive() async {
    final snapshot = await _firestore
        .collection('cards')
        .where('status', isEqualTo: 'archived')
        .get();
    setState(() {
      archivedCards = snapshot.docs;
    });
  }

  Future<void> _loadPrintLogs() async {
    final snap = await _firestore
        .collection('print_logs')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();
    setState(() {
      printLogs = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return PrintLog(
          id: d.id,
          networkId: data['networkId'] ?? '',
          categoryId: data['categoryId'] ?? '',
          count: data['count'] ?? 0,
          type: data['type'] ?? '',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
    });
  }

  Future<void> _logPrintAction(String type, int count) async {
    await _firestore.collection('print_logs').add({
      'agentPhone': sys.currentUserPhone,
      'networkId': selectedNetworkId ?? '',
      'categoryId': selectedCategory?['id'] ?? '',
      'count': count,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _loadPrintLogs();
  }

  void loadSavedSettings() {
    if (selectedCategory == null) return;
    final cat = selectedCategory!;
    textX.value = (cat['textXPercent'] ?? 50).toDouble();
    textY.value = (cat['textYPercent'] ?? 50).toDouble();
    fontSize.value = (cat['textFontSize'] ?? 14).toDouble();
    textColor.value = Color(cat['textColor'] ?? Colors.black.value);
    copiesPerCard.text = (cat['copiesPerCard'] ?? 1).toString();
    perRow.text = (cat['cardsPerRow'] ?? 3).toString();
    perColumn.text = (cat['cardsPerColumn'] ?? 4).toString();
    widthMM.text = (cat['cardWidth'] ?? 85).toString();
    heightMM.text = (cat['cardHeight'] ?? 55).toString();
    if (cat['templateBase64'] != null) {
      templateImage = base64Decode(cat['templateBase64']);
    } else {
      templateImage = null;
    }
  }

  Future<void> saveSettings() async {
    if (selectedNetworkId == null || selectedCategory == null) return;
    final networkRef = _firestore.collection('networks').doc(selectedNetworkId);
    final doc = await networkRef.get();
    final data = doc.data();
    if (data == null) return;
    List cats = List<Map<String, dynamic>>.from(data['categories'] ?? []);
    final index = cats.indexWhere((e) => e['id'] == selectedCategory!['id']);
    if (index == -1) return;
    cats[index] = {
      ...cats[index],
      'textXPercent': textX.value,
      'textYPercent': textY.value,
      'textFontSize': fontSize.value,
      'textColor': textColor.value.value,
      'copiesPerCard': int.tryParse(copiesPerCard.text) ?? 1,
      'cardsPerRow': int.tryParse(perRow.text) ?? 3,
      'cardsPerColumn': int.tryParse(perColumn.text) ?? 4,
      'cardWidth': double.tryParse(widthMM.text) ?? 85,
      'cardHeight': double.tryParse(heightMM.text) ?? 55,
    };
    await networkRef.update({'categories': cats});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم حفظ الإعدادات")));
    }
  }

  // ========== طباعة ==========
  Future<Uint8List> generatePdf(int count) async {
    final pdf = pw.Document();
    final perRowVal = int.tryParse(perRow.text) ?? 3;
    final width = double.tryParse(widthMM.text) ?? 85;
    final height = double.tryParse(heightMM.text) ?? 55;
    final selectedCards = cards.take(count).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.GridView(
            crossAxisCount: perRowVal,
            children: selectedCards.map((card) {
              final pin = card['pin'] ?? '------';
              return pw.Container(
                width: width * PdfPageFormat.mm,
                height: height * PdfPageFormat.mm,
                child: pw.Stack(
                  children: [
                    if (templateImage != null)
                      pw.Image(pw.MemoryImage(templateImage!), fit: pw.BoxFit.fill),
                    pw.Positioned(
                      left: (textX.value / 100) * width * PdfPageFormat.mm,
                      top: (textY.value / 100) * height * PdfPageFormat.mm,
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
    return pdf.save();
  }

  void showPrintDialog() {
    final int available = cards.length;
    int requested = int.tryParse(printCountController.text) ?? available;
    if (requested > available) requested = available;
    if (requested <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لا توجد كروت للطباعة")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("تأكيد الطباعة"),
          content: Text(
              "الكروت الجاهزة: $available\nسيتم طباعة: $requested كرت"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            TextButton(
              child: const Text("معاينة فقط"),
              onPressed: () async {
                Navigator.pop(context);
                final pdf = await generatePdf(requested);
                await Printing.layoutPdf(onLayout: (_) => pdf);
                _logPrintAction('view', requested);
              },
            ),
            TextButton(
              child: const Text("طباعة فقط"),
              onPressed: () async {
                Navigator.pop(context);
                final pdf = await generatePdf(requested);
                await Printing.layoutPdf(onLayout: (_) => pdf);
                _logPrintAction('print_only', requested);
              },
            ),
            TextButton(
              child: const Text("طباعة وأرشفة"),
              onPressed: () async {
                Navigator.pop(context);
                final pdf = await generatePdf(requested);
                await Printing.layoutPdf(onLayout: (_) => pdf);
                // الأرشيف
                final batch = _firestore.batch();
                for (var i = 0; i < requested; i++) {
                  batch.update(cards[i].reference, {'status': 'archived'});
                }
                final networkRef =
                    _firestore.collection('networks').doc(selectedNetworkId);
                final docSnapshot = await networkRef.get();
                final data = docSnapshot.data();
                if (data != null) {
                  List cats =
                      List<Map<String, dynamic>>.from(data['categories'] ?? []);
                  final index = cats.indexWhere(
                      (e) => e['id'] == selectedCategory!['id']);
                  if (index != -1) {
                    final currentStock = cats[index]['stock'] ?? 0;
                    cats[index]['stock'] = (currentStock as int) - requested;
                    batch.update(networkRef, {'categories': cats});
                  }
                }
                await batch.commit();
                _loadCards();
                _loadArchive();
                _logPrintAction('print_archive', requested);
              },
            ),
          ],
        );
      },
    );
  }

  // ========== اختصارات المواضع ==========
  void _setPosition(double x, double y) {
    textX.value = x;
    textY.value = y;
  }

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
      onTap: () => _setPosition(x, y),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label),
      ),
    );
  }

  // ========== معاينة بحجم حقيقي (قابلة للتكبير) ==========
  Widget _fullSizePreview() {
    if (templateImage == null) return const Text("لا يوجد قالب");
    return ValueListenableBuilder(
      valueListenable: textX,
      builder: (_, __, ___) => ValueListenableBuilder(
        valueListenable: textY,
        builder: (_, __, ___) => ValueListenableBuilder(
          valueListenable: fontSize,
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: textColor,
            builder: (_, __, ___) {
              return InteractiveViewer(
                maxScale: 4.0,
                child: Container(
                  width: double.parse(widthMM.text) * 3,
                  height: double.parse(heightMM.text) * 3,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: MemoryImage(templateImage!),
                      fit: BoxFit.fill,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: (textX.value / 100) *
                            double.parse(widthMM.text) *
                            3,
                        top: (textY.value / 100) *
                            double.parse(heightMM.text) *
                            3,
                        child: Text(
                          "####",
                          style: TextStyle(
                            fontSize: fontSize.value * 2,
                            color: textColor.value,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ========== الأرشيف ==========
  Widget _buildArchiveTab() {
    final filtered = archiveSearchQuery.isEmpty
        ? archivedCards
        : archivedCards
            .where((c) => (c['pin'] ?? '')
                .toLowerCase()
                .contains(archiveSearchQuery.toLowerCase()))
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
        Text('${filtered.length} كرت في الأرشيف'),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final card = filtered[index];
              return ListTile(
                title: Text(card['pin'] ?? '---'),
                subtitle: Text(card['categoryId'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore, color: Colors.orange),
                      onPressed: () async {
                        await card.reference.update({'status': 'print_ready'});
                        _loadArchive();
                        _loadCards();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await card.reference.delete();
                        _loadArchive();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
          TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.orange,
            tabs: const [
              Tab(icon: Icon(Icons.print), text: "الطباعة"),
              Tab(icon: Icon(Icons.archive), text: "الأرشيف"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPrintTab(),
                _buildArchiveTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إعدادات الطباعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // اختيار الشبكة
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'اختر الشبكة', border: OutlineInputBorder()),
            value: selectedNetworkId,
            items: networks.map((e) {
              return DropdownMenuItem<String>(
                value: e.id,
                child: Text(e['name'] ?? ''),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                selectedNetworkId = val;
                selectedCategory = null;
                templateImage = null;
                cards = [];
              });
              if (val != null) {
                // load categories for display
              }
            },
          ),
          const SizedBox(height: 12),
          // اختيار الفئة مع مؤشر المخزون
          if (selectedNetworkId != null &&
              networkCategories[selectedNetworkId] != null)
            DropdownButtonFormField<Map<String, dynamic>>(
              decoration: const InputDecoration(
                  labelText: 'اختر الفئة',
                  border: OutlineInputBorder()),
              value: selectedCategory,
              items: networkCategories[selectedNetworkId]!
                  .map((cat) {
                    final readyCount = cards
                        .where((c) => c['categoryId'] == cat['id'])
                        .length;
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: cat,
                      child: Text(
                          "${cat['name']} (${cat['stock'] ?? 0} مخزون، جاهز: $readyCount)"),
                    );
                  })
                  .toList(),
              onChanged: (val) {
                setState(() => selectedCategory = val);
                if (val != null) {
                  loadSavedSettings();
                  _loadCards();
                }
              },
            ),
          const SizedBox(height: 10),
          // اختصارات المواضع
          _positionShortcuts(),
          // معاينة بحجم حقيقي
          _fullSizePreview(),
          // إعدادات النص
          slider("الموقع الأفقي %", textX, 100),
          slider("الموقع الرأسي %", textY, 100),
          slider("حجم الخط", fontSize, 40),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      content: ColorPicker(
                        pickerColor: textColor.value,
                        onColorChanged: (c) => textColor.value = c,
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.colorize, color: textColor.value),
                label: const Text("لون النص"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: textColor.value.withOpacity(0.2)),
              ),
            ],
          ),
          // قوالب الطباعة
          const SizedBox(height: 12),
          const Text("قوالب الطباعة المحفوظة",
              style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            children: savedTemplates.map((t) {
              return TextButton(
                onPressed: () => _applyTemplate(t),
                child: Text(t['name'] ?? ''),
              );
            }).toList(),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      final nameCtrl = TextEditingController();
                      return AlertDialog(
                        title: const Text("حفظ كقالب"),
                        content: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: "اسم القالب"),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
                          ElevatedButton(
                            onPressed: () {
                              if (nameCtrl.text.isNotEmpty) {
                                _saveCurrentAsTemplate(nameCtrl.text);
                                Navigator.pop(context);
                              }
                            },
                            child: const Text("حفظ"),
                          )
                        ],
                      );
                    },
                  );
                },
                child: const Text("حفظ الإعدادات الحالية كقالب"),
              ),
            ],
          ),
          // إعدادات التخطيط
          const SizedBox(height: 20),
          const Text('إعدادات التخطيط',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: copiesPerCard,
                      decoration: const InputDecoration(
                          labelText: "نسخ لكل كرت",
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: perRow,
                      decoration: const InputDecoration(
                          labelText: "كروت/صف",
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: perColumn,
                      decoration: const InputDecoration(
                          labelText: "كروت/عمود",
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: widthMM,
                      decoration: const InputDecoration(
                          labelText: "عرض (مم)",
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
              controller: heightMM,
              decoration: const InputDecoration(
                  labelText: "ارتفاع (مم)", border: OutlineInputBorder()),
              keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saveSettings,
              icon: const Icon(Icons.save),
              label: const Text("حفظ جميع الإعدادات للفئة"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: printCountController,
              decoration: const InputDecoration(
                  labelText: "عدد الكروت المطلوب",
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: showPrintDialog,
              icon: const Icon(Icons.print),
              label: const Text("بدء الطباعة"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ),
          // سجل الطباعة
          const SizedBox(height: 20),
          const Text("سجل آخر عمليات الطباعة",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...printLogs.take(5).map((log) => ListTile(
                title: Text(
                    "${log.count} كرت - ${log.type == 'print_archive' ? 'طباعة وأرشفة' : log.type == 'print_only' ? 'طباعة فقط' : 'معاينة'}"),
                subtitle: Text("${log.timestamp}".substring(0, 19)),
              )),
        ],
      ),
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
              onChanged: (v) => notifier.value = v,
            ),
          ],
        );
      },
    );
  }

  void _logPrintAction(String type, int count) async {
    await _firestore.collection('print_logs').add({
      'agentPhone': sys.currentUserPhone,
      'networkId': selectedNetworkId ?? '',
      'categoryId': selectedCategory?['id'] ?? '',
      'count': count,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // تحديث السجل مباشرة
    _loadPrintLogs();
  }
}
