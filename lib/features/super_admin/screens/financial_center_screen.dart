import 'dart:convert'; // 👈 ضروري لفك تشفير صورة السند
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection; 
import 'package:pdf/pdf.dart'; 
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart'; 

import '../../../core/providers/system_provider.dart'; 
import '../../../core/providers/ui_provider.dart'; 
import '../../../core/providers/theme_provider.dart'; // 👈 ضروري لتكيف الألوان
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 

class FinancialCenterScreen extends StatefulWidget {
  const FinancialCenterScreen({super.key});

  @override
  State<FinancialCenterScreen> createState() => _FinancialCenterScreenState();
}

class _FinancialCenterScreenState extends State<FinancialCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = ''; 
  
  final Set<String> _processingRequests = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        Provider.of<UiProvider>(context, listen: false).playSound('click');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _play(BuildContext context, String type) => 
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // النوافذ المنبثقة لطلبات الشحن 
  // ==========================================
  void _acceptRequest(Map<String, dynamic> req, SystemProvider provider) async {
    _play(context, 'click'); 
    final docId = req['docId'];
    if (_processingRequests.contains(docId)) return; 

    setState(() => _processingRequests.add(docId)); 

    try {
      await provider.acceptRechargeRequest(
        requestId: docId,
        agentPhone: req['agentPhone'],
        agentName: req['agentName'],
        amount: double.parse(req['amount'].toString()),
      );
      if (mounted) {
        _play(context, 'success'); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تأكيد الشحن وإيداع المبلغ بنجاح ✅'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        _play(context, 'error'); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingRequests.remove(docId)); 
    }
  }

  void _showRejectDialog(Map<String, dynamic> req, SystemProvider provider) {
    _play(context, 'click');
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
              backgroundColor: Theme.of(context).cardColor, // 👈 توافق مع الوضع الليلي
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
                      hintText: 'مثال: رقم المرجع غير صحيح...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                if (!isRejecting)
                  TextButton(onPressed: () { _play(context, 'click'); Navigator.pop(context); }, child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: isRejecting ? null : () async {
                    setStateDialog(() => isRejecting = true);
                    try {
                      await provider.rejectRechargeRequest(docId, reasonController.text);
                      if (mounted) {
                        _play(context, 'success'); 
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب بنجاح.'), backgroundColor: Colors.red));
                      }
                    } catch (e) {
                      setStateDialog(() => isRejecting = false);
                      if (mounted) {
                        _play(context, 'error');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
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
  // النوافذ المنبثقة للمحافظ والتسوية
  // ==========================================
  void _showManualSettlementDialog(Map<String, dynamic> agent, SystemProvider provider) {
    _play(context, 'click');
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
                            title: const Text('إضافة 🟢', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            value: 1, groupValue: settlementType,
                            onChanged: (val) { _play(context, 'click'); setStateDialog(() => settlementType = val as int); },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile(
                            title: const Text('خصم 🔴', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            value: 2, groupValue: settlementType,
                            onChanged: (val) { _play(context, 'click'); setStateDialog(() => settlementType = val as int); },
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
                  TextButton(onPressed: () { _play(context, 'click'); Navigator.pop(context); }, child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: settlementType == 1 ? Colors.green : Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: isProcessing ? null : () async {
                    if (amountController.text.isEmpty || reasonController.text.isEmpty) {
                      _play(context, 'error');
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال المبلغ والسبب!')));
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
                        _play(context, 'success');
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت التسوية بنجاح ✅'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setStateDialog(() => isProcessing = false);
                      if (mounted) {
                        _play(context, 'error');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
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
    _play(context, 'click');
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
              const SizedBox(height: 10),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'رصيد التنبيه (بالريال)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () { _play(context, 'click'); Navigator.pop(context); }, child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                try {
                  await provider.updateDangerLimit(agent['phone'], double.parse(limitController.text));
                  if (mounted) {
                    _play(context, 'success');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث حد الخطر بنجاح.')));
                  }
                } catch (e) {
                  _play(context, 'error');
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
    _play(context, 'click');
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
                      _play(context, 'click');
                      final picked = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) { _play(context, 'click'); setStateDialog(() => startDate = picked); }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(startDate == null ? 'من تاريخ (البداية)' : DateFormat('yyyy-MM-dd').format(startDate!)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      _play(context, 'click');
                      final picked = await showDatePicker(context: context, initialDate: endDate ?? DateTime.now(), firstDate: startDate ?? DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) { _play(context, 'click'); setStateDialog(() => endDate = picked); }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(endDate == null ? 'إلى تاريخ (النهاية)' : DateFormat('yyyy-MM-dd').format(endDate!)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () { _play(context, 'click'); Navigator.pop(context); }, child: const Text('إلغاء')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  if (startDate == null || endDate == null) {
                    _play(context, 'error');
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد فترة الكشف!'), backgroundColor: Colors.orange));
                    return;
                  }
                  _play(context, 'click');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري توليد الـ PDF... ⏳')));
                  await _generateAndDownloadPdf(agent, startDate!, endDate!, provider.transactionsLedger);
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

  Future<void> _generateAndDownloadPdf(Map<String, dynamic> agent, DateTime start, DateTime end, List<Map<String, dynamic>> allLedger) async {
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
                    pw.Text('نظام كروت نت', style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              pw.Text('اسم الوكيل: ${agent['name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('الهاتف: ${agent['phone']}'),
              pw.Text('الفترة: من ${DateFormat('yyyy-MM-dd').format(start)} إلى ${DateFormat('yyyy-MM-dd').format(end)}', style: const pw.TextStyle(color: PdfColors.grey700)),
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
                      DateFormat('yyyy-MM-dd HH:mm').format(date),
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
    if (mounted) _play(context, 'success'); 
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context); // 👈 استدعاء الثيم
    final adminBalance = systemProvider.adminMainBalance;
    final cardColor = Theme.of(context).cardColor;
    final textColor = themeProvider.adaptiveTextColor;

    return Scaffold(
      appBar: const CustomHeader(title: 'المركز المالي والمحافظ'),
      drawer: CustomDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (value) {
                  if(value.length == 1) _play(context, 'click'); 
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: 'بحث شامل بالاسم، أو رقم الهاتف...',
                  prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                  filled: true,
                  fillColor: cardColor, // 👈 متوافق مع الثيم
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
                tabs: const [
                  Tab(icon: Icon(Icons.download), text: 'طلبات الشحن'),
                  Tab(icon: Icon(Icons.account_balance_wallet), text: 'أرصدة المحافظ'),
                  Tab(icon: Icon(Icons.receipt_long), text: 'السجل الشامل'),
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
      return (req['agentName']?.toString().toLowerCase().contains(query) ?? false) ||
             (req['agentPhone']?.toString().contains(query) ?? false) ||
             (req['ref']?.toString().contains(query) ?? false);
    }).toList();

    if (requests.isEmpty) return const Center(child: Text('لا توجد طلبات شحن مطابقة أو قيد الانتظار.'));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final docId = req['docId'];
        final isProcessing = _processingRequests.contains(docId); 

        return Card(
          color: cardColor, // 👈 متوافق مع الثيم
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(req['agentName'] ?? 'مجهول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    Text(req['timestamp'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((req['timestamp'] as Timestamp).toDate()) : 'الآن', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const Divider(),
                _buildInfoRow('رقم الهاتف:', req['agentPhone'] ?? '', textColor: textColor),
                _buildInfoRow('المبلغ المطلوب:', '${req['amount']} ريال', isBold: true, color: Colors.green, textColor: textColor),
                _buildInfoRow('البنك المحول منه:', req['bankName'] ?? 'غير محدد', textColor: textColor),
                _buildInfoRow('رقم المرجع:', req['ref'] ?? 'لا يوجد', textColor: textColor),
                const SizedBox(height: 10),
                
                // 👈 1. برمجة زر عرض الصورة المشفرة Base64
                OutlinedButton.icon(
                  onPressed: () {
                    _play(context, 'click');
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الوكيل لم يقم بإرفاق صورة السند ⏳'), backgroundColor: Colors.orange));
                    }
                  },
                  icon: Icon(Icons.image, size: 18, color: req['hasReceipt'] == true ? Colors.green : Colors.grey),
                  label: Text(req['hasReceipt'] == true ? 'عرض صورة السند 📸' : 'لا يوجد سند مرفق', style: TextStyle(color: req['hasReceipt'] == true ? Colors.green : Colors.grey)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isProcessing ? null : () => _acceptRequest(req, provider),
                        icon: isProcessing ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        label: Text(isProcessing ? 'جاري...' : 'تأكيد الشحن', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isProcessing ? null : () => _showRejectDialog(req, provider),
                        icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
                        label: const Text('رفض', style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: isDanger ? Colors.red : Colors.transparent, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${agent['name']} (${agent['phone']})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                    Row(
                      children: [
                        if (isDanger) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 5),
                        Text('$balance ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDanger ? Colors.red : Colors.green)),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIconButton(Icons.settings, 'تسوية', Colors.blue, () => _showManualSettlementDialog(agent, provider), textColor),
                    _buildIconButton(Icons.tune, 'الخطر', Colors.orange, () => _showDangerLimitDialog(agent, provider), textColor),
                    _buildIconButton(Icons.picture_as_pdf, 'كشف', Colors.red, () => _showPdfStatementDialog(agent, provider), textColor),
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
             (log['type']?.toString().contains(query) ?? false);
    }).toList();

    if (ledger.isEmpty) return const Center(child: Text('السجل المالي فارغ أو لا توجد نتائج للبحث.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ledger.length,
      itemBuilder: (context, index) {
        final log = ledger[index];
        final amount = double.parse(log['amount'].toString());
        final isPositive = amount > 0;
        final color = isPositive ? Colors.green : Colors.red;

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(isPositive ? Icons.arrow_downward : Icons.arrow_upward, color: color),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(log['agentName'] ?? 'مجهول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                Text('${isPositive ? '+' : ''}$amount', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14), textDirection: TextDirection.ltr),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(log['type'] ?? 'حركة مالية', style: TextStyle(fontWeight: FontWeight.bold, color: textColor.withOpacity(0.8))), 
                if (log['reason'] != null) Text('السبب: ${log['reason']}', style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6))),
                const SizedBox(height: 4),
                Text(log['timestamp'] != null ? DateFormat('yyyy-MM-dd hh:mm a').format((log['timestamp'] as Timestamp).toDate()) : 'الآن', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String title, String value, {bool isBold = false, Color? color, required Color textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: textColor.withOpacity(0.7))),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? textColor)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, Color color, VoidCallback onTap, Color textColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
