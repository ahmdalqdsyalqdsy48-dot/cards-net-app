import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as ex; // مكتبة الإكسل
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
  // تصدير PDF حقيقي (يدعم اللغة العربية)
  // ==========================================
  Future<void> _exportToPDF(List<Map<String, dynamic>> data, SystemProvider sys) async {
    _play('click');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز ملف PDF...', textDirection: TextDirection.rtl)));

    final pdf = pw.Document();
    // تحميل خط عربي من جوجل للـ PDF
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('كشف حساب وكيل', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(sys.currentUserName, style: pw.TextStyle(fontSize: 18)),
                ]
              )
            ),
            pw.Text('رقم الهاتف: ${sys.currentUserPhone}'),
            pw.Text('تاريخ الطباعة: ${DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now())}'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['التاريخ', 'البيان', 'دائن (+)', 'مدين (-)', 'الرصيد'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              cellAlignment: pw.Alignment.center,
              data: data.map((row) => [
                row['date'],
                row['desc'],
                row['credit'] > 0 ? row['credit'].toString() : '-',
                row['debit'] > 0 ? row['debit'].toString() : '-',
                row['balance'].toString(),
              ]).toList(),
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
  // تصدير Excel حقيقي ومشاركته
  // ==========================================
  Future<void> _exportToExcel(List<Map<String, dynamic>> data, SystemProvider sys) async {
    _play('click');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز ملف Excel...', textDirection: TextDirection.rtl)));

    var excel = ex.Excel.createExcel();
    ex.Sheet sheetObject = excel['Statement'];
    excel.setDefaultSheet('Statement');

    // ترويسة الجدول
    sheetObject.appendRow([
      const ex.TextCellValue('رقم العملية'),
      const ex.TextCellValue('التاريخ'),
      const ex.TextCellValue('الوقت'),
      const ex.TextCellValue('البيان'),
      const ex.TextCellValue('دائن (إيداع)'),
      const ex.TextCellValue('مدين (سحب)'),
      const ex.TextCellValue('الرصيد المتراكم')
    ]);

    // تعبئة البيانات
    for (var row in data) {
      sheetObject.appendRow([
        ex.TextCellValue(row['id'].toString()),
        ex.TextCellValue(row['date'].toString()),
        ex.TextCellValue(row['time'].toString()),
        ex.TextCellValue(row['desc'].toString()),
        ex.DoubleCellValue(row['credit']),
        ex.DoubleCellValue(row['debit']),
        ex.DoubleCellValue(row['balance']),
      ]);
    }

    var fileBytes = excel.encode();
    if (fileBytes != null) {
      // استخدام share_plus لمشاركة الملف (تعمل للويب والموبايل)
      final xFile = XFile.fromData(
        Uint8List.fromList(fileBytes),
        name: 'Statement_${sys.currentUserPhone}.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      await Share.shareXFiles([xFile], text: 'كشف حساب الوكيل: ${sys.currentUserName}');
    }
  }

  // ==========================================
  // عرض سند إلكتروني تفصيلي للعملية
  // ==========================================
  void _showReceiptDialog(Map<String, dynamic> row) {
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
                const Text('تفاصيل العملية', style: TextStyle(fontWeight: FontWeight.bold)),
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
                _buildReceiptRow('الرصيد بعد العملية:', '${row['balance']} ريال', isBold: true, color: Colors.blue),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
              ElevatedButton.icon(
                onPressed: () {
                  _play('click');
                  String text = "🧾 *سند إلكتروني*\nالمرجع: ${row['id']}\nالتاريخ: ${row['date']} ${row['time']}\nالبيان: ${row['desc']}\nالمبلغ: ${row['credit'] > 0 ? row['credit'] : row['debit']} ريال\nالرصيد: ${row['balance']}";
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ السند بنجاح')));
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('نسخ السند'),
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
          Expanded(flex: 2, child: Text(title, style: const TextStyle(color: Colors.grey))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87))),
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
            // 1. الحاوية العلوية المنحنية مع أدوات التصدير
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.cyan.shade800,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تصدير التقرير المحاسبي:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    children: [
                      // زر الـ PDF الحقيقي
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('transactions').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
                        builder: (context, snapshot) {
                          return IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                            tooltip: 'تصدير PDF',
                            onPressed: snapshot.hasData ? () => _exportToPDF(_processData(snapshot.data!.docs), sys) : null,
                          );
                        }
                      ),
                      // زر الـ Excel الحقيقي
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('transactions').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
                        builder: (context, snapshot) {
                          return IconButton(
                            icon: const Icon(Icons.table_view, color: Colors.white),
                            tooltip: 'تصدير Excel',
                            onPressed: snapshot.hasData ? () => _exportToExcel(_processData(snapshot.data!.docs), sys) : null,
                          );
                        }
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 2. الجلب الحي للبيانات والفلترة
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // نجلب كل عمليات الوكيل (بدون ترتيب هنا لتجنب Index Error)
                stream: _db.collection('transactions').where('agentPhone', isEqualTo: sys.currentUserPhone).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  
                  // معالجة البيانات الحية (ترتيب، حساب رصيد، فلترة)
                  List<Map<String, dynamic>> finalData = _processData(snapshot.hasData ? snapshot.data!.docs : []);

                  // حساب الإجماليات
                  final double totalCredit = finalData.fold(0.0, (sum, item) => sum + item['credit']);
                  final double totalDebit = finalData.fold(0.0, (sum, item) => sum + item['debit']);
                  final double netMovement = totalCredit - totalDebit;

                  return Column(
                    children: [
                      // 3. بطاقات الملخص المالي
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(child: _buildSummaryCard('إجمالي إيداعات (+)', totalCredit, Colors.green)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildSummaryCard('إجمالي مسحوبات (-)', totalDebit, Colors.red)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildSummaryCard('صافي الحركة', netMovement, Colors.blue)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4. أدوات الفلترة والبحث
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))],
                          border: Border.all(color: Colors.grey.shade300),
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
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.cyan.shade800),
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
                                    ),
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                                    items: ['الكل', 'مبيعات', 'شحن رصيد', 'أخرى'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                    onChanged: (val) { _play('click'); setState(() => _selectedType = val!); },
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
                                decoration: InputDecoration(
                                  hintText: 'ابحث عن اسم الشبكة أو الفئة...',
                                  prefixIcon: const Icon(Icons.search),
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      // 5. ترويسة الجدول المحاسبي
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

                      // 6. محتوى الجدول (العمليات المفلترة)
                      Expanded(
                        child: finalData.isEmpty
                            ? const Center(child: Text('لا توجد عمليات مطابقة لبحثك في هذه الفترة.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: finalData.length,
                                itemBuilder: (context, index) {
                                  final row = finalData[index];
                                  Color creditColor = row['credit'] > 0 ? Colors.green.shade700 : Colors.grey.shade400;
                                  Color debitColor = row['debit'] > 0 ? Colors.red.shade700 : Colors.grey.shade400;

                                  return InkWell(
                                    onTap: () => _showReceiptDialog(row), // فتح السند الإلكتروني
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
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

  // ==========================================
  // المحرك المحاسبي: تحضير، ترتيب، فلترة، وحساب الرصيد
  // ==========================================
  List<Map<String, dynamic>> _processData(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> rawList = [];
    
    // 1. تحويل البيانات وتجهيز الحقول
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      Timestamp? ts = data['createdAt'];
      DateTime dt = ts != null ? ts.toDate() : DateTime.now();
      
      double amount = (data['amount'] ?? 0).toDouble();
      String rawType = data['type'] ?? 'أخرى';
      
      // تصنيف النوع المحاسبي (بيع = مدين ، إيداع = دائن)
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
        'id': doc.id.substring(0, 6).toUpperCase(), // رقم مرجعي قصير
        'rawDate': dt, // نستخدمه للترتيب
        'date': DateFormat('yyyy-MM-dd').format(dt),
        'time': DateFormat('hh:mm a').format(dt),
        'desc': desc,
        'credit': credit,
        'debit': debit,
        'type': uiType,
        'balance': 0.0 // سيتم حسابه
      });
    }

    // 2. الترتيب الزمني (من الأقدم للأحدث) لحساب الرصيد التراكمي
    rawList.sort((a, b) => (a['rawDate'] as DateTime).compareTo(b['rawDate'] as DateTime));

    // 3. حساب الرصيد التراكمي سطر بسطر
    double runningBalance = 0.0;
    for (int i = 0; i < rawList.length; i++) {
      runningBalance += rawList[i]['credit'];
      runningBalance -= rawList[i]['debit'];
      rawList[i]['balance'] = runningBalance;
    }

    // 4. عكس القائمة (الأحدث يظهر في الأعلى)
    List<Map<String, dynamic>> reversedList = rawList.reversed.toList();

    // 5. تطبيق الفلترة (تاريخ، نوع، بحث)
    return reversedList.where((row) {
      // الفلترة بالنوع
      if (_selectedType != 'الكل' && row['type'] != _selectedType) return false;
      
      // الفلترة بالبحث النصي
      if (_searchQuery.isNotEmpty && !row['desc'].toString().toLowerCase().contains(_searchQuery)) return false;

      // الفلترة بالتاريخ
      if (_selectedDateRange != null) {
        DateTime rowDate = row['rawDate'];
        DateTime start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        DateTime end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        if (rowDate.isBefore(start) || rowDate.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  // أداة بناء بطاقات الملخص
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
          Text(
            '${amount.toStringAsFixed(0)}', 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
