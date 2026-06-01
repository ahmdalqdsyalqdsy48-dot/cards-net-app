import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/transactions_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _selectedReportType = 'الكل (شامل)';
  String _selectedAgent = 'الكل';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showChart = false;

  String _scheduleFrequency = 'شهرياً';
  int _scheduleDay = 1;
  int _scheduleHour = 8;
  int _scheduleMinute = 0;
  String _scheduleAmPm = 'صباحاً';
  String _scheduleEmail = '';
  bool _hasSchedule = false;
  String? _scheduleDocId;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  void _showSnack(String m, {bool isErr = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isErr ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

  Future<void> _loadSchedule() async {
    final auth = context.read<AuthProvider>();
    final phone = auth.activeUserPhone ?? 'admin';
    final snap = await _db
        .collection('scheduled_reports')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first.data();
      setState(() {
        _hasSchedule = true;
        _scheduleDocId = snap.docs.first.id;
        _scheduleFrequency = data['frequency'] ?? 'شهرياً';
        _scheduleDay = data['day'] ?? 1;
        _scheduleHour = data['hour'] ?? 8;
        _scheduleMinute = data['minute'] ?? 0;
        _scheduleAmPm = data['amPm'] ?? 'صباحاً';
        _scheduleEmail = data['email'] ?? '';
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredData(TransactionsProvider transactions) {
    List<Map<String, dynamic>> data = List.from(transactions.transactionsLedger);

    if (_startDate != null || _endDate != null) {
      data = data.where((tx) {
        if (tx['timestamp'] == null) return true;
        DateTime txDate = (tx['timestamp'] as Timestamp).toDate();
        if (_startDate != null && txDate.isBefore(_startDate!)) return false;
        if (_endDate != null &&
            txDate.isAfter(_endDate!.add(const Duration(days: 1))))
          return false;
        return true;
      }).toList();
    }

    if (_selectedAgent != 'الكل') {
      data = data
          .where((tx) => tx['agentName'] == _selectedAgent)
          .toList();
    }

    if (_selectedReportType == 'إيداعات وشحن') {
      data = data.where((tx) =>
          tx['type'] == 'deposit' ||
          tx['title'].toString().contains('توريد')).toList();
    } else if (_selectedReportType == 'تسويات وخصومات') {
      data = data.where((tx) =>
          tx['type'].toString().contains('تسوية') ||
          tx['type'] == 'expense').toList();
    }

    return data;
  }

  double _calculateTotalAmount(List<Map<String, dynamic>> filteredData) {
    double total = 0.0;
    for (var tx in filteredData) {
      total += (tx['amount'] ?? 0.0).toDouble();
    }
    return total;
  }

  void _showScheduleDialog() {
    context.read<UiProvider>().playSound('click');
    String freq = _scheduleFrequency;
    int day = _scheduleDay;
    int hour = _scheduleHour;
    int minute = _scheduleMinute;
    String amPm = _scheduleAmPm;
    final emailCtrl = TextEditingController(text: _scheduleEmail);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.schedule, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('جدولة التقرير التلقائي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('سيتم إرسال التقرير إلى بريدك تلقائياً:',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: freq,
                    decoration: InputDecoration(
                        labelText: 'التكرار',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                    items: ['يومياً', 'أسبوعياً', 'شهرياً']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setStateDialog(() => freq = val!),
                  ),
                  const SizedBox(height: 10),
                  if (freq == 'أسبوعياً')
                    _buildDayOfWeekPicker(
                        day, (val) => setStateDialog(() => day = val)),
                  if (freq == 'شهرياً')
                    _buildDayOfMonthPicker(
                        day, (val) => setStateDialog(() => day = val)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(
                              text: hour.toString()),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الساعة (1-12)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            int? h = int.tryParse(val);
                            if (h != null && h >= 1 && h <= 12) {
                              setStateDialog(() => hour = h);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: amPm,
                          decoration: const InputDecoration(
                            labelText: 'صباحاً/مساءاً',
                            border: OutlineInputBorder(),
                          ),
                          items: ['صباحاً', 'مساءاً']
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) =>
                              setStateDialog(() => amPm = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: TextEditingController(
                        text: minute.toString()),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الدقائق (0-59)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      int? m = int.tryParse(val);
                      if (m != null && m >= 0 && m <= 59) {
                        setStateDialog(() => minute = m);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: const Icon(Icons.email, color: Colors.blue),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    _showSnack('يرجى إدخال بريد إلكتروني صحيح!',
                        isErr: true);
                    return;
                  }

                  final auth = context.read<AuthProvider>();
                  final phone = auth.activeUserPhone ?? 'admin';

                  try {
                    if (_scheduleDocId != null) {
                      await _db
                          .collection('scheduled_reports')
                          .doc(_scheduleDocId)
                          .update({
                        'phone': phone,
                        'frequency': freq,
                        'day': day,
                        'hour': hour,
                        'minute': minute,
                        'amPm': amPm,
                        'email': email,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await _db.collection('scheduled_reports').add({
                        'phone': phone,
                        'frequency': freq,
                        'day': day,
                        'hour': hour,
                        'minute': minute,
                        'amPm': amPm,
                        'email': email,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }

                    setState(() {
                      _hasSchedule = true;
                      _scheduleFrequency = freq;
                      _scheduleDay = day;
                      _scheduleHour = hour;
                      _scheduleMinute = minute;
                      _scheduleAmPm = amPm;
                      _scheduleEmail = email;
                    });

                    if (mounted) {
                      context.read<UiProvider>().playSound('success');
                      Navigator.pop(ctx);
                      _showSnack('تم حفظ الجدولة بنجاح! ✅');
                    }
                  } catch (e) {
                    _showSnack('خطأ: $e', isErr: true);
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayOfWeekPicker(int current, Function(int) onChanged) {
    final days = [
      'السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'
    ];
    return DropdownButtonFormField<int>(
      value: current,
      decoration: const InputDecoration(
        labelText: 'يوم الأسبوع',
        border: OutlineInputBorder(),
      ),
      items: List.generate(
          7,
          (i) => DropdownMenuItem(value: i + 1, child: Text(days[i]))),
      onChanged: (val) => onChanged(val!),
    );
  }

  Widget _buildDayOfMonthPicker(int current, Function(int) onChanged) {
    return DropdownButtonFormField<int>(
      value: current,
      decoration: const InputDecoration(
        labelText: 'يوم الشهر (1-28)',
        border: OutlineInputBorder(),
      ),
      items: List.generate(
          28,
          (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
      onChanged: (val) => onChanged(val!),
    );
  }

  Future<void> _exportToPDF(
      List<Map<String, dynamic>> data, double totalAmount) async {
    context.read<UiProvider>().playSound('click');
    _showSnack('جاري تجهيز ملف PDF... ⏳');
    try {
      final pdf = pw.Document();
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicFontBold = await PdfGoogleFonts.cairoBold();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('تقرير كروت نت الشامل',
                    style: pw.TextStyle(
                        font: arabicFontBold, fontSize: 24))),
            pw.Text(
                'تاريخ التصدير: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
            pw.Text(
                'الوكيل المحدد: $_selectedAgent | نوع التقرير: $_selectedReportType'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(
                  font: arabicFontBold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blue800),
              rowDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey100),
              cellAlignment: pw.Alignment.center,
              headers: ['المبلغ', 'النوع', 'اسم الوكيل', 'التاريخ'],
              data: data.map((row) {
                String dateStr = row['timestamp'] != null
                    ? DateFormat('yyyy-MM-dd HH:mm')
                        .format((row['timestamp'] as Timestamp).toDate())
                    : '';
                return [
                  '${row['amount']} ريال',
                  row['type'] ?? '',
                  row['agentName'] ?? '',
                  dateStr,
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('إجمالي المبالغ في التقرير:',
                      style: pw.TextStyle(
                          font: arabicFontBold, fontSize: 16)),
                  pw.Text('${totalAmount.toStringAsFixed(0)} ريال',
                      style: pw.TextStyle(
                          font: arabicFontBold,
                          fontSize: 16,
                          color: PdfColors.green700)),
                ])
          ];
        },
      ));

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'CardsNet_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      context.read<UiProvider>().playSound('success');
      _showSnack('تم فتح نافذة الطباعة/المشاركة ✅');
    } catch (e) {
      context.read<UiProvider>().playSound('error');
      _showSnack('حدث خطأ أثناء التصدير: $e', isErr: true);
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> data) async {
    context.read<UiProvider>().playSound('click');
    _showSnack('جاري إعداد ملف الإكسل... 📊');
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];
      excel.setDefaultSheet('Sheet1');

      sheetObject.appendRow([
        TextCellValue('التاريخ'),
        TextCellValue('اسم الوكيل'),
        TextCellValue('نوع العملية'),
        TextCellValue('المبلغ (ريال)')
      ]);

      for (var row in data) {
        String dateStr = row['timestamp'] != null
            ? DateFormat('yyyy-MM-dd HH:mm')
                .format((row['timestamp'] as Timestamp).toDate())
            : '';
        sheetObject.appendRow([
          TextCellValue(dateStr),
          TextCellValue(row['agentName']?.toString() ?? ''),
          TextCellValue(row['type']?.toString() ?? ''),
          DoubleCellValue((row['amount'] ?? 0.0).toDouble()),
        ]);
      }

      var fileBytes = excel.save();

      if (!kIsWeb) {
        Directory directory = await getApplicationDocumentsDirectory();
        String filePath =
            '${directory.path}/CardsNet_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes!);
        context.read<UiProvider>().playSound('success');
        _showSnack('تم حفظ الملف بنجاح في المسار:\n$filePath');
      } else {
        _showSnack(
            'بيانات الإكسل جاهزة! استخدم PDF للحفظ على الويب.');
      }
    } catch (e) {
      context.read<UiProvider>().playSound('error');
      _showSnack('حدث خطأ أثناء تصدير الإكسل: $e', isErr: true);
    }
  }

  void _showTransactionReceipt(
      Map<String, dynamic> log, SettingsProvider settings) {
    context.read<UiProvider>().playSound('click');
    final GlobalKey receiptKey = GlobalKey();

    final double amount =
        double.tryParse(log['amount'].toString()) ?? 0.0;
    final bool isPositive =
        log['type'] == 'deposit' || log['type'] == 'income';
    final Color color = isPositive ? Colors.green : Colors.red;
    final String dateStr = log['timestamp'] != null
        ? DateFormat('yyyy-MM-dd hh:mm a')
            .format((log['timestamp'] as Timestamp).toDate())
        : 'الآن';

    showDialog(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          content: RepaintBoundary(
            key: receiptKey,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).cardColor,
                    color.withOpacity(0.08)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: color.withOpacity(0.3), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(
                        isPositive
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: 30,
                        color: color),
                  ),
                  const SizedBox(height: 10),
                  Text('نظام ${settings.appName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey)),
                  Text('إشعار عملية مالية',
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(thickness: 1.5)),
                  Text(log['title'] ?? log['type'] ?? 'عملية مسجلة',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  _buildReceiptRow('المرجع',
                      log['reference'] ?? 'لا يوجد',
                      isBold: true),
                  _buildReceiptRow('التاريخ', dateStr),
                  _buildReceiptRow(
                      'المبلغ',
                      '${NumberFormat('#,###').format(amount)} ريال',
                      valueColor: color,
                      isBold: true),
                  _buildReceiptRow('الطرف الآخر',
                      log['agentName'] ?? 'مجهول'),
                  if (log['networkName'] != null &&
                      log['networkName'] != 'غير محدد')
                    _buildReceiptRow(
                        'الشبكة', log['networkName']),
                  if (log['paymentMethod'] != null)
                    _buildReceiptRow(
                        'طريقة الدفع', log['paymentMethod']),
                  if (log['fee'] != null &&
                      double.tryParse(log['fee'].toString()) != 0)
                    _buildReceiptRow(
                        'الرسوم التشغيلية',
                        '${NumberFormat('#,###').format(log['fee'])} ريال',
                        valueColor: Colors.red),
                  if (log['reason'] != null)
                    _buildReceiptRow('السبب', log['reason']),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(thickness: 1.5)),
                  const Text('المركز المالي لمالك النظام',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('إغلاق',
                    style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold))),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.blue),
              tooltip: 'نسخ كنص',
              onPressed: () {
                context.read<UiProvider>().playSound('click');
                String text =
                    "🧾 *إشعار عملية - ${settings.appName}*\n";
                text +=
                    "المرجع: ${log['reference'] ?? 'لا يوجد'}\n";
                text += "التاريخ: $dateStr\n";
                text +=
                    "البيان: ${log['title'] ?? log['type']}\n";
                text +=
                    "المبلغ: ${NumberFormat('#,###').format(amount)} ريال\n";
                text +=
                    "الطرف: ${log['agentName'] ?? 'مجهول'}\n";
                Clipboard.setData(ClipboardData(text: text));
                _showSnack('تم نسخ النص بنجاح');
              },
            ),
            ElevatedButton.icon(
                icon: const Icon(Icons.image,
                    color: Colors.white, size: 16),
                label: const Text('مشاركة',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                onPressed: () async {
                  context.read<UiProvider>().playSound('click');
                  _showSnack('جاري تجهيز الصورة... ⏳');
                  try {
                    RenderRepaintBoundary boundary = receiptKey
                        .currentContext!
                        .findRenderObject() as RenderRepaintBoundary;
                    ui.Image image =
                        await boundary.toImage(pixelRatio: 3.0);
                    ByteData? byteData = await image.toByteData(
                        format: ui.ImageByteFormat.png);
                    Uint8List pngBytes =
                        byteData!.buffer.asUint8List();

                    await Share.shareXFiles(
                        [
                          XFile.fromData(pngBytes,
                              mimeType: 'image/png',
                              name: 'receipt.png')
                        ],
                        text:
                            'إيصال عملية مالية - ${settings.appName}');
                    context.read<UiProvider>().playSound('success');
                  } catch (e) {
                    context.read<UiProvider>().playSound('error');
                    _showSnack(
                        'حدث خطأ أثناء التقاط الصورة',
                        isErr: true);
                  }
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: isBold ? 14 : 12,
                  fontWeight:
                      isBold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final transactions = context.watch<TransactionsProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final filteredData = _getFilteredData(transactions);
    final currentTotalAmount = _calculateTotalAmount(filteredData);

    List<String> agentNames = ['الكل'];
    agentNames.addAll(wallet.agentsList
        .map((a) => a['name'].toString())
        .toSet()
        .toList());

    return Scaffold(
      appBar: const CustomHeader(title: 'التقارير الشاملة'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints:
            'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 300));
          context.read<UiProvider>().playSound('success');
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _buildExportBtn(
                              Icons.table_view,
                              'Excel',
                              Colors.green.shade700,
                              () => _exportToExcel(filteredData)),
                          const SizedBox(width: 8),
                          _buildExportBtn(
                              Icons.picture_as_pdf,
                              'PDF',
                              Colors.red.shade700,
                              () => _exportToPDF(
                                  filteredData,
                                  currentTotalAmount)),
                          const SizedBox(width: 8),
                          _buildExportBtn(
                              Icons.schedule,
                              'جدولة',
                              Colors.orange.shade800,
                              _showScheduleDialog),
                        ],
                      ),
                    ),
                    if (_hasSchedule)
                      Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'جدولة: $_scheduleFrequency | $_scheduleEmail | ${_scheduleHour}:${_scheduleMinute.toString().padLeft(2, '0')} $_scheduleAmPm',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 18),
                              onPressed: () async {
                                if (_scheduleDocId != null) {
                                  await _db
                                      .collection(
                                          'scheduled_reports')
                                      .doc(_scheduleDocId)
                                      .delete();
                                  setState(() {
                                    _hasSchedule = false;
                                    _scheduleDocId = null;
                                  });
                                  _showSnack('تم حذف الجدولة');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedReportType,
                            decoration: const InputDecoration(
                                labelText: 'نوع التقرير'),
                            items: [
                              'الكل (شامل)',
                              'إيداعات وشحن',
                              'تسويات وخصومات'
                            ]
                                .map((e) => DropdownMenuItem(
                                    value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) => setState(() =>
                                _selectedReportType = val!),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedAgent,
                            decoration: const InputDecoration(
                                labelText: 'الوكيل'),
                            items: agentNames
                                .map((e) => DropdownMenuItem(
                                    value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) => setState(
                                () => _selectedAgent = val!),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final picked =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: _startDate ??
                                          DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null)
                                      setState(() =>
                                          _startDate = picked);
                                  },
                                  icon: const Icon(
                                      Icons.date_range,
                                      color: Colors.blueAccent),
                                  label: Text(_startDate == null
                                      ? 'بداية الفترة'
                                      : _formatDate(
                                          _startDate!)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final picked =
                                        await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _endDate ?? DateTime.now(),
                                      firstDate: _startDate ??
                                          DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null)
                                      setState(
                                          () => _endDate = picked);
                                  },
                                  icon: const Icon(
                                      Icons.date_range,
                                      color: Colors.orangeAccent),
                                  label: Text(_endDate == null
                                      ? 'نهاية الفترة'
                                      : _formatDate(_endDate!)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
          body: filteredData.isEmpty
              ? const Center(
                  child: Text('لا توجد بيانات مطابقة للفلاتر'))
              : _showChart
                  ? _buildChartView(filteredData)
                  : _buildTableView(filteredData, settings),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.blue.shade900,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
                'إجمالي كروت: ${settings.totalSystemCards}',
                style: const TextStyle(color: Colors.white)),
            Text(
                'مجموع المبالغ: ${currentTotalAmount.toStringAsFixed(0)} ريال',
                style: const TextStyle(color: Colors.greenAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableView(
      List<Map<String, dynamic>> data, SettingsProvider settings) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final row = data[index];
        String dateStr = '';
        if (row['timestamp'] != null) {
          dateStr = DateFormat('yyyy-MM-dd HH:mm')
              .format((row['timestamp'] as Timestamp).toDate());
        }

        bool isPositive = row['type'] == 'deposit' ||
            row['type'] == 'income' ||
            row['title'].toString().contains('توريد');
        Color amountColor = isPositive ? Colors.green : Colors.red;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            onTap: () => _showTransactionReceipt(row, settings),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                            row['title'] ??
                                row['type'] ??
                                'عملية',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      Text(
                          '$dateStr',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          row['agentName'] ?? 'مجهول',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text(
                          '${isPositive ? '+' : ''}${row['amount']} ريال',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: amountColor,
                              fontSize: 14)),
                    ],
                  ),
                  if (row['reference'] != null)
                    Text('المرجع: ${row['reference']}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.blueGrey)),
                  if (row['networkName'] != null &&
                      row['networkName'] != 'غير محدد')
                    Text('الشبكة: ${row['networkName']}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.blueGrey)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartView(List<Map<String, dynamic>> data) {
    Map<String, double> agentTotals = {};
    for (var tx in data) {
      String name = tx['agentName'] ?? 'مجهول';
      double amount = (tx['amount'] ?? 0.0).toDouble();
      agentTotals[name] =
          (agentTotals[name] ?? 0.0) + amount;
    }

    var sortedAgents = agentTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var topAgents = sortedAgents.take(4).toList();

    double maxAmount =
        topAgents.isNotEmpty ? topAgents.first.value : 1.0;
    if (maxAmount == 0) maxAmount = 1.0;

    List<Color> barColors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('أعلى الوكلاء في هذه الفترة (مبالغ)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple)),
              const SizedBox(height: 30),
              Expanded(
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: topAgents
                      .asMap()
                      .entries
                      .map((entry) {
                    int index = entry.key;
                    var agentData = entry.value;
                    double barHeight =
                        (agentData.value / maxAmount) * 150.0;
                    if (barHeight < 10) barHeight = 10;

                    return _buildBar(
                        agentData.key,
                        barHeight,
                        barColors[index % barColors.length],
                        agentData.value);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                  '💡 الرسم البياني يتغير آلياً حسب الفلاتر أعلاه.',
                  style: TextStyle(
                      color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(
      String label, double height, Color color, double amount) {
    String shortLabel =
        label.length > 8 ? '${label.substring(0, 8)}..' : label;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(amount.toStringAsFixed(0),
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 0))
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(shortLabel,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildExportBtn(IconData icon, String label, Color color,
      VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12)),
      style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 0),
          elevation: 1),
    );
  }
}
