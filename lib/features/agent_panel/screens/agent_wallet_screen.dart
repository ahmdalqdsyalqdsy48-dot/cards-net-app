import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart'; // 👈 ضروري للون الواجهة
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentWalletScreen extends StatefulWidget {
  const AgentWalletScreen({super.key});

  @override
  State<AgentWalletScreen> createState() => _AgentWalletScreenState();
}

class _AgentWalletScreenState extends State<AgentWalletScreen> {
  String _selectedFilter = 'الكل';
  bool _isBalanceHidden = false; // 👈 4. متغير إخفاء الرصيد
  bool _isUploadingReceipt = false;

  void _showSnack(String m, {bool isErr = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m, textDirection: TextDirection.rtl), backgroundColor: isErr ? Colors.red : Colors.green)
    );
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // 3. رفع صورة السند 📸
  // ==========================================
  Future<void> _uploadReceiptImage(String docId) async {
    _play('click');
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;

    setState(() => _isUploadingReceipt = true);
    _showSnack('جاري رفع السند... ⏳');

    try {
      final Uint8List bytes = await pickedFile.readAsBytes();
      String fileName = 'receipts/req_${docId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('recharge_requests').doc(docId).update({
        'hasReceipt': true,
        'receiptUrl': downloadUrl,
      });

      _play('success');
      _showSnack('تم إرفاق السند بنجاح ✅');
    } catch (e) {
      _play('error');
      _showSnack('فشل رفع السند: $e', isErr: true);
    } finally {
      setState(() => _isUploadingReceipt = false);
    }
  }

  // ==========================================
  // نافذة طلب رصيد 
  // ==========================================
  void _showRequestBalanceDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final activeBanks = sys.bankAccounts.where((bank) => bank['status'] == 'نشط').toList();
    
    String? selectedBank;
    if (activeBanks.isNotEmpty) selectedBank = activeBanks.first['bankName']; 

    final amountController = TextEditingController();
    final refController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
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

                if (amount > 0 && refController.text.isNotEmpty && selectedBank != null) {
                  if (sys.isCurrencyAutoRounding) amount = amount.ceilToDouble();

                  await FirebaseFirestore.instance.collection('recharge_requests').add({
                    'agentPhone': sys.currentUserPhone,
                    'agentName': sys.currentUserName,
                    'amount': amount,
                    'bankName': selectedBank,
                    'reference': refController.text,
                    'status': 'قيد الانتظار',
                    'hasReceipt': false,
                    'receiptUrl': null,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context); _play('success'); _showSnack('تم إرسال الطلب! قم بإرفاق السند من القائمة.');
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
    );
  }

  // ==========================================
  // 5. تحويل رصيد لأي مستخدم 🌍
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
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isSearching = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('تحويل رصيد (مؤمن) 🛡️', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('يمكنك التحويل لأي مستخدم داخل النظام بكتابة رقم هاتفه.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    const SizedBox(height: 15),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'رقم هاتف المستلم', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder()),
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
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: isSearching ? null : () async {
                    String targetPhone = phoneController.text.trim();
                    double amount = double.tryParse(amountController.text) ?? 0;
                    
                    if (passwordController.text != myPassword) {
                      _play('error'); _showSnack('كلمة المرور غير صحيحة! ❌', isErr: true); return;
                    }
                    if (targetPhone == sys.currentUserPhone) {
                      _play('error'); _showSnack('لا يمكنك التحويل لنفسك!', isErr: true); return;
                    }
                    if (amount <= 0 || amount > sys.currentUserBalance) {
                      _play('error'); _showSnack('المبلغ غير متاح أو غير صحيح!', isErr: true); return;
                    }

                    setStateDialog(() => isSearching = true);
                    try {
                      // البحث عن المستخدم في النظام
                      var userSnap = await FirebaseFirestore.instance.collection('users').doc(targetPhone).get();
                      
                      if (!userSnap.exists) {
                        setStateDialog(() => isSearching = false);
                        _play('error'); _showSnack('رقم الهاتف غير مسجل في النظام!', isErr: true); return;
                      }

                      String targetName = userSnap.data()?['name'] ?? 'مستخدم';

                      // تنفيذ التحويل
                      WriteBatch batch = FirebaseFirestore.instance.batch();
                      batch.update(FirebaseFirestore.instance.collection('users').doc(sys.currentUserPhone), {'balance': FieldValue.increment(-amount)});
                      batch.update(FirebaseFirestore.instance.collection('users').doc(targetPhone), {'balance': FieldValue.increment(amount)});
                      
                      batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
                        'fromPhone': sys.currentUserPhone, 'toPhone': targetPhone,
                        'agentName': sys.currentUserName, 'targetName': targetName,
                        'amount': amount, 'type': 'transfer', 'title': 'تحويل رصيد صادر إلى $targetName', 'timestamp': FieldValue.serverTimestamp()
                      });

                      await batch.commit();
                      if (mounted) {
                        Navigator.pop(context); _play('success'); _showSnack('تم التحويل إلى $targetName بنجاح! 🎉');
                      }
                    } catch (e) {
                      setStateDialog(() => isSearching = false);
                      _play('error'); _showSnack('حدث خطأ: $e', isErr: true);
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
  // 6. تأكيد حذف الطلب ⚠️
  // ==========================================
  void _confirmDeleteRequest(String docId) {
    _play('click');
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الطلب ⚠️', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد أنك تريد إلغاء طلب الشحن المعلق؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('recharge_requests').doc(docId).delete();
                if (mounted) {
                  Navigator.pop(context);
                  _play('success');
                  _showSnack('تم إلغاء الطلب بنجاح.');
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
  // 9 & 10. كشف حساب الوكيل (PDF) الاحترافي 📄
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
    final themeProvider = Provider.of<ThemeProvider>(context); // 👈 7. استدعاء الثيم
    final isDark = themeProvider.isDarkMode;

    // 8. فلترة العمليات الخاصة بالوكيل مع أنواع جديدة
    final List<Map<String, dynamic>> realTransactions = sys.transactionsLedger.where((t) {
      if (t['agentPhone'] != sys.currentUserPhone && t['fromPhone'] != sys.currentUserPhone && t['toPhone'] != sys.currentUserPhone) return false;
      
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'إيداعات وأرباح' && (t['type'] == 'income' || t['type'] == 'deposit')) return true;
      if (_selectedFilter == 'مسحوبات ومصروفات' && (t['type'] == 'expense' || t['type'] == 'purchase')) return true;
      if (_selectedFilter == 'حوالات صادرة' && t['type'] == 'transfer' && t['fromPhone'] == sys.currentUserPhone) return true;
      if (_selectedFilter == 'حوالات واردة' && t['type'] == 'transfer' && t['toPhone'] == sys.currentUserPhone) return true;
      return false;
    }).toList();

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
        // 👈 2. جعل الشاشة بالكامل قابلة للتمرير
        child: SingleChildScrollView( 
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ==========================================
              // ترويسة الرصيد (لون يتفاعل مع الثيم) 🎨
              // ==========================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 25, left: 25, right: 25, bottom: 25),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : themeProvider.primaryColor, // 👈 7. لون متكيف
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
                ),
                child: Column(
                  children: [
                    const Text('رصيدك المتاح', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isBalanceHidden ? '******' : '${sys.currentUserBalance.toStringAsFixed(2)} ريال', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                          onPressed: () { _play('click'); setState(() => _isBalanceHidden = !_isBalanceHidden); }, // 👈 4. إخفاء الرصيد
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickBtn(Icons.add_to_photos, 'طلب رصيد', _showRequestBalanceDialog),
                        _buildQuickBtn(Icons.swap_horiz, 'تحويل رصيد', _showTransferToAnyUserDialog),
                        _buildQuickBtn(Icons.picture_as_pdf, 'كشف حساب', () => _showPdfStatementDialog(sys, realTransactions)),
                      ],
                    )
                  ],
                ),
              ),
              
              // ==========================================
              // متتبع الطلبات المعلقة ⏳
              // ==========================================
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('recharge_requests')
                    .where('agentPhone', isEqualTo: sys.currentUserPhone)
                    .where('status', isEqualTo: 'قيد الانتظار')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                  
                  return Container(
                    color: Colors.orange.shade50,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: snapshot.data!.docs.map((doc) {
                        var req = doc.data() as Map<String, dynamic>;
                        bool hasReceipt = req['hasReceipt'] ?? false;

                        return ListTile(
                          leading: const CircularProgressIndicator(color: Colors.orange),
                          title: Text('طلب شحن: ${req['amount']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(hasReceipt ? 'السند مرفق - قيد المراجعة' : 'يرجى إرفاق صورة السند 📸', style: TextStyle(color: hasReceipt ? Colors.green : Colors.orange, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!hasReceipt)
                                IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Colors.teal),
                                  onPressed: () => _uploadReceiptImage(doc.id), // 👈 3. رفع السند
                                ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _confirmDeleteRequest(doc.id), // 👈 6. تأكيد الحذف
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),

              // ==========================================
              // الفلتر والسجل
              // ==========================================
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('السجل المالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    _buildFilterDropdown(isDark),
                  ],
                ),
              ),

              realTransactions.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد عمليات مسجلة حالياً'))
                  : ListView.builder(
                      shrinkWrap: true, // 👈 2. السماح بالتمرير كجزء من الشاشة الكلية
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: realTransactions.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final txn = realTransactions[index];
                        // تحديد نوع العملية
                        bool isPlus = (txn['type'] == 'income' || txn['type'] == 'deposit' || (txn['type'] == 'transfer' && txn['toPhone'] == sys.currentUserPhone));
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPlus ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              child: Icon(isPlus ? Icons.arrow_downward : Icons.arrow_upward, color: isPlus ? Colors.green : Colors.red),
                            ),
                            title: Text(txn['title'] ?? 'عملية مالية', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(txn['timestamp'] != null ? DateFormat('yyyy-MM-dd hh:mm a').format((txn['timestamp'] as Timestamp).toDate()) : 'الآن', style: const TextStyle(fontSize: 12)),
                            trailing: Text('${isPlus ? '+' : '-'}${txn['amount']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isPlus ? Colors.green : Colors.red), textDirection: TextDirection.ltr),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          CircleAvatar(backgroundColor: Colors.white24, radius: 25, child: Icon(icon, color: Colors.white)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButton<String>(
        value: _selectedFilter,
        underline: const SizedBox(),
        items: ['الكل', 'إيداعات وأرباح', 'مسحوبات ومصروفات', 'حوالات صادرة', 'حوالات واردة'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (v) { _play('click'); setState(() => _selectedFilter = v!); },
      ),
    );
  }
}
