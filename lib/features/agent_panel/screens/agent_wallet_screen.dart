import 'dart:convert'; // 👈 ضروري لتشفير الصورة إلى Base64
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
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

class _AgentWalletScreenState extends State<AgentWalletScreen> {
  String _selectedFilter = 'الكل';
  bool _isBalanceHidden = false; 

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
  // 1. نافذة طلب رصيد (مع دمج السند كـ Base64) 📸
  // ==========================================
  void _showRequestBalanceDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final activeBanks = sys.bankAccounts.where((bank) => bank['status'] == 'نشط').toList();
    
    String? selectedBank;
    if (activeBanks.isNotEmpty) selectedBank = activeBanks.first['bankName']; 

    final amountController = TextEditingController();
    final refController = TextEditingController();
    
    String? base64Image; // 👈 متغير لحفظ الصورة كنص

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
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'المبلغ المحول', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(labelText: 'رقم المرجع / العملية', prefixIcon: Icon(Icons.receipt), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),

                  // 👈 زر التقاط الصورة وتحويلها لـ Base64
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(border: Border.all(color: base64Image == null ? Colors.grey : Colors.green), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        Icon(base64Image == null ? Icons.camera_alt : Icons.check_circle, color: base64Image == null ? Colors.grey : Colors.green, size: 30),
                        const SizedBox(height: 5),
                        ElevatedButton(
                          onPressed: () async {
                            _play('click');
                            final picker = ImagePicker();
                            // ضغط الصورة لتقليل حجم النص (مهم جداً لتجنب حدود Firestore)
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
                onPressed: activeBanks.isEmpty ? null : () async {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  double minLimit = double.tryParse(sys.minimumChargeLimit) ?? 0;

                  if (amount < minLimit) {
                    _play('error'); _showSnack('المبلغ أقل من الحد الأدنى المسموح به!', isErr: true); return;
                  }
                  if (base64Image == null) {
                    _play('error'); _showSnack('يجب إرفاق صورة السند أولاً!', isErr: true); return;
                  }

                  if (amount > 0 && refController.text.isNotEmpty && selectedBank != null) {
                    if (sys.isCurrencyAutoRounding) amount = amount.ceilToDouble();

                    // حفظ الطلب مع الصورة المشفرة
                    await FirebaseFirestore.instance.collection('recharge_requests').add({
                      'agentPhone': sys.currentUserPhone,
                      'agentName': sys.currentUserName,
                      'amount': amount,
                      'bankName': selectedBank,
                      'reference': refController.text,
                      'status': 'قيد الانتظار',
                      'hasReceipt': true,
                      'receiptBase64': base64Image, // 👈 حفظ الصورة كنص هنا
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    if (mounted) {
                      Navigator.pop(context); _play('success'); _showSnack('تم إرسال الطلب وهو قيد المراجعة ⏳');
                    }
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
  // 2. تحويل رصيد بأمان (بخطوتين واضحتين) 🛡️
  // ==========================================
  void _showTransferToAnyUserDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final passwordController = TextEditingController();

    final myData = sys.agentsList.firstWhere((a) => a['phone'] == sys.currentUserPhone, orElse: () => {});
    final myPassword = myData['password'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isSearching = false;
          bool isUserFound = false;
          String targetName = '';
          String targetPhoneStr = '';

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('تحويل رصيد', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isUserFound) ...[
                      const Text('أدخل رقم هاتف المستلم للتحقق من هويته:', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      const SizedBox(height: 15),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'رقم المستلم', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder()),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                        child: Column(
                          children: [
                            const Text('سيتم التحويل إلى:', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                            Text(targetName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                            Text(_maskPhone(targetPhoneStr), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.blueGrey), textDirection: TextDirection.ltr),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.send), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'كلمة المرور (للتأكيد)', prefixIcon: Icon(Icons.lock, color: Colors.red), border: OutlineInputBorder()),
                      ),
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
                      if (targetPhone.isEmpty || targetPhone == sys.currentUserPhone) {
                        _play('error'); _showSnack('رقم غير صالح!', isErr: true); return;
                      }

                      setStateDialog(() => isSearching = true);
                      try {
                        var userSnap = await FirebaseFirestore.instance.collection('users').doc(targetPhone).get();
                        if (userSnap.exists) {
                          _play('success');
                          setStateDialog(() {
                            targetName = userSnap.data()?['name'] ?? 'مستخدم';
                            targetPhoneStr = targetPhone;
                            isUserFound = true;
                            isSearching = false;
                          });
                        } else {
                          setStateDialog(() => isSearching = false);
                          _play('error'); _showSnack('لم يتم العثور على مستخدم بهذا الرقم!', isErr: true);
                        }
                      } catch (e) {
                        setStateDialog(() => isSearching = false);
                        _play('error'); _showSnack('حدث خطأ في الاتصال', isErr: true);
                      }
                    },
                    child: isSearching ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تحقق من الرقم', style: TextStyle(color: Colors.white)),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: isSearching ? null : () async {
                      double amount = double.tryParse(amountController.text) ?? 0;
                      
                      if (passwordController.text != myPassword) {
                        _play('error'); _showSnack('كلمة المرور غير صحيحة! ❌', isErr: true); return;
                      }
                      if (amount <= 0 || amount > sys.currentUserBalance) {
                        _play('error'); _showSnack('المبلغ غير متاح في رصيدك!', isErr: true); return;
                      }

                      setStateDialog(() => isSearching = true);
                      try {
                        WriteBatch batch = FirebaseFirestore.instance.batch();
                        batch.update(FirebaseFirestore.instance.collection('users').doc(sys.currentUserPhone), {'balance': FieldValue.increment(-amount)});
                        
                        var targetRef = FirebaseFirestore.instance.collection('users').doc(targetPhoneStr);
                        batch.set(targetRef, {'balance': FieldValue.increment(amount)}, SetOptions(merge: true));
                        
                        batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
                          'fromPhone': sys.currentUserPhone, 'toPhone': targetPhoneStr,
                          'agentName': sys.currentUserName, 'targetName': targetName,
                          'amount': amount, 'type': 'transfer', 'title': 'تحويل رصيد صادر إلى $targetName', 'timestamp': FieldValue.serverTimestamp()
                        });

                        await batch.commit();
                        if (mounted) {
                          Navigator.pop(context); _play('success'); _showSnack('تم التحويل بنجاح! 🎉');
                        }
                      } catch (e) {
                        setStateDialog(() => isSearching = false);
                        _play('error'); _showSnack('حدث خطأ أثناء التحويل', isErr: true);
                      }
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
  // 3. تأكيد وإلغاء الطلب المعلق (زر واحد فقط) ⚠️
  // ==========================================
  void _confirmDeleteRequest(String docId) {
    _play('click');
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('إلغاء الطلب ⚠️', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد أنك تريد إلغاء طلب الشحن المعلق؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // الحذف من قاعدة البيانات يلغيه من لوحة الإدارة تلقائياً
                await FirebaseFirestore.instance.collection('recharge_requests').doc(docId).delete();
                if (mounted) {
                  Navigator.pop(context);
                  _play('success');
                  _showSnack('تم إلغاء الطلب ومسحه بنجاح.');
                }
              },
              child: const Text('نعم، ألغِ الطلب', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. كشف حساب الوكيل (PDF) 📄
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
            title: const Text('تصدير كشف حساب', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () async {
                  if (startDate == null || endDate == null) {
                    _play('error'); _showSnack('يرجى تحديد فترة الكشف!', isErr: true); return;
                  }
                  _play('click');
                  Navigator.pop(context);
                  _generateMyStatement(sys, realTransactions, startDate!, endDate!);
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

  Future<void> _generateMyStatement(SystemProvider sys, List<Map<String, dynamic>> allTxn, DateTime start, DateTime end) async {
    _showSnack('جاري تجهيز كشف الحساب... ⏳');
    final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59); 
    final startInclusive = DateTime(start.year, start.month, start.day, 0, 0, 0);

    final filtered = allTxn.where((t) {
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
                    pw.Text('كشف حساب محفظة رقمية', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('نظام كروت نت', style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              pw.Text('اسم الوكيل: ${sys.currentUserName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('رقم الحساب: ${sys.currentUserPhone}'),
              pw.Text('الفترة: ${DateFormat('yyyy-MM-dd').format(start)} إلى ${DateFormat('yyyy-MM-dd').format(end)}', style: const pw.TextStyle(color: PdfColors.grey700)),
              pw.SizedBox(height: 20),
              
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(font: arabicBold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: pw.TextStyle(font: arabicFont),
                cellAlignment: pw.Alignment.center,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                data: <List<String>>[
                  <String>['التاريخ', 'البيان', 'النوع', 'المبلغ'], 
                  ...filtered.map((item) {
                    DateTime date = (item['timestamp'] as Timestamp).toDate();
                    bool isPlus = item['type'] == 'income' || item['type'] == 'deposit';
                    return [
                      DateFormat('yyyy-MM-dd HH:mm').format(date),
                      item['title'] ?? 'عملية',
                      isPlus ? 'إيداع (+)' : 'خصم (-)',
                      '${item['amount']} ريال'
                    ];
                  })
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Statement_${sys.currentUserPhone}.pdf');
    _play('success');
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // فلترة العمليات الخاصة بالوكيل مع أنواع جديدة
    final List<Map<String, dynamic>> realTransactions = sys.transactionsLedger.where((t) {
      if (t['agentPhone'] != sys.currentUserPhone && t['fromPhone'] != sys.currentUserPhone && t['toPhone'] != sys.currentUserPhone) return false;
      
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'إيداعات وأرباح' && (t['type'] == 'income' || t['type'] == 'deposit')) return true;
      if (_selectedFilter == 'مسحوبات ومصروفات' && (t['type'] == 'expense' || t['type'] == 'purchase')) return true;
      if (_selectedFilter == 'حوالات صادرة' && t['type'] == 'transfer' && t['fromPhone'] == sys.currentUserPhone) return true;
      if (_selectedFilter == 'حوالات واردة' && t['type'] == 'transfer' && t['toPhone'] == sys.currentUserPhone) return true;
      return false;
    }).toList();

    // حساب إحصائيات الدخل والمصروفات للشريط الذكي
    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in realTransactions) {
      double amt = double.tryParse(t['amount'].toString()) ?? 0;
      if (t['type'] == 'income' || t['type'] == 'deposit' || (t['type'] == 'transfer' && t['toPhone'] == sys.currentUserPhone)) {
        totalIncome += amt;
      } else {
        totalExpense += amt;
      }
    }
    double totalVolume = totalIncome + totalExpense;
    int incomeFlex = totalVolume == 0 ? 50 : ((totalIncome / totalVolume) * 100).toInt();
    int expenseFlex = totalVolume == 0 ? 50 : 100 - incomeFlex;

    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = themeProvider.adaptiveTextColor;

    return Scaffold(
      appBar: const CustomHeader(title: 'المحفظة المالية'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد',
        currentBalance: sys.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // ترويسة الرصيد (تتفاعل مع الوضع الليلي والنهاري)
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 25, left: 25, right: 25, bottom: 25),
              decoration: BoxDecoration(
                color: cardColor, 
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: Column(
                children: [
                  Text('رصيدك المتاح', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isBalanceHidden ? '******' : '${sys.currentUserBalance.toStringAsFixed(2)} ريال', style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: textColor.withOpacity(0.6)),
                        onPressed: () { _play('click'); setState(() => _isBalanceHidden = !_isBalanceHidden); }, 
                      )
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  // شريط الإحصائيات 
                  Row(
                    children: [
                      const Icon(Icons.arrow_upward, color: Colors.green, size: 14),
                      Text(' إيداع: ${totalIncome.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('سحب: ${totalExpense.toStringAsFixed(0)} ', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                      const Icon(Icons.arrow_downward, color: Colors.red, size: 14),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        Expanded(flex: incomeFlex > 0 ? incomeFlex : 1, child: Container(height: 6, color: Colors.green)),
                        Expanded(flex: expenseFlex > 0 ? expenseFlex : 1, child: Container(height: 6, color: Colors.red)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ==========================================
                  // مراقب الطلبات المعلقة ⏳ (يخفي زر الطلب إذا وجد)
                  // ==========================================
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('recharge_requests')
                        .where('agentPhone', isEqualTo: sys.currentUserPhone)
                        .where('status', isEqualTo: 'قيد الانتظار')
                        .snapshots(),
                    builder: (context, snapshot) {
                      bool hasPendingRequest = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                      return Column(
                        children: [
                          if (hasPendingRequest) ...[
                            // عرض بطاقة الطلب المعلق مع زر الإلغاء فقط
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('طلب شحن بقيمة: ${snapshot.data!.docs.first['amount']} ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                        const Text('الطلب قيد المراجعة ⏳', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _confirmDeleteRequest(snapshot.data!.docs.first.id),
                                    icon: const Icon(Icons.cancel, color: Colors.white, size: 16),
                                    label: const Text('إلغاء الطلب', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10)),
                                  )
                                ],
                              ),
                            ),
                          ] else ...[
                            // إظهار زر "طلب رصيد" فقط إذا لم يكن هناك طلب معلق
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildQuickBtn(Icons.add_to_photos, 'طلب رصيد', Colors.green, _showRequestBalanceDialog),
                                _buildQuickBtn(Icons.swap_horiz, 'تحويل رصيد', Colors.orange, _showTransferToAnyUserDialog),
                                _buildQuickBtn(Icons.picture_as_pdf, 'كشف حساب', Colors.blue, () => _showPdfStatementDialog(sys, realTransactions)),
                              ],
                            ),
                          ]
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // ==========================================
            // الفلتر والسجل (مع التمرير السليم)
            // ==========================================
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('السجل المالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  _buildFilterDropdown(),
                ],
              ),
            ),

            Expanded(
              child: realTransactions.isEmpty
                  ? const Center(child: Text('لا توجد عمليات مسجلة حالياً'))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: realTransactions.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemBuilder: (context, index) {
                        final txn = realTransactions[index];
                        bool isPlus = (txn['type'] == 'income' || txn['type'] == 'deposit' || (txn['type'] == 'transfer' && txn['toPhone'] == sys.currentUserPhone));
                        
                        return Card(
                          color: cardColor,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPlus ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              child: Icon(isPlus ? Icons.arrow_downward : Icons.arrow_upward, color: isPlus ? Colors.green : Colors.red),
                            ),
                            title: Text(txn['title'] ?? 'عملية مالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                            subtitle: Text(txn['timestamp'] != null ? DateFormat('yyyy-MM-dd hh:mm a').format((txn['timestamp'] as Timestamp).toDate()) : 'الآن', style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6))),
                            trailing: Text('${isPlus ? '+' : '-'}${txn['amount']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isPlus ? Colors.green : Colors.red), textDirection: TextDirection.ltr),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickBtn(IconData icon, String label, Color iconColor, VoidCallback onTap) {
    final textColor = Provider.of<ThemeProvider>(context).adaptiveTextColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          CircleAvatar(backgroundColor: iconColor.withOpacity(0.15), radius: 25, child: Icon(icon, color: iconColor)),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButton<String>(
        value: _selectedFilter,
        dropdownColor: Theme.of(context).cardColor,
        underline: const SizedBox(),
        items: ['الكل', 'إيداعات وأرباح', 'مسحوبات ومصروفات', 'حوالات صادرة', 'حوالات واردة'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: TextStyle(fontSize: 12, color: Provider.of<ThemeProvider>(context).adaptiveTextColor)))).toList(),
        onChanged: (v) { _play('click'); setState(() => _selectedFilter = v!); },
      ),
    );
  }
}
