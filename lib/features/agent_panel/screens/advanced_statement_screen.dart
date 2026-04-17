import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/custom_agent_drawer.dart';

class AdvancedStatementScreen extends StatefulWidget {
  const AdvancedStatementScreen({super.key});

  @override
  State<AdvancedStatementScreen> createState() => _AdvancedStatementScreenState();
}

class _AdvancedStatementScreenState extends State<AdvancedStatementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  DateTimeRange? _selectedDateRange;
  String _selectedType = 'الكل';
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)), 
      end: DateTime.now()
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

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
  // تصدير PDF احترافي (تم تحديث خصائص التلوين)
  // ==========================================
  Future<void> _exportToPDF(List<Map<String, dynamic>> data, SystemProvider sys, double tCredit, double tDebit, double net) async {
    _play('click');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز التقرير المحاسبي (PDF)...', textDirection: TextDirection.rtl)));

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            // الترويسة
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(color: PdfColors.cyan50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('كشف حساب تفصيلي', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)),
                      pw.Text('الوكيل: ${sys.currentUserName}', style: const pw.TextStyle(fontSize: 14)),
                      pw.Text('رقم الهاتف: ${sys.currentUserPhone}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('تاريخ الإصدار', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                      pw.Text(intl.DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
                    ]
                  )
                ]
              )
            ),
            pw.SizedBox(height: 20),

            // الجدول
            pw.TableHelper.fromTextArray(
              headers: ['التاريخ', 'البيان', 'دائن (+)', 'مدين (-)', 'الرصيد'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan800),
              cellAlignment: pw.Alignment.center,
              // تم التحديث هنا لتوافق الإصدار الجديد من مكتبة PDF
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: data.map((row) => [
                '${row['date']}\n${row['time']}',
                row['desc'],
                row['credit'] > 0 ? '+${row['credit']}' : '-',
                row['debit'] > 0 ? '-${row['debit']}' : '-',
                row['balance'].toString(),
              ]).toList(),
            ),
            pw.SizedBox(height: 20),

            // تذييل الملخص
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.cyan), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text('إجمالي الدائن: +$tCredit', style: pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                  pw.Text('إجمالي المدين: -$tDebit', style: pw.TextStyle(color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                  pw.Text('صافي الحركة: $net', style: pw.TextStyle(color: PdfColors.blue700, fontWeight: pw.FontWeight.bold)),
                ]
              )
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Statement_${sys.currentUserPhone}.pdf');
  }

  // ==========================================
  // تصدير Excel (تم التحديث لتوافق الإصدار)
  // ==========================================
  Future<void> _exportToExcel(List<Map<String, dynamic>> data, SystemProvider sys) async {
    _play('click');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز ملف Excel...', textDirection: TextDirection.rtl)));

    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['كشف الحساب'];
    excel.setDefaultSheet('كشف الحساب');
    excel.delete('Sheet1'); // حذف الورقة الافتراضية

    // تم إزالة sheet.isRightToLeft لأن الإصدار 4.0.6 لا يدعمها مباشرة

    // تنسيق الترويسة
    ex.CellStyle headerStyle = ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.blueGrey,
      fontColorHex: ex.ExcelColor.white,
      bold: true,
      horizontalAlign: ex.HorizontalAlign.Center,
    );

    List<String> headers = ['رقم العملية', 'التاريخ', 'الوقت', 'البيان', 'دائن (+)', 'مدين (-)', 'الرصيد'];
    sheet.appendRow(headers.map((e) => ex.TextCellValue(e)).toList());
    
    // تطبيق التنسيق على الصف الأول
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    // تعبئة البيانات
    for (var row in data) {
      sheet.appendRow([
        ex.TextCellValue(row['id'].toString()),
        ex.TextCellValue(row['date'].toString()),
        ex.TextCellValue(row['time'].toString()),
        ex.TextCellValue(row['desc'].toString()),
        ex.DoubleCellValue(row['credit'].toDouble()),
        ex.DoubleCellValue(row['debit'].toDouble()),
        ex.DoubleCellValue(row['balance'].toDouble()),
      ]);
    }

    var fileBytes = excel.encode();
    if (fileBytes != null) {
      final xFile = XFile.fromData(Uint8List.fromList(fileBytes), name: 'Statement_${sys.currentUserPhone}.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      await Share.shareXFiles([xFile], text: 'كشف حساب الوكيل: ${sys.currentUserName}');
    }
  }

  // ==========================================
  // عرض سند إلكتروني للعملية (مع زر مشاركة)
  // ==========================================
  void _showReceiptDialog(Map<String, dynamic> row, SystemProvider sys) {
    _play('click');
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(row['credit'] > 0 ? Icons.arrow_downward : Icons.arrow_upward, color: row['credit'] > 0 ? Colors.green : Colors.red),
                const SizedBox(width: 10),
                const Text('إشعار عملية', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReceiptRow('رقم المرجع:', row['id']),
                const Divider(),
                _buildReceiptRow('التاريخ:', '${row['date']}  ${row['time']}'),
                const Divider(),
                _buildReceiptRow('نوع العملية:', row['type']),
                const Divider(),
                _buildReceiptRow('البيان:', row['desc']),
                const Divider(),
                _buildReceiptRow('المبلغ:', '${row['credit'] > 0 ? row['credit'] : row['debit']} ريال', isBold: true, color: row['credit'] > 0 ? Colors.green : Colors.red),
                const Divider(),
                _buildReceiptRow('الرصيد:', '${row['balance']} ريال', isBold: true, color: Colors.blue),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق', style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                onPressed: () {
                  _play('click');
                  String text = "🧾 *إشعار عملية - ${sys.currentUserName}*\n";
                  text += "المرجع: #${row['id']}\nالتاريخ: ${row['date']} ${row['time']}\n";
                  text += "البيان: ${row['desc']}\n";
                  text += "المبلغ: ${row['credit'] > 0 ? row['credit'] : row['debit']} ريال\n";
                  text += "الرصيد الحالي: ${row['balance']} ريال";
                  Share.share(text);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700),
                icon: const Icon(Icons.share, size: 18, color: Colors.white),
                label: const Text('مشاركة الإشعار', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildReceiptRow(String title, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'كشف الحساب المتقدم'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // الفلاتر والبحث (مفصولة للحفاظ على الكيبورد)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.cyan.shade800,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.date_range, size: 18, color: Colors.cyan),
                          label: Text(
                            _selectedDateRange == null ? 'الفترة الزمنية' : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyan),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedType,
                              isExpanded: true,
                              icon: const Icon(Icons.filter_list, color: Colors.cyan, size: 18),
                              style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                              items: ['الكل', 'مبيعات', 'شحن رصيد', 'أخرى'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) { setState(() => _selectedType = val!); },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'بحث سريع في البيان...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: Colors.cyan),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),

            // StreamBuilder للجدول
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('transactions').where('agentPhone', isEqualTo: sys.currentUserPhone).orderBy('createdAt', descending: true).limit(500).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  
                  List<Map<String, dynamic>> finalData = _processData(snapshot.hasData ? snapshot.data!.docs : []);
                  final double totalCredit = finalData.fold(0.0, (sum, item) => sum + item['credit']);
                  final double totalDebit = finalData.fold(0.0, (sum, item) => sum + item['debit']);
                  final double netMovement = totalCredit - totalDebit;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الملخص المالي للفترة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), onPressed: finalData.isNotEmpty ? () => _exportToPDF(finalData, sys, totalCredit, totalDebit, netMovement) : null),
                                IconButton(icon: const Icon(Icons.table_view, color: Colors.green), onPressed: finalData.isNotEmpty ? () => _exportToExcel(finalData, sys) : null),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(child: _buildSummaryCard('إيداعات (+)', totalCredit, Colors.green)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildSummaryCard('مسحوبات (-)', totalDebit, Colors.red)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildSummaryCard('صافي الحركة', netMovement, Colors.blue)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: Text('البيان / التاريخ', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(flex: 2, child: Text('دائن (+)', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(flex: 2, child: Text('مدين (-)', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(flex: 2, child: Text('الرصيد', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                        ),
                      ),

                      Expanded(
                        child: finalData.isEmpty
                            ? const Center(child: Text('لا توجد عمليات مطابقة في هذه الفترة.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: finalData.length,
                                itemBuilder: (context, index) {
                                  final row = finalData[index];
                                  return InkWell(
                                    onTap: () => _showReceiptDialog(row, sys),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: index % 2 == 0 ? Theme.of(context).cardColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade50),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row['desc'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text('${row['date']} • ${row['time']}', style: const TextStyle(fontSize: 9, color: Colors.grey), textDirection: TextDirection.ltr)])),
                                          Expanded(flex: 2, child: Text(row['credit'] > 0 ? '+${row['credit']}' : '-', textAlign: TextAlign.center, style: TextStyle(color: row['credit'] > 0 ? Colors.green.shade700 : Colors.grey, fontWeight: FontWeight.bold, fontSize: 11))),
                                          Expanded(flex: 2, child: Text(row['debit'] > 0 ? '-${row['debit']}' : '-', textAlign: TextAlign.center, style: TextStyle(color: row['debit'] > 0 ? Colors.red.shade700 : Colors.grey, fontWeight: FontWeight.bold, fontSize: 11))),
                                          Expanded(flex: 2, child: Text('${row['balance']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11))),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // المحرك المحاسبي: تحضير، ترتيب، فلترة، وحساب الرصيد
  // ==========================================
  List<Map<String, dynamic>> _processData(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> rawList = [];
    
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      Timestamp? ts = data['createdAt'];
      DateTime dt = ts != null ? ts.toDate() : DateTime.now();
      
      double amount = (data['amount'] ?? 0).toDouble();
      String rawType = data['type'] ?? 'أخرى';
      
      String uiType = 'أخرى';
      double credit = 0.0;
      double debit = 0.0;
      
      if (rawType == 'sale') {
        uiType = 'مبيعات';
        debit = amount;
      } else if (rawType == 'deposit') {
        uiType = 'شحن رصيد';
        credit = amount;
      }

      String desc = data['desc'] ?? '';
      if (desc.isEmpty && rawType == 'sale') {
        desc = 'بيع كروت: ${data['networkName']} - ${data['categoryName']} (${data['quantity']} كرت)';
      }

      rawList.add({
        'id': doc.id.substring(0, 6).toUpperCase(),
        'rawDate': dt,
        'date': intl.DateFormat('yyyy-MM-dd').format(dt),
        'time': intl.DateFormat('hh:mm a').format(dt),
        'desc': desc,
        'credit': credit,
        'debit': debit,
        'type': uiType,
        'balance': 0.0 
      });
    }

    // الترتيب من الأقدم للأحدث لحساب الرصيد
    rawList.sort((a, b) => (a['rawDate'] as DateTime).compareTo(b['rawDate'] as DateTime));

    double runningBalance = 0.0;
    for (int i = 0; i < rawList.length; i++) {
      runningBalance += rawList[i]['credit'];
      runningBalance -= rawList[i]['debit'];
      rawList[i]['balance'] = runningBalance;
    }

    // عكس القائمة ليظهر الأحدث أولاً
    List<Map<String, dynamic>> reversedList = rawList.reversed.toList();

    // الفلترة (محلية)
    return reversedList.where((row) {
      if (_selectedType != 'الكل' && row['type'] != _selectedType) return false;
      if (_searchQuery.isNotEmpty && !row['desc'].toString().toLowerCase().contains(_searchQuery)) return false;
      if (_selectedDateRange != null) {
        DateTime rowDate = row['rawDate'];
        DateTime start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        DateTime end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        if (rowDate.isBefore(start) || rowDate.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text('${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
