import 'dart:convert'; 
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart'; 
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentWalletScreen extends StatefulWidget {
  const AgentWalletScreen({super.key});

  @override
  State<AgentWalletScreen> createState() => _AgentWalletScreenState();
}

class _AgentWalletScreenState extends State<AgentWalletScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;

  String _selectedFilter = 'الكل';
  String _selectedDateFilter = 'الكل'; 
  bool _isBalanceHidden = false; 

  // 👈 تم إعادة المتغيرات هنا لتعمل في الخلفية وتصلح خطأ البناء (Build Error)
  double _vipThreshold = 50000.0;
  String _autoVipCommission = '5%';

  @override
  void initState() {
    super.initState();
    // 3 تبويبات: السجل والتحويل، الطلبات، حساباتي البنكية
    _tabController = TabController(length: 3, vsync: this);
  }

  void _showSnack(String m, {bool isErr = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m, textDirection: TextDirection.rtl), backgroundColor: isErr ? Colors.red : Colors.green)
    );
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 2)}';
  }

  // ==========================================
  // 1. نافذة طلب رصيد 📸
  // ==========================================
  void _showRequestBalanceDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final activeBanks = sys.bankAccounts.where((bank) => bank['status'] == 'نشط').toList();
    
    String? selectedBank;
    if (activeBanks.isNotEmpty) selectedBank = activeBanks.first['bankName']; 

    final amountController = TextEditingController();
    final refController = TextEditingController();
    String? base64Image;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('طلب تغذية رصيد', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الحد الأدنى: ${sys.minimumChargeLimit} ريال', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  if (activeBanks.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedBank,
                      decoration: const InputDecoration(labelText: 'البنك المُحوَّل إليه', border: OutlineInputBorder()),
                      items: activeBanks.map((bank) => DropdownMenuItem(value: bank['bankName'].toString(), child: Text(bank['bankName'].toString()))).toList(),
                      onChanged: (val) { _play('click'); selectedBank = val!; },
                    )
                  else
                    const Text('لا توجد حسابات بنكية نشطة حالياً.', style: TextStyle(color: Colors.red)),
                  
                  const SizedBox(height: 10),
                  TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المحول', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: refController, decoration: const InputDecoration(labelText: 'رقم المرجع / العملية', prefixIcon: Icon(Icons.receipt), border: OutlineInputBorder())),
                  const SizedBox(height: 15),

                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(border: Border.all(color: base64Image == null ? Colors.grey : Colors.green), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        Icon(base64Image == null ? Icons.camera_alt : Icons.check_circle, color: base64Image == null ? Colors.grey : Colors.green, size: 30),
                        const SizedBox(height: 5),
                        ElevatedButton(
                          onPressed: () async {
                            _play('click');
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 600);
                            if (pickedFile != null) {
                              final bytes = await pickedFile.readAsBytes();
                              setStateDialog(() => base64Image = base64Encode(bytes));
                              _showSnack('تم إرفاق السند بنجاح ✅');
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: base64Image == null ? Colors.blueGrey : Colors.green),
                          child: Text(base64Image == null ? 'إرفاق صورة السند 📸' : 'تغيير الصورة المرفقة', style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: activeBanks.isEmpty ? null : () {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  double minLimit = double.tryParse(sys.minimumChargeLimit) ?? 0;

                  if (amount < minLimit) { _play('error'); _showSnack('المبلغ أقل من الحد الأدنى المسموح به!', isErr: true); return; }
                  if (base64Image == null) { _play('error'); _showSnack('يجب إرفاق صورة السند أولاً!', isErr: true); return; }

                  if (amount > 0 && refController.text.isNotEmpty && selectedBank != null) {
                    _play('warning');
                    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
                      title: const Text('تأكيد الطلب ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text('هل أنت متأكد من إرسال طلب تغذية بقيمة $amount ريال؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () async {
                            Navigator.pop(ctx); 
                            Navigator.pop(context); 
                            
                            _play('success');
                            _showSnack('جاري إرسال الطلب... ⏳');
                            
                            try {
                              if (sys.isCurrencyAutoRounding) amount = amount.ceilToDouble();
                              await _db.collection('recharge_requests').add({
                                'agentPhone': sys.currentUserPhone, 'agentName': sys.currentUserName,
                                'amount': amount, 'bankName': selectedBank, 'reference': refController.text,
                                'status': 'قيد الانتظار', 'hasReceipt': true, 'receiptBase64': base64Image, 'timestamp': FieldValue.serverTimestamp(),
                              });
                              if (mounted) _showSnack('تم إرسال الطلب للمراجعة بنجاح ✅');
                            } catch(e) {
                              _play('error');
                              if (mounted) _showSnack('حدث خطأ أثناء الإرسال', isErr: true);
                            }
                          },
                          child: const Text('تأكيد وإرسال', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    )));
                  } else {
                    _play('error'); _showSnack('يرجى إكمال البيانات', isErr: true);
                  }
                },
                child: const Text('إرسال الطلب', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة التحويل المتقدمة 🛡️🔥
  // ==========================================
  void _showAdvancedTransferDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final taxController = TextEditingController();
    final noteController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isSearching = false;
          bool isUserFound = false;
          Map<String, dynamic>? targetData; 
          String targetPhoneStr = '';
          String selectedPaymentMethod = 'نقدي'; // الافتراضي
          
          // متغيرات للحساب اللحظي
          double currentAmount = 0;
          double currentTax = 0;
          double taxValue = 0;
          double totalCost = 0;

          void calculateLive() {
            currentAmount = double.tryParse(amountController.text) ?? 0;
            currentTax = double.tryParse(taxController.text) ?? 0;
            taxValue = currentAmount * (currentTax / 100);
            totalCost = currentAmount + taxValue;
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('تحويل رصيد (متقدم)', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isUserFound) ...[
                      const Text('أدخل رقم هاتف المستلم للبحث عنه في النظام:', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      const SizedBox(height: 15),
                      TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم المستلم', prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('سيتم التحويل إلى:', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الاسم:', style: TextStyle(fontSize: 12, color: Colors.grey)), Text(targetData?['name'] ?? 'مجهول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue))]),
                            const SizedBox(height: 5),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الرقم:', style: TextStyle(fontSize: 12, color: Colors.grey)), Text(targetPhoneStr, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1), textDirection: TextDirection.ltr)]),
                            const SizedBox(height: 5),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الدور:', style: TextStyle(fontSize: 12, color: Colors.grey)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(5)), child: Text((targetData?['role'] == 'pos') ? 'نقطة بيع' : (targetData?['role'] == 'agent') ? 'وكيل' : 'مستخدم', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)))]),
                            const SizedBox(height: 5),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('رصيده الحالي لديك:', style: TextStyle(fontSize: 12, color: Colors.grey)), Text('${targetData?['balance']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
                            const SizedBox(height: 5),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('آخر شحن:', style: TextStyle(fontSize: 12, color: Colors.grey)), Text(targetData?['lastRecharge'] ?? 'لا يوجد', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: amountController, keyboardType: TextInputType.number, 
                              onChanged: (v) => setStateDialog((){ calculateLive(); }),
                              decoration: const InputDecoration(labelText: 'الكمية (نقاط/مبلغ)', border: OutlineInputBorder())
                            )
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: taxController, keyboardType: TextInputType.number, 
                              onChanged: (v) => setStateDialog((){ calculateLive(); }),
                              decoration: const InputDecoration(labelText: 'الضريبة %', border: OutlineInputBorder())
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        decoration: const InputDecoration(labelText: 'طريقة الاستلام الدفع', border: OutlineInputBorder()),
                        items: ['نقدي', 'تحويل بنكي', 'آجل'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setStateDialog(() => selectedPaymentMethod = v!),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: noteController, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder())),
                      
                      if (currentAmount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 15),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('سيتم خصم: $currentAmount من رصيدك', style: const TextStyle(fontSize: 11)),
                              Text('الضريبة/الرسوم المضافة: $taxValue ريال', style: const TextStyle(fontSize: 11, color: Colors.red)),
                              const Divider(),
                              Text('الإجمالي المطلوب (سداد/دين): $totalCost ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              if (selectedPaymentMethod == 'آجل')
                                const Text('⚠️ سيتم تقييد الإجمالي كدين على المستلم تلقائياً', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),

                      const SizedBox(height: 15),
                      TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة مرورك (للتأكيد)', prefixIcon: Icon(Icons.lock, color: Colors.red), border: OutlineInputBorder())),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _play('click');
                    if (isUserFound) setStateDialog(() => isUserFound = false); 
                    else Navigator.pop(context);
                  }, 
                  child: Text(isUserFound ? 'تغيير الرقم' : 'إلغاء', style: const TextStyle(color: Colors.grey))
                ),
                
                if (!isUserFound)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: isSearching ? null : () async {
                      String targetPhone = phoneController.text.trim();
                      if (targetPhone.isEmpty || targetPhone == sys.currentUserPhone) { _play('error'); _showSnack('رقم غير صالح!', isErr: true); return; }
                      setStateDialog(() => isSearching = true);
                      
                      try {
                        var data = await sys.searchUserForTransfer(targetPhone);
                        if (data != null) {
                          _play('success');
                          setStateDialog(() { targetData = data; targetPhoneStr = targetPhone; isUserFound = true; isSearching = false; });
                        } else {
                          setStateDialog(() => isSearching = false); _play('error'); _showSnack('لم يتم العثور على مستخدم بهذا الرقم!', isErr: true);
                        }
                      } catch (e) {
                        setStateDialog(() => isSearching = false); _play('error'); _showSnack(e.toString(), isErr: true);
                      }
                    },
                    child: isSearching ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('بحث وتحقق', style: TextStyle(color: Colors.white)),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: isSearching ? null : () async {
                      if (passwordController.text.isEmpty) { _play('error'); _showSnack('يرجى إدخال كلمة المرور', isErr: true); return; }
                      if (currentAmount <= 0 || currentAmount > sys.currentUserBalance) { _play('error'); _showSnack('المبلغ غير متاح في رصيدك!', isErr: true); return; }

                      _play('warning');
                      showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
                        title: const Text('تأكيد التحويل ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: Text('تأكيد تحويل $currentAmount (بإجمالي مطلوب $totalCost) إلى ${targetData?['name']}؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              setStateDialog(() => isSearching = true);
                              try {
                                await sys.advancedSecureTransferBalance(
                                  targetPhone: targetPhoneStr, 
                                  targetName: targetData?['name'], 
                                  amount: currentAmount,
                                  taxPercentage: currentTax,
                                  note: noteController.text,
                                  paymentMethod: selectedPaymentMethod,
                                  password: passwordController.text
                                );
                                
                                if (mounted) { Navigator.pop(context); _play('success'); _showSnack('تم التحويل بنجاح! 🎉'); }
                              } catch (e) {
                                setStateDialog(() => isSearching = false); _play('error'); _showSnack(e.toString(), isErr: true);
                              }
                            },
                            child: const Text('نعم، حوّل الرصيد', style: TextStyle(color: Colors.white)),
                          )
                        ],
                      )));
                    },
                    child: isSearching ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تأكيد وإرسال', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          );
        }
      ),
    );
  }

  // ==========================================
  // 3. تصدير كشف حساب PDF 📄 
  // ==========================================
  void _showPdfStatementDialog(SystemProvider sys, List<Map<String, dynamic>> realTransactions) {
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
            title: const Text('تصدير كشف حساب PDF', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('يمكنك تصدير السجل المالي بالكامل، أو تحديد فترة معينة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 15),
                  
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      _play('click'); Navigator.pop(context);
                      _generateMyStatement(sys, realTransactions, DateTime(2020), DateTime.now(), isAll: true);
                    },
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text('تصدير كل السجل (سريع)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('أو تحديد فترة', style: TextStyle(fontSize: 11, color: Colors.grey))), Expanded(child: Divider())])),

                  OutlinedButton.icon(
                    onPressed: () async {
                      _play('click');
                      final picked = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) setStateDialog(() => startDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(startDate == null ? 'من تاريخ (البداية)' : DateFormat('yyyy-MM-dd').format(startDate!)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      _play('click');
                      final picked = await showDatePicker(context: context, initialDate: endDate ?? DateTime.now(), firstDate: startDate ?? DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) setStateDialog(() => endDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(endDate == null ? 'إلى تاريخ (النهاية)' : DateFormat('yyyy-MM-dd').format(endDate!)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () async {
                  if (startDate == null || endDate == null) { _play('error'); _showSnack('يرجى تحديد فترة الكشف أولاً!', isErr: true); return; }
                  _play('click'); Navigator.pop(context);
                  _generateMyStatement(sys, realTransactions, startDate!, endDate!, isAll: false);
                },
                child: const Text('تصدير المحدد', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateMyStatement(SystemProvider sys, List<Map<String, dynamic>> allTxn, DateTime start, DateTime end, {required bool isAll}) async {
    _showSnack('جاري تجهيز كشف الحساب (PDF)... ⏳');
    final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59); 
    final startInclusive = DateTime(start.year, start.month, start.day, 0, 0, 0);

    final filtered = allTxn.where((t) {
      if (t['timestamp'] == null) return false;
      DateTime d = (t['timestamp'] as Timestamp).toDate();
      return d.isAfter(startInclusive) && d.isBefore(endInclusive);
    }).toList();

    double totalIn = 0;
    double totalOut = 0;

    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl, 
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
      header: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(color: PdfColors.teal800, borderRadius: pw.BorderRadius.circular(10)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('كشف حساب محفظة مالية', style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text('الوكيل: ${sys.currentUserName}', style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                      pw.Text('رقم الحساب: ${sys.currentUserPhone}', style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                    ]
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(5)),
                    child: pw.Text('نظام كروت نت', style: pw.TextStyle(color: PdfColors.teal800, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  )
                ]
              )
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(isAll ? 'الفترة: السجل بالكامل' : 'الفترة: ${DateFormat('yyyy-MM-dd').format(start)} إلى ${DateFormat('yyyy-MM-dd').format(end)}', style: const pw.TextStyle(color: PdfColors.grey700)),
                pw.Text('تاريخ الإصدار: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(color: PdfColors.grey700)),
              ]
            ),
            pw.SizedBox(height: 20),
          ]
        );
      },
      build: (pw.Context context) {
        return [
          pw.TableHelper.fromTextArray(
            context: context,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 11),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: pw.TextStyle(font: arabicFont, fontSize: 10),
            cellAlignment: pw.Alignment.center,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            data: <List<String>>[
              <String>['رقم المرجع', 'التاريخ', 'البيان', 'النوع', 'المبلغ'], 
              ...filtered.map((item) {
                DateTime date = (item['timestamp'] as Timestamp).toDate();
                bool isPlus = item['type'] == 'income' || item['type'] == 'deposit' || (item['type'] == 'transfer' && item['toPhone'] == sys.currentUserPhone);
                
                double amt = double.tryParse(item['amount'].toString()) ?? 0.0;
                if (isPlus) totalIn += amt; else totalOut += amt;

                return [
                  item['reference'] ?? 'N/A',
                  DateFormat('yyyy-MM-dd HH:mm').format(date), 
                  item['title'] ?? 'عملية', 
                  isPlus ? 'إيداع (+)' : 'خصم (-)', 
                  '${item['amount']}'
                ];
              })
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('إجمالي الإيداعات', style: pw.TextStyle(color: PdfColors.grey700, font: arabicBold)),
                    pw.Text('$totalIn ريال', style: pw.TextStyle(color: PdfColors.green700, fontSize: 16, font: arabicBold)),
                  ]
                ),
                pw.Column(
                  children: [
                    pw.Text('إجمالي المسحوبات', style: pw.TextStyle(color: PdfColors.grey700, font: arabicBold)),
                    pw.Text('$totalOut ريال', style: pw.TextStyle(color: PdfColors.red700, fontSize: 16, font: arabicBold)),
                  ]
                ),
                pw.Column(
                  children: [
                    pw.Text('صافي الحركة', style: pw.TextStyle(color: PdfColors.grey700, font: arabicBold)),
                    pw.Text('${totalIn - totalOut} ريال', style: pw.TextStyle(color: (totalIn - totalOut) >= 0 ? PdfColors.blue800 : PdfColors.red800, fontSize: 16, font: arabicBold)),
                  ]
                ),
              ]
            )
          )
        ];
      },
    ));

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Statement_${sys.currentUserPhone}.pdf');
    _play('success');
  }

  // ==========================================
  // 4. تصدير كشف حساب بصيغة Excel/CSV 📊 
  // ==========================================
  Future<void> _exportCSV(List<Map<String, dynamic>> txns, SystemProvider sys) async {
    _play('click');
    if (txns.isEmpty) {
      _showSnack('لا توجد بيانات لتصديرها!', isErr: true);
      return;
    }
    _showSnack('جاري تصدير السجل إلى إكسل... ⏳');
    
    String csv = '\uFEFF'; 
    csv += 'المرجع,التاريخ,البيان,النوع,المبلغ (ريال),الطرف الآخر\n';
    
    for(var t in txns) {
      if (t['timestamp'] == null) continue;
      DateTime d = (t['timestamp'] as Timestamp).toDate();
      String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(d);
      bool isPlus = t['type'] == 'income' || t['type'] == 'deposit' || (t['type'] == 'transfer' && t['toPhone'] == sys.currentUserPhone);
      String typeStr = isPlus ? 'إيداع (+)' : 'خصم (-)';
      String target = t['targetName'] ?? 'نظام كروت نت';
      String ref = t['reference'] ?? 'بدون مرجع';

      csv += '$ref,$dateStr,${t['title'] ?? 'عملية'},$typeStr,${t['amount']},$target\n';
    }
    
    Uint8List bytes = Uint8List.fromList(utf8.encode(csv));
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'text/csv', name: 'Wallet_Ledger_${sys.currentUserPhone}.csv')], 
      text: 'مرفق كشف حساب المحفظة بصيغة إكسل'
    );
    _play('success');
  }

  // ==========================================
  // 5. نافذة عرض الإيصال الرقمي 🧾
  // ==========================================
  void _showTransactionReceipt(Map<String, dynamic> txn, SystemProvider sys) {
    _play('click');
    bool isPlus = txn['type'] == 'income' || txn['type'] == 'deposit' || (txn['type'] == 'transfer' && txn['toPhone'] == sys.currentUserPhone);
    String dateStr = txn['timestamp'] != null ? DateFormat('yyyy-MM-dd hh:mm a').format((txn['timestamp'] as Timestamp).toDate()) : 'الآن';
    
    showDialog(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Container(
            width: 300,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300)
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long, size: 40, color: Colors.blueGrey),
                const SizedBox(height: 5),
                const Text('نظام كروت نت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                const Text('إيصال عملية إلكترونية', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.5)),
                
                Text(txn['title'] ?? 'عملية مالية', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                const SizedBox(height: 15),
                
                _buildReceiptRow('المبلغ', '${txn['amount']} ريال', valueColor: isPlus ? Colors.green : Colors.red, isBold: true),
                _buildReceiptRow('تاريخ العملية', dateStr),
                _buildReceiptRow('نوع الحركة', isPlus ? 'إيداع (+)' : 'خصم (-)'),
                if (txn['paymentMethod'] != null)
                  _buildReceiptRow('طريقة الدفع', txn['paymentMethod']),
                if (txn['targetName'] != null)
                  _buildReceiptRow('الطرف الآخر', txn['targetName']),
                if (txn['reference'] != null)
                  _buildReceiptRow('رقم المرجع', txn['reference']),

                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.5)), 
                const Text('شكراً لاستخدامكم محفظة كروت نت', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('إغلاق', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            ElevatedButton.icon(
               icon: const Icon(Icons.share, color: Colors.white, size: 16),
               label: const Text('مشاركة الإيصال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
               onPressed: () {
                  _play('click');
                  String shareText = '🧾 *إيصال عملية رقمية - كروت نت*\n';
                  shareText += '----------------------------\n';
                  shareText += 'البيان: ${txn['title']}\n';
                  shareText += 'المبلغ: *${txn['amount']} ريال*\n';
                  shareText += 'التاريخ: $dateStr\n';
                  shareText += 'النوع: ${isPlus ? "إيداع" : "خصم"}\n';
                  if(txn['paymentMethod'] != null) shareText += 'طريقة الدفع: ${txn['paymentMethod']}\n';
                  if(txn['reference'] != null) shareText += 'المرجع: ${txn['reference']}\n';
                  shareText += '----------------------------';
                  Share.share(shareText);
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
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: isBold ? 16 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }

  // ==========================================
  // وظائف الموافقة والرفض لطلبات الشحن 
  // ==========================================
  void _confirmApproveRequest(String reqId, String posPhone, double amount, bool isVip, SystemProvider sys, String userName) {
    _play('warning');
    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
      title: const Text('تأكيد الموافقة ✅', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      content: Text('هل تم التأكد من وصول مبلغ $amount ريال من $userName؟\nسيتم إضافة الرصيد إلى محفظته فوراً.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () async {
            Navigator.pop(ctx);
            _play('click');
            try {
              await sys.agentAcceptUserRecharge(reqId, posPhone, amount);
              if (isVip) {
                await sys.upgradeUserToPos(posPhone: posPhone, storeName: 'محل $userName', location: 'غير محدد', creditLimit: 0.0, commission: _autoVipCommission, allowedCategories: []);
                if(mounted) _showSnack('تم الموافقة وترقية الزبون إلى بقالة تلقائياً! 🌟');
              } else {
                if(mounted) _showSnack('تم إضافة الرصيد لمحفظة الزبون بنجاح ✅');
              }
              _play('success');
            } catch (e) {
              _play('error'); _showSnack('حدث خطأ أثناء الموافقة: $e', isErr: true);
            }
          },
          child: const Text('نعم، أؤكد الاستلام', style: TextStyle(color: Colors.white)),
        )
      ],
    )));
  }

  void _confirmRejectRequest(String reqId) {
    _play('warning');
    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
      title: const Text('رفض الطلب ❌', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      content: const Text('هل أنت متأكد أنك تريد رفض هذا الطلب؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(ctx);
            _play('click');
            await _db.collection('recharge_requests').doc(reqId).update({'status': 'مرفوض'});
            if(mounted) { _play('success'); _showSnack('تم رفض الطلب.'); }
          },
          child: const Text('نعم، ارفض الطلب', style: TextStyle(color: Colors.white)),
        )
      ],
    )));
  }

  void _confirmBulkApprove(List<QueryDocumentSnapshot> requests, SystemProvider sys) {
    if (requests.isEmpty) return;
    _play('warning');
    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
      title: const Text('موافقة جماعية ⚡', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      content: Text('أنت على وشك الموافقة على (${requests.length}) طلبات شحن دفعة واحدة.\nهل أنت متأكد من استلامك لجميع الحوالات؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () async {
            Navigator.pop(ctx);
            _play('click');
            showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
            try {
              for (var reqDoc in requests) {
                var req = reqDoc.data() as Map<String, dynamic>;
                double reqAmount = (req['amount'] ?? 0).toDouble();
                bool isVip = reqAmount >= _vipThreshold; 
                await sys.agentAcceptUserRecharge(reqDoc.id, req['userPhone'], reqAmount);
                if (isVip) {
                  await sys.upgradeUserToPos(posPhone: req['userPhone'], storeName: 'محل ${req['userName']}', location: 'غير محدد', creditLimit: 0.0, commission: _autoVipCommission, allowedCategories: []);
                }
              }
              if (mounted) { Navigator.pop(context); _play('success'); _showSnack('تمت الموافقة على جميع الطلبات بنجاح! ✅'); }
            } catch (e) {
              if (mounted) { Navigator.pop(context); _play('error'); _showSnack('حدث خطأ أثناء المعالجة الجماعية', isErr: true); }
            }
          },
          child: const Text('تأكيد الكل', style: TextStyle(color: Colors.white)),
        )
      ],
    )));
  }

  // ==========================================
  // التبويب الثالث: حساباتي البنكية 🏦 (البديل للـ VIP)
  // ==========================================
  Widget _buildBankAccountsTab(SystemProvider sys) {
    var accounts = sys.myAgentBankAccounts;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showAddEditBankDialog(sys),
            icon: const Icon(Icons.add_card, color: Colors.white),
            label: const Text('إضافة حساب بنكي جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 50)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(alignment: Alignment.centerRight, child: Text('يمكنك ترتيب الحسابات بالسحب والإفلات ↕️', style: TextStyle(fontSize: 11, color: Colors.grey))),
        ),
        Expanded(
          child: accounts.isEmpty
            ? const Center(child: Text('لم تقم بإضافة حسابات بنكية بعد', style: TextStyle(color: Colors.grey)))
            : ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: accounts.length,
                onReorder: (oldIndex, newIndex) {
                  _play('click');
                  sys.reorderAgentBankAccounts(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  var bank = accounts[index];
                  bool isActive = bank['status'] == 'نشط';
                  
                  return Card(
                    key: ValueKey(bank['docId']),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isActive ? Colors.transparent : Colors.red.withOpacity(0.5))),
                    child: ListTile(
                      leading: Icon(Icons.account_balance, color: isActive ? Colors.blue : Colors.red),
                      title: Text('${bank['bankName']} - ${bank['networkName']}', style: TextStyle(fontWeight: FontWeight.bold, decoration: isActive ? null : TextDecoration.lineThrough)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('رقم الحساب: ${bank['accountNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text('المستلم: ${bank['agentName']}', style: const TextStyle(fontSize: 12)),
                          if (bank['note'] != null && bank['note'].toString().isNotEmpty)
                            Text('ملاحظة: ${bank['note']}', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(isActive ? Icons.toggle_on : Icons.toggle_off, color: isActive ? Colors.green : Colors.red, size: 30),
                            onPressed: () { _play('click'); sys.toggleAgentBankAccountStatus(bank['docId'], bank['status']); }
                          ),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              _play('click');
                              if (val == 'edit') _showAddEditBankDialog(sys, bankData: bank);
                              if (val == 'delete') {
                                showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
                                  title: const Text('حذف الحساب ⚠️'),
                                  content: const Text('هل أنت متأكد من حذف هذا الحساب نهائياً؟'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
                                    ElevatedButton(onPressed: () { Navigator.pop(ctx); sys.deleteAgentBankAccount(bank['docId']); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('نعم، احذف', style: TextStyle(color: Colors.white))),
                                  ]
                                )));
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                              const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                          const Icon(Icons.drag_handle, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
        )
      ],
    );
  }

  void _showAddEditBankDialog(SystemProvider sys, {Map<String, dynamic>? bankData}) {
    _play('click');
    bool isEdit = bankData != null;
    final networkCtrl = TextEditingController(text: isEdit ? bankData['networkName'] : '');
    final nameCtrl = TextEditingController(text: isEdit ? bankData['agentName'] : sys.currentUserName);
    final bankCtrl = TextEditingController(text: isEdit ? bankData['bankName'] : '');
    final accCtrl = TextEditingController(text: isEdit ? bankData['accountNumber'] : '');
    final noteCtrl = TextEditingController(text: isEdit ? bankData['note'] : '');

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(isEdit ? 'تعديل الحساب البنكي' : 'إضافة حساب بنكي', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: networkCtrl, decoration: const InputDecoration(labelText: 'اسم الشبكة التابع لها الحساب', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المستلم (الوكيل) الرباعي', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'اسم البنك / المحفظة (مثل: الكريمي)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: accCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم الحساب', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'ملاحظة للزبائن (اختياري)', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                if (networkCtrl.text.isEmpty || nameCtrl.text.isEmpty || bankCtrl.text.isEmpty || accCtrl.text.isEmpty) {
                  _play('error'); _showSnack('يرجى تعبئة جميع الحقول المطلوبة!', isErr: true); return;
                }
                Navigator.pop(context);
                try {
                  if (isEdit) {
                    await sys.updateAgentBankAccount(bankData['docId'], networkCtrl.text, nameCtrl.text, bankCtrl.text, accCtrl.text, noteCtrl.text);
                    _showSnack('تم تعديل الحساب بنجاح ✅');
                  } else {
                    await sys.addAgentBankAccount(networkCtrl.text, nameCtrl.text, bankCtrl.text, accCtrl.text, noteCtrl.text);
                    _showSnack('تم إضافة الحساب بنجاح ✅');
                  }
                  _play('success');
                } catch(e) {
                  _play('error'); _showSnack(e.toString(), isErr: true);
                }
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // واجهات مساعدة
  // ==========================================
  Widget _buildQuickBtn(IconData icon, String label, Color iconColor, VoidCallback onTap) {
    final textColor = Provider.of<ThemeProvider>(context).adaptiveTextColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          CircleAvatar(backgroundColor: iconColor.withOpacity(0.15), radius: 22, child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({required String value, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButton<String>(
        value: value,
        dropdownColor: Theme.of(context).cardColor,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
        items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: TextStyle(fontSize: 11, color: Provider.of<ThemeProvider>(context).adaptiveTextColor)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
