import 'dart:convert'; 
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart'; // 👈 ضروري للمشاركة (إكسل وإيصالات)
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
  String _selectedDateFilter = 'الكل'; // 👈 فلتر زمني جديد
  bool _isBalanceHidden = false; 

  // إعدادات الـ VIP (المحولة من الشاشة السابقة)
  double _vipThreshold = 50000.0;
  String _autoVipCommission = '5%';

  @override
  void initState() {
    super.initState();
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
  // 1. نافذة طلب رصيد (مع تأكيد) 📸
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
                    // 👈 نافذة تأكيد قبل الإرسال
                    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
                      title: const Text('تأكيد الطلب ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text('هل أنت متأكد من إرسال طلب تغذية بقيمة $amount ريال؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () async {
                            Navigator.pop(ctx); // إغلاق التأكيد
                            if (sys.isCurrencyAutoRounding) amount = amount.ceilToDouble();
                            await _db.collection('recharge_requests').add({
                              'agentPhone': sys.currentUserPhone, 'agentName': sys.currentUserName,
                              'amount': amount, 'bankName': selectedBank, 'reference': refController.text,
                              'status': 'قيد الانتظار', 'hasReceipt': true, 'receiptBase64': base64Image, 'timestamp': FieldValue.serverTimestamp(),
                            });
                            if (mounted) { Navigator.pop(context); _play('success'); _showSnack('تم إرسال الطلب للمراجعة ⏳'); }
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
  // 2. تحويل رصيد بأمان (مع تأكيد نهائي) 🛡️
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
      context: context, barrierDismissible: false,
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
                      TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم المستلم', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
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
                      TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.send), border: OutlineInputBorder())),
                      const SizedBox(height: 15),
                      TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور (للتأكيد)', prefixIcon: Icon(Icons.lock, color: Colors.red), border: OutlineInputBorder())),
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
                        var userSnap = await _db.collection('users').doc(targetPhone).get();
                        if (userSnap.exists) {
                          _play('success');
                          setStateDialog(() { targetName = userSnap.data()?['name'] ?? 'مستخدم'; targetPhoneStr = targetPhone; isUserFound = true; isSearching = false; });
                        } else {
                          setStateDialog(() => isSearching = false); _play('error'); _showSnack('لم يتم العثور على مستخدم بهذا الرقم!', isErr: true);
                        }
                      } catch (e) {
                        setStateDialog(() => isSearching = false); _play('error'); _showSnack('حدث خطأ في الاتصال', isErr: true);
                      }
                    },
                    child: isSearching ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تحقق من الرقم', style: TextStyle(color: Colors.white)),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: isSearching ? null : () async {
                      double amount = double.tryParse(amountController.text) ?? 0;
                      if (passwordController.text != myPassword) { _play('error'); _showSnack('كلمة المرور غير صحيحة! ❌', isErr: true); return; }
                      if (amount <= 0 || amount > sys.currentUserBalance) { _play('error'); _showSnack('المبلغ غير متاح في رصيدك!', isErr: true); return; }

                      _play('warning');
                      // 👈 تأكيد نهائي للتحويل
                      showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
                        title: const Text('تأكيد التحويل ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: Text('هل أنت متأكد من تحويل $amount ريال إلى $targetName؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              setStateDialog(() => isSearching = true);
                              try {
                                WriteBatch batch = _db.batch();
                                batch.update(_db.collection('users').doc(sys.currentUserPhone), {'balance': FieldValue.increment(-amount)});
                                batch.set(_db.collection('users').doc(targetPhoneStr), {'balance': FieldValue.increment(amount)}, SetOptions(merge: true));
                                batch.set(_db.collection('transactions').doc(), {
                                  'fromPhone': sys.currentUserPhone, 'toPhone': targetPhoneStr,
                                  'agentName': sys.currentUserName, 'targetName': targetName,
                                  'amount': amount, 'type': 'transfer', 'title': 'تحويل رصيد صادر إلى $targetName', 'timestamp': FieldValue.serverTimestamp()
                                });
                                await batch.commit();
                                if (mounted) { Navigator.pop(context); _play('success'); _showSnack('تم التحويل بنجاح! 🎉'); }
                              } catch (e) {
                                setStateDialog(() => isSearching = false); _play('error'); _showSnack('حدث خطأ أثناء التحويل', isErr: true);
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
                  if (startDate == null || endDate == null) { _play('error'); _showSnack('يرجى تحديد فترة الكشف!', isErr: true); return; }
                  _play('click'); Navigator.pop(context);
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
    _showSnack('جاري تجهيز كشف الحساب (PDF)... ⏳');
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

    pdf.addPage(pw.Page(
      textDirection: pw.TextDirection.rtl, 
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(15), color: PdfColors.teal700,
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
                  bool isPlus = item['type'] == 'income' || item['type'] == 'deposit' || (item['type'] == 'transfer' && item['toPhone'] == sys.currentUserPhone);
                  return [DateFormat('yyyy-MM-dd HH:mm').format(date), item['title'] ?? 'عملية', isPlus ? 'إيداع (+)' : 'خصم (-)', '${item['amount']} ريال'];
                })
              ],
            ),
          ],
        );
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
    _showSnack('جاري تصدير السجل إلى Excel... ⏳');
    
    // إضافة BOM لكي يقرأ الإكسل اللغة العربية بشكل صحيح
    String csv = '\uFEFF'; 
    csv += 'التاريخ,البيان,النوع,المبلغ (ريال)\n';
    
    for(var t in txns) {
      if (t['timestamp'] == null) continue;
      DateTime d = (t['timestamp'] as Timestamp).toDate();
      String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(d);
      bool isPlus = t['type'] == 'income' || t['type'] == 'deposit' || (t['type'] == 'transfer' && t['toPhone'] == sys.currentUserPhone);
      String typeStr = isPlus ? 'إيداع (+)' : 'خصم (-)';
      csv += '$dateStr,${t['title'] ?? 'عملية'},$typeStr,${t['amount']}\n';
    }
    
    Uint8List bytes = Uint8List.fromList(utf8.encode(csv));
    await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'text/csv', name: 'Wallet_Ledger_${sys.currentUserPhone}.csv')], text: 'مرفق كشف حساب المحفظة');
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Center(child: Text('إيصال عملية 🧾', style: TextStyle(fontWeight: FontWeight.bold))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(txn['title'] ?? 'عملية مالية', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const Divider(),
              ListTile(title: const Text('المبلغ', style: TextStyle(fontSize: 12, color: Colors.grey)), trailing: Text('${txn['amount']} ريال', style: TextStyle(color: isPlus ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 18))),
              ListTile(title: const Text('التاريخ', style: TextStyle(fontSize: 12, color: Colors.grey)), trailing: Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
              ListTile(title: const Text('نوع العملية', style: TextStyle(fontSize: 12, color: Colors.grey)), trailing: Text(isPlus ? 'إيداع (+)' : 'خصم (-)', style: const TextStyle(fontWeight: FontWeight.bold))),
              if (txn['reference'] != null)
                ListTile(title: const Text('المرجع', style: TextStyle(fontSize: 12, color: Colors.grey)), trailing: Text(txn['reference'], style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('إغلاق', style: TextStyle(color: Colors.grey))),
            ElevatedButton.icon(
               icon: const Icon(Icons.share, color: Colors.white, size: 18),
               label: const Text('مشاركة الإيصال', style: TextStyle(color: Colors.white)),
               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
               onPressed: () {
                  _play('click');
                  Share.share('🧾 *إيصال عملية رقمية*\n\nالبيان: ${txn['title']}\nالمبلغ: ${txn['amount']} ريال\nالتاريخ: $dateStr\nنوع العملية: ${isPlus ? "إيداع" : "خصم"}\n\nنظام كروت نت');
               }
            )
          ]
        )
      )
    );
  }

  // ==========================================
  // وظائف الموافقة والرفض لطلبات الشحن (مع تأكيدات)
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
              _play('error'); _showSnack('حدث خطأ أثناء الموافقة', isErr: true);
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


  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = themeProvider.adaptiveTextColor;

    // فلترة العمليات الخاصة بالوكيل
    final List<Map<String, dynamic>> realTransactions = sys.transactionsLedger.where((t) {
      if (t['agentPhone'] != sys.currentUserPhone && t['fromPhone'] != sys.currentUserPhone && t['toPhone'] != sys.currentUserPhone) return false;
      
      // الفلترة بالنوع
      bool typeMatch = false;
      if (_selectedFilter == 'الكل') typeMatch = true;
      else if (_selectedFilter == 'إيداعات وأرباح' && (t['type'] == 'income' || t['type'] == 'deposit')) typeMatch = true;
      else if (_selectedFilter == 'مسحوبات ومصروفات' && (t['type'] == 'expense' || t['type'] == 'purchase' || t['type'] == 'sale')) typeMatch = true;
      else if (_selectedFilter == 'حوالات صادرة' && t['type'] == 'transfer' && t['fromPhone'] == sys.currentUserPhone) typeMatch = true;
      else if (_selectedFilter == 'حوالات واردة' && t['type'] == 'transfer' && t['toPhone'] == sys.currentUserPhone) typeMatch = true;
      
      if (!typeMatch) return false;

      // الفلترة بالزمن
      if (_selectedDateFilter == 'الكل') return true;
      if (t['timestamp'] == null) return false;
      DateTime d = (t['timestamp'] as Timestamp).toDate();
      DateTime now = DateTime.now();
      
      if (_selectedDateFilter == 'اليوم') return d.year == now.year && d.month == now.month && d.day == now.day;
      if (_selectedDateFilter == 'هذا الأسبوع') return now.difference(d).inDays <= 7;
      if (_selectedDateFilter == 'هذا الشهر') return d.year == now.year && d.month == now.month;

      return true;
    }).toList();

    // حساب إحصائيات الدخل والمصروفات
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
    double netFlow = totalIncome - totalExpense;
    
    double totalVolume = totalIncome + totalExpense;
    int incomeFlex = totalVolume == 0 ? 50 : ((totalIncome / totalVolume) * 100).toInt();
    int expenseFlex = totalVolume == 0 ? 50 : 100 - incomeFlex;

    return Scaffold(
      appBar: const CustomHeader(title: 'المحفظة والمالية'),
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
            // ترويسة الرصيد + التبويبات (بدون إخفاء الأزرار)
            // ==========================================
            Container(
              width: double.infinity,
              color: isDark ? Colors.grey.shade900 : Colors.teal.shade800,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('رصيد المحفظة المتاح', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Row(
                              children: [
                                Text(_isBalanceHidden ? '******' : '${sys.currentUserBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 5),
                                const Text('ريال', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                IconButton(icon: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 20), onPressed: () { _play('click'); setState(() => _isBalanceHidden = !_isBalanceHidden); }),
                              ],
                            ),
                          ],
                        ),
                        // صندوق صافي التدفق
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            children: [
                              const Text('صافي التدفق', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              Text('${netFlow >= 0 ? "+" : ""}${netFlow.toStringAsFixed(0)}', style: TextStyle(color: netFlow >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14), textDirection: TextDirection.ltr),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  
                  // نظام التبويبات مع Badge للطلبات
                  StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('user_recharges').where('targetPhone', isEqualTo: sys.currentUserPhone).where('status', isEqualTo: 'قيد الانتظار').snapshots(),
                    builder: (context, snapshot) {
                      int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

                      return TabBar(
                        controller: _tabController,
                        labelColor: Colors.white, 
                        unselectedLabelColor: Colors.white60, 
                        indicatorColor: Colors.orange, indicatorWeight: 4,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
                        tabs: [
                          const Tab(text: 'السجل والتحويل'),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('الطلبات'),
                                if (pendingCount > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                ]
                              ],
                            )
                          ),
                          const Tab(text: 'إعدادات VIP 🌟'),
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWalletAndLedgerTab(sys, realTransactions, totalIncome, totalExpense, incomeFlex, expenseFlex, isDark, cardColor, textColor),
                  _buildRequestsTab(sys),
                  _buildVipSettingsTab(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // التبويب الأول: المحفظة والسجل (Ledger)
  // ==========================================
  Widget _buildWalletAndLedgerTab(SystemProvider sys, List<Map<String, dynamic>> realTransactions, double totalIncome, double totalExpense, int incomeFlex, int expenseFlex, bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        // الأزرار السريعة الدائمة
        Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          color: isDark ? Colors.grey.shade800 : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickBtn(Icons.add_to_photos, 'طلب رصيد', Colors.green, _showRequestBalanceDialog),
              _buildQuickBtn(Icons.swap_horiz, 'تحويل سريع', Colors.orange, _showTransferToAnyUserDialog),
              _buildQuickBtn(Icons.picture_as_pdf, 'تصدير PDF', Colors.blue, () => _showPdfStatementDialog(sys, realTransactions)),
              _buildQuickBtn(Icons.table_chart, 'إكسل CSV', Colors.teal, () => _exportCSV(realTransactions, sys)),
            ],
          ),
        ),
        
        // شريط الإحصائيات البصري
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
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
            ],
          ),
        ),

        // الفلاتر
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('السجل المالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  _buildFilterDropdown(
                    value: _selectedDateFilter,
                    items: ['الكل', 'اليوم', 'هذا الأسبوع', 'هذا الشهر'],
                    onChanged: (v) { _play('click'); setState(() => _selectedDateFilter = v!); }
                  ),
                  const SizedBox(width: 5),
                  _buildFilterDropdown(
                    value: _selectedFilter,
                    items: ['الكل', 'إيداعات وأرباح', 'مسحوبات ومصروفات', 'حوالات صادرة', 'حوالات واردة'],
                    onChanged: (v) { _play('click'); setState(() => _selectedFilter = v!); }
                  ),
                ],
              ),
            ],
          ),
        ),

        // السجل المالي (Ledger)
        Expanded(
          child: realTransactions.isEmpty
              ? const Center(child: Text('لا توجد عمليات مسجلة تطابق الفلتر', style: TextStyle(color: Colors.grey)))
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
                        onTap: () => _showTransactionReceipt(txn, sys), // 👈 إظهار الإيصال
                        leading: CircleAvatar(
                          backgroundColor: isPlus ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          child: Icon(isPlus ? Icons.arrow_downward : Icons.arrow_upward, color: isPlus ? Colors.green : Colors.red),
                        ),
                        title: Text(txn['title'] ?? 'عملية مالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                        subtitle: Text(txn['timestamp'] != null ? DateFormat('yyyy-MM-dd hh:mm a').format((txn['timestamp'] as Timestamp).toDate()) : 'الآن', style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.6))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${isPlus ? '+' : '-'}${txn['amount']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isPlus ? Colors.green : Colors.red), textDirection: TextDirection.ltr),
                            const SizedBox(width: 5),
                            Icon(Icons.receipt_long, color: Colors.grey.shade400, size: 16), // دليل أن العنصر قابل للنقر
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

  // ==========================================
  // التبويب الثاني: طلبات الشحن
  // ==========================================
  Widget _buildRequestsTab(SystemProvider sys) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('user_recharges').where('targetPhone', isEqualTo: sys.currentUserPhone).where('status', isEqualTo: 'قيد الانتظار').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        var requests = snapshot.data!.docs;
        
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text('لا توجد طلبات شحن معلقة حالياً.', style: TextStyle(color: Colors.grey)),
              ],
            )
          );
        }

        return Column(
          children: [
            // زر الموافقة الجماعية
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.green.withOpacity(0.1),
              child: ElevatedButton.icon(
                onPressed: () => _confirmBulkApprove(requests, sys),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text('الموافقة على جميع الطلبات (${requests.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12), 
                itemCount: requests.length,
                itemBuilder: (context, i) {
                  var req = requests[i].data() as Map<String, dynamic>;
                  String reqId = requests[i].id;
                  double reqAmount = (req['amount'] ?? 0).toDouble();
                  bool isVip = reqAmount >= _vipThreshold; 

                  return Card(
                    color: isVip ? Colors.amber.shade50 : Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isVip ? Colors.amber : Colors.blue.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${req['userName']} ${isVip ? "🌟" : ""}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(isVip ? 'يستحق الترقية لبقالة!' : 'طلب عادي', style: TextStyle(color: isVip ? Colors.orange : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('رقم: ${req['userPhone']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('المبلغ: $reqAmount ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isVip ? Colors.amber.shade800 : Colors.blue)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            children: [
                              Expanded(child: OutlinedButton(onPressed: () => _confirmRejectRequest(reqId), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('رفض ❌'))),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: ElevatedButton(
                                onPressed: () => _confirmApproveRequest(reqId, req['userPhone'], reqAmount, isVip, sys, req['userName']),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('موافقة ✅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              )),
                            ],
                          )
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
    );
  }

  // ==========================================
  // التبويب الثالث: إعدادات VIP
  // ==========================================
  Widget _buildVipSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange)),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.orange, size: 40),
                const SizedBox(width: 15),
                const Expanded(child: Text('نظام الترقية التلقائية: إذا طلب زبون شحناً بالمبلغ المستهدف، سيتم تحويله إلى بقالة تابعة لك مع نسبة عمولة ثابتة.', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text('المبلغ المستهدف (ريال):', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_vipThreshold ريال', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: _showVipSettingsDialog),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('نسبة العمولة التلقائية للبقالة:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_autoVipCommission, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple)),
                IconButton(icon: const Icon(Icons.edit, color: Colors.purple), onPressed: _showVipSettingsDialog),
              ],
            ),
          ),
        ],
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
