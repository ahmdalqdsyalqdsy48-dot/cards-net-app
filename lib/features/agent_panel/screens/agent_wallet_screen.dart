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
  // 1. نافذة طلب حصة (SaaS) ودفع الرسوم التشغيلية
  // ==========================================
  void _showRequestBalanceDialog() {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final activeBanks = sys.bankAccounts.where((bank) => bank['status'] == 'نشط').toList();
    
    String? selectedBank;
    if (activeBanks.isNotEmpty) selectedBank = activeBanks.first['bankName']; 

    final quotaController = TextEditingController();
    final sourceController = TextEditingController();
    final refController = TextEditingController();
    
    String transferType = 'تطبيق بنكي'; 
    String? base64Image;
    double feePercentage = 1.0; // نسبة رسوم النظام (يجب جلبها من إعدادات الوكيل مستقبلاً، وضعناها 1% كمثال)
    double calculatedFee = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('طلب حصة مبيعات (Quota)', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('أدخل مبلغ الحصة الذي تريد بيع كروت به، وسيقوم النظام بحساب الرسوم التشغيلية المطلوبة منك إيداعها.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 15),
                  
                  TextField(
                    controller: quotaController, 
                    keyboardType: TextInputType.number, 
                    onChanged: (val) {
                      setStateDialog(() {
                        double amount = double.tryParse(val) ?? 0;
                        calculatedFee = amount * (feePercentage / 100);
                      });
                    },
                    decoration: const InputDecoration(labelText: 'مبلغ الحصة المطلوبة', prefixIcon: Icon(Icons.account_balance_wallet, color: Colors.blue), border: OutlineInputBorder())
                  ),
                  
                  if (calculatedFee > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 15),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('المبلغ المطلوب تحويله كرسوم تشغيلية ($feePercentage%): ${calculatedFee.toStringAsFixed(0)} ريال', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    
                  if (activeBanks.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedBank,
                      decoration: const InputDecoration(labelText: 'حساب مالك النظام (المُحوَّل إليه الرسوم)', border: OutlineInputBorder()),
                      items: activeBanks.map((bank) => DropdownMenuItem(value: bank['bankName'].toString(), child: Text(bank['bankName'].toString(), style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) { _play('click'); selectedBank = val!; },
                    )
                  else
                    const Text('لا توجد حسابات بنكية نشطة لمالك النظام.', style: TextStyle(color: Colors.red)),
                  
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('تطبيق بنكي', style: TextStyle(fontSize: 11)),
                          value: 'تطبيق بنكي',
                          groupValue: transferType,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) { _play('click'); setStateDialog(() => transferType = val!); },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('محل صرافة', style: TextStyle(fontSize: 11)),
                          value: 'محل صرافة',
                          groupValue: transferType,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) { _play('click'); setStateDialog(() => transferType = val!); },
                        ),
                      ),
                    ],
                  ),
                  
                  TextField(
                    controller: sourceController, 
                    decoration: InputDecoration(labelText: transferType == 'تطبيق بنكي' ? 'اسم التطبيق البنكي (مثل: محفظتي)' : 'اسم محل الصرافة (مثل: الياباني)', prefixIcon: Icon(transferType == 'تطبيق بنكي' ? Icons.phone_android : Icons.store), border: const OutlineInputBorder())
                  ),
                  const SizedBox(height: 10),
                  
                  TextField(
                    controller: refController, 
                    decoration: InputDecoration(labelText: transferType == 'تطبيق بنكي' ? 'رقم المرجع' : 'رقم الحوالة', prefixIcon: const Icon(Icons.receipt), border: const OutlineInputBorder())
                  ),
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
                          child: Text(base64Image == null ? 'إرفاق صورة سند الرسوم 📸' : 'تغيير الصورة المرفقة', style: const TextStyle(color: Colors.white)),
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
                  double quota = double.tryParse(quotaController.text) ?? 0;
                  
                  if (quota <= 0) { _play('error'); _showSnack('يرجى إدخال مبلغ حصة صالح!', isErr: true); return; }
                  if (sourceController.text.isEmpty || refController.text.isEmpty) { _play('error'); _showSnack('يرجى إكمال بيانات التحويل!', isErr: true); return; }
                  if (base64Image == null) { _play('error'); _showSnack('يجب إرفاق صورة السند الخاص بالرسوم التشغيلية!', isErr: true); return; }

                  _play('warning');
                  showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
                    title: const Text('تأكيد طلب الحصة ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: Text('أنت تطلب حصة مبيعات بقيمة: $quota ريال\nالرسوم المدفوعة والمرفقة: $calculatedFee ريال\n\nهل أنت متأكد من الإرسال؟'),
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
                            // 👈 استدعاء الدالة الجديدة الخاصة بالـ SaaS في Provider
                            await sys.submitSaaSRechargeRequest(
                              quotaAmount: quota,
                              feeAmount: calculatedFee,
                              adminBankName: selectedBank!,
                              transferSource: sourceController.text.trim(),
                              reference: refController.text.trim(),
                              base64Image: base64Image!
                            );
                            if (mounted) { _play('success'); _showSnack('تم إرسال الطلب للمراجعة بنجاح ✅'); }
                          } catch(e) {
                            _play('error');
                            if (mounted) _showSnack('حدث خطأ أثناء الإرسال: $e', isErr: true);
                          }
                        },
                        child: const Text('تأكيد وإرسال', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  )));
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
  // 2. نافذة التحويل المتقدمة 
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
                  Text('تحويل رصيد للغير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              _play('error'); _showSnack('فشل البحث: $e', isErr: true);
                            }
                          },
                          child: isSearching 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : const Icon(Icons.search, color: Colors.white),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),

                    // لوحة عرض بيانات المستلم
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
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الشبكة:', style: TextStyle(fontSize: 11, color: Colors.grey)), Text(targetData?['networkName'] ?? 'غير محدد', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                            const SizedBox(height: 4),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الدور:', style: TextStyle(fontSize: 11, color: Colors.grey)), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text((targetData?['role'] == 'pos') ? 'نقطة بيع' : (targetData?['role'] == 'agent') ? 'وكيل' : 'مستخدم', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)))]),
                            const SizedBox(height: 4),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الرصيد لديك:', style: TextStyle(fontSize: 11, color: Colors.grey)), Text('${targetData?['balance']} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green))]),
                          ],
                        ),
                      ),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: amountController, keyboardType: TextInputType.number, 
                            onChanged: (v) => setStateDialog((){ calculateLive(); }),
                            decoration: const InputDecoration(labelText: 'المبلغ الأساسي', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))
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
                      decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      items: ['نقدي', 'تحويل بنكي', 'آجل'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontWeight: e == 'آجل' ? FontWeight.bold : FontWeight.normal, color: e == 'آجل' ? Colors.red : null)))).toList(),
                      onChanged: (v) => setStateDialog(() { selectedPaymentMethod = v!; calculateLive(); }),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: noteController, decoration: const InputDecoration(labelText: 'البيان / ملاحظة (اختياري)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))),
                    
                    if (currentAmount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 15),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('خصم من حصتك:', style: TextStyle(fontSize: 11)), Text('$currentAmount ريال', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الضريبة المضافة:', style: TextStyle(fontSize: 11, color: Colors.red)), Text('$taxValue ريال', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold))]),
                            const Divider(),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي مبلغ المستلم:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), Text('$totalCost ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))]),
                            if (selectedPaymentMethod == 'آجل')
                              const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Text('⚠️ سيتم تقييد الإجمالي ($totalCost) كـ "دين آجل" على المستلم تلقائياً.', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
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
                    if (currentAmount <= 0 || currentAmount > sys.currentUserBalance) { _play('error'); _showSnack('حصتك الحالية غير كافية للتحويل!', isErr: true); return; }

                    _play('warning');
                    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
                      title: const Text('تأكيد التحويل النهائي ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text('تأكيد تحويل $currentAmount (بإجمالي $totalCost ريال) إلى ${targetData?['name']}؟\n\nالشبكة: ${targetData?['networkName']}\nطريقة الدفع: $selectedPaymentMethod'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          onPressed: () async {
                            Navigator.pop(ctx); 
                            _play('click');
                            showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator())); 
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
                                Navigator.pop(context); 
                                Navigator.pop(context); 
                                _play('success'); 
                                _showSnack('تم التحويل بنجاح! وتم توثيق العملية في السجل. 🎉'); 
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.pop(context); 
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
  // 🎨 بناء الشاشة بنظام NestedScrollView 
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = themeProvider.adaptiveTextColor;

    // جلب اسم النظام العالمي المتغير من Provider بدلاً من النص الثابت
    final String globalAppName = sys.appName; 

    final List<Map<String, dynamic>> realTransactions = sys.transactionsLedger.where((t) {
      if (t['agentPhone'] != sys.currentUserPhone && t['fromPhone'] != sys.currentUserPhone && t['toPhone'] != sys.currentUserPhone) return false;
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

    return Scaffold(
      appBar: CustomHeader(title: 'محفظة وكيل - $globalAppName'),
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
                          const Text('حصة المبيعات المتاحة', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                      const Tab(text: 'لوحة التحكم والتحويل'),
                      Tab(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _db.collection('user_recharges').where('targetPhone', isEqualTo: sys.currentUserPhone).where('status', isEqualTo: 'قيد الانتظار').snapshots(),
                          builder: (context, snapshot) {
                            int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('طلبات التحويل'),
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
              _buildWalletAndLedgerTab(sys, realTransactions, isDark, cardColor, textColor),
              _buildRequestsTab(sys),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // التبويب الأول: أزرار العمليات 
  // ==========================================
  Widget _buildWalletAndLedgerTab(SystemProvider sys, List<Map<String, dynamic>> realTransactions, bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          color: isDark ? Colors.grey.shade900 : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickBtn(Icons.rocket_launch, 'طلب حصة', Colors.green, _showRequestBalanceDialog),
              _buildQuickBtn(Icons.send_to_mobile, 'تحويل رصيد', Colors.orange, _showAdvancedTransferDialog),
              _buildQuickBtn(Icons.document_scanner, 'الكشف المتقدم', Colors.blue, () {
                _play('click');
                // توجيه الوكيل لشاشة الكشف المتقدم التي أصلحناها سابقاً
                Navigator.pushNamed(context, '/advanced_statement_screen');
              }),
            ],
          ),
        ),
        
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_edu, size: 80, color: Colors.black12),
                SizedBox(height: 10),
                Text('يرجى الانتقال إلى (الكشف المتقدم) للاطلاع على\nسجل العمليات والفواتير التفصيلية الملونة.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
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
                const Text('لا توجد طلبات تحويل معلقة حالياً، عمل رائع!', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
  // واجهات مساعدة وموافقة الطلبات
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
          Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmApproveRequest(String reqId, String posPhone, double amount, SystemProvider sys, String userName) {
    _play('warning');
    showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
      title: const Text('تأكيد الموافقة ✅', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      content: Text('هل تم التأكد من استلام مبلغ $amount ريال من $userName؟\nسيتم توريد الحصة لمحفظته فوراً.'),
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
                _showSnack('تم إضافة الرصيد بنجاح ✅');
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
      content: Text('أنت على وشك الموافقة على (${requests.length}) طلبات دفعة واحدة.\nهل أنت متأكد؟'),
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
}

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
