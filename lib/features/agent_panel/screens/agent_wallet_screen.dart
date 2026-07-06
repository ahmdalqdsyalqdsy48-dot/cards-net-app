import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:local_auth/local_auth.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';
import 'agent_bank_accounts_screen.dart';
import 'advanced_statement_screen.dart';

class AgentWalletScreen extends StatefulWidget {
  const AgentWalletScreen({super.key});

  @override
  State<AgentWalletScreen> createState() => _AgentWalletScreenState();
}

class _AgentWalletScreenState extends State<AgentWalletScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;
  bool _isBalanceHidden = true; // مخفي افتراضيًا
  final LocalAuthentication _localAuth = LocalAuthentication();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // ---------- دوال الإشعارات المحسّنة ----------
  void _showSuccessSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInDialogError(String message) {
    // تستخدم داخل setStateDialog لاظهار خطأ دون إغلاق الحوار
    _showErrorSnack(message);
  }

  void _play(String type) => context.read<UiProvider>().playSound(type);

  // ========== تحديث شامل للقسم ==========
  Future<void> _refreshAll() async {
    _play('click');
    // إعادة بناء الواجهة بطلب تحديث من WalletProvider
    context.read<WalletProvider>().notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    _play('success');
    _showSuccessSnack('تم تحديث المحفظة بنجاح');
  }

  // ========== تحويل الأرقام إلى كلمات عربية (دون تغيير) ==========
  String _convertNumberToArabicWords(double number) {
    if (number == 0) return 'صفر';
    int num = number.toInt();
    if (num >= 1000000) {
      int millions = num ~/ 1000000;
      int remainder = num % 1000000;
      String millionsText = millions == 1 ? 'مليون' : '$millions ملايين';
      if (remainder == 0) return millionsText;
      return '$millionsText و ${_convertLessThanOneMillion(remainder)}';
    }
    return _convertLessThanOneMillion(num);
  }

  String _convertLessThanOneMillion(int num) {
    if (num == 0) return '';
    if (num < 1000) return _convertHundreds(num);
    int thousands = num ~/ 1000;
    int remainder = num % 1000;
    String thousandsText = _convertThousands(thousands);
    if (remainder == 0) return thousandsText;
    return '$thousandsText و ${_convertHundreds(remainder)}';
  }

  String _convertThousands(int num) {
    if (num == 1) return 'ألف';
    if (num == 2) return 'ألفان';
    if (num <= 10) return '${_convertOnes(num)} آلاف';
    return '${_convertHundreds(num)} ألف';
  }

  String _convertHundreds(int num) {
    if (num == 0) return '';
    if (num < 100) return _convertTens(num);
    int hundreds = num ~/ 100;
    int remainder = num % 100;
    String hundredsText = _convertHundredsPrefix(hundreds);
    if (remainder == 0) return hundredsText;
    return '$hundredsText و ${_convertTens(remainder)}';
  }

  String _convertHundredsPrefix(int num) {
    switch (num) {
      case 1: return 'مائة';
      case 2: return 'مائتان';
      default: return '${_convertOnes(num)} مائة';
    }
  }

  String _convertTens(int num) {
    if (num < 10) return _convertOnes(num);
    if (num == 10) return 'عشرة';
    if (num == 11) return 'أحد عشر';
    if (num == 12) return 'اثنا عشر';
    if (num < 20) return '${_convertOnes(num % 10)} عشر';
    int tens = num ~/ 10;
    int ones = num % 10;
    String tensText = _convertTensPrefix(tens);
    if (ones == 0) return tensText;
    return '${_convertOnes(ones)} و $tensText';
  }

  String _convertTensPrefix(int tens) {
    switch (tens) {
      case 2: return 'عشرون';
      case 3: return 'ثلاثون';
      case 4: return 'أربعون';
      case 5: return 'خمسون';
      case 6: return 'ستون';
      case 7: return 'سبعون';
      case 8: return 'ثمانون';
      case 9: return 'تسعون';
      default: return '';
    }
  }

  String _convertOnes(int num) {
    switch (num) {
      case 1: return 'واحد';
      case 2: return 'اثنان';
      case 3: return 'ثلاثة';
      case 4: return 'أربعة';
      case 5: return 'خمسة';
      case 6: return 'ستة';
      case 7: return 'سبعة';
      case 8: return 'ثمانية';
      case 9: return 'تسعة';
      default: return '';
    }
  }

  // ========== عرض صورة السند (تعمل الآن) ==========
  void _showReceiptDialog(String base64Image) {
    if (base64Image.isEmpty) return;
    _play('click');
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.memory(base64Decode(base64Image), fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 1. طلب حصة (شحن رصيد من الإدارة) – محدث بالكامل ==========
  void _showRequestBalanceDialog({Map<String, dynamic>? existingRequest}) {
    _play('click');
    final wallet = context.read<WalletProvider>();
    final auth = context.read<AuthProvider>();

    final currentUserData = wallet.usersList.firstWhere(
        (u) => u['phone'] == auth.activeUserPhone,
        orElse: () => {});
    String rawMargin = currentUserData['profitMargin']?.toString() ?? '0';
    rawMargin = rawMargin.replaceAll(RegExp(r'[^0-9.]'), '');
    double feePercentage = double.tryParse(rawMargin) ?? 0.0;

    final activeBanks = wallet.bankAccounts.where((bank) => bank['status'] == 'نشط').toList();
    final myBanks = wallet.myAgentBankAccounts.where((b) => b['status'] == 'نشط').toList();

    // حالات المتغيرات
    String paymentMethod = existingRequest?['paymentMethod'] ?? 'offline';
    String currency = existingRequest?['currency'] ?? 'SAR';
    double exchangeRate = double.tryParse(existingRequest?['exchangeRate']?.toString() ?? '1.0') ?? 1.0;
    
    String? selectedOwnerBankId = existingRequest?['destinationBankAccountId'];
    Map<String, dynamic>? selectedOwnerBankDetails;
    if (selectedOwnerBankId != null) {
      selectedOwnerBankDetails = activeBanks.firstWhere(
        (b) => b['docId'] == selectedOwnerBankId,
        orElse: () => <String, dynamic>{},
      );
    }

    String? selectedMyBankId = existingRequest?['sourceBankAccountId'];
    Map<String, dynamic>? selectedMyBankDetails;
    if (selectedMyBankId != null && myBanks.isNotEmpty) {
      selectedMyBankDetails = myBanks.firstWhere(
        (b) => b['docId'] == selectedMyBankId,
        orElse: () => <String, dynamic>{},
      );
    }

    final quotaController = TextEditingController(text: existingRequest?['amount']?.toString() ?? '');
    final sourceController = TextEditingController(text: existingRequest?['transferSource'] ?? '');
    final refController = TextEditingController(text: existingRequest?['reference'] ?? '');
    String? base64Image = existingRequest?['receiptBase64'];

    double currentQuota = double.tryParse(quotaController.text) ?? 0;
    double calculatedFee = currentQuota * (feePercentage / 100);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.account_balance_wallet, color: Colors.green)),
              const SizedBox(width: 10),
              Text(existingRequest != null ? 'تعديل طلب الحصة' : 'طلب حصة مبيعات', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('حدد المبلغ وطريقة الدفع والعملة.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 15),
                
                // حساب الوكيل البنكي (مصدر الدفع) إن وجد
                if (myBanks.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: selectedMyBankId ?? (myBanks.isNotEmpty ? myBanks.first['docId'] : null),
                    decoration: InputDecoration(
                      labelText: 'حسابك البنكي (مصدر الدفع)',
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: myBanks.map((bank) => DropdownMenuItem(
                      value: bank['docId'].toString(),
                      child: Text('${bank['bankName']} (${bank['accountNumber']})'),
                    )).toList(),
                    onChanged: (val) {
                      _play('click');
                      setStateDialog(() {
                        selectedMyBankId = val;
                        selectedMyBankDetails = myBanks.firstWhere((b) => b['docId'] == val, orElse: () => <String, dynamic>{});
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                
                // المبلغ
                TextField(
                  controller: quotaController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  onChanged: (val) => setStateDialog(() { currentQuota = double.tryParse(val) ?? 0; calculatedFee = currentQuota * (feePercentage / 100); }),
                  decoration: InputDecoration(labelText: 'مبلغ الحصة (الرصيد المراد إضافته)', filled: true, fillColor: Colors.blue.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                if (currentQuota > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 10),
                    child: Text('${intl.NumberFormat('#,###').format(currentQuota)} ريال ${_convertNumberToArabicWords(currentQuota).isNotEmpty ? "(${_convertNumberToArabicWords(currentQuota)} ريال لا غير)" : ""}',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                  ),
                if (calculatedFee > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 15, bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange.shade50, Colors.white]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('📌 تنبيه:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 5),
                      Text('نسبة الربح المخصصة لك: $feePercentage%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('المبلغ المطلوب تحويله للنظام هو: ${intl.NumberFormat('#,###').format(calculatedFee)} ريال فقط', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      const Text('سيتم إضافة كامل مبلغ الحصة إلى محفظتك بعد التأكيد.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ),
                  
                const SizedBox(height: 10),
                
                // 🆕 اختيار طريقة الدفع
                const Text('اختر طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('تحويل بنكي'),
                      selected: paymentMethod == 'bank_transfer',
                      selectedColor: Colors.blue.shade100,
                      onSelected: (v) => setStateDialog(() => paymentMethod = 'bank_transfer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('محل صرافة'),
                      selected: paymentMethod == 'offline',
                      selectedColor: Colors.orange.shade100,
                      onSelected: (v) => setStateDialog(() => paymentMethod = 'offline'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('دفع نقدي'),
                      selected: paymentMethod == 'cash',
                      selectedColor: Colors.green.shade100,
                      onSelected: (v) => setStateDialog(() => paymentMethod = 'cash'),
                    ),
                  ),
                ]),

                const SizedBox(height: 15),
                
                // اختيار العملة
                DropdownButtonFormField<String>(
                  value: currency,
                  decoration: InputDecoration(
                    labelText: 'العملة',
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                    DropdownMenuItem(value: 'YER_OLD', child: Text('ريال يمني (قديم)')),
                    DropdownMenuItem(value: 'YER_NEW', child: Text('ريال يمني (جديد)')),
                    DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD)')),
                  ],
                  onChanged: (val) {
                    _play('click');
                    setStateDialog(() {
                      currency = val!;
                      exchangeRate = 1.0;
                    });
                  },
                ),
                
                if (currency != 'SAR')
                  FutureBuilder<double>(
                    future: wallet.getExchangeRate(currency, 'SAR'),
                    builder: (context, snap) {
                      final rate = snap.data ?? exchangeRate;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'سعر الصرف التقريبي: 1 $currency ≈ ${rate.toStringAsFixed(4)} SAR',
                          style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                        ),
                      );
                    },
                  ),
                
                const SizedBox(height: 10),

                // المحتوى يعتمد على طريقة الدفع
                if (paymentMethod == 'bank_transfer') ...[
                  if (activeBanks.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: selectedOwnerBankId ?? (activeBanks.isNotEmpty ? activeBanks.first['docId'] : null),
                      decoration: InputDecoration(labelText: 'اختر حساب النظام للإيداع', filled: true, fillColor: Colors.grey.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      items: activeBanks.map((bank) => DropdownMenuItem(
                        value: bank['docId'].toString(),
                        child: Text('${bank['bankName']} (${bank['accountNumber']})'),
                      )).toList(),
                      onChanged: (val) {
                        _play('click');
                        setStateDialog(() {
                          selectedOwnerBankId = val;
                          selectedOwnerBankDetails = activeBanks.firstWhere((b) => b['docId'] == val, orElse: () => <String, dynamic>{});
                        });
                      },
                    ),
                    if (selectedOwnerBankDetails != null && selectedOwnerBankDetails!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.teal.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.withOpacity(0.3))),
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Expanded(child: Text('المستفيد: ${selectedOwnerBankDetails!['beneficiary']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            InkWell(onTap: () { Clipboard.setData(ClipboardData(text: selectedOwnerBankDetails!['beneficiary'])); _showSuccessSnack('تم نسخ اسم المستفيد'); }, child: const Icon(Icons.copy, size: 16, color: Colors.teal)),
                          ]),
                          const Divider(height: 10),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Expanded(child: Text('رقم الحساب: ${selectedOwnerBankDetails!['accountNumber']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal), textDirection: TextDirection.ltr)),
                            InkWell(onTap: () { Clipboard.setData(ClipboardData(text: selectedOwnerBankDetails!['accountNumber'])); _showSuccessSnack('تم نسخ رقم الحساب'); }, child: const Icon(Icons.copy, size: 16, color: Colors.teal)),
                          ]),
                        ]),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        _play('click');
                        _showInDialogError('سيتم توجيهك لتطبيق البنك لإتمام الدفع قريباً');
                      },
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('الدفع عبر التطبيق البنكي'),
                    ),
                  ] else
                    const Text('لا توجد حسابات بنكية نشطة للمركز.', style: TextStyle(color: Colors.red)),
                ] else if (paymentMethod == 'offline') ...[
                  TextField(
                    controller: sourceController,
                    decoration: InputDecoration(
                      labelText: 'اسم الصراف (مثال: الياباني)',
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: refController,
                    decoration: InputDecoration(
                      labelText: 'رقم الحوالة',
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      _play('click');
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 600);
                      if (pickedFile != null) {
                        final bytes = await pickedFile.readAsBytes();
                        setStateDialog(() => base64Image = base64Encode(bytes));
                        _play('success');
                        _showSuccessSnack('تم إرفاق السند بنجاح ✅');
                      }
                    },
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(color: base64Image == null ? Colors.grey.withOpacity(0.1) : Colors.green.withOpacity(0.1), border: Border.all(color: base64Image == null ? Colors.grey : Colors.green), borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        Icon(base64Image == null ? Icons.add_a_photo : Icons.check_circle, color: base64Image == null ? Colors.grey : Colors.green, size: 30),
                        const SizedBox(height: 5),
                        Text(base64Image == null ? 'انقر لإرفاق السند' : 'تم الإرفاق (انقر للتغيير)', style: TextStyle(color: base64Image == null ? Colors.grey : Colors.green, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ] else if (paymentMethod == 'cash') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                    child: const Text('سيتم تسليم المبلغ نقداً للمركز الرئيسي أو من ينوب عنه، وسيتم تأكيد الحصة بعد الاستلام.'),
                  ),
                ],
                const SizedBox(height: 20),
              ]),
            ),
            actions: [
              TextButton(onPressed: () { _play('click'); Navigator.pop(ctx); }, child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  // التحقق من صحة البيانات (مع بقاء النافذة مفتوحة عند الخطأ)
                  if (currentQuota <= 0) {
                    _play('error');
                    _showInDialogError('يرجى إدخال مبلغ حصة صالح!');
                    return;
                  }
                  if (paymentMethod == 'offline') {
                    if (sourceController.text.isEmpty || refController.text.isEmpty) {
                      _play('error');
                      _showInDialogError('يرجى كتابة اسم الصراف ورقم الحوالة!');
                      return;
                    }
                    if (base64Image == null) {
                      _play('error');
                      _showInDialogError('يجب إرفاق السند!');
                      return;
                    }
                  } else if (paymentMethod == 'bank_transfer') {
                    if (selectedOwnerBankId == null) {
                      _play('error');
                      _showInDialogError('اختر حساب النظام البنكي!');
                      return;
                    }
                  }

                  Navigator.pop(ctx);
                  _play('click');
                  _showSuccessSnack('جاري إرسال الطلب للمركز الرئيسي... ⏳');
                  
                  try {
                    if (existingRequest != null) await wallet.cancelQuotaRequest(existingRequest['docId']);
                    
                    await wallet.submitSaaSRechargeRequest(
                      quotaAmount: currentQuota,
                      feeAmount: calculatedFee,
                      adminBankName: selectedOwnerBankDetails?['bankName'] ?? '',
                      transferSource: paymentMethod == 'offline' ? sourceController.text.trim() : (paymentMethod == 'bank_transfer' ? 'تحويل بنكي' : 'دفع نقدي'),
                      reference: refController.text.trim(),
                      base64Image: base64Image ?? '',
                      paymentMethod: paymentMethod,
                      currency: currency,
                      destinationBankAccountId: selectedOwnerBankId ?? '',
                      sourceBankAccountId: selectedMyBankId ?? '',
                      offlineProviderName: paymentMethod == 'offline' ? sourceController.text.trim() : '',
                      offlineReference: paymentMethod == 'offline' ? refController.text.trim() : '',
                      offlineReceiptBase64: paymentMethod == 'offline' ? (base64Image ?? '') : '',
                    );
                    if (mounted) { _play('success'); _showSuccessSnack('تم إرسال الطلب بنجاح وهو قيد المراجعة ✅'); }
                  } catch (e) { _play('error'); if (mounted) _showErrorSnack('حدث خطأ: $e'); }
                },
                child: Text(existingRequest != null ? 'حفظ التعديلات' : 'تأكيد وإرسال', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 2. تحويل للغير (PIN + بصمة) – مُحسّن ==========
  void _showAdvancedTransferDialog() {
    _play('click');
    final wallet = context.read<WalletProvider>();
    final auth = context.read<AuthProvider>();

    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final taxController = TextEditingController();
    final noteController = TextEditingController();
    final pinController = TextEditingController();

    bool isSearching = false;
    Map<String, dynamic>? targetData;
    String selectedPaymentMethod = 'نقدي';
    Timer? _searchDebounce;
    double currentAmount = 0, currentTax = 0, taxValue = 0, totalCost = 0;
    bool obscurePin = true;
    bool useBiometrics = false;

    final currentUserData = wallet.usersList.firstWhere((u) => u['phone'] == auth.activeUserPhone, orElse: () => {});
    bool isPinEnabled = currentUserData['pinEnabled'] ?? false;
    bool isBiometricEnabled = currentUserData['isBiometricEnabled'] ?? false;
    final double agentBalance = wallet.currentUserBalance;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async { _searchDebounce?.cancel(); return true; },
          child: StatefulBuilder(
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Row(children: [Icon(Icons.send_to_mobile, color: Colors.orange), SizedBox(width: 10), Text('تحويل رصيد للغير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
                  content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // رصيد المرسل
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('رصيدك الحالي:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${intl.NumberFormat('#,###').format(agentBalance)} ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ]),
                      ),
                      const Text('رقم المستلم:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        onChanged: (val) {
                          if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                          _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
                            String targetPhone = val.trim();
                            if (targetPhone.isEmpty || targetPhone == auth.activeUserPhone) return;
                            setStateDialog(() { isSearching = true; targetData = null; });
                            try {
                              var data = await wallet.searchUserForTransfer(targetPhone);
                              if (!context.mounted) return;
                              if (data != null) { _play('success'); setStateDialog(() { targetData = data; isSearching = false; }); }
                              else { setStateDialog(() { isSearching = false; }); }
                            } catch (e) { setStateDialog(() { isSearching = false; }); }
                          });
                        },
                        decoration: InputDecoration(hintText: 'أدخل الرقم ليتم البحث تلقائياً...', filled: true, fillColor: Colors.grey.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), suffixIcon: isSearching ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))) : const Icon(Icons.search, color: Colors.grey)),
                      ),
                      if (targetData != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _infoRow('الاسم', targetData?['name'] ?? 'مجهول'),
                            _infoRow('الدور', targetData?['role'] == 'agent' ? 'وكيل' : 'مستخدم عادي'),
                            if (targetData?['role'] == 'agent') _infoRow('الشبكة', targetData?['networkName'] ?? 'غير محدد'),
                            if (targetData?['showBalance'] != false) _infoRow('الرصيد', '${targetData?['balance']} ريال'),
                          ]),
                        ),
                      ],
                      Row(children: [
                        Expanded(flex: 2, child: TextField(controller: amountController, keyboardType: TextInputType.number, onChanged: (v) => setStateDialog(() => calculateLive()), decoration: InputDecoration(labelText: 'المبلغ', filled: true, fillColor: Colors.grey.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                        const SizedBox(width: 10),
                        Expanded(flex: 1, child: TextField(controller: taxController, keyboardType: TextInputType.number, onChanged: (v) => setStateDialog(() => calculateLive()), decoration: InputDecoration(labelText: 'ضريبة %', filled: true, fillColor: Colors.grey.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                      ]),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        decoration: InputDecoration(labelText: 'طريقة الدفع', filled: true, fillColor: Colors.grey.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                        items: ['نقدي', 'تحويل بنكي', 'آجل'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setStateDialog(() { selectedPaymentMethod = v!; calculateLive(); }),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: noteController, decoration: InputDecoration(labelText: 'ملاحظة (اختياري)', filled: true, fillColor: Colors.grey.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                      if (currentAmount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 15), padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Column(children: [
                            _infoRow('المبلغ', intl.NumberFormat('#,###').format(currentAmount)),
                            _infoRow('الضريبة', intl.NumberFormat('#,###').format(taxValue)),
                            const Divider(),
                            _infoRow('الإجمالي', '${intl.NumberFormat('#,###').format(totalCost)} ريال'),
                            _infoRow('المتبقي بعد التحويل', '${intl.NumberFormat('#,###').format(agentBalance - totalCost)} ريال'),
                          ]),
                        ),
                      const SizedBox(height: 15),
                      if (isPinEnabled && !useBiometrics) ...[
                        TextField(
                          controller: pinController,
                          obscureText: obscurePin,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'رمز PIN',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility), onPressed: () => setStateDialog(() => obscurePin = !obscurePin)),
                              if (isBiometricEnabled)
                                IconButton(icon: const Icon(Icons.fingerprint, color: Colors.green), onPressed: () => setStateDialog(() => useBiometrics = true)),
                            ]),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                      if (useBiometrics && isBiometricEnabled)
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              bool authenticated = await _localAuth.authenticate(localizedReason: 'تأكيد بصمة الإصبع للتحويل', options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true));
                              if (authenticated) {
                                if (agentBalance < totalCost) {
                                  _showInDialogError('رصيدك غير كافٍ لإتمام التحويل');
                                  return;
                                }
                                Navigator.pop(context);
                                _executeTransfer(phoneController.text.trim(), targetData, currentAmount, currentTax, noteController.text, selectedPaymentMethod, 'biometric');
                              }
                            } catch (e) { _showInDialogError('فشل التحقق البيومتري'); }
                          },
                          icon: const Icon(Icons.fingerprint, color: Colors.white),
                          label: const Text('تأكيد بالبصمة', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                    ]),
                  ),
                  actions: [
                    TextButton(onPressed: () { _searchDebounce?.cancel(); _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
                    if (isPinEnabled && !useBiometrics)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () {
                          if (targetData == null || currentAmount <= 0) {
                            _showInDialogError('يرجى اختيار مستلم وإدخال مبلغ صحيح');
                            return;
                          }
                          if (agentBalance < totalCost) {
                            _showInDialogError('رصيدك غير كافٍ لإتمام التحويل');
                            return;
                          }
                          Navigator.pop(context);
                          _executeTransfer(phoneController.text.trim(), targetData, currentAmount, currentTax, noteController.text, selectedPaymentMethod, pinController.text);
                        },
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        label: const Text('تنفيذ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _executeTransfer(String targetPhone, Map<String, dynamic>? targetData, double amount, double tax, String note, String method, String pinOrBio) async {
    final wallet = context.read<WalletProvider>();
    _play('warning');
    bool? confirm = await showDialog<bool>(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('تأكيد ⚠️'), content: Text('تأكيد تحويل $amount إلى ${targetData?['name']}؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد'))])));
    if (confirm != true) return;
    try {
      await wallet.advancedSecureTransferBalance(targetPhone: targetPhone, targetName: targetData?['name'] ?? 'مجهول', amount: amount, taxPercentage: tax, note: note, paymentMethod: method, password: pinOrBio);
      if (mounted) { _play('success'); _showSuccessSnack('تم التحويل بنجاح! 🎉'); }
    } catch (e) { if (mounted) { _play('error'); _showErrorSnack(e.toString()); } }
  }

  Widget _infoRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]));

  // ========== تبويب طلبات الشحن (POS + مستخدمين) ==========
  void _showRejectReasonDialog(String reqId, String requesterPhone, double amount, WalletProvider wallet) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(hintText: 'اكتب سبب الرفض ليصل للمستخدم')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () async {
            if (reasonController.text.isEmpty) return;
            Navigator.pop(ctx);
            await wallet.rejectRechargeRequest(reqId, reasonController.text);
            _showSuccessSnack('تم رفض الطلب');
          }, child: const Text('رفض')),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomHeader(title: 'محفظة وكيل - ${settings.appName}'),
      drawer: CustomAgentDrawer(agentName: wallet.currentUserName, phoneNumber: auth.activeUserPhone ?? '', role: 'وكيل معتمد', currentBalance: wallet.currentUserBalance),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    color: colors.primaryContainer,
                    padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 15),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('حصة المبيعات المتاحة', style: TextStyle(color: colors.onPrimaryContainer.withOpacity(0.7), fontSize: 12)),
                      Row(children: [
                        Text(_isBalanceHidden ? '******' : intl.NumberFormat('#,###.##').format(wallet.currentUserBalance), style: TextStyle(color: colors.onPrimaryContainer, fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 5),
                        Text('ريال', style: TextStyle(color: colors.onPrimaryContainer.withOpacity(0.7), fontSize: 14)),
                        IconButton(icon: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: colors.onPrimaryContainer.withOpacity(0.7), size: 20), onPressed: () { _play('click'); setState(() => _isBalanceHidden = !_isBalanceHidden); }),
                      ]),
                    ]),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: colors.primary,
                      unselectedLabelColor: colors.onSurfaceVariant,
                      indicatorColor: colors.primary,
                      indicatorWeight: 4,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [Tab(text: 'الرئيسية والطلبات'), Tab(text: 'طلبات الشحن')],
                    ),
                    color: colors.surface,
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildMainDashboardTab(wallet, auth, colors),
                _buildRechargeRequestsTab(wallet, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainDashboardTab(WalletProvider wallet, AuthProvider auth, ColorScheme colors) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20), margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildQuickBtn(Icons.add_card, 'طلب حصة', Colors.green, () => _showRequestBalanceDialog()),
            _buildQuickBtn(Icons.send, 'تحويل للغير', Colors.orange, _showAdvancedTransferDialog),
            _buildQuickBtn(Icons.receipt_long, 'الكشف المالي', Colors.blue, () {
              _play('click');
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedStatementScreen()));
            }),
            _buildQuickBtn(Icons.account_balance, 'حساباتي', Colors.deepPurple, () { _play('click'); Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentBankAccountsScreen())); }),
          ]),
        ),
        // طلبات الحصة المعلقة
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: wallet.getMyPendingQuotaRequests(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
            final requests = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('طلباتي المعلقة مع المركز الرئيسي:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                ...requests.map((req) => _buildPendingQuotaCard(req, wallet, colors)),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildPendingQuotaCard(Map<String, dynamic> req, WalletProvider wallet, ColorScheme colors) {
    final amount = (req['amount'] ?? 0.0).toDouble();
    final fee = (req['fee'] ?? 0.0).toDouble();
    final currency = req['currency'] ?? 'SAR';
    final exchangeRate = (req['exchangeRate'] ?? 1.0).toDouble();
    final paymentMethod = req['paymentMethod'] ?? 'offline';
    final status = req['status'] ?? 'قيد الانتظار';
    final ts = (req['timestamp'] as Timestamp?)?.toDate();
    final dateStr = ts != null ? intl.DateFormat('yyyy/MM/dd hh:mm a').format(ts) : '';
    final provider = req['offlineProviderName'] ?? req['transferSource'] ?? '';
    final ref = req['reference'] ?? '';
    final receiptBase64 = req['receiptBase64'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$amount ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'awaiting_payment' ? Colors.blue.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(status == 'awaiting_payment' ? 'انتظار الدفع' : 'قيد المراجعة',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status == 'awaiting_payment' ? Colors.blue : Colors.orange)),
            ),
          ]),
          const SizedBox(height: 8),
          if (dateStr.isNotEmpty) Text('التاريخ: $dateStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text('طريقة الدفع: ${paymentMethod == 'bank_transfer' ? 'تحويل بنكي' : paymentMethod == 'offline' ? 'محل صرافة' : 'دفع نقدي'}', style: const TextStyle(fontSize: 11)),
          if (currency != 'SAR') Text('العملة: $currency | سعر الصرف: $exchangeRate', style: const TextStyle(fontSize: 11)),
          if (provider.isNotEmpty) Text('المصدر: $provider', style: const TextStyle(fontSize: 11)),
          if (ref.isNotEmpty) Text('المرجع: $ref', style: const TextStyle(fontSize: 11)),
          if (fee > 0) Text('الرسوم: $fee ريال', style: const TextStyle(fontSize: 11, color: Colors.red)),
          if (receiptBase64.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showReceiptDialog(receiptBase64),
              icon: const Icon(Icons.image, size: 16),
              label: const Text('عرض السند'),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { _play('warning'); await wallet.cancelQuotaRequest(req['docId']); _showSuccessSnack('تم إلغاء الطلب'); }, icon: const Icon(Icons.cancel, size: 16), label: const Text('إلغاء'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(onPressed: () => _showRequestBalanceDialog(existingRequest: req), icon: const Icon(Icons.edit, size: 16), label: const Text('تعديل'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildRechargeRequestsTab(WalletProvider wallet, ColorScheme colors) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: wallet.getPendingPosRechargeRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا توجد طلبات شحن حالياً.', style: TextStyle(color: Colors.grey)));
        final requests = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, i) {
            var req = requests[i];
            final String userName = req['userName'] ?? 'مستخدم';
            final String accountNumber = req['accountNumber'] ?? 'غير متوفر';
            final double amount = (req['amount'] ?? 0.0).toDouble();
            final String paymentMethod = req['paymentMethod'] ?? 'حوالة بنكية';
            final String currency = req['currency'] ?? 'SAR';
            final double exchangeRate = (req['exchangeRate'] ?? 1.0).toDouble();
            final String reference = req['reference'] ?? '';
            final String? receiptBase64 = req['receiptBase64'];
            final Timestamp? ts = req['timestamp'] as Timestamp?;
            final String dateStr = ts != null ? intl.DateFormat('yyyy/MM/dd hh:mm a').format(ts.toDate()) : '';
            final String status = req['status'] ?? 'قيد الانتظار';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    Text('$amount ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  ]),
                  const SizedBox(height: 4),
                  Text('رقم الحساب: $accountNumber', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('طريقة الدفع: $paymentMethod', style: const TextStyle(fontSize: 11)),
                  if (currency != 'SAR') Text('العملة: $currency | سعر الصرف: $exchangeRate', style: const TextStyle(fontSize: 11)),
                  if (reference.isNotEmpty) Text('المرجع: $reference', style: const TextStyle(fontSize: 11)),
                  if (dateStr.isNotEmpty) Text('التاريخ: $dateStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'awaiting_payment' ? Colors.blue.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(status == 'awaiting_payment' ? 'انتظار الدفع' : 'معلق',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'awaiting_payment' ? Colors.blue : Colors.orange)),
                    ),
                  ]),
                  if (receiptBase64 != null && receiptBase64.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _showReceiptDialog(receiptBase64),
                      icon: const Icon(Icons.image, size: 16),
                      label: const Text('عرض السند'),
                    ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => _showRejectReasonDialog(req['docId'], req['userPhone'], amount, wallet), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('رفض'))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(onPressed: () async {
                      bool? confirm = await showDialog<bool>(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('تأكيد الموافقة'), content: Text('سيتم إضافة $amount ريال لـ $userName.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('موافقة'))])));
                      if (confirm == true) {
                        await wallet.agentAcceptUserRecharge(req['docId'], req['userPhone'], amount);
                        _showSuccessSnack('تمت الموافقة وإضافة الرصيد');
                      }
                    }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('موافقة ✅'))),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(15),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color color;
  _SliverAppBarDelegate(this._tabBar, {required this.color});
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: color, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
