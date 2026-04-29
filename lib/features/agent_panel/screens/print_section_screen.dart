import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../widgets/custom_agent_drawer.dart';

class PrintSectionScreen extends StatefulWidget {
  const PrintSectionScreen({super.key});

  @override
  State<PrintSectionScreen> createState() => _PrintSectionScreenState();
}

class _PrintSectionScreenState extends State<PrintSectionScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _selectedNetworkId;
  String? _selectedCategoryId;
  Map? _selectedCategory;
  String? _templateBase64;
  List<Map<String, dynamic>> _printReadyCards = [];

  int _copiesPerCard = 1;
  int _cardsPerRow = 3;
  int _cardsPerColumn = 4;
  double _cardWidth = 85;
  double _cardHeight = 55;

  double _pinXPercent = 50;
  double _pinYPercent = 50;
  double _pinFontSize = 14;
  Color _pinColor = Colors.black;

  int? _printCount;
  final TextEditingController _printCountController = TextEditingController();

  late final TextEditingController _copiesController;
  late final TextEditingController _cardsPerRowController;
  late final TextEditingController _cardsPerColumnController;
  late final TextEditingController _cardWidthController;
  late final TextEditingController _cardHeightController;

  @override
  void initState() {
    super.initState();
    _printCountController.addListener(() {
      int? val = int.tryParse(_printCountController.text);
      if (val != null && val >= 0) {
        setState(() => _printCount = val);
      } else {
        setState(() => _printCount = null);
      }
    });

    _copiesController = TextEditingController(text: _copiesPerCard.toString());
    _cardsPerRowController = TextEditingController(text: _cardsPerRow.toString());
    _cardsPerColumnController = TextEditingController(text: _cardsPerColumn.toString());
    _cardWidthController = TextEditingController(text: _cardWidth.toStringAsFixed(1));
    _cardHeightController = TextEditingController(text: _cardHeight.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _printCountController.dispose();
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

  Future<void> _loadPrintReadyCards() async {
    if (_selectedNetworkId == null || _selectedCategoryId == null) return;
    final snapshot = await _db
        .collection('cards')
        .where('categoryId', isEqualTo: _selectedCategoryId)
        .where('status', isEqualTo: 'print_ready')
        .get();
    setState(() {
      _printReadyCards =
          snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      _printCount = _printReadyCards.length;
      _printCountController.text = _printCount.toString();
    });
  }

  Future<void> _saveAllSettings() async {
    if (_selectedNetworkId == null || _selectedCategoryId == null) return;
    final netDoc = await _db.collection('networks').doc(_selectedNetworkId).get();
    List cats = List.from((netDoc.data() as Map)['categories']);
    int idx = cats.indexWhere((c) => c['id'] == _selectedCategoryId);
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
          .doc(_selectedNetworkId)
          .update({'categories': cats});
      _play('success');
      _showToast('تم حفظ جميع الإعدادات للفئة');
    }
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

  Widget _buildLivePreview() {
    if (_templateBase64 == null || _templateBase64!.isEmpty) return const SizedBox.shrink();
    final bytes = base64Decode(_templateBase64!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('معاينة مباشرة:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
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
                Positioned.fill(child: Image.memory(bytes, fit: BoxFit.contain)),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'print_only'),
              icon: const Icon(Icons.print),
              label: const Text('طباعة فقط'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'print_archive'),
              icon: const Icon(Icons.archive),
              label: const Text('طباعة وأرشفة'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
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
      _loadPrintReadyCards();
    }
  }

  Future<void> _generateAndPrintPdf(List<Map<String, dynamic>> cards) async {
    final double xPercent = (_selectedCategory?['textXPercent'] ?? _pinXPercent).toDouble();
    final double yPercent = (_selectedCategory?['textYPercent'] ?? _pinYPercent).toDouble();
    final double fontSize = (_selectedCategory?['textFontSize'] ?? _pinFontSize).toDouble();
    final Color color = Color(_selectedCategory?['textColor'] ?? _pinColor.value);

    final pdf = pw.Document();
    final int cardsPerPage = _cardsPerRow * _cardsPerColumn;
    final int totalPages = (cards.length / cardsPerPage).ceil();

    for (int page = 0; page < totalPages; page++) {
      final pageCards = cards.skip(page * cardsPerPage).take(cardsPerPage).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            List<pw.Widget> cardWidgets = [];
            for (var card in pageCards) {
              String pin = card['pin'] ?? '----';
              pw.Widget cardContent;
              if (_templateBase64 != null && _templateBase64!.isNotEmpty) {
                final templateImage = pw.MemoryImage(base64Decode(_templateBase64!));
                cardContent = pw.Container(
                  width: _cardWidth * 2.83,
                  height: _cardHeight * 2.83,
                  child: pw.Stack(
                    children: [
                      pw.Positioned.fill(child: pw.Image(templateImage, fit: pw.BoxFit.contain)),
                      // وضع النص باستخدام محاذاة دقيقة
                      pw.Align(
                        alignment: pw.Alignment(
                          (xPercent / 100) * 2 - 1,   // تحويل النسبة المئوية إلى Alignment بين -1 و 1
                          (yPercent / 100) * 2 - 1,
                        ),
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(pin,
                              style: pw.TextStyle(
                                fontSize: fontSize,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor(
                                  color.red / 255,
                                  color.green / 255,
                                  color.blue / 255,
                                ),
                              )),
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
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  ),
                  child: pw.Center(
                    child: pw.Text(pin,
                        style: pw.TextStyle(
                            fontSize: fontSize,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor(
                              color.red / 255,
                              color.green / 255,
                              color.blue / 255,
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
        name: 'cards_print_${DateTime.now().millisecondsSinceEpoch}.pdf');
    _play('success');
    _showToast('تم إرسال ملف الطباعة بنجاح');
  }

  Future<void> _archivePrintedCards(List<Map<String, dynamic>> cards) async {
    if (_selectedNetworkId == null || _selectedCategoryId == null) return;
    final WriteBatch batch = _db.batch();

    for (var card in cards) {
      final querySnap = await _db
          .collection('cards')
          .where('pin', isEqualTo: card['pin'])
          .where('categoryId', isEqualTo: _selectedCategoryId)
          .where('status', isEqualTo: 'print_ready')
          .limit(1)
          .get();
      if (querySnap.docs.isNotEmpty) {
        batch.update(querySnap.docs.first.reference, {'status': 'archived'});
      }
    }

    final netDoc = await _db.collection('networks').doc(_selectedNetworkId).get();
    List cats = List.from((netDoc.data() as Map)['categories']);
    int idx = cats.indexWhere((c) => c['id'] == _selectedCategoryId);
    if (idx != -1) {
      cats[idx]['stock'] = (cats[idx]['stock'] ?? 0) - cards.length;
      batch.update(
          _db.collection('networks').doc(_selectedNetworkId), {'categories': cats});
    }

    await batch.commit();
    _showToast('تمت أرشفة ${cards.length} كرت بنجاح');
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('قسم الطباعة والأرشيف'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
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

          if (agentNetworks.isEmpty)
            return const Center(child: Text('لا توجد شبكات لعرض الفئات.'));

          return Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
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
                    value: _selectedNetworkId,
                    items: agentNetworks
                        .map((net) => DropdownMenuItem(
                            value: net.id,
                            child: Text((net.data() as Map)['name'])))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedNetworkId = val;
                        _selectedCategoryId = null;
                        _selectedCategory = null;
                        _templateBase64 = null;
                        _printReadyCards = [];
                        _printCount = null;
                        _printCountController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_selectedNetworkId != null)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'اختر الفئة',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category, color: Colors.orange)),
                      value: _selectedCategoryId,
                      items: (agentNetworks
                              .firstWhere((net) => net.id == _selectedNetworkId)
                              .data() as Map)['categories']
                          .map<DropdownMenuItem<String>>((cat) {
                        return DropdownMenuItem(
                            value: cat['id'], child: Text(cat['name']));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCategoryId = val;
                          if (val != null) {
                            final netData = agentNetworks
                                .firstWhere((net) => net.id == _selectedNetworkId)
                                .data() as Map;
                            final categories = netData['categories'] as List;
                            _selectedCategory =
                                categories.firstWhere((c) => c['id'] == val);
                            _templateBase64 = _selectedCategory?['templateBase64'];
                            _pinXPercent =
                                (_selectedCategory?['textXPercent'] ?? 50).toDouble();
                            _pinYPercent =
                                (_selectedCategory?['textYPercent'] ?? 50).toDouble();
                            _pinFontSize =
                                (_selectedCategory?['textFontSize'] ?? 14).toDouble();
                            _pinColor = Color(
                                _selectedCategory?['textColor'] ?? Colors.black.value);
                            _loadPrintReadyCards();
                          } else {
                            _selectedCategory = null;
                            _templateBase64 = null;
                            _printReadyCards = [];
                            _printCount = null;
                            _printCountController.clear();
                          }
                        });
                      },
                    ),
                  if (_templateBase64 != null && _templateBase64!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('معاينة القالب:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
                  if (_selectedCategory != null) ...[
                    const Text('إعدادات النص على القالب ✍️',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (_templateBase64 != null && _templateBase64!.isNotEmpty)
                      _buildLivePreview(),
                    const SizedBox(height: 12),
                    Text('الموقع الأفقي: ${_pinXPercent.toStringAsFixed(1)}%'),
                    Slider(
                      value: _pinXPercent,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: _pinXPercent.toStringAsFixed(1),
                      onChanged: (v) {
                        // تحديث النص فورًا دون إعادة بناء المعاينة
                        _pinXPercent = v;
                      },
                      onChangeEnd: (v) {
                        setState(() {
                          _pinXPercent = v;
                        });
                      },
                    ),
                    Text('الموقع الرأسي: ${_pinYPercent.toStringAsFixed(1)}%'),
                    Slider(
                      value: _pinYPercent,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: _pinYPercent.toStringAsFixed(1),
                      onChanged: (v) {
                        _pinYPercent = v;
                      },
                      onChangeEnd: (v) {
                        setState(() {
                          _pinYPercent = v;
                        });
                      },
                    ),
                    Text('حجم الخط: ${_pinFontSize.toStringAsFixed(1)} pt'),
                    Slider(
                      value: _pinFontSize,
                      min: 6,
                      max: 40,
                      divisions: 34,
                      label: _pinFontSize.toStringAsFixed(1),
                      onChanged: (v) {
                        _pinFontSize = v;
                      },
                      onChangeEnd: (v) {
                        setState(() {
                          _pinFontSize = v;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final color = await _openColorPicker(_pinColor);
                            if (color != null) setState(() => _pinColor = color);
                          },
                          icon: Icon(Icons.colorize, color: _pinColor),
                          label: const Text('اختر اللون'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _pinColor.withOpacity(0.2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('إعدادات التخطيط',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          onChanged: (v) => _copiesPerCard = int.tryParse(v) ?? 1,
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
                          onChanged: (v) => _cardsPerRow = int.tryParse(v) ?? 3,
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
                          onChanged: (v) => _cardsPerColumn = int.tryParse(v) ?? 4,
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
                          onChanged: (v) => _cardWidth = double.tryParse(v) ?? 85,
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
                    onChanged: (v) => _cardHeight = double.tryParse(v) ?? 55,
                  ),
                  const SizedBox(height: 20),
                  if (_selectedCategory != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveAllSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ جميع الإعدادات للفئة'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_printReadyCards.isNotEmpty) ...[
                    Text('الكروت المعدة للطباعة: ${_printReadyCards.length} كرت',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.teal)),
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
                          : _showPrintConfirmationDialog,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
