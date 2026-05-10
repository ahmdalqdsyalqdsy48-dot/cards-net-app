import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as ex;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

class UserTransactionsScreen extends StatefulWidget {
  const UserTransactionsScreen({super.key});

  @override
  State<UserTransactionsScreen> createState() => _UserTransactionsScreenState();
}

class _UserTransactionsScreenState extends State<UserTransactionsScreen> {
  DateTimeRange? _selectedDateRange;
  String _selectedType = 'الكل';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // نافذة اختيار التاريخ
  // ==========================================
  Future<void> _selectDateRange() async {
    _play('click');
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  // ==========================================
  // معالجة البيانات (تصنيف، فلترة، رصيد تراكمي)
  // ==========================================
  List<Map<String, dynamic>> _processData(
      List<Map<String, dynamic>> rawList, String currentPhone) {
    List<Map<String, dynamic>> processed = [];

    for (var tx in rawList) {
      // التصفية الأساسية للمستخدم الحالي
      final from = tx['fromPhone'] ?? '';
      final to = tx['toPhone'] ?? '';
      if (from != currentPhone && to != currentPhone) continue;

      final Timestamp? timestamp = tx['timestamp'];
      final DateTime dt =
          timestamp != null ? timestamp.toDate() : DateTime.now();
      final double amount = (tx['amount'] ?? 0).toDouble();
      final String type = tx['type'] ?? 'أخرى';
      final String title = tx['title'] ?? '';
      final String ref = tx['reference'] ?? '';
      final String network = tx['networkName'] ?? '';
      final String note = tx['note'] ?? '';

      bool isIncoming = (to == currentPhone);
      double incomingAmount = isIncoming ? amount : 0.0;
      double outgoingAmount = isIncoming ? 0.0 : amount;

      String uiType;
      IconData uiIcon;
      Color uiColor;
      String uiLabel;

      switch (type) {
        case 'sale':
          uiType = 'شراء كرت';
          uiIcon = Icons.shopping_cart;
          uiColor = Colors.orange;
          uiLabel = 'شراء';
          break;
        case 'deposit':
          uiType = 'إيداع / شحن';
          uiIcon = Icons.account_balance_wallet;
          uiColor = Colors.green;
          uiLabel = 'شحن';
          break;
        case 'transfer':
          uiType = 'تحويل';
          uiIcon = Icons.swap_horiz;
          uiColor = Colors.blue;
          uiLabel = 'تحويل';
          break;
        case 'credit_refund':
          uiType = 'استرداد رصيد';
          uiIcon = Icons.replay;
          uiColor = Colors.teal;
          uiLabel = 'استرداد';
          break;
        default:
          uiType = type;
          uiIcon = Icons.receipt;
          uiColor = Colors.grey;
          uiLabel = 'أخرى';
      }

      processed.add({
        'rawDate': dt,
        'date': intl.DateFormat('yyyy-MM-dd').format(dt),
        'time': intl.DateFormat('hh:mm a').format(dt),
        'title': title.isNotEmpty ? title : uiLabel,
        'type': uiType,
        'icon': uiIcon,
        'color': uiColor,
        'amount': amount,
        'isIncoming': isIncoming,
        'incomingAmount': incomingAmount,
        'outgoingAmount': outgoingAmount,
        'reference': ref,
        'network': network,
        'note': note,
      });
    }

    // ترتيب تصاعدي لحساب الرصيد التراكمي
    processed.sort((a, b) => (a['rawDate'] as DateTime).compareTo(b['rawDate'] as DateTime));
    double runningBalance = 0;
    for (var row in processed) {
      runningBalance += row['incomingAmount'];
      runningBalance -= row['outgoingAmount'];
      row['balance'] = runningBalance;
    }
    // عكس ليظهر الأحدث أولاً
    processed = processed.reversed.toList();

    // تطبيق الفلاتر الإضافية
    return processed.where((row) {
      // فلتر النوع
      if (_selectedType != 'الكل' && row['type'] != _selectedType) {
        return false;
      }
      // فلتر النص
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        final title = (row['title'] ?? '').toString().toLowerCase();
        final ref = (row['reference'] ?? '').toString().toLowerCase();
        final network = (row['network'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !ref.contains(q) && !network.contains(q)) {
          return false;
        }
      }
      // فلتر التاريخ
      if (_selectedDateRange != null) {
        DateTime rowDate = row['rawDate'];
        DateTime start = DateTime(_selectedDateRange!.start.year,
            _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        DateTime end = DateTime(_selectedDateRange!.end.year,
            _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        if (rowDate.isBefore(start) || rowDate.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  // ==========================================
  // إيصال تفصيلي ذكي
  // ==========================================
  void _showReceipt(Map<String, dynamic> row) {
    _play('click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(row['icon'], color: row['color'], size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(row['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.confirmation_number, 'المرجع', row['reference'] ?? '-'),
                _infoRow(Icons.calendar_today, 'التاريخ والوقت', '${row['date']} ${row['time']}'),
                if (row['network'].toString().isNotEmpty)
                  _infoRow(Icons.wifi, 'الشبكة', row['network']),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${row['amount']} ريال',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: row['isIncoming'] ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الرصيد بعد العملية:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${row['balance']} ريال',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                if (row['note'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('ملاحظة: ${row['note']}',
                        style: const TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _shareReceipt(row);
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('مشاركة'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/user_support_screen',
                    arguments: {'subject': 'استفسار حول العملية رقم ${row['reference']}'});
              },
              icon: const Icon(Icons.support_agent, size: 18),
              label: const Text('دعم فني'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _shareReceipt(Map<String, dynamic> row) {
    final text = '''
🧾 إيصال عملية
المرجع: ${row['reference']}
التاريخ: ${row['date']} ${row['time']}
المبلغ: ${row['amount']} ريال
النوع: ${row['type']}
الرصيد بعد العملية: ${row['balance']} ريال
''';
    Share.share(text);
  }

  // ==========================================
  // تصدير PDF
  // ==========================================
  Future<void> _exportPDF(List<Map<String, dynamic>> data) async {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    _showSnack('جاري تجهيز PDF...');
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      textDirection: pw.TextDirection.rtl,
      build: (ctx) => [
        pw.Text('سجل العمليات المالية', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('المستخدم: ${sys.currentUserName}'),
        pw.Text('رقم الهاتف: ${sys.currentUserPhone}'),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: ['التاريخ', 'النوع', 'المبلغ', 'الرصيد'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
          cellAlignment: pw.Alignment.center,
          data: data.map((r) => [
            '${r['date']} ${r['time']}',
            r['type'],
            (r['isIncoming'] ? '+' : '-') + '${r['amount']}',
            '${r['balance']}',
          ]).toList(),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ==========================================
  // تصدير Excel
  // ==========================================
  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    _showSnack('جاري تجهيز Excel...');
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['المعاملات'];
    excel.delete('Sheet1');
    sheet.appendRow([
      'التاريخ', 'الوقت', 'النوع', 'المبلغ', 'الرصيد'
    ].map((e) => ex.TextCellValue(e)).toList());
    for (var r in data) {
      sheet.appendRow([
        ex.TextCellValue(r['date']),
        ex.TextCellValue(r['time']),
        ex.TextCellValue(r['type']),
        ex.TextCellValue((r['isIncoming'] ? '+' : '-') + r['amount'].toString()),
        ex.TextCellValue(r['balance'].toString()),
      ]);
    }
    var bytes = excel.encode();
    if (bytes != null) {
      final xFile = XFile.fromData(Uint8List.fromList(bytes),
          name: 'transactions_${sys.currentUserPhone}.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      await Share.shareXFiles([xFile], text: 'سجل العمليات');
    }
  }

  // ==========================================
  // بناء الشاشة
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // جميع العمليات من العقل المدبر، نعكسها ليظهر الأحدث أولاً
    final allTransactions = sys.transactionsLedger.reversed.toList();
    final filtered = _processData(allTransactions, sys.currentUserPhone);

    double totalIn = filtered.fold(0, (sum, r) => sum + (r['incomingAmount'] as double));
    double totalOut = filtered.fold(0, (sum, r) => sum + (r['outgoingAmount'] as double));
    double net = totalIn - totalOut;

    // تجميع حسب اليوم
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var row in filtered) {
      final dayKey = row['date'].toString().substring(0, 10);
      grouped.putIfAbsent(dayKey, () => []).add(row);
    }
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: const CustomHeader(title: 'سجل العمليات المالية'),
      drawer: CustomUserDrawer(
        userName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // شريط الفلاتر
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : colorScheme.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            _selectedDateRange == null
                                ? 'الفترة'
                                : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            backgroundColor: colorScheme.surface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: colorScheme.surface,
                          ),
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                          items: ['الكل', 'شراء كرت', 'إيداع / شحن', 'تحويل', 'استرداد رصيد']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {
                            _play('click');
                            setState(() => _selectedType = v!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم المرجع أو البيان...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),

            // ملخص وأزرار تصدير
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryChip('داخل', totalIn, Colors.green),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildSummaryChip('خارج', totalOut, Colors.red),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildSummaryChip('صافي', net, net >= 0 ? Colors.green : Colors.red),
                  ),
                ],
              ),
            ),
            if (filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      onPressed: () => _exportPDF(filtered),
                      tooltip: 'PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.table_view, color: Colors.green),
                      onPressed: () => _exportExcel(filtered),
                      tooltip: 'Excel',
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('لا توجد عمليات في هذه الفترة.',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: sortedDays.length,
                      itemBuilder: (ctx, index) {
                        final day = sortedDays[index];
                        final rows = grouped[day]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              color: colorScheme.primary.withOpacity(0.05),
                              child: Text(day,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary)),
                            ),
                            ...rows.map((row) => Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    onTap: () => _showReceipt(row),
                                    leading: Icon(row['icon'],
                                        color: row['color'], size: 28),
                                    title: Text(row['title'],
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        '${row['date']}  ${row['time']}',
                                        style: const TextStyle(fontSize: 11)),
                                    trailing: Text(
                                      '${row['isIncoming'] ? "+" : "-"}${row['amount']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: row['isIncoming'] ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ),
                                )),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          Text('${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
