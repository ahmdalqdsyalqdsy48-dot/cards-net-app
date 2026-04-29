import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/providers/system_provider.dart'; // لاستخدامه في CustomAgentDrawer
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
  final perColumn = TextEditingController(text: "5");
  final widthMM = TextEditingController(text: "50");
  final heightMM = TextEditingController(text: "30");
  final printCountController = TextEditingController(text: "10");
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
    });
  }

  void loadSavedSettings() {
    final cat = selectedCategory!;
    textX.value = (cat['textXPercent'] ?? 50).toDouble();
    textY.value = (cat['textYPercent'] ?? 50).toDouble();
    fontSize.value = (cat['textFontSize'] ?? 14).toDouble();
    textColor.value = Color(cat['textColor'] ?? Colors.black.value);
    copiesPerCard.text = (cat['copiesPerCard'] ?? 1).toString();
    perRow.text = (cat['perRow'] ?? 3).toString();
    perColumn.text = (cat['perColumn'] ?? 5).toString();
    widthMM.text = (cat['widthMM'] ?? 50).toString();
    heightMM.text = (cat['heightMM'] ?? 30).toString();
    if (cat['templateBase64'] != null) {
      templateImage = base64Decode(cat['templateBase64']);
    }
  }

  Future<void> saveSettings() async {
    final networkRef = _firestore.collection('networks').doc(selectedNetworkId);
    final doc = await networkRef.get();
    final data = doc.data();
    List cats = data?['categories'] ?? [];
    final index = cats.indexWhere((e) => e['id'] == selectedCategory!['id']);
    cats[index] = {
      ...cats[index],
      'textXPercent': textX.value,
      'textYPercent': textY.value,
      'textFontSize': fontSize.value,
      'textColor': textColor.value.value,
      'copiesPerCard': int.parse(copiesPerCard.text),
      'perRow': int.parse(perRow.text),
      'perColumn': int.parse(perColumn.text),
      'widthMM': double.parse(widthMM.text),
      'heightMM': double.parse(heightMM.text),
    };
    await networkRef.update({'categories': cats});
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("تم حفظ الإعدادات")));
    }
  }

  Future<Uint8List> generatePdf(int count) async {
    final pdf = pw.Document();
    final perRowVal = int.parse(perRow.text);
    final perColVal = int.parse(perColumn.text);
    final width = double.parse(widthMM.text);
    final height = double.parse(heightMM.text);
    final selectedCards = cards.take(count).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.GridView(
            crossAxisCount: perRowVal,
            children: selectedCards.map((card) {
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
                      left: (textX.value / 100) * width,
                      top: (textY.value / 100) * height,
                      child: pw.Text(
                        card['code'],
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
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("تأكيد الطباعة"),
          content: Text("سيتم طباعة ${printCountController.text} كرت"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            TextButton(
              child: const Text("معاينة"),
              onPressed: () async {
                final pdf = await generatePdf(int.parse(printCountController.text));
                await Printing.layoutPdf(onLayout: (_) => pdf);
              },
            ),
            TextButton(
              child: const Text("طباعة فقط"),
              onPressed: () async {
                final pdf = await generatePdf(int.parse(printCountController.text));
                await Printing.layoutPdf(onLayout: (_) => pdf);
              },
            ),
            TextButton(
              child: const Text("طباعة وأرشفة"),
              onPressed: () async {
                final count = int.parse(printCountController.text);
                final pdf = await generatePdf(count);
                await Printing.layoutPdf(onLayout: (_) => pdf);
                final batch = _firestore.batch();
                for (var i = 0; i < count; i++) {
                  batch.update(cards[i].reference, {'status': 'archived'});
                }
                await batch.commit();
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
          children: [
            DropdownButton(
              hint: const Text("اختر الشبكة"),
              value: selectedNetworkId,
              items: networks.map((e) {
                return DropdownMenuItem(
                  value: e.id,
                  child: Text(e['name']),
                );
              }).toList(),
              onChanged: (val) async {
                selectedNetworkId = val;
                await loadCategories(val!);
                setState(() {});
              },
            ),
            DropdownButton(
              hint: const Text("اختر الفئة"),
              value: selectedCategory,
              items: categories.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e['name']),
                );
              }).toList(),
              onChanged: (val) async {
                selectedCategory = val;
                loadSavedSettings();
                await loadCards();
                setState(() {});
              },
            ),
            const SizedBox(height: 20),
            preview(),
            slider("الموقع الأفقي", textX, 100),
            slider("الموقع الرأسي", textY, 100),
            slider("حجم الخط", fontSize, 40),
            ElevatedButton(
              child: const Text("اختيار لون"),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) {
                    return AlertDialog(
                      content: ColorPicker(
                        pickerColor: textColor.value,
                        onColorChanged: (c) => textColor.value = c,
                      ),
                    );
                  },
                );
              },
            ),
            TextField(
              controller: printCountController,
              decoration: const InputDecoration(labelText: "عدد الكروت"),
            ),
            ElevatedButton(
              onPressed: saveSettings,
              child: const Text("حفظ جميع الإعدادات للفئة"),
            ),
            ElevatedButton(
              onPressed: showPrintDialog,
              child: const Text("بدء الطباعة"),
            ),
          ],
        ),
      ),
    );
  }
}
