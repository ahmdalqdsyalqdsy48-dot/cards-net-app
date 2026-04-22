import 'dart:convert'; 
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl; 
import 'package:pdf/pdf.dart'; 
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart'; 
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/system_provider.dart'; 
import '../../../core/providers/ui_provider.dart'; 
import '../../../core/providers/theme_provider.dart'; 
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 

class FinancialCenterScreen extends StatefulWidget {
  const FinancialCenterScreen({super.key});

  @override
  State<FinancialCenterScreen> createState() => _FinancialCenterScreenState();
}

class _FinancialCenterScreenState extends State<FinancialCenterScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;
  String _searchQuery = ''; 
  
  final Set<String> _processingRequests = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _play('click');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showSnack(String m, {bool isErr = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, textDirection: TextDirection.rtl, style: const TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: isErr ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  // ==========================================
  // النوافذ المنبثقة لطلبات الشحن (SaaS)
  // ==========================================
  void _acceptRequest(Map<String, dynamic> req, SystemProvider provider) async {
    _play('warning'); 
    final docId = req['docId'];
    
    String agentPhone = req['userPhone'] ?? req['agentPhone'];
    String agentName = req['userName'] ?? req['agentName'] ?? 'مجهول';
    double quotaAmount = double.tryParse(req['amount'].toString()) ?? 0.0;
    double feeAmount = double.tryParse(req['fee']?.toString() ?? '0') ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تأكيد توريد الحصة 🚀', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          content: Text(
            'هل تأكدت من وصول الرسوم (${intl.NumberFormat('#,###').format(feeAmount)} ريال) إلى حسابك البنكي؟\n\n'
            'بموافقتك سيتم إضافة حصة مبيعات بقيمة (${intl.NumberFormat('#,###').format(quotaAmount)} ريال) لمحفظة الوكيل $agentName فوراً.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.pop(ctx);
                if (_processingRequests.contains(docId)) return; 
                setState(() => _processingRequests.add(docId)); 

                try {
                  _play('click');
                  await provider.adminAcceptSaaSRecharge(docId, agentPhone, quotaAmount, feeAmount);
                  if (mounted) {
                    _play('success'); 
                    _showSnack('تم تأكيد الشحن وإيداع الحصة بنجاح ✅');
                  }
                } catch (e) {
                  if (mounted) {
                    _play('error'); 
                    _showSnack('خطأ: $e', isErr: true);
                  }
                } finally {
                  if (mounted) setState(() => _processingRequests.remove(docId)); 
                }
              },
              child: const Text('نعم، أؤكد الاستلام', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> req, SystemProvider provider) {
    _play('click');
    final reasonController = TextEditingController();
    final docId = req['docId'];

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isRejecting = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).cardColor, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('رفض طلب الشحن ❌', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('يرجى كتابة سبب الرفض (سيصل للوكيل كإشعار):', style: TextStyle(color: Provider.of<ThemeProvider>(context).adaptiveTextColor)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'مثال: رقم المرجع غير صحيح، أو السند غير واضح...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                if (!isRejecting)
                  TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: isRejecting ? null : () async {
                    if (reasonController.text.trim().isEmpty) {
                      _showSnack('يرجى كتابة السبب أولاً!', isErr: true);
                      return;
                    }
                    setStateDialog(() => isRejecting = true);
                    try {
                      _play('click');
                      await provider.rejectRechargeRequest(docId, reasonController.text);
                      if (mounted) {
                        _play('success'); 
                        Navigator.pop(context);
                        _showSnack('تم رفض الطلب وإشعار الوكيل.');
                      }
                    } catch (e) {
                      setStateDialog(() => isRejecting = false);
                      if (mounted) {
                        _play('error');
                        _showSnack('خطأ: $e', isErr: true);
                      }
                    }
                  },
                  child: isRejecting 
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  // ==========================================
  // الإيصال الذكي للتفاصيل (الميزة الجديدة) 🎨
  // ==========================================
  void _showTransactionReceipt(Map<String, dynamic> log, SystemProvider sys) {
    _play('click');
    final GlobalKey receiptKey = GlobalKey();
    
    final double amount = double.tryParse(log['amount'].toString()) ?? 0.0;
    final bool isPositive = log['type'] == 'deposit' || log['type'] == 'income';
    final Color color = isPositive ? Colors.green : Colors.red;
    final String dateStr = log['timestamp'] != null ? intl.DateFormat('yyyy-MM-dd hh:mm a').format((log['timestamp'] as Timestamp).toDate()) : 'الآن';

    showDialog(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: RepaintBoundary(
            key: receiptKey,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).cardColor, color.withOpacity(0.08)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(isPositive ? Icons.arrow_downward : Icons.arrow_upward, size: 30, color: color),
                  ),
                  const SizedBox(height: 10),
                  Text('نظام ${sys.appName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                  Text('إشعار عملية مالية', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.5)),
                  
                  Text(log['title'] ?? log['type'] ?? 'عملية مسجلة', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  
                  _buildReceiptRow('المرجع', log['reference'] ?? 'لا يوجد', isBold: true),
                  _buildReceiptRow('التاريخ', dateStr),
                  _buildReceiptRow('المبلغ', '${intl.NumberFormat('#,###').format(amount)} ريال', valueColor: color, isBold: true),
                  _buildReceiptRow('الطرف الآخر', log['agentName'] ?? 'مجهول'),
                  
                  if (log['networkName'] != null && log['networkName'] != 'غير محدد')
                    _buildReceiptRow('الشبكة', log['networkName']),
                  if (log['paymentMethod'] != null)
                    _buildReceiptRow('طريقة الدفع', log['paymentMethod']),
                  if (log['fee'] != null && double.tryParse(log['fee'].toString()) != 0)
                    _buildReceiptRow('الرسوم التشغيلية', '${intl.NumberFormat('#,###').format(log['fee'])} ريال', valueColor: Colors.red),
                  if (log['reason'] != null)
                    _buildReceiptRow('السبب', log['reason']),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.5)),
                  const Text('المركز المالي لمالك النظام', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('إغلاق', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.blue),
              tooltip: 'نسخ كنص',
              onPressed: () {
                _play('click');
                String text = "🧾 *إشعار عملية - ${sys.appName}*\n";
                text += "المرجع: ${log['reference'] ?? 'لا يوجد'}\n";
                text += "التاريخ: $dateStr\n";
                text += "البيان: ${log['title'] ?? log['type']}\n";
                text += "المبلغ: ${intl.NumberFormat('#,###').format(amount)} ريال\n";
                text += "الطرف: ${log['agentName'] ?? 'مجهول'}\n";
                Clipboard.setData(ClipboardData(text: text));
                _showSnack('تم نسخ النص بنجاح');
              },
            ),
            ElevatedButton.icon(
               icon: const Icon(Icons.image, color: Colors.white, size: 16),
               label: const Text('مشاركة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
               onPressed: () async {
                  _play('click');
                  _showSnack('جاري تجهيز الصورة... ⏳');
                  try {
                    RenderRepaintBoundary boundary = receiptKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                    ui.Image image = await boundary.toImage(pixelRatio: 3.0); 
                    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                    Uint8List pngBytes = byteData!.buffer.asUint8List();
                    
                    await Share.shareXFiles([XFile.fromData(pngBytes, mimeType: 'image/png', name: 'receipt.png')], text: 'إيصال عملية مالية - ${sys.appName}');
                    _play('success');
                  } catch (e) {
                    _play('error');
                    _showSnack('حدث خطأ أثناء التقاط الصورة', isErr: true);
                  }
               }
            )
          ]
        )
      )
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Expanded(
            child: Text(
              value, 
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // النوافذ المنبثقة للمحافظ والتسوية
  // ==========================================
  void _showManualSettlementDialog(Map<String, dynamic> agent, SystemProvider provider) {
    _play('click');
    int settlementType = 1; 
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isProcessing = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('تسوية يدوية لمحفظة: ${agent['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile(
                            title: const Text('إضافة حصة 🟢', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                            value: 1, groupValue: settlementType,
                            onChanged: (val) { _play('click'); setStateDialog(() => settlementType = val as int); },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile(
                            title: const Text('سحب حصة 🔴', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                            value: 2, groupValue: settlementType,
                            onChanged: (val) { _play('click'); setStateDialog(() => settlementType = val as int); },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField('المبلغ (بالريال)', Icons.money, controller: amountController, isNumber: true),
                    const SizedBox(height: 10),
                    _buildTextField('السبب (إجباري للسجل)', Icons.edit_note, controller: reasonController),
                  ],
                ),
              ),
              actions: [
                if (!isProcessing)
                  TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: settlementType == 1 ? Colors.green : Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: isProcessing ? null : () async {
                    if (amountController.text.isEmpty || reasonController.text.isEmpty) {
                      _play('error');
                      _showSnack('الرجاء إدخال المبلغ والسبب!', isErr: true);
                      return;
                    }
                    setStateDialog(() => isProcessing = true);

                    try {
                      double amount = double.parse(amountController.text);
                      if (settlementType == 2) amount = -amount; 

                      await provider.manualSettlement(
                        agentPhone: agent['phone'],
                        agentName: agent['name'],
                        amount: amount,
                        reason: reasonController.text,
                      );

                      if (mounted) {
                        _play('success');
                        Navigator.pop(context);
                        _showSnack('تمت التسوية بنجاح ✅');
                      }
                    } catch (e) {
                      setStateDialog(() => isProcessing = false);
                      if (mounted) {
                        _play('error');
                        _showSnack('خطأ: $e', isErr: true);
                      }
                    }
                  },
                  child: isProcessing 
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('تنفيذ التسوية', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showDangerLimitDialog(Map<String, dynamic> agent, SystemProvider provider) {
    _play('click');
    final limitController = TextEditingController(text: (agent['dangerLimit'] ?? 0).toString());
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('ضبط حد الخطر 🎛️', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الوكيل: ${agent['name']}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 15),
              _buildTextField('رصيد التنبيه (بالريال)', Icons.warning_amber, controller: limitController, isNumber: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                try {
                  await provider.updateDangerLimit(agent['phone'], double.parse(limitController.text));
                  if (mounted) {
                    _play('success');
                    Navigator.pop(context);
                    _showSnack('تم تحديث حد الخطر بنجاح.');
                  }
                } catch (e) {
                  _play('error');
                }
              }, 
              child: const Text('حفظ الحد', style: TextStyle(color: Colors.white))
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 📄 نافذة توليد كشف الحساب (PDF)
  // ==========================================
  void _showPdfStatementDialog(Map<String, dynamic> agent, SystemProvider provider) {
    _play('click');
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('كشف حساب: ${agent['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      _play('click');
                      final picked = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) { _play('click'); setStateDialog(() => startDate = picked); }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(startDate == null ? 'من تاريخ (البداية)' : intl.DateFormat('yyyy-MM-dd').format(startDate!)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      _play('click');
                      final picked = await showDatePicker(context: context, initialDate: endDate ?? DateTime.now(), firstDate: startDate ?? DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) { _play('click'); setStateDialog(() => endDate = picked); }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(endDate == null ? 'إلى تاريخ (النهاية)' : intl.DateFormat('yyyy-MM-dd').format(endDate!)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  if (startDate == null || endDate == null) {
                    _play('error');
                    _showSnack('يرجى تحديد فترة الكشف!', isErr: true);
                    return;
                  }
                  _play('click');
                  _showSnack('جاري توليد الـ PDF... ⏳');
                  await _generateAndDownloadPdf(agent, startDate!, endDate!, provider.transactionsLedger, provider.appName);
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text('تصدير (PDF)', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateAndDownloadPdf(Map<String, dynamic> agent, DateTime start, DateTime end, List<Map<String, dynamic>> allLedger, String appName) async {
    final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59); 
    final startInclusive = DateTime(start.year, start.month, start.day, 0, 0, 0);

    final filteredLedger = allLedger.where((t) {
      if (t['agentPhone'] != agent['phone']) return false;
      if (t['timestamp'] == null) return false;
      DateTime d = (t['timestamp'] as Timestamp).toDate();
      return d.isAfter(startInclusive) && d.isBefore(endInclusive);
    }).toList();

    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl, 
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                color: PdfColors.teal700,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('كشف حساب وكيل', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('نظام $appName', style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              pw.Text('اسم الوكيل: ${agent['name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('الهاتف: ${agent['phone']}'),
              pw.Text('الفترة: من ${intl.DateFormat('yyyy-MM-dd').format(start)} إلى ${intl.DateFormat('yyyy-MM-dd').format(end)}', style: const pw.TextStyle(color: PdfColors.grey700)),
              pw.SizedBox(height: 20),
              
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(font: arabicBold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: pw.TextStyle(font: arabicFont),
                cellAlignment: pw.Alignment.center,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                data: <List<String>>[
                  <String>['التاريخ', 'النوع', 'المبلغ'], 
                  ...filteredLedger.map((item) {
                    DateTime date = (item['timestamp'] as Timestamp).toDate();
                    return [
                      intl.DateFormat('yyyy-MM-dd HH:mm').format(date),
                      item['type'] ?? 'عملية',
                      item['amount'].toString(),
                    ];
                  })
                ],
              ),
              
              if (filteredLedger.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Center(child: pw.Text('لا توجد حركات مالية في هذه الفترة.')),
                )
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'statement_${agent['phone']}.pdf');
    if (mounted) _play('success'); 
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;
    final cardColor = Theme.of(context).cardColor;
    final textColor = themeProvider.adaptiveTextColor;

    return Scaffold(
      appBar: CustomHeader(title: 'المركز المالي (SaaS) - ${systemProvider.appName}'),
      drawer: CustomDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح تشغيلية (SaaS): ${intl.NumberFormat('#,###').format(adminBalance)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (value) {
                  if(value.length == 1) _play('click'); 
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: 'بحث شامل بالاسم، أو رقم الهاتف، أو المرجع...',
                  prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                  filled: true,
                  fillColor: cardColor, 
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
            ),
            
            Container(
              color: Colors.transparent, 
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download, size: 18),
                        const SizedBox(width: 4),
                        const Text('طلبات الشحن'),
                        if (systemProvider.pendingRechargeRequests.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: Text('${systemProvider.pendingRechargeRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          )
                        ]
                      ],
                    ),
                  ),
                  const Tab(icon: Icon(Icons.account_balance_wallet, size: 18), text: 'أرصدة المحافظ'),
                  const Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'السجل الشامل'),
                ],
              ),
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRechargeRequestsTab(systemProvider, cardColor, textColor),
                  _buildWalletsTab(systemProvider, cardColor, textColor),
                  _buildLedgerTab(systemProvider, cardColor, textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRechargeRequestsTab(SystemProvider provider, Color cardColor, Color textColor) {
    final requests = provider.pendingRechargeRequests.where((req) {
      final query = _searchQuery.toLowerCase();
      return (req['userName']?.toString().toLowerCase().contains(query) ?? req['agentName']?.toString().toLowerCase().contains(query) ?? false) ||
             (req['userPhone']?.toString().contains(query) ?? req['agentPhone']?.toString().contains(query) ?? false) ||
             (req['reference']?.toString().contains(query) ?? req['ref']?.toString().contains(query) ?? false);
    }).toList();

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green.withOpacity(0.2)),
            const SizedBox(height: 10),
            const Text('لا توجد طلبات شحن معلقة حالياً، عمل رائع!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final docId = req['docId'];
        final isProcessing = _processingRequests.contains(docId); 
        
        bool isSaaS = req['type'] == 'saas_quota';
        double quotaAmount = double.tryParse(req['amount'].toString()) ?? 0;
        double feeAmount = double.tryParse(req['fee']?.toString() ?? '0') ?? 0;
        String agentName = req['userName'] ?? req['agentName'] ?? 'مجهول';
        String agentPhone = req['userPhone'] ?? req['agentPhone'] ?? '';

        return Card(
          color: cardColor, 
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.person, color: Colors.blue)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(agentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                            Text(agentPhone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('قيد الانتظار ⏳', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 5),
                        Text(req['timestamp'] != null ? intl.DateFormat('hh:mm a').format((req['timestamp'] as Timestamp).toDate()) : 'الآن', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    )
                  ],
                ),
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                
                if (isSaaS) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.2))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('حصة المبيعات المطلوبة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${intl.NumberFormat('#,###').format(quotaAmount)} ريال', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.2))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الرسوم المحولة لك:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                        Text('${intl.NumberFormat('#,###').format(feeAmount)} ريال', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                ] else ...[
                  _buildInfoRow('المبلغ المطلوب:', '${intl.NumberFormat('#,###').format(quotaAmount)} ريال', isBold: true, color: Colors.green, textColor: textColor),
                ],
                
                const SizedBox(height: 10),
                _buildInfoRow('البنك المُحوّل إليه:', req['bankName'] ?? 'غير محدد', textColor: textColor),
                _buildInfoRow('مصدر التحويل:', req['transferSource'] ?? 'غير محدد', textColor: textColor),
                _buildInfoRow('رقم المرجع:', req['reference'] ?? req['ref'] ?? 'لا يوجد', textColor: textColor),
                const SizedBox(height: 15),
                
                OutlinedButton.icon(
                  onPressed: () {
                    _play('click');
                    if (req['hasReceipt'] == true && req['receiptBase64'] != null) {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              InteractiveViewer(child: Image.memory(base64Decode(req['receiptBase64']), fit: BoxFit.contain)),
                              IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                            ],
                          ),
                        ),
                      );
                    } else {
                      _showSnack('الوكيل لم يقم بإرفاق صورة السند ⏳', isErr: true);
                    }
                  },
                  icon: Icon(Icons.image, size: 18, color: req['hasReceipt'] == true ? Colors.green : Colors.grey),
                  label: Text(req['hasReceipt'] == true ? 'عرض صورة السند المرفق 📸' : 'لا يوجد سند مرفق', style: TextStyle(color: req['hasReceipt'] == true ? Colors.green : Colors.grey)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: isProcessing ? null : () => _acceptRequest(req, provider),
                        icon: isProcessing ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        label: Text(isProcessing ? 'جاري...' : 'تأكيد وإيداع الحصة', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: isProcessing ? null : () => _showRejectDialog(req, provider),
                        icon: const Icon(Icons.cancel, color: Colors.white, size: 16),
                        label: const Text('رفض', style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalletsTab(SystemProvider provider, Color cardColor, Color textColor) {
    final wallets = provider.agentsList.where((agent) {
      final query = _searchQuery.toLowerCase();
      return (agent['name']?.toString().toLowerCase().contains(query) ?? false) ||
             (agent['phone']?.toString().contains(query) ?? false);
    }).toList();

    if (wallets.isEmpty) return const Center(child: Text('لا يوجد وكلاء مطابقين للبحث.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: wallets.length,
      itemBuilder: (context, index) {
        final agent = wallets[index];
        final balance = double.parse(agent['balance'].toString());
        final dangerLimit = double.parse((agent['dangerLimit'] ?? 0).toString());
        final isDanger = balance <= dangerLimit;

        return Card(
          color: cardColor,
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDanger ? Colors.red.withOpacity(0.5) : Colors.transparent, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: isDanger ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1), child: Icon(Icons.storefront, color: isDanger ? Colors.red : Colors.blue)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${agent['name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                            Text('${agent['phone']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('حصة المبيعات', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Row(
                          children: [
                            if (isDanger) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                            const SizedBox(width: 4),
                            Text('${intl.NumberFormat('#,###').format(balance)} ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDanger ? Colors.red : Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIconButton(Icons.settings, 'تسوية', Colors.blue, () => _showManualSettlementDialog(agent, provider), textColor),
                    _buildIconButton(Icons.tune, 'حد الخطر', Colors.orange, () => _showDangerLimitDialog(agent, provider), textColor),
                    _buildIconButton(Icons.picture_as_pdf, 'كشف حساب', Colors.red, () => _showPdfStatementDialog(agent, provider), textColor),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLedgerTab(SystemProvider provider, Color cardColor, Color textColor) {
    final ledger = provider.transactionsLedger.where((log) {
      final query = _searchQuery.toLowerCase();
      return (log['agentName']?.toString().toLowerCase().contains(query) ?? false) ||
             (log['agentPhone']?.toString().contains(query) ?? false) ||
             (log['type']?.toString().contains(query) ?? false) ||
             (log['title']?.toString().contains(query) ?? false);
    }).toList();

    if (ledger.isEmpty) return const Center(child: Text('السجل المالي فارغ أو لا توجد نتائج للبحث.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: ledger.length,
      itemBuilder: (context, index) {
        final log = ledger[index];
        final amount = double.parse(log['amount'].toString());
        final isPositive = log['type'] == 'deposit' || log['type'] == 'income'; 
        final color = isPositive ? Colors.green : Colors.red;

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
          child: InkWell(
            onTap: () => _showTransactionReceipt(log, provider), // 👈 النقر لعرض الفاتورة
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(isPositive ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log['title'] ?? log['type'] ?? 'حركة مالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${log['agentName'] ?? 'مجهول'} (${log['agentPhone'] ?? ''})', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        if (log['reason'] != null) Text('السبب: ${log['reason']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${isPositive ? '+' : ''}${intl.NumberFormat('#,###').format(amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14), textDirection: TextDirection.ltr),
                      const SizedBox(height: 4),
                      Text(log['timestamp'] != null ? intl.DateFormat('yyyy-MM-dd hh:mm a').format((log['timestamp'] as Timestamp).toDate()) : 'الآن', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String title, String value, {bool isBold = false, Color? color, required Color textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? textColor, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, {TextEditingController? controller, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, Color color, VoidCallback onTap, Color textColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
