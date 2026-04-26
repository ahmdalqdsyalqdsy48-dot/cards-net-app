import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';
import 'agent_bank_accounts_screen.dart'; // 🆕

class AgentWalletScreen extends StatefulWidget {
  const AgentWalletScreen({super.key});

  @override
  State<AgentWalletScreen> createState() => _AgentWalletScreenState();
}

class _AgentWalletScreenState extends State<AgentWalletScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;
  bool _isBalanceHidden = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _showSnack(String m, {bool isErr = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isErr ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ------------------- دالة تحويل الأرقام إلى كلمات عربية -------------------
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
      case 1:
        return 'مائة';
      case 2:
        return 'مائتان';
      default:
        return '${_convertOnes(num)} مائة';
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
      case 2:
        return 'عشرون';
      case 3:
        return 'ثلاثون';
      case 4:
        return 'أربعون';
      case 5:
        return 'خمسون';
      case 6:
        return 'ستون';
      case 7:
        return 'سبعون';
      case 8:
        return 'ثمانون';
      case 9:
        return 'تسعون';
      default:
        return '';
    }
  }

  String _convertOnes(int num) {
    switch (num) {
      case 1:
        return 'واحد';
      case 2:
        return 'اثنان';
      case 3:
        return 'ثلاثة';
      case 4:
        return 'أربعة';
      case 5:
        return 'خمسة';
      case 6:
        return 'ستة';
      case 7:
        return 'سبعة';
      case 8:
        return 'ثمانية';
      case 9:
        return 'تسعة';
      default:
        return '';
    }
  }

  // -------------------------------------------------------------------------

  void _showRequestBalanceDialog({Map<String, dynamic>? existingRequest}) {
    _play('click');
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final activeBanks =
        sys.bankAccounts.where((bank) => bank['status'] == 'نشط').toList();

    final currentUserData = sys.usersList.firstWhere(
        (u) => u['phone'] == sys.currentUserPhone,
        orElse: () => {});
    String rawMargin = currentUserData['profitMargin']?.toString() ?? '0';
    rawMargin = rawMargin.replaceAll(RegExp(r'[^0-9.]'), '');
    double feePercentage = double.tryParse(rawMargin) ?? 0.0;

    String? selectedBankName = existingRequest != null
        ? existingRequest['bankName']
        : (activeBanks.isNotEmpty ? activeBanks.first['bankName'] : null);
    Map<String, dynamic>? selectedBankDetails = activeBanks.firstWhere(
        (b) => b['bankName'] == selectedBankName,
        orElse: () => <String, dynamic>{});

    final quotaController = TextEditingController(
        text: existingRequest != null
            ? existingRequest['amount'].toString()
            : '');
    final sourceController = TextEditingController(
        text: existingRequest != null ? existingRequest['transferSource'] : '');
    final refController = TextEditingController(
        text: existingRequest != null ? existingRequest['reference'] : '');

    String transferType = existingRequest != null
        ? (existingRequest['transferSource'].toString().contains('تطبيق')
            ? 'تطبيق بنكي'
            : 'محل صرافة')
        : 'تطبيق بنكي';
    String? base64Image = existingRequest?['receiptBase64'];

    double currentQuota = double.tryParse(quotaController.text) ?? 0;
    double calculatedFee = currentQuota * (feePercentage / 100);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            titlePadding:
                const EdgeInsets.only(top: 20, right: 20, left: 20, bottom: 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.account_balance_wallet,
                      color: Colors.green),
                ),
                const SizedBox(width: 10),
                Text(
                    existingRequest != null
                        ? 'تعديل طلب الحصة'
                        : 'طلب حصة مبيعات',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'قم بتحديد مبلغ الحصة، وسيحسب النظام الرسوم المطلوبة.',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 15),
                    TextField(
                        controller: quotaController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        onChanged: (val) {
                          setStateDialog(() {
                            currentQuota = double.tryParse(val) ?? 0;
                            calculatedFee = currentQuota * (feePercentage / 100);
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'مبلغ الحصة (الرصيد المراد إضافته)',
                          filled: true,
                          fillColor: Colors.blue.withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        )),
                    if (currentQuota > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 5, right: 10),
                        child: Text(
                            '${intl.NumberFormat('#,###').format(currentQuota)} ريال ${_convertNumberToArabicWords(currentQuota).isNotEmpty ? "(${_convertNumberToArabicWords(currentQuota)} ريال لا غير)" : ""}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold)),
                      ),
                    if (calculatedFee > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 15, bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Colors.red.shade50, Colors.white]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200)),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  'الرسوم التشغيلية ($feePercentage%): ${intl.NumberFormat('#,###').format(calculatedFee)} ريال فقط',
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 15),
                    if (activeBanks.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedBankName,
                        decoration: InputDecoration(
                            labelText: 'اختر حساب النظام للإيداع',
                            filled: true,
                            fillColor: Colors.grey.withOpacity(0.05),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none)),
                        items: activeBanks
                            .map((bank) => DropdownMenuItem(
                                value: bank['bankName'].toString(),
                                child: Text(bank['bankName'].toString(),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (val) {
                          _play('click');
                          setStateDialog(() {
                            selectedBankName = val;
                            selectedBankDetails = activeBanks
                                .firstWhere((b) => b['bankName'] == val);
                          });
                        },
                      ),
                      if (selectedBankDetails != null &&
                          selectedBankDetails!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: Colors.teal.withOpacity(0.3))),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          'المستلم: ${selectedBankDetails!['beneficiary']}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(
                                          text: selectedBankDetails![
                                              'beneficiary']));
                                      _showSnack('تم نسخ اسم المستلم');
                                    },
                                    child: const Icon(Icons.copy,
                                        size: 16, color: Colors.teal),
                                  )
                                ],
                              ),
                              const Divider(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          'رقم الحساب: ${selectedBankDetails!['accountNumber']}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal),
                                          textDirection: TextDirection.ltr)),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(
                                          text: selectedBankDetails![
                                              'accountNumber']));
                                      _showSnack('تم نسخ رقم الحساب');
                                    },
                                    child: const Icon(Icons.copy,
                                        size: 16, color: Colors.teal),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                    ] else
                      const Text('لا توجد حسابات بنكية نشطة.',
                          style: TextStyle(color: Colors.red)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                            child: RadioListTile<String>(
                                title: const Text('تطبيق بنكي',
                                    style: TextStyle(fontSize: 11)),
                                value: 'تطبيق بنكي',
                                groupValue: transferType,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) {
                                  _play('click');
                                  setStateDialog(() => transferType = val!);
                                })),
                        Expanded(
                            child: RadioListTile<String>(
                                title: const Text('محل صرافة',
                                    style: TextStyle(fontSize: 11)),
                                value: 'محل صرافة',
                                groupValue: transferType,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) {
                                  _play('click');
                                  setStateDialog(() => transferType = val!);
                                })),
                      ],
                    ),
                    TextField(
                        controller: sourceController,
                        decoration: InputDecoration(
                            labelText: transferType == 'تطبيق بنكي'
                                ? 'اسم التطبيق (مثال: الكريمي)'
                                : 'اسم الصراف (مثال: الياباني)',
                            filled: true,
                            fillColor: Colors.grey.withOpacity(0.05),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none))),
                    const SizedBox(height: 10),
                    TextField(
                        controller: refController,
                        decoration: InputDecoration(
                            labelText: transferType == 'تطبيق بنكي'
                                ? 'رقم المرجع'
                                : 'رقم الحوالة',
                            filled: true,
                            fillColor: Colors.grey.withOpacity(0.05),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none))),
                    const SizedBox(height: 15),
                    InkWell(
                      onTap: () async {
                        _play('click');
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 40,
                            maxWidth: 600);
                        if (pickedFile != null) {
                          final bytes = await pickedFile.readAsBytes();
                          setStateDialog(() => base64Image = base64Encode(bytes));
                          _play('success');
                          _showSnack('تم إرفاق السند بنجاح ✅');
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                            color: base64Image == null
                                ? Colors.grey.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            border: Border.all(
                                color: base64Image == null
                                    ? Colors.grey
                                    : Colors.green),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Icon(
                                base64Image == null
                                    ? Icons.add_a_photo
                                    : Icons.check_circle,
                                color: base64Image == null
                                    ? Colors.grey
                                    : Colors.green,
                                size: 30),
                            const SizedBox(height: 5),
                            Text(
                                base64Image == null
                                    ? 'انقر لإرفاق السند'
                                    : 'تم الإرفاق (انقر للتغيير)',
                                style: TextStyle(
                                    color: base64Image == null
                                        ? Colors.grey
                                        : Colors.green,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.all(20),
            actions: [
              TextButton(
                  onPressed: () {
                    _play('click');
                    Navigator.pop(context);
                  },
                  child: const Text('إلغاء',
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: activeBanks.isEmpty
                    ? null
                    : () async {
                        if (currentQuota <= 0) {
                          _play('error');
                          _showSnack('يرجى إدخال مبلغ حصة صالح!', isErr: true);
                          return;
                        }
                        if (sourceController.text.isEmpty ||
                            refController.text.isEmpty) {
                          _play('error');
                          _showSnack('يرجى إكمال بيانات التحويل!', isErr: true);
                          return;
                        }
                        if (base64Image == null) {
                          _play('error');
                          _showSnack('يجب إرفاق السند!', isErr: true);
                          return;
                        }

                        Navigator.pop(context);
                        _play('success');
                        _showSnack('جاري إرسال الطلب للمركز الرئيسي... ⏳');

                        try {
                          if (existingRequest != null) {
                            await sys.cancelQuotaRequest(existingRequest['docId']);
                          }
                          await sys.submitSaaSRechargeRequest(
                              quotaAmount: currentQuota,
                              feeAmount: calculatedFee,
                              adminBankName: selectedBankName!,
                              transferSource: sourceController.text.trim(),
                              reference: refController.text.trim(),
                              base64Image: base64Image!);
                          if (mounted) {
                            _play('success');
                            _showSnack('تم إرسال الطلب بنجاح وهو قيد المراجعة ✅');
                          }
                        } catch (e) {
                          _play('error');
                          if (mounted) _showSnack('حدث خطأ: $e', isErr: true);
                        }
                      },
                child: Text(
                    existingRequest != null ? 'حفظ التعديلات' : 'تأكيد وإرسال',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    Timer? _searchDebounce;

    double currentAmount = 0;
    double currentTax = 0;
    double taxValue = 0;
    double totalCost = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            _searchDebounce?.cancel();
            return true;
          },
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Row(
                    children: [
                      Icon(Icons.send_to_mobile, color: Colors.orange),
                      SizedBox(width: 10),
                      Text('تحويل رصيد للغير',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  content: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('رقم المستلم:',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          onChanged: (val) {
                            if (_searchDebounce?.isActive ?? false) {
                              _searchDebounce!.cancel();
                            }
                            _searchDebounce = Timer(
                                const Duration(milliseconds: 600), () async {
                              String targetPhone = val.trim();
                              if (targetPhone.isEmpty) {
                                if (!context.mounted) return;
                                setStateDialog(() {
                                  targetData = null;
                                  isSearching = false;
                                });
                                return;
                              }
                              if (targetPhone == sys.currentUserPhone) {
                                _showSnack('لا يمكنك التحويل لنفسك!',
                                    isErr: true);
                                return;
                              }

                              if (!context.mounted) return;
                              setStateDialog(() {
                                isSearching = true;
                                targetData = null;
                              });
                              try {
                                var data =
                                    await sys.searchUserForTransfer(targetPhone);
                                if (!context.mounted) return;
                                if (data != null) {
                                  _play('success');
                                  setStateDialog(() {
                                    targetData = data;
                                    isSearching = false;
                                  });
                                } else {
                                  setStateDialog(() {
                                    isSearching = false;
                                  });
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                setStateDialog(() {
                                  isSearching = false;
                                });
                              }
                            });
                          },
                          decoration: InputDecoration(
                              hintText: 'أدخل الرقم ليتم البحث تلقائياً...',
                              filled: true,
                              fillColor: Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none),
                              suffixIcon: isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.orange)))
                                  : const Icon(Icons.search,
                                      color: Colors.grey)),
                        ),
                        const SizedBox(height: 10),
                        if (targetData != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.orange.withOpacity(0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الاسم:',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                      Text(targetData?['name'] ?? 'مجهول',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13))
                                    ]),
                                const SizedBox(height: 4),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الشبكة:',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                      Text(targetData?['networkName'] ?? 'غير محدد',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold))
                                    ]),
                                const SizedBox(height: 4),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الرصيد لديك:',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                      Text('${targetData?['balance']} ريال',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.green))
                                    ]),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child: TextField(
                                    controller: amountController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setStateDialog(() {
                                          calculateLive();
                                        }),
                                    decoration: InputDecoration(
                                        labelText: 'المبلغ',
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.05),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide.none)))),
                            const SizedBox(width: 10),
                            Expanded(
                                flex: 1,
                                child: TextField(
                                    controller: taxController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setStateDialog(() {
                                          calculateLive();
                                        }),
                                    decoration: InputDecoration(
                                        labelText: 'ضريبة %',
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.05),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide.none)))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedPaymentMethod,
                          decoration: InputDecoration(
                              labelText: 'طريقة الدفع',
                              filled: true,
                              fillColor: Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none)),
                          items: ['نقدي', 'تحويل بنكي', 'آجل']
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: TextStyle(
                                          fontWeight: e == 'آجل'
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: e == 'آجل' ? Colors.red : null))))
                              .toList(),
                          onChanged: (v) => setStateDialog(() {
                            selectedPaymentMethod = v!;
                            calculateLive();
                          }),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                            controller: noteController,
                            decoration: InputDecoration(
                                labelText: 'ملاحظة (اختياري)',
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.05),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none))),
                        if (currentAmount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 15),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              children: [
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('المبلغ:',
                                          style: TextStyle(fontSize: 11)),
                                      Text(
                                          '${intl.NumberFormat('#,###').format(currentAmount)}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))
                                    ]),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الضريبة:',
                                          style: TextStyle(
                                              fontSize: 11, color: Colors.red)),
                                      Text(
                                          '${intl.NumberFormat('#,###').format(taxValue)}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold))
                                    ]),
                                const Divider(),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الإجمالي:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green)),
                                      Text(
                                          '${intl.NumberFormat('#,###').format(totalCost)} ريال',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                              fontSize: 16))
                                    ]),
                              ],
                            ),
                          ),
                        const SizedBox(height: 15),
                        TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock,
                                    color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.05),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none))),
                      ],
                    ),
                  ),
                  actionsPadding: const EdgeInsets.all(20),
                  actions: [
                    TextButton(
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _play('click');
                          Navigator.pop(context);
                        },
                        child: const Text('إلغاء',
                            style: TextStyle(color: Colors.grey))),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () async {
                        if (targetData == null ||
                            passwordController.text.isEmpty ||
                            currentAmount <= 0) return;
                        _play('warning');
                        showDialog(
                            context: context,
                            builder: (ctx) => Directionality(
                                textDirection: TextDirection.rtl,
                                child: AlertDialog(
                                  title: const Text('تأكيد ⚠️',
                                      style:
                                          TextStyle(fontWeight: FontWeight.bold)),
                                  content: Text(
                                      'تأكيد تحويل $currentAmount إلى ${targetData?['name']}؟'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('تراجع')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange),
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        _play('click');
                                        try {
                                          await sys.advancedSecureTransferBalance(
                                              targetPhone:
                                                  phoneController.text.trim(),
                                              targetName:
                                                  targetData?['name'] ?? 'مجهول',
                                              amount: currentAmount,
                                              taxPercentage: currentTax,
                                              note: noteController.text,
                                              paymentMethod: selectedPaymentMethod,
                                              password: passwordController.text);
                                          if (mounted) {
                                            Navigator.pop(context);
                                            _play('success');
                                            _showSnack('تم التحويل بنجاح! 🎉');
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            _play('error');
                                            _showSnack(e.toString(), isErr: true);
                                          }
                                        }
                                      },
                                      child: const Text('تأكيد',
                                          style: TextStyle(color: Colors.white)),
                                    )
                                  ],
                                )));
                      },
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      label: const Text('تنفيذ',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: CustomHeader(title: 'محفظة وكيل - ${sys.appName}'),
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
                  padding: const EdgeInsets.only(
                      top: 20, left: 20, right: 20, bottom: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('حصة المبيعات المتاحة',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Row(
                        children: [
                          Text(
                              _isBalanceHidden
                                  ? '******'
                                  : intl.NumberFormat('#,###.##')
                                      .format(sys.currentUserBalance),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 5),
                          const Text('ريال',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                          IconButton(
                              icon: Icon(
                                  _isBalanceHidden
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                  size: 20),
                              onPressed: () {
                                _play('click');
                                setState(() => _isBalanceHidden = !_isBalanceHidden);
                              }),
                        ],
                      ),
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
                    unselectedLabelColor:
                        isDark ? Colors.white70 : Colors.black54,
                    indicatorColor: Colors.orangeAccent,
                    indicatorWeight: 4,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(text: 'الرئيسية والطلبات'),
                      Tab(text: 'إدارة نقاط البيع')
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
              _buildMainDashboardTab(sys),
              _buildRequestsFromPosTab(sys),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainDashboardTab(SystemProvider sys) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickBtn(Icons.add_card, 'طلب حصة', Colors.green,
                    _showRequestBalanceDialog),
                _buildQuickBtn(Icons.send, 'تحويل للغير', Colors.orange,
                    _showAdvancedTransferDialog),
                _buildQuickBtn(Icons.receipt_long, 'الكشف المالي', Colors.blue,
                    () {
                  _play('click');
                  Navigator.pushNamed(context, '/advanced_statement_screen');
                }),
                // 🆕 زر الحسابات البنكية
                _buildQuickBtn(Icons.account_balance, 'حساباتي', Colors.deepPurple,
                    () {
                  _play('click');
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AgentBankAccountsScreen()));
                }),
              ],
            ),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: sys.getMyPendingQuotaRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox();
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox();
              }

              final requests = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('طلباتي المعلقة مع المركز الرئيسي:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    ...requests.map((req) {
                      DateTime dt = (req['timestamp'] as Timestamp).toDate();
                      String timeStr = intl.DateFormat('hh:mm a').format(dt);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            border: Border.all(color: Colors.blue.shade200),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  const Icon(Icons.access_time,
                                      size: 16, color: Colors.orange),
                                  const SizedBox(width: 5),
                                  Text('قيد المراجعة - $timeStr',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold))
                                ]),
                                Text(
                                    '${intl.NumberFormat('#,###').format(req['amount'])} ريال',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue)),
                              ],
                            ),
                            const Divider(height: 15),
                            Row(
                              children: [
                                Expanded(
                                    child: OutlinedButton.icon(
                                  onPressed: () async {
                                    _play('warning');
                                    await sys.cancelQuotaRequest(req['docId']);
                                    _showSnack('تم إلغاء الطلب بنجاح');
                                  },
                                  icon: const Icon(Icons.cancel, size: 16),
                                  label: const Text('إلغاء'),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red)),
                                )),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showRequestBalanceDialog(
                                        existingRequest: req);
                                  },
                                  icon: const Icon(Icons.edit,
                                      size: 16, color: Colors.white),
                                  label: const Text('تعديل',
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue),
                                )),
                              ],
                            )
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsFromPosTab(SystemProvider sys) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: sys.getPendingPosRechargeRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('لا توجد طلبات من نقاط البيع.',
                  style: TextStyle(color: Colors.grey)));
        }

        final requests = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, i) {
            var req = requests[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.green.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${req['userName']} يطلب:',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${req['amount']} ريال',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => _confirmRejectRequest(
                                    req['docId'], sys),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('رفض'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: ElevatedButton(
                                onPressed: () => _confirmApproveRequest(
                                    req['docId'],
                                    req['userPhone'],
                                    (req['amount'] ?? 0).toDouble(),
                                    sys,
                                    req['userName']),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                child: const Text('موافقة ✅',
                                    style: TextStyle(color: Colors.white)))),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmApproveRequest(String reqId, String posPhone, double amount,
      SystemProvider sys, String userName) {
    _play('warning');
    showDialog(
        context: context,
        builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تأكيد الموافقة',
                  style:
                      TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              content: Text('سيتم توريد $amount ريال لـ $userName.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('تراجع')),
                ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await sys.agentAcceptUserRecharge(reqId, posPhone, amount);
                      _showSnack('تمت الموافقة');
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('تأكيد',
                        style: TextStyle(color: Colors.white))),
              ],
            )));
  }

  void _confirmRejectRequest(String reqId, SystemProvider sys) {
    showDialog(
        context: context,
        builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('رفض الطلب',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              content: const Text('تأكيد رفض الطلب؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('تراجع')),
                ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await sys.rejectRechargeRequest(reqId, 'مرفوض');
                      _showSnack('تم الرفض');
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('رفض',
                        style: TextStyle(color: Colors.white))),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
