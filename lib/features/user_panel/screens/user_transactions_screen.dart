import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  Future<void> _selectDateRange() async {
    _play('click');
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null) setState(() => _selectedDateRange = picked);
  }

  // ========== معالجة البيانات وتصنيفها ==========
  List<Map<String, dynamic>> _processData(
      List<Map<String, dynamic>> rawList, String currentPhone) {
    List<Map<String, dynamic>> processed = [];

    for (var tx in rawList) {
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
      final String category = tx['categoryName'] ?? '';
      final int quantity = tx['quantity'] ?? 1;
      final double unitPrice = (tx['unitPrice'] ?? amount).toDouble();
      final double discount = (tx['discount'] ?? 0).toDouble();
      final String note = tx['note'] ?? '';
      final String senderName = tx['senderName'] ?? '';
      final String receiverName = tx['receiverName'] ?? '';

      bool isIncoming = (to == currentPhone);
      double incomingAmount = isIncoming ? amount : 0.0;
      double outgoingAmount = isIncoming ? 0.0 : amount;

      IconData uiIcon;
      Color uiColor;

      switch (type) {
        case 'sale':
          uiIcon = Icons.shopping_cart;
          uiColor = Colors.orange;
          break;
        case 'deposit':
          uiIcon = Icons.account_balance_wallet;
          uiColor = Colors.green;
          break;
        case 'transfer':
          uiIcon = Icons.swap_horiz;
          uiColor = Colors.blue;
          break;
        case 'credit_refund':
          uiIcon = Icons.replay;
          uiColor = Colors.teal;
          break;
        default:
          uiIcon = Icons.receipt;
          uiColor = Colors.grey;
      }

      processed.add({
        'rawDate': dt,
        'date': intl.DateFormat('yyyy-MM-dd').format(dt),
        'time': intl.DateFormat('hh:mm a').format(dt),
        'title': title.isNotEmpty ? title : type,
        'type': type,
        'icon': uiIcon,
        'color': uiColor,
        'amount': amount,
        'isIncoming': isIncoming,
        'incomingAmount': incomingAmount,
        'outgoingAmount': outgoingAmount,
        'reference': ref,
        'network': network,
        'category': category,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discount': discount,
        'note': note,
        'senderName': senderName,
        'receiverName': receiverName,
      });
    }

    // رصيد تراكمي
    processed.sort((a, b) => (a['rawDate'] as DateTime).compareTo(b['rawDate'] as DateTime));
    double runningBalance = 0;
    for (var row in processed) {
      runningBalance += row['incomingAmount'];
      runningBalance -= row['outgoingAmount'];
      row['balance'] = runningBalance;
    }
    processed = processed.reversed.toList();

    // تطبيق الفلاتر
    return processed.where((row) {
      if (_selectedType != 'الكل' && row['type'] != _selectedType) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        final title = (row['title'] ?? '').toLowerCase();
        final ref = (row['reference'] ?? '').toLowerCase();
        final network = (row['network'] ?? '').toLowerCase();
        if (!title.contains(q) && !ref.contains(q) && !network.contains(q))
          return false;
      }
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

  // ========== إيصال تفصيلي مع مشاركة (نص + صورة) ==========
  void _showReceipt(Map<String, dynamic> row) {
    _play('click');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final GlobalKey receiptKey = GlobalKey();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // بوستر الإيصال (يُستخدم للمشاركة كصورة)
              RepaintBoundary(
                key: receiptKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary.withOpacity(0.2), colorScheme.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(row['icon'], color: row['color'], size: 40),
                      const SizedBox(height: 8),
                      Text(row['title'],
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: colorScheme.onSurface)),
                      const Divider(),
                      _infoRow(Icons.confirmation_number, 'المرجع', row['reference']),
                      _infoRow(Icons.calendar_today, 'التاريخ والوقت', '${row['date']} ${row['time']}'),
                      if (row['network'].toString().isNotEmpty)
                        _infoRow(Icons.wifi, 'الشبكة', row['network']),
                      if (row['category'].toString().isNotEmpty)
                        _infoRow(Icons.category, 'الفئة', row['category']),
                      if ((row['quantity'] ?? 1) > 1)
                        _infoRow(Icons.shopping_cart, 'الكمية', '${row['quantity']}'),
                      if ((row['unitPrice'] ?? row['amount']) != row['amount'])
                        _infoRow(Icons.monetization_on, 'سعر الوحدة', '${row['unitPrice']}'),
                      if ((row['discount'] ?? 0) > 0)
                        _infoRow(Icons.discount, 'الخصم', '${row['discount']}'),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المبلغ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الرصيد بعد العملية', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${row['balance']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // أزرار
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('مشاركة'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _shareReceipt(row, receiptKey);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.secondary,
                        ),
                        icon: const Icon(Icons.support_agent, size: 18),
                        label: const Text('دعم فني'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/user_support_screen',
                              arguments: {
                                'subject':
                                    'استفسار حول العملية رقم ${row['reference']}'
                              });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                      ),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value.toString())),
        ],
      ),
    );
  }

  void _shareReceipt(Map<String, dynamic> row, GlobalKey key) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_fields, color: Colors.blue),
                title: const Text('مشاركة كنص'),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(
                    '🧾 إيصال عملية\nالمرجع: ${row['reference']}\nالتاريخ: ${row['date']} ${row['time']}\nالمبلغ: ${row['amount']} ريال\nالنوع: ${row['type']}\nالرصيد بعد العملية: ${row['balance']} ريال',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.teal),
                title: const Text('مشاركة كصورة'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final boundary = key.currentContext!
                        .findRenderObject() as RenderRepaintBoundary;
                    final image = await boundary.toImage(pixelRatio: 3);
                    final byteData =
                        await image.toByteData(format: ui.ImageByteFormat.png);
                    if (byteData != null) {
                      await Share.shareXFiles([
                        XFile.fromData(byteData.buffer.asUint8List(),
                            name: 'receipt.png', mimeType: 'image/png')
                      ]);
                    }
                  } catch (_) {
                    _showSnack('تعذرت المشاركة كصورة', isError: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== تصدير PDF ==========
  Future<void> _exportPDF(List<Map<String, dynamic>> data) async {
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
        pw.Text('سجل العمليات المالية',
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('المستخدم: ${sys.currentUserName}'),
        pw.Text('رقم الهاتف: ${sys.currentUserPhone}'),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: [
            'التاريخ',
            'النوع',
            'الشبكة',
            'الفئة',
            'الكمية',
            'سعر الوحدة',
            'الخصم',
            'المبلغ',
            'الرصيد'
          ],
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.blueGrey),
          cellAlignment: pw.Alignment.center,
          oddRowDecoration:
              const pw.BoxDecoration(color: PdfColors.grey100),
          data: data.map((r) => [
                '${r['date']} ${r['time']}',
                r['type'],
                r['network'] ?? '-',
                r['category'] ?? '-',
                '${r['quantity'] ?? 1}',
                '${r['unitPrice'] ?? r['amount']}',
                '${r['discount'] ?? 0}',
                (r['isIncoming'] ? '+' : '-') + '${r['amount']}',
                '${r['balance']}',
              ]).toList(),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ========== تصدير Excel ==========
  Future<void> _exportExcel(List<Map<String, dynamic>> data) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    _showSnack('جاري تجهيز Excel...');
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['المعاملات'];
    excel.delete('Sheet1');
    sheet.appendRow([
      'التاريخ', 'الوقت', 'النوع', 'الشبكة', 'الفئة',
      'الكمية', 'سعر الوحدة', 'الخصم', 'المبلغ', 'الرصيد'
    ].map((e) => ex.TextCellValue(e)).toList());
    for (var r in data) {
      sheet.appendRow([
        ex.TextCellValue(r['date']),
        ex.TextCellValue(r['time']),
        ex.TextCellValue(r['type']),
        ex.TextCellValue(r['network'] ?? ''),
        ex.TextCellValue(r['category'] ?? ''),
        ex.TextCellValue('${r['quantity'] ?? 1}'),
        ex.TextCellValue('${r['unitPrice'] ?? r['amount']}'),
        ex.TextCellValue('${r['discount'] ?? 0}'),
        ex.TextCellValue(
            (r['isIncoming'] ? '+' : '-') + r['amount'].toString()),
        ex.TextCellValue(r['balance'].toString()),
      ]);
    }
    var bytes = excel.encode();
    if (bytes != null) {
      await Share.shareXFiles([
        XFile.fromData(Uint8List.fromList(bytes),
            name: 'transactions_${sys.currentUserPhone}.xlsx',
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      ], text: 'سجل العمليات');
    }
  }

  // ========== واجهة المستخدم الرئيسية ==========
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final allTransactions = sys.transactionsLedger.reversed.toList();
    final filtered = _processData(allTransactions, sys.currentUserPhone);

    double totalIn = filtered.fold(0, (sum, r) => sum + (r['incomingAmount'] as double));
    double totalOut = filtered.fold(0, (sum, r) => sum + (r['outgoingAmount'] as double));
    double net = totalIn - totalOut;

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
        child: CustomScrollView(
          slivers: [
            // فلاتر (تختفي مع التمرير)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade900
                      : colorScheme.primary.withOpacity(0.1),
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
                            items: [
                              'الكل',
                              'sale',
                              'deposit',
                              'transfer',
                              'credit_refund'
                            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ملخص وتصدير (يختفي مع التمرير)
            SliverToBoxAdapter(
              child: Padding(
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
                      child: _buildSummaryChip(
                          'صافي', net, net >= 0 ? Colors.green : Colors.red),
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
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
              ),

            // القائمة الرئيسية
            filtered.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('لا توجد عمليات في هذه الفترة.',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final day = sortedDays[index];
                        final rows = grouped[day]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              color: colorScheme.primary.withOpacity(0.05),
                              child: Text(day,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary)),
                            ),
                            ...rows.map((row) => Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    onTap: () => _showReceipt(row),
                                    leading: Icon(row['icon'],
                                        color: row['color'], size: 28),
                                    title: Text(row['title'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        '${row['date']}  ${row['time']}',
                                        style: const TextStyle(fontSize: 11)),
                                    trailing: Text(
                                      '${row['isIncoming'] ? "+" : "-"}${row['amount']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: row['isIncoming']
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                )),
                          ],
                        );
                      },
                      childCount: sortedDays.length,
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
          Text(label,
              style:
                  TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          Text('${amount.toStringAsFixed(0)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
