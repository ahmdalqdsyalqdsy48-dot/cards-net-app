import 'dart:convert'; 
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  @override
  void initState() {
    super.initState();
    // تم التعديل إلى تبويبين فقط كما تم الاتفاق
    _tabController = TabController(length: 2, vsync: this);
  }

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

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // 1. نافذة طلب رصيد (مكتملة ومستقرة)
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
                              _play('success');
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
                            _showSnack('جاري إرسال الطلب للمركز الرئيسي... ⏳');
                            
                            try {
                              if (sys.isCurrencyAutoRounding) amount = amount.ceilToDouble();
                              await _db.collection('recharge_requests').add({
                                'agentPhone': sys.currentUserPhone, 'agentName': sys.currentUserName,
                                'amount': amount, 'bankName': selectedBank, 'reference': refController.text,
                                'status': 'قيد الانتظار', 'hasReceipt': true, 'receiptBase64': base64Image, 'timestamp': FieldValue.serverTimestamp(),
                              });
                              if (mounted) { _play('success'); _showSnack('تم إرسال الطلب للمراجعة بنجاح ✅'); }
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
  // 2. نافذة التحويل المتقدمة (تظهر كل الحقول مرة واحدة) 🔥
  // ==========================================
  void _showAdvancedTransferDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final taxController = TextEditingController();
    final noteController = TextEditingController();
    final passwordController = TextEditingController();

    bool isSearching = false;
    Map<String, dynamic>? targetData; 
    String selectedPaymentMethod = 'نقدي'; 
    
    double currentAmount = 0;
    double currentTax = 0;
    double taxValue = 0;
    double totalCost = 0;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {

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
              title: const Row(
                children: [
                  Icon(Icons.send_to_mobile, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('تحويل رصيد (متقدم)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- القسم الأول: البحث وجلب البيانات ---
                    const Text('رقم هاتف المستلم:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneController, 
                            keyboardType: TextInputType.phone, 
                            decoration: const InputDecoration(
                              hintText: 'أدخل الرقم للبحث...', 
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            )
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))
                          ),
                          onPressed: isSearching ? null : () async {
                            String targetPhone = phoneController.text.trim();
                            if (targetPhone.isEmpty || targetPhone == sys.currentUserPhone) { 
                              _play('error'); _showSnack('رقم غير صالح أو لا يمكنك التحويل لنفسك!', isErr: true); return; 
                            }
                            setStateDialog(() { isSearching = true; targetData = null; });
                            
                            try {
                              var data = await sys.searchUserForTransfer(targetPhone);
                              if (data != null) {
                                _play('success');
                                setStateDialog(() { targetData = data; isSearching = false; });
                              } else {
                                setStateDialog(() { isSearching = false; }); 
                                _play('error'); _showSnack('الرقم غير موجود في النظام!', isErr: true);
                              }
                            } catch (e) {
                              setStateDialog(() { isSearching = false; }); 
                              _play('error'); _showSnack('فشل البحث: قد تحتاج لإنشاء فهرس (Index) في الفايربيز', isErr: true);
                            }
                          },
                          child: isSearching 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : const Icon(Icons.search, color: Colors.white),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),

                    // --- لوحة عرض بيانات المستلم (تظهر فقط عند نجاح البحث) ---
                    if (targetData != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05), 
                          borderRadius: BorderRadius.circular(8), 
                          border: Border.all(color: Colors.blue.withOpacity(0.3))
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('بيانات المستلم:', style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                            const Divider(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الاسم:', style: TextStyle(fontSize: 11, color: Colors.grey)), Text(targetData?['name'] ?? 'مجهول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue))]),
                            const SizedBox(height: 4),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الدور:', style: TextStyle(fontSize: 11, color: Colors.grey)), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text((targetData?['role'] == 'pos') ? 'نقطة بيع' : (targetData?['role'] == 'agent') ? 'وكيل' : 'مستخدم', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)))]),
                            const SizedBox(height: 4),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الرصيد لديك:', style: TextStyle(fontSize: 11, color: Colors.grey)), Text('${targetData?['balance']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green))]),
                            const SizedBox(height: 4),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('آخر شحن:', style: TextStyle(fontSize: 11, color: Colors.grey)), Text(targetData?['lastRecharge'] ?? 'لا يوجد', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]),
                          ],
                        ),
                      ),

                    // --- القسم الثاني: حقول المعاملة (تظهر دائماً) ---
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: amountController, keyboardType: TextInputType.number, 
                            onChanged: (v) => setStateDialog((){ calculateLive(); }),
                            decoration: const InputDecoration(labelText: 'الكمية (نقاط/مبلغ)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))
                          )
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: taxController, keyboardType: TextInputType.number, 
                            onChanged: (v) => setStateDialog((){ calculateLive(); }),
                            decoration: const InputDecoration(labelText: 'الضريبة %', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      decoration: const InputDecoration(labelText: 'طريقة الدفع (الاستلام)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      items: ['نقدي', 'تحويل بنكي', 'آجل'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontWeight: e == 'آجل' ? FontWeight.bold : FontWeight.normal, color: e == 'آجل' ? Colors.red : null)))).toList(),
                      onChanged: (v) => setStateDialog(() { selectedPaymentMethod = v!; calculateLive(); }),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: noteController, decoration: const InputDecoration(labelText: 'البيان / ملاحظة (اختياري)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))),
                    
                    // --- لوحة الحساب الآلي اللحظية ---
                    if (currentAmount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 15),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('خصم من رصيدك:', style: TextStyle(fontSize: 11)), Text('$currentAmount ريال', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الضريبة/الرسوم:', style: TextStyle(fontSize: 11, color: Colors.red)), Text('$taxValue ريال', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold))]),
                            const Divider(),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي المطلوب:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), Text('$totalCost ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))]),
                            if (selectedPaymentMethod == 'آجل')
                              const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Text('⚠️ سيتم تقييد الإجمالي كـ "دين آجل" على المستلم تلقائياً.', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 15),
                    TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة مرور الوكيل (للتأكيد الآمن)', prefixIcon: Icon(Icons.lock, color: Colors.red), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () async {
                    if (targetData == null) { _play('error'); _showSnack('يجب البحث عن الرقم والتحقق منه أولاً!', isErr: true); return; }
                    if (passwordController.text.isEmpty) { _play('error'); _showSnack('يرجى إدخال كلمة المرور!', isErr: true); return; }
                    if (currentAmount <= 0 || currentAmount > sys.currentUserBalance) { _play('error'); _showSnack('المبلغ غير صالح أو غير متاح في رصيدك!', isErr: true); return; }

                    _play('warning');
                    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
                      title: const Text('تأكيد التحويل النهائي ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text('تأكيد تحويل $currentAmount (بإجمالي $totalCost ريال) إلى ${targetData?['name']}؟\n\nطريقة الدفع: $selectedPaymentMethod'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          onPressed: () async {
                            Navigator.pop(ctx); // إغلاق التأكيد
                            _play('click');
                            showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator())); // Loading
                            try {
                              await sys.advancedSecureTransferBalance(
                                targetPhone: phoneController.text.trim(), 
                                targetName: targetData?['name'] ?? 'مجهول', 
                                amount: currentAmount,
                                taxPercentage: currentTax,
                                note: noteController.text,
                                paymentMethod: selectedPaymentMethod,
                                password: passwordController.text
                              );
                              
                              if (mounted) { 
                                Navigator.pop(context); // إغلاق الـ Loading
                                Navigator.pop(context); // إغلاق نافذة التحويل
                                _play('success'); 
                                _showSnack('تم التحويل بنجاح! وتم تقييد العملية في السجل المالي. 🎉'); 
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.pop(context); // إغلاق الـ Loading
                                _play('error'); 
                                _showSnack(e.toString(), isErr: true);
                              }
                            }
                          },
                          child: const Text('نعم، حوّل الرصيد', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    )));
                  },
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  label: const Text('تنفيذ التحويل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  // 5. نافذة عرض الإيصال الرقمي (تصدير كصورة 📸)
  // ==========================================
  void _showTransactionReceipt(Map<String, dynamic> txn, SystemProvider sys) {
    _play('click');
    bool isPlus = txn['type'] == 'income' || txn['type'] == 'deposit' || (txn['type'] == 'transfer' && txn['toPhone'] == sys.currentUserPhone);
    String dateStr = txn['timestamp'] != null ? DateFormat('yyyy-MM-dd hh:mm a').format((txn['timestamp'] as Timestamp).toDate()) : 'الآن';
    
    final GlobalKey receiptKey = GlobalKey(); 

    showDialog(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: RepaintBoundary(
            key: receiptKey,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
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
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.5, color: Colors.grey)),
                  
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

                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.5, color: Colors.grey)), 
                  const Text('شكراً لاستخدامكم محفظة كروت نت', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('إغلاق', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            ElevatedButton.icon(
               icon: const Icon(Icons.image, color: Colors.white, size: 16),
               label: const Text('مشاركة كصورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
               onPressed: () async {
                  _play('click');
                  _showSnack('جاري تجهيز الصورة للمشاركة... ⏳');
                  try {
                    RenderRepaintBoundary boundary = receiptKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                    ui.Image image = await boundary.toImage(pixelRatio: 3.0); 
                    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                    Uint8List pngBytes = byteData!.buffer.asUint8List();
                    
                    await Share.shareXFiles([XFile.fromData(pngBytes, mimeType: 'image/png', name: 'receipt.png')], text: 'إيصال عملية مالية - كروت نت');
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
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: isBold ? 16 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }

  // ==========================================
  // وظائف الموافقة والرفض لطلبات الشحن 
  // ==========================================
  void _confirmApproveRequest(String reqId, String posPhone, double amount, SystemProvider sys, String userName) {
    _play('warning');
    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
      title: const Text('تأكيد الموافقة ✅', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      content: Text('هل تم التأكد من استلام مبلغ $amount ريال من $userName؟\nسيتم توريد الرصيد لمحفظته فوراً.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () async {
            Navigator.pop(ctx);
            _play('click');
            try {
              await sys.agentAcceptUserRecharge(reqId, posPhone, amount);
              if(mounted) {
                _play('success');
                _showSnack('تم إضافة الرصيد لمحفظة الزبون بنجاح ✅');
              }
            } catch (e) {
              _play('error'); _showSnack('حدث خطأ: $e', isErr: true);
            }
          },
          child: const Text('نعم، أؤكد الاستلام', style: TextStyle(color: Colors.white)),
        )
      ],
    )));
  }

  // 👈 تم الإصلاح هنا بتعريف المتغير sys بشكل صحيح لحل خطأ الـ Build
  void _confirmRejectRequest(String reqId) {
    _play('warning');
    final sys = Provider.of<SystemProvider>(context, listen: false); 
    
    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
      title: const Text('رفض الطلب ❌', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      content: const Text('هل أنت متأكد أنك تريد رفض هذا الطلب وإلغاءه؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(ctx);
            _play('click');
            try {
              await sys.rejectRechargeRequest(reqId, 'مرفوض من قبل الوكيل');
              if(mounted) { _play('success'); _showSnack('تم رفض الطلب بنجاح.'); }
            } catch(e) {
               _play('error'); _showSnack('حدث خطأ أثناء الرفض', isErr: true);
            }
          },
          child: const Text('نعم، ارفض الطلب', style: TextStyle(color: Colors.white)),
        )
      ],
    )));
  }

  void _confirmBulkApprove(List<QueryDocumentSnapshot> requests, SystemProvider sys) {
    if (requests.isEmpty) {
      _play('error'); _showSnack('لا توجد طلبات للموافقة عليها!', isErr: true); return;
    }
    _play('warning');
    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
      title: const Text('موافقة جماعية ⚡', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      content: Text('أنت على وشك الموافقة على (${requests.length}) طلبات شحن دفعة واحدة.\nهل أنت متأكد من استلامك لجميع المبالغ؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () async {
            Navigator.pop(ctx);
            _play('click');
            showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.green)));
            try {
              for (var reqDoc in requests) {
                var req = reqDoc.data() as Map<String, dynamic>;
                double reqAmount = (req['amount'] ?? 0).toDouble();
                await sys.agentAcceptUserRecharge(reqDoc.id, req['userPhone'], reqAmount);
              }
              if (mounted) { 
                Navigator.pop(context); // close loader
                _play('success'); 
                _showSnack('تمت الموافقة على جميع الطلبات بنجاح! ✅'); 
              }
            } catch (e) {
              if (mounted) { 
                Navigator.pop(context); // close loader
                _play('error'); 
                _showSnack('حدث خطأ أثناء المعالجة الجماعية', isErr: true); 
              }
            }
          },
          child: const Text('تأكيد الكل', style: TextStyle(color: Colors.white)),
        )
      ],
    )));
  }

  // ==========================================
  // 🎨 بناء الشاشة بنظام NestedScrollView 
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = themeProvider.adaptiveTextColor;

    final List<Map<String, dynamic>> realTransactions = sys.transactionsLedger.where((t) {
      if (t['agentPhone'] != sys.currentUserPhone && t['fromPhone'] != sys.currentUserPhone && t['toPhone'] != sys.currentUserPhone) return false;
      
      bool typeMatch = false;
      if (_selectedFilter == 'الكل') typeMatch = true;
      else if (_selectedFilter == 'إيداعات وأرباح' && (t['type'] == 'income' || t['type'] == 'deposit')) typeMatch = true;
      else if (_selectedFilter == 'مسحوبات ومصروفات' && (t['type'] == 'expense' || t['type'] == 'purchase' || t['type'] == 'sale')) typeMatch = true;
      else if (_selectedFilter == 'حوالات صادرة' && t['type'] == 'transfer' && t['fromPhone'] == sys.currentUserPhone) typeMatch = true;
      else if (_selectedFilter == 'حوالات واردة' && t['type'] == 'transfer' && t['toPhone'] == sys.currentUserPhone) typeMatch = true;
      
      if (!typeMatch) return false;

      if (_selectedDateFilter == 'الكل') return true;
      if (t['timestamp'] == null) return false;
      DateTime d = (t['timestamp'] as Timestamp).toDate();
      DateTime now = DateTime.now();
      
      if (_selectedDateFilter == 'اليوم') return d.year == now.year && d.month == now.month && d.day == now.day;
      if (_selectedDateFilter == 'هذا الأسبوع') return now.difference(d).inDays <= 7;
      if (_selectedDateFilter == 'هذا الشهر') return d.year == now.year && d.month == now.month;

      return true;
    }).toList();

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
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: isDark ? Colors.grey.shade900 : Colors.teal.shade800,
                  padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 15),
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
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.orangeAccent, 
                    unselectedLabelColor: isDark ? Colors.white70 : Colors.black54, 
                    indicatorColor: Colors.orangeAccent, 
                    indicatorWeight: 4,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
                    tabs: [
                      const Tab(text: 'السجل والتحويل'),
                      Tab(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _db.collection('user_recharges').where('targetPhone', isEqualTo: sys.currentUserPhone).where('status', isEqualTo: 'قيد الانتظار').snapshots(),
                          builder: (context, snapshot) {
                            int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('طلبات الشحن'),
                                if (pendingCount > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                ]
                              ],
                            );
                          }
                        )
                      ),
                    ],
                  ),
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildWalletAndLedgerTab(sys, realTransactions, totalIncome, totalExpense, incomeFlex, expenseFlex, isDark, cardColor, textColor),
              _buildRequestsTab(sys),
            ],
          ),
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
        Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          color: isDark ? Colors.grey.shade900 : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickBtn(Icons.add_to_photos, 'طلب رصيد', Colors.green, _showRequestBalanceDialog),
              _buildQuickBtn(Icons.send_to_mobile, 'تحويل رصيد', Colors.orange, _showAdvancedTransferDialog),
              _buildQuickBtn(Icons.picture_as_pdf, 'تصدير PDF', Colors.blue, () => _showPdfStatementDialog(sys, realTransactions)),
              _buildQuickBtn(Icons.table_chart, 'إكسل CSV', Colors.teal, () => _exportCSV(realTransactions, sys)),
            ],
          ),
        ),
        
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('سجل العمليات المالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
                      child: ListTile(
                        onTap: () => _showTransactionReceipt(txn, sys), 
                        leading: CircleAvatar(
                          backgroundColor: isPlus ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          child: Icon(isPlus ? Icons.arrow_downward : Icons.arrow_upward, color: isPlus ? Colors.green : Colors.red),
                        ),
                        title: Text(txn['title'] ?? 'عملية مالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                        subtitle: Text(txn['timestamp'] != null ? DateFormat('yyyy-MM-dd hh:mm a').format((txn['timestamp'] as Timestamp).toDate()) : 'الآن', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${isPlus ? '+' : '-'}${txn['amount']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isPlus ? Colors.green : Colors.red), textDirection: TextDirection.ltr),
                            const SizedBox(width: 5),
                            Icon(Icons.receipt_long, color: Colors.grey.shade400, size: 16), 
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orange));
        var requests = snapshot.data!.docs;
        
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read, size: 70, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text('لا توجد طلبات شحن معلقة حالياً، عمل رائع!', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            )
          );
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.green.withOpacity(0.1),
              child: ElevatedButton.icon(
                onPressed: () => _confirmBulkApprove(requests, sys),
                icon: const Icon(Icons.playlist_add_check_circle, color: Colors.white),
                label: Text('موافقة على جميع الطلبات (${requests.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, elevation: 0),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12), 
                itemCount: requests.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, i) {
                  var req = requests[i].data() as Map<String, dynamic>;
                  String reqId = requests[i].id;
                  double reqAmount = (req['amount'] ?? 0).toDouble();

                  return Card(
                    color: Theme.of(context).cardColor,
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blue.shade200, width: 1.5)),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${req['userName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(5)), child: const Text('طلب جديد', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('رقم: ${req['userPhone']}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              Text('$reqAmount ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Divider()),
                          Row(
                            children: [
                              Expanded(flex: 1, child: OutlinedButton(onPressed: () => _confirmRejectRequest(reqId), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('رفض ❌'))),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: ElevatedButton(
                                onPressed: () => _confirmApproveRequest(reqId, req['userPhone'], reqAmount, sys, req['userName']),
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
  // واجهات مساعدة
  // ==========================================
  Widget _buildQuickBtn(IconData icon, String label, Color iconColor, VoidCallback onTap) {
    final textColor = Provider.of<ThemeProvider>(context).adaptiveTextColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          CircleAvatar(backgroundColor: iconColor.withOpacity(0.15), radius: 25, child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({required String value, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButton<String>(
        value: value,
        dropdownColor: Theme.of(context).cardColor,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.blueAccent),
        items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Provider.of<ThemeProvider>(context).adaptiveTextColor)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// 👈 كلاس مساعد لجعل شريط التبويبات (TabBar) يثبت في الأعلى عند التمرير
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color color;

  _SliverAppBarDelegate(this._tabBar, {required this.color});

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: color,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
