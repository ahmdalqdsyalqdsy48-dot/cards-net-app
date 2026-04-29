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

class _PrintSectionScreenState extends State<PrintSectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedNetworkId;
  Map<String, dynamic>? selectedCategory;
  List<QueryDocumentSnapshot> networks = [];
  List<Map<String, dynamic>> categories = [];
  List<QueryDocumentSnapshot> cards = [];

  /// ⚡ تحكم سريع بدون إعادة بناء
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

  @override
  void initState() {
    super.initState();
    loadNetworks();
  }

  Future<void> loadNetworks() async {
    final snapshot = await _firestore.collection('networks').get();
    setState(() {
      networks = snapshot.docs;
    });
  }

  Future<void> loadCategories(String networkId) async {
    final doc = await _firestore.collection('networks').doc(networkId).get();
    final data = doc.data();
    if (data == null) return;
    setState(() {
      categories = List<Map<String, dynamic>>.from(data['categories'] ?? []);
    });
  }

  Future<void> loadCards() async {
    if (selectedCategory == null) return;
    final snapshot = await _firestore
        .collection('cards')
        .where('categoryId', isEqualTo: selectedCategory!['id'])
        .where('status', isEqualTo: 'print_ready')
        .get();
    setState(() {
      cards = snapshot.docs;
      // نجعل العدد الافتراضي هو عدد الكروت الجاهزة
      if (cards.isNotEmpty) {
        printCountController.text = cards.length.toString();
      } else {
        printCountController.text = '0';
      }
    });
  }

  void loadSavedSettings() {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("تم حفظ جميع الإعدادات للفئة")));
    }
  }

  Future<Uint8List> generatePdf(int count) async {
    final pdf = pw.Document();
    final perRowVal = int.tryParse(perRow.text) ?? 3;
    final perColVal = int.tryParse(perColumn.text) ?? 4;
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
                      pw.Image(
                        pw.MemoryImage(templateImage!),
                        fit: pw.BoxFit.fill,
                      ),
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
          content: Text("الكروت الجاهزة: $available\nسيتم طباعة: $requested كرت\nاختر الإجراء:"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            TextButton(
              child: const Text("معاينة فقط"),
              onPressed: () async {
                Navigator.pop(context);
                final pdf = await generatePdf(requested);
                await Printing.layoutPdf(onLayout: (_) => pdf);
              },
            ),
            TextButton(
              child: const Text("طباعة فقط"),
              onPressed: () async {
                Navigator.pop(context);
                final pdf = await generatePdf(requested);
                await Printing.layoutPdf(onLayout: (_) => pdf);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم فتح الملف للطباعة")),
                );
              },
            ),
            TextButton(
              child: const Text("طباعة وأرشفة"),
              onPressed: () async {
                Navigator.pop(context);
                final count = requested;
                final pdf = await generatePdf(count);
                await Printing.layoutPdf(onLayout: (_) => pdf);
                // الأرشفة وتحديث المخزون
                final batch = _firestore.batch();
                for (var i = 0; i < count; i++) {
                  batch.update(cards[i].reference, {'status': 'archived'});
                }
                // تحديث المخزون في الفئة
                final networkRef = _firestore.collection('networks').doc(selectedNetworkId);
                final docSnapshot = await networkRef.get();
                final data = docSnapshot.data();
                if (data != null) {
                  List cats = List<Map<String, dynamic>>.from(data['categories'] ?? []);
                  final index = cats.indexWhere((e) => e['id'] == selectedCategory!['id']);
                  if (index != -1) {
                    final currentStock = cats[index]['stock'] ?? 0;
                    cats[index]['stock'] = (currentStock as int) - count;
                    batch.update(networkRef, {'categories': cats});
                  }
                }
                await batch.commit();
                // إعادة تحميل الكروت والمخزون
                loadCards();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("تمت أرشفة $count كرت وتحديث المخزون")),
                );
              },
            ),
          ],
        );
      },
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

  Widget preview() {
    if (templateImage == null) {
      return const Text("لا يوجد قالب");
    }
    return ValueListenableBuilder(
      valueListenable: textX,
      builder: (_, __, ___) {
        return ValueListenableBuilder(
          valueListenable: textY,
          builder: (_, __, ___) {
            return ValueListenableBuilder(
              valueListenable: fontSize,
              builder: (_, __, ___) {
                return ValueListenableBuilder(
                  valueListenable: textColor,
                  builder: (_, __, ___) {
                    return Container(
                      width: 200,
                      height: 120,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: MemoryImage(templateImage!),
                          fit: BoxFit.fill,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // محاكاة بسيطة للموضع (تقريب)
                          Positioned(
                            left: textX.value * 2,
                            top: textY.value,
                            child: Text(
                              "####",
                              style: TextStyle(
                                fontSize: fontSize.value,
                                color: textColor.value,
                              ),
                            ),
                          )
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    return Scaffold(
      appBar: const CustomHeader(title: 'قسم الطباعة والأرشيف'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إعدادات الطباعة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'اختر الشبكة',
                border: OutlineInputBorder(),
              ),
              value: selectedNetworkId,
              items: networks.map((e) {
                return DropdownMenuItem<String>(
                  value: e.id,
                  child: Text(e['name'] ?? ''),
                );
              }).toList(),
              onChanged: (val) async {
                selectedNetworkId = val;
                selectedCategory = null;
                templateImage = null;
                cards = [];
                if (val != null) {
                  await loadCategories(val);
                }
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            if (categories.isNotEmpty)
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: 'اختر الفئة',
                  border: OutlineInputBorder(),
                ),
                value: selectedCategory,
                items: categories.map((e) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: e,
                    child: Text(e['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (val) async {
                  selectedCategory = val;
                  if (val != null) {
                    loadSavedSettings();
                    await loadCards();
                  }
                  setState(() {});
                },
              ),
            const SizedBox(height: 20),
            if (cards.isNotEmpty)
              Text('الكروت الجاهزة: ${cards.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 10),
            preview(),
            slider("الموقع الأفقي %", textX, 100),
            slider("الموقع الرأسي %", textY, 100),
            slider("حجم الخط", fontSize, 40),
            const SizedBox(height: 10),
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
                  label: const Text("اختيار لون"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textColor.value.withOpacity(0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('إعدادات التخطيط',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: copiesPerCard,
                    decoration: const InputDecoration(labelText: "عدد النسخ لكل كرت", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: perRow,
                    decoration: const InputDecoration(labelText: "كروت في الصف", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: perColumn,
                    decoration: const InputDecoration(labelText: "كروت في العمود", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widthMM,
                    decoration: const InputDecoration(labelText: "عرض الكرت (مم)", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: heightMM,
              decoration: const InputDecoration(labelText: "ارتفاع الكرت (مم)", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
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
              decoration: const InputDecoration(labelText: "عدد الكروت المطلوب", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
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
          ],
        ),
      ),
    );
  }
}
