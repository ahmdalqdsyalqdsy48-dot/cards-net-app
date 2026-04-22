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
    // تعيين النطاق الافتراضي ليكون آخر 30 يوم
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
  // معالجة البيانات والمحرك المحاسبي العميق (تحديث SaaS)
  // ==========================================
  List<Map<String, dynamic>> _processData(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> rawList = [];
    
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      // الفايربيز قد يخزن الوقت في timestamp أو createdAt، ندعم الاثنين
      Timestamp? ts = data['timestamp'] ?? data['createdAt'];
      DateTime dt = ts != null ? ts.toDate() : DateTime.now();
      
      double amount = (data['amount'] ?? 0).toDouble();
      double fee = (data['fee'] ?? 0).toDouble(); // رسوم النظام/الضريبة
      String rawType = data['type'] ?? 'أخرى';
      
      String uiType = 'أخرى';
      double credit = 0.0;
      double debit = 0.0;
      
      // تصنيف العمليات لزيادة ونقصان
      if (rawType == 'income' || rawType == 'deposit' || rawType == 'receive') {
        uiType = rawType == 'deposit' ? 'شحن حصة' : 'إيراد/استلام';
        credit = amount;
      } else if (rawType == 'expense' || rawType == 'sale' || rawType == 'transfer') {
        uiType = rawType == 'sale' ? 'مبيعات كروت' : 'تحويل/خصم';
        debit = amount;
      }

      // 👈 بناء النص البارز (العنوان الديناميكي للعملية)
      String desc = data['title'] ?? data['desc'] ?? '';
      if (desc.isEmpty) {
        if (rawType == 'sale') {
          desc = 'بيع كرت لـ ${data['targetName'] ?? 'زبون'} - شبكة: ${data['networkName'] ?? 'غير محدد'}';
        } else if (rawType == 'transfer') {
          String payMethod = data['paymentMethod'] ?? 'نقدي';
          desc = 'تحويل ($payMethod) إلى: ${data['targetName'] ?? 'مجهول'}';
        }
      }

      rawList.add({
        'id': doc.id.substring(0, 6).toUpperCase(),
        'rawDate': dt,
        'date': intl.DateFormat('yyyy-MM-dd').format(dt),
        'time': intl.DateFormat('hh:mm a').format(dt),
        'desc': desc,
        'credit': credit,
        'debit': debit,
        'fee': fee,
        'paymentMethod': data['paymentMethod'] ?? 'غير محدد',
        'targetName': data['targetName'] ?? data['senderName'] ?? '-',
        'networkName': data['networkName'] ?? '-',
        'type': uiType,
        'balance': 0.0 // سيتم حسابه لاحقاً
      });
    }

    // الترتيب من الأقدم للأحدث لحساب الرصيد التراكمي الدقيق
    rawList.sort((a, b) => (a['rawDate'] as DateTime).compareTo(b['rawDate'] as DateTime));

    double runningBalance = 0.0;
    for (int i = 0; i < rawList.length; i++) {
      runningBalance += rawList[i]['credit'];
      runningBalance -= rawList[i]['debit'];
      rawList[i]['balance'] = runningBalance;
    }

    // عكس القائمة ليظهر الأحدث في الأعلى (في الواجهة)
    List<Map<String, dynamic>> reversedList = rawList.reversed.toList();

    // الفلترة 
    return reversedList.where((row) {
      if (_selectedType != 'الكل' && !row['type'].toString().contains(_selectedType)) return false;
      if (_searchQuery.isNotEmpty && 
          !row['desc'].toString().toLowerCase().contains(_searchQuery) &&
          !row['targetName'].toString().toLowerCase().contains(_searchQuery) &&
          !row['networkName'].toString().toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_selectedDateRange != null) {
        DateTime rowDate = row['rawDate'];
        DateTime start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        DateTime end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        if (rowDate.isBefore(start) || rowDate.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  // ==========================================
  // عرض الإيصال الإلكتروني التفصيلي (Smart Receipt)
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
                Icon(
                  row['credit'] > 0 ? Icons.arrow_downward : Icons.arrow_upward, 
                  color: row['credit'] > 0 ? Colors.green : Colors.red
                ),
                const SizedBox(width: 10),
                const Text('فاتورة تفصيلية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildReceiptRow('رقم المرجع:', '#${row['id']}'),
                  const Divider(thickness: 0.5),
                  _buildReceiptRow('التاريخ والوقت:', '${row['date']}  ${row['time']}'),
                  const Divider(thickness: 0.5),
                  _buildReceiptRow('نوع العملية:', row['type']),
                  const Divider(thickness: 0.5),
                  _buildReceiptRow('البيان:', row['desc'], isBold: true),
                  
                  if (row['targetName'] != '-') ...[
                    const Divider(thickness: 0.5),
                    _buildReceiptRow('الطرف الآخر:', row['targetName'], color: Colors.blueAccent, isBold: true),
                  ],
                  if (row['networkName'] != '-') ...[
                    const Divider(thickness: 0.5),
                    _buildReceiptRow('الشبكة التابعة:', row['networkName']),
                  ],
                  if (row['paymentMethod'] != 'غير محدد') ...[
                    const Divider(thickness: 0.5),
                    _buildReceiptRow('طريقة الدفع:', row['paymentMethod'], color: row['paymentMethod'] == 'آجل' ? Colors.deepOrange : Colors.black87, isBold: row['paymentMethod'] == 'آجل'),
                  ],

                  const Divider(color: Colors.black, thickness: 1.5),
                  
                  _buildReceiptRow(
                    'المبلغ الأساسي:', 
                    '${row['credit'] > 0 ? row['credit'] : row['debit']} ريال', 
                    isBold: true, 
                    color: row['credit'] > 0 ? Colors.green : Colors.red
                  ),

                  if (row['fee'] > 0) ...[
                    const SizedBox(height: 5),
                    _buildReceiptRow('الرسوم / الضريبة:', '${row['fee']} ريال', color: Colors.red, isBold: true),
                  ],

                  const Divider(thickness: 0.5),
                  _buildReceiptRow('الرصيد بعد العملية:', '${row['balance']} ريال', isBold: true, color: Colors.blue.shade900),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('إغلاق', style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _play('click');
                  String text = "🧾 *إشعار عملية مالية - ${sys.appName}*\n";
                  text += "الوكيل: ${sys.currentUserName}\n";
                  text += "المرجع: #${row['id']}\nالتاريخ: ${row['date']} ${row['time']}\n";
                  text += "البيان: ${row['desc']}\n";
                  if(row['targetName'] != '-') text += "الطرف الآخر: ${row['targetName']}\n";
                  if(row['paymentMethod'] != 'غير محدد') text += "طريقة الدفع: ${row['paymentMethod']}\n";
                  text += "المبلغ: ${row['credit'] > 0 ? row['credit'] : row['debit']} ريال\n";
                  if(row['fee'] > 0) text += "الرسوم/الضريبة: ${row['fee']} ريال\n";
                  text += "الرصيد الحالي: ${row['balance']} ريال";
                  Share.share(text);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700),
                icon: const Icon(Icons.share, size: 18, color: Colors.white),
                label: const Text('مشاركة', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildReceiptRow(String title, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }

  // ==========================================
  // تصدير PDF احترافي (الآن مع اسم النظام المتغير وتفاصيل الأطراف)
  // ==========================================
  Future<void> _exportToPDF(List<Map<String, dynamic>> data, SystemProvider sys, double tCredit, double tDebit, double net) async {
    _play('click');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري تجهيز التقرير المحاسبي (PDF)...', textDirection: TextDirection.rtl))
    );

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
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.cyan50, 
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('كشف حساب تفصيلي', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)),
                      pw.SizedBox(height: 5),
                      pw.Text('الوكيل: ${sys.currentUserName}', style: const pw.TextStyle(fontSize: 14)),
                      pw.Text('رقم الهاتف: ${sys.currentUserPhone}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // 👈 استخدام اسم النظام العالمي هنا
                      pw.Text('نظام ${sys.appName}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan800)),
                      pw.SizedBox(height: 5),
                      pw.Text('تاريخ الإصدار', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                      pw.Text(intl.DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
                    ]
                  )
                ]
              )
            ),
            pw.SizedBox(height: 20),

            // الجدول بعد تحديث أعمدته
            pw.TableHelper.fromTextArray(
              headers: ['التاريخ/الوقت', 'البيان', 'الطرف الآخر/طريقة الدفع', 'دائن (+)', 'مدين (-)', 'الرصيد'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan800),
              cellAlignment: pw.Alignment.center,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: data.map((row) => [
                '${row['date']}\n${row['time']}',
                row['desc'],
                '${row['targetName'] != '-' ? row['targetName'] : ''}\n${row['paymentMethod'] != 'غير محدد' ? '(${row['paymentMethod']})' : ''}',
                row['credit'] > 0 ? '+${row['credit']}' : '-',
                row['debit'] > 0 ? '-${row['debit']}' : '-',
                row['balance'].toString(),
              ]).toList(),
            ),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.cyan), 
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))
              ),
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(), 
      name: 'Statement_${sys.currentUserPhone}.pdf'
    );
  }

  // ==========================================
  // تصدير Excel احترافي
  // ==========================================
  Future<void> _exportToExcel(List<Map<String, dynamic>> data, SystemProvider sys) async {
    _play('click');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري تجهيز ملف Excel...', textDirection: TextDirection.rtl))
    );

    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['كشف الحساب'];
    excel.setDefaultSheet('كشف الحساب');
    excel.delete('Sheet1'); 

    ex.CellStyle headerStyle = ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.blueGrey,
      fontColorHex: ex.ExcelColor.white,
      bold: true,
      horizontalAlign: ex.HorizontalAlign.Center,
    );

    List<String> headers = ['رقم العملية', 'التاريخ', 'الوقت', 'نوع العملية', 'البيان', 'الطرف الآخر', 'الشبكة', 'طريقة الدفع', 'الرسوم', 'دائن (+)', 'مدين (-)', 'الرصيد'];
    sheet.appendRow(headers.map((e) => ex.TextCellValue(e)).toList());
    
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (var row in data) {
      sheet.appendRow([
        ex.TextCellValue(row['id'].toString()),
        ex.TextCellValue(row['date'].toString()),
        ex.TextCellValue(row['time'].toString()),
        ex.TextCellValue(row['type'].toString()),
        ex.TextCellValue(row['desc'].toString()),
        ex.TextCellValue(row['targetName'].toString()),
        ex.TextCellValue(row['networkName'].toString()),
        ex.TextCellValue(row['paymentMethod'].toString()),
        ex.DoubleCellValue(row['fee'].toDouble()),
        ex.DoubleCellValue(row['credit'].toDouble()),
        ex.DoubleCellValue(row['debit'].toDouble()),
        ex.DoubleCellValue(row['balance'].toDouble()),
      ]);
    }

    var fileBytes = excel.encode();
    if (fileBytes != null) {
      final xFile = XFile.fromData(
        Uint8List.fromList(fileBytes), 
        name: 'Statement_${sys.currentUserPhone}.xlsx', 
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      await Share.shareXFiles([xFile], text: 'كشف حساب الوكيل: ${sys.currentUserName} - نظام ${sys.appName}');
    }
  }

  // ==========================================
  // بناء الشاشة الرئيسية (UI)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomHeader(title: 'كشف الحساب - ${sys.appName}'),
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
            // الفلاتر والبحث
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
                        child: OutlinedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            _selectedDateRange == null ? 'تحديد الفترة الزمنية' : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.cyanAccent : Colors.cyan.shade800,
                            backgroundColor: Theme.of(context).cardColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                          ),
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                          // 👈 فلاتر ذكية تتناسب مع طبيعة العمليات
                          items: ['الكل', 'مبيعات كروت', 'شحن حصة', 'تحويل/خصم', 'إيراد/استلام'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) { 
                            _play('click'); 
                            setState(() => _selectedType = val!); 
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 45,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن اسم الطرف الآخر، الشبكة، أو البيان...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),

            // StreamBuilder لجلب البيانات الحية
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // نجلب كل العمليات الخاصة بهذا الوكيل لضمان عدم ضياع أي بيانات
                stream: _db.collection('transactions').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ في الاتصال: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.cyan));
                  }
                  
                  List<Map<String, dynamic>> finalData = _processData(snapshot.hasData ? snapshot.data!.docs : []);

                  final double totalCredit = finalData.fold(0.0, (sum, item) => sum + item['credit']);
                  final double totalDebit = finalData.fold(0.0, (sum, item) => sum + item['debit']);
                  final double netMovement = totalCredit - totalDebit;

                  return Column(
                    children: [
                      // أدوات التصدير
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('تصدير الكشف المعروض:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                  tooltip: 'تصدير PDF',
                                  onPressed: finalData.isNotEmpty ? () => _exportToPDF(finalData, sys, totalCredit, totalDebit, netMovement) : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.table_view, color: Colors.green),
                                  tooltip: 'تصدير Excel',
                                  onPressed: finalData.isNotEmpty ? () => _exportToExcel(finalData, sys) : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // بطاقات الملخص المالي
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(child: _buildSummaryCard('إجمالي دائن (+)', totalCredit, Colors.green)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildSummaryCard('إجمالي مدين (-)', totalDebit, Colors.red)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ترويسة الجدول 
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(color: Colors.cyan.shade800, borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: Text('البيان / التاريخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 2, child: Text('دائن (+)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 2, child: Text('مدين (-)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 2, child: Text('الرصيد', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                        ),
                      ),

                      // محتوى السجل الفعلي
                      Expanded(
                        child: finalData.isEmpty
                            ? const Center(child: Text('لا توجد عمليات مطابقة في هذه الفترة.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: finalData.length,
                                physics: const BouncingScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final row = finalData[index];
                                  Color creditColor = row['credit'] > 0 ? Colors.green.shade700 : Colors.grey.shade400;
                                  Color debitColor = row['debit'] > 0 ? Colors.red.shade700 : Colors.grey.shade400;
                                  bool isDebt = row['paymentMethod'] == 'آجل';

                                  return InkWell(
                                    onTap: () => _showReceiptDialog(row, sys),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isDebt ? Colors.orange.withOpacity(0.05) : Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDebt ? Colors.orange.shade200 : Colors.grey.shade200),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(row['desc'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Text('${row['date']} • ${row['time']}', style: const TextStyle(color: Colors.grey, fontSize: 10), textDirection: TextDirection.ltr),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(row['credit'] > 0 ? '+${row['credit']}' : '-', textAlign: TextAlign.center, style: TextStyle(color: creditColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(row['debit'] > 0 ? '-${row['debit']}' : '-', textAlign: TextAlign.center, style: TextStyle(color: debitColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text('${row['balance']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
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

  // بناء بطاقة الملخص
  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(
            '${amount.toStringAsFixed(0)} ريال', 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
