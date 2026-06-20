// lib/features/super_admin/screens/financial_center_screen.dart

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

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class FinancialCenterScreen extends StatefulWidget {
  const FinancialCenterScreen({super.key});

  @override
  State<FinancialCenterScreen> createState() => _FinancialCenterScreenState();
}

class _FinancialCenterScreenState extends State<FinancialCenterScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;
  String _searchQuery = '';

  DateTime? _startDate;
  DateTime? _endDate;

  final Set<String> _processingRequests = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<UiProvider>().playSound('click');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _can(String permission) {
    final auth = context.read<AuthProvider>();
    return auth.currentUserRole == 'super_admin' || auth.hasPermission(permission);
  }

  void _showSnack(String m, {bool isErr = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, textDirection: TextDirection.rtl, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isErr ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _generateReference(String prefix) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    String code = '';
    for (int i = 0; i < 4; i++) {
      code += chars[(random.codeUnitAt(i % random.length) + i) % chars.length];
    }
    return '$prefix-$code';
  }

  Future<void> _pickStartDate() async {
    context.read<UiProvider>().playSound('click');
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'اختر تاريخ البداية',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    context.read<UiProvider>().playSound('click');
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'اختر تاريخ النهاية',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
    }
  }

  void _resetDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    context.read<UiProvider>().playSound('click');
    _showSnack('تم إعادة تعيين الفلترة الزمنية 📅');
  }

  bool _isWithinDateRange(dynamic timestamp) {
    if (_startDate == null && _endDate == null) return true;
    if (timestamp == null) return true;
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return true;
    }
    if (_startDate != null && date.isBefore(_startDate!)) return false;
    if (_endDate != null && date.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
    return true;
  }

  void _acceptRequest(Map<String, dynamic> req, WalletProvider wallet) async {
    if (!_can('قبول طلب شحن')) return;
    context.read<UiProvider>().playSound('warning');
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
                  context.read<UiProvider>().playSound('click');
                  await wallet.adminAcceptSaaSRecharge(docId, agentPhone, quotaAmount, feeAmount);
                  if (mounted) {
                    context.read<UiProvider>().playSound('success');
                    _showSnack('تم تأكيد الشحن وإيداع الحصة بنجاح ✅');
                  }
                } catch (e) {
                  if (mounted) {
                    context.read<UiProvider>().playSound('error');
                    _showSnack('خطأ: $e', isErr: true);
                  }
                } finally {
                  if (mounted) setState(() => _processingRequests.remove(docId));
                }
              },
              child: const Text('نعم، أؤكد الاستلام', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> req, WalletProvider wallet) {
    if (!_can('رفض طلب شحن')) return;
    context.read<UiProvider>().playSound('click');
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
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('رفض طلب الشحن ❌', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('يرجى كتابة سبب الرفض (سيصل للوكيل كإشعار):', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(hintText: 'مثال: رقم المرجع غير صحيح، أو السند غير واضح...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                if (!isRejecting)
                  TextButton(onPressed: () { context.read<UiProvider>().playSound('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: isRejecting ? null : () async {
                    if (reasonController.text.trim().isEmpty) {
                      _showSnack('يرجى كتابة السبب أولاً!', isErr: true);
                      return;
                    }
                    setStateDialog(() => isRejecting = true);
                    try {
                      context.read<UiProvider>().playSound('click');
                      await wallet.rejectRechargeRequest(docId, reasonController.text);
                      if (mounted) {
                        context.read<UiProvider>().playSound('success');
                        Navigator.pop(context);
                        _showSnack('تم رفض الطلب وإشعار الوكيل.');
                      }
                    } catch (e) {
                      setStateDialog(() => isRejecting = false);
                      if (mounted) {
                        context.read<UiProvider>().playSound('error');
                        _showSnack('خطأ: $e', isErr: true);
                      }
                    }
                  },
                  child: isRejecting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTransactionReceipt(Map<String, dynamic> log, SettingsProvider settings) {
    context.read<UiProvider>().playSound('click');
    final GlobalKey receiptKey = GlobalKey();
    final double amount = double.tryParse(log['amount'].toString()) ?? 0.0;
    final bool isPositive = log['type'] == 'deposit' || log['type'] == 'income';
    final Color color = isPositive ? Colors.green : Colors.red;
    final String dateStr = log['timestamp'] != null
        ? intl.DateFormat('yyyy-MM-dd hh:mm a').format((log['timestamp'] as Timestamp).toDate())
        : 'الآن';

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
                gradient: LinearGradient(colors: [Theme.of(context).colorScheme.surface, color.withOpacity(0.08)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(isPositive ? Icons.arrow_downward : Icons.arrow_upward, size: 30, color: color)),
                  const SizedBox(height: 10),
                  Text('نظام ${settings.appName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                  Text('إشعار عملية مالية', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.5)),
                  Text(log['title'] ?? log['type'] ?? 'عملية مسجلة', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  _buildReceiptRow('المرجع', log['reference'] ?? 'لا يوجد', isBold: true),
                  _buildReceiptRow('التاريخ', dateStr),
                  _buildReceiptRow('المبلغ', '${intl.NumberFormat('#,###').format(amount)} ريال', valueColor: color, isBold: true),
                  _buildReceiptRow('الطرف الآخر', log['agentName'] ?? 'مجهول'),
                  if (log['networkName'] != null && log['networkName'] != 'غير محدد') _buildReceiptRow('الشبكة', log['networkName']),
                  if (log['paymentMethod'] != null) _buildReceiptRow('طريقة الدفع', log['paymentMethod']),
                  if (log['fee'] != null && double.tryParse(log['fee'].toString()) != 0) _buildReceiptRow('الرسوم التشغيلية', '${intl.NumberFormat('#,###').format(log['fee'])} ريال', valueColor: Colors.red),
                  if (log['reason'] != null) _buildReceiptRow('السبب', log['reason']),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.5)),
                  const Text('المركز المالي لمالك النظام', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.blue),
              tooltip: 'نسخ كنص',
              onPressed: () {
                context.read<UiProvider>().playSound('click');
                String text = "🧾 *إشعار عملية - ${settings.appName}*\n";
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
                context.read<UiProvider>().playSound('click');
                _showSnack('جاري تجهيز الصورة... ⏳');
                try {
                  RenderRepaintBoundary boundary = receiptKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                  ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                  ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                  Uint8List pngBytes = byteData!.buffer.asUint8List();
                  await Share.shareXFiles([XFile.fromData(pngBytes, mimeType: 'image/png', name: 'receipt.png')], text: 'إيصال عملية مالية - ${settings.appName}');
                  context.read<UiProvider>().playSound('success');
                } catch (e) {
                  context.read<UiProvider>().playSound('error');
                  _showSnack('حدث خطأ أثناء التقاط الصورة', isErr: true);
                }
              },
            ),
          ],
        ),
      ),
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
            child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _showManualSettlementDialog(Map<String, dynamic> agent, WalletProvider wallet) {
    if (!_can('تسوية رصيد')) return;
    context.read<UiProvider>().playSound('click');
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
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('تسوية يدوية لمحفظة: ${agent['name']}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile(
                            title: const Text('إضافة حصة 🟢', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                            value: 1,
                            groupValue: settlementType,
                            onChanged: (val) { context.read<UiProvider>().playSound('click'); setStateDialog(() => settlementType = val as int); },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile(
                            title: const Text('سحب حصة 🔴', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                            value: 2,
                            groupValue: settlementType,
                            onChanged: (val) { context.read<UiProvider>().playSound('click'); setStateDialog(() => settlementType = val as int); },
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
                  TextButton(onPressed: () { context.read<UiProvider>().playSound('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: settlementType == 1 ? Colors.green : Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: isProcessing ? null : () async {
                    if (amountController.text.isEmpty || reasonController.text.isEmpty) {
                      context.read<UiProvider>().playSound('error');
                      _showSnack('الرجاء إدخال المبلغ والسبب!', isErr: true);
                      return;
                    }
                    setStateDialog(() => isProcessing = true);
                    try {
                      double amount = double.parse(amountController.text);
                      if (settlementType == 2) amount = -amount;
                      await wallet.manualSettlement(agentPhone: agent['phone'], agentName: agent['name'], amount: amount, reason: reasonController.text);
                      if (mounted) {
                        context.read<UiProvider>().playSound('success');
                        Navigator.pop(context);
                        _showSnack('تمت التسوية بنجاح ✅');
                      }
                    } catch (e) {
                      setStateDialog(() => isProcessing = false);
                      if (mounted) {
                        context.read<UiProvider>().playSound('error');
                        _showSnack('خطأ: $e', isErr: true);
                      }
                    }
                  },
                  child: isProcessing ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تنفيذ التسوية', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDangerLimitDialog(Map<String, dynamic> agent, WalletProvider wallet) {
    if (!_can('تعديل حد الخطر')) return;
    context.read<UiProvider>().playSound('click');
    final limitController = TextEditingController(text: (agent['dangerLimit'] ?? 0).toString());
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
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
            TextButton(onPressed: () { context.read<UiProvider>().playSound('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                try {
                  await wallet.updateDangerLimit(agent['phone'], double.parse(limitController.text));
                  if (mounted) {
                    context.read<UiProvider>().playSound('success');
                    Navigator.pop(context);
                    _showSnack('تم تحديث حد الخطر بنجاح.');
                  }
                } catch (e) {
                  context.read<UiProvider>().playSound('error');
                }
              },
              child: const Text('حفظ الحد', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAgentDetails(Map<String, dynamic> agent) {
    context.read<UiProvider>().playSound('click');
    final phone = agent['phone'];
    final accountNumber = agent['accountNumber'] ?? 'غير متوفر';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تفاصيل الوكيل: ${agent['name']}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _db.collection('users').doc(phone).snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const Center(child: Text('لا توجد بيانات'));
                  }
                  final data = userSnap.data!.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'غير محدد';
                  final subStatus = data['subStatus'] ?? 'غير محدد';
                  final balance = (data['balance'] ?? 0.0).toDouble();
                  final subExpiry = data['subExpiry'] ?? 'غير محدد';
                  final role = data['role'] ?? 'agent';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('رقم الهاتف', phone),
                      _buildDetailRow('رقم الحساب', accountNumber),
                      _buildDetailRow('الدور', role),
                      _buildDetailRow('الحالة', status),
                      _buildDetailRow('حالة الاشتراك', subStatus),
                      _buildDetailRow('الرصيد الحالي', '${balance.toStringAsFixed(2)} ريال'),
                      _buildDetailRow('تاريخ انتهاء الاشتراك', subExpiry.toString()),
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final colors = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: const CustomHeader(title: 'المركز المالي'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: auth.currentUserRole == 'super_admin' ? 'مالك النظام' : 'موظف مخصص',
        balanceOrPoints: 'أرباح تشغيلية (SaaS): ${intl.NumberFormat('#,###').format(settings.adminMainBalance)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              context.read<UiProvider>().playSound('success');
              _showSnack('تم تحديث الصفحة بنجاح ✅');
            }
          },
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    child: TextField(
                      onChanged: (value) {
                        if (value.length == 1) context.read<UiProvider>().playSound('click');
                        setState(() => _searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'بحث شامل بالاسم، أو رقم الهاتف، أو المرجع...',
                        prefixIcon: Icon(Icons.search, color: colors.primary, size: isSmallScreen ? 20 : 24),
                        filled: true,
                        fillColor: colors.surface,
                        contentPadding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _pickStartDate,
                                icon: Icon(Icons.date_range, color: colors.primary, size: isSmallScreen ? 16 : 18),
                                label: Text(_startDate == null ? 'بداية الفترة' : _formatDate(_startDate!), style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 12 : 13)),
                                style: ElevatedButton.styleFrom(backgroundColor: colors.surface, padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _pickEndDate,
                                icon: Icon(Icons.date_range, color: colors.secondary, size: isSmallScreen ? 16 : 18),
                                label: Text(_endDate == null ? 'نهاية الفترة' : _formatDate(_endDate!), style: TextStyle(color: colors.secondary, fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 12 : 13)),
                                style: ElevatedButton.styleFrom(backgroundColor: colors.surface, padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                          ],
                        ),
                        if (_startDate != null || _endDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('الفلترة: ${_startDate != null ? _formatDate(_startDate!) : "أول سنة"} - ${_endDate != null ? _formatDate(_endDate!) : "اليوم"}', style: TextStyle(color: colors.onSurface, fontSize: 12)),
                                IconButton(icon: Icon(Icons.clear_all, color: colors.onSurface), tooltip: 'إعادة تعيين', onPressed: _resetDates),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: colors.primary,
                      unselectedLabelColor: colors.onSurfaceVariant,
                      indicatorColor: colors.primary,
                      indicatorWeight: 3,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 12 : 13),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download, size: isSmallScreen ? 16 : 18),
                              const SizedBox(width: 4),
                              const Text('طلبات الشحن'),
                              if (wallet.pendingRechargeRequests.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${wallet.pendingRechargeRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 10))),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet, size: isSmallScreen ? 16 : 18),
                              const SizedBox(width: 4),
                              const Text('أرصدة المحافظ'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildRechargeRequestsTab(wallet, settings, colors, isSmallScreen),
                _buildWalletsTab(wallet, settings, colors, isSmallScreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.year}/${date.month}/${date.day}';

  Widget _buildRechargeRequestsTab(WalletProvider wallet, SettingsProvider settings, ColorScheme colors, bool isSmallScreen) {
    final requests = wallet.pendingRechargeRequests.where((req) {
      final query = _searchQuery.toLowerCase();
      final matchesQuery = (req['userName']?.toString().toLowerCase().contains(query) ?? false) ||
          (req['agentName']?.toString().toLowerCase().contains(query) ?? false) ||
          (req['userPhone']?.toString().contains(query) ?? false) ||
          (req['agentPhone']?.toString().contains(query) ?? false) ||
          (req['reference']?.toString().contains(query) ?? false) ||
          (req['ref']?.toString().contains(query) ?? false);
      if (!matchesQuery) return false;
      return _isWithinDateRange(req['timestamp']);
    }).toList();

    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: requests.isEmpty ? 1 : requests.length + 1, // +1 للطلبات الحديثة
      itemBuilder: (context, index) {
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

        if (index == requests.length) {
          // 🆕 قسم الطلبات الحديثة
          return _buildRecentRequests(wallet, settings, colors, isSmallScreen);
        }

        final req = requests[index];
        final docId = req['docId'];
        final isProcessing = _processingRequests.contains(docId);
        bool isSaaS = req['type'] == 'saas_quota';
        double quotaAmount = double.tryParse(req['amount'].toString()) ?? 0;
        double feeAmount = double.tryParse(req['fee']?.toString() ?? '0') ?? 0;
        String agentName = req['userName'] ?? req['agentName'] ?? 'مجهول';
        String agentPhone = req['userPhone'] ?? req['agentPhone'] ?? '';
        String refNumber = req['reference'] ?? req['ref'] ?? 'لا يوجد';

        return Card(
          color: colors.surface,
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: colors.primary.withOpacity(0.1), child: Icon(Icons.person, color: colors.primary)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(agentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 13 : 14, color: colors.primary)),
                            Text(agentPhone, style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: colors.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Text('قيد الانتظار ⏳', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 5),
                        Text(
                          req['timestamp'] != null ? intl.DateFormat('hh:mm a').format((req['timestamp'] as Timestamp).toDate()) : 'الآن',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: isSmallScreen ? 10 : 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const Text('رقم المرجع: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: refNumber));
                          _showSnack('تم نسخ رقم المرجع');
                        },
                        child: Text(refNumber, style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                  _buildInfoRow('المبلغ المطلوب:', '${intl.NumberFormat('#,###').format(quotaAmount)} ريال', isBold: true, color: Colors.green, textColor: colors.onSurface),
                ],
                const SizedBox(height: 10),
                _buildInfoRow('البنك المحول إليه:', req['bankName'] ?? 'غير محدد', textColor: colors.onSurface),
                _buildInfoRow('مصدر التحويل:', req['transferSource'] ?? 'غير محدد', textColor: colors.onSurface),
                const SizedBox(height: 15),
                if (req['receiptBase64'] != null && (req['receiptBase64'] as String).isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () {
                      context.read<UiProvider>().playSound('click');
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
                    },
                    icon: const Icon(Icons.image, size: 18, color: Colors.green),
                    label: const Text('عرض صورة السند المرفق 📸', style: TextStyle(color: Colors.green)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () { _showSnack('الوكيل لم يقم بإرفاق صورة السند ⏳', isErr: true); },
                    icon: const Icon(Icons.image, size: 18, color: Colors.grey),
                    label: const Text('لا يوجد سند مرفق', style: TextStyle(color: Colors.grey)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (_can('قبول طلب شحن'))
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : () => _acceptRequest(req, wallet),
                          icon: isProcessing ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle, color: Colors.white, size: 18),
                          label: Text(isProcessing ? 'جاري...' : 'تأكيد وإيداع الحصة', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        ),
                      ),
                    if (_can('قبول طلب شحن') && _can('رفض طلب شحن')) const SizedBox(width: 10),
                    if (_can('رفض طلب شحن'))
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : () => _showRejectDialog(req, wallet),
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

  Widget _buildRecentRequests(WalletProvider wallet, SettingsProvider settings, ColorScheme colors, bool isSmallScreen) {
    final allRequests = wallet.pendingRechargeRequests;
    if (allRequests.isEmpty) return const SizedBox.shrink();

    // أحدث 10 طلبات
    final recent = allRequests.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('الطلبات الحديثة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 14 : 16, color: colors.onSurface)),
        ),
        ...recent.map((req) {
          final status = req['status'] ?? 'قيد الانتظار';
          final bool isApproved = status == 'approved';
          final bool isRejected = status == 'rejected';
          final Color statusColor = isApproved ? Colors.green : (isRejected ? Colors.red : Colors.orange);
          final IconData statusIcon = isApproved ? Icons.check_circle : (isRejected ? Icons.cancel : Icons.pending);
          final String statusText = isApproved ? 'مقبول' : (isRejected ? 'مرفوض' : 'معلق');

          return Card(
            color: colors.surface,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: Icon(statusIcon, color: statusColor),
              title: Text(req['userName'] ?? req['agentName'] ?? 'مجهول', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
              subtitle: Text('${req['amount']} ريال', style: TextStyle(color: colors.onSurfaceVariant)),
              trailing: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWalletsTab(WalletProvider wallet, SettingsProvider settings, ColorScheme colors, bool isSmallScreen) {
    final wallets = wallet.agentsList.where((agent) {
      final query = _searchQuery.toLowerCase();
      return (agent['name']?.toString().toLowerCase().contains(query) ?? false) || (agent['phone']?.toString().contains(query) ?? false);
    }).toList();

    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: wallets.isEmpty ? 1 : wallets.length + 1, // +1 للحركات الأخيرة
      itemBuilder: (context, index) {
        if (wallets.isEmpty) {
          return const Center(child: Text('لا يوجد وكلاء مطابقين للبحث.'));
        }

        if (index == wallets.length) {
          // 🆕 قسم الحركات الأخيرة
          return _buildRecentMovements(wallet, settings, colors, isSmallScreen);
        }

        final agent = wallets[index];
        final balance = double.parse(agent['balance'].toString());
        final dangerLimit = double.parse((agent['dangerLimit'] ?? 0).toString());
        final isDanger = balance <= dangerLimit;

        return Card(
          color: colors.surface,
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDanger ? colors.error.withOpacity(0.5) : Colors.transparent, width: 2),
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 15.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: isDanger ? colors.error.withOpacity(0.1) : colors.primary.withOpacity(0.1), child: Icon(Icons.storefront, color: isDanger ? colors.error : colors.primary)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${agent['name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 13 : 14, color: colors.onSurface)),
                            Text('${agent['phone']}', style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: colors.onSurfaceVariant)),
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
                            if (isDanger) Icon(Icons.warning_amber_rounded, color: colors.error, size: 16),
                            const SizedBox(width: 4),
                            Text('${intl.NumberFormat('#,###').format(balance)} ريال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 14 : 15, color: isDanger ? colors.error : Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (_can('تسوية رصيد'))
                      _buildIconButton(Icons.settings, 'تسوية', colors.primary, () => _showManualSettlementDialog(agent, wallet), colors.onSurface),
                    if (_can('تعديل حد الخطر'))
                      _buildIconButton(Icons.tune, 'حد الخطر', Colors.orange, () => _showDangerLimitDialog(agent, wallet), colors.onSurface),
                    _buildIconButton(Icons.info_outline, 'تفاصيل الوكيل', Colors.teal, () => _showAgentDetails(agent), colors.onSurface),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentMovements(WalletProvider wallet, SettingsProvider settings, ColorScheme colors, bool isSmallScreen) {
    final allTransactions = wallet.transactionsLedger;
    if (allTransactions.isEmpty) return const SizedBox.shrink();

    // آخر 10 حركات خلال 24 ساعة
    final now = DateTime.now();
    final recent = allTransactions.where((tx) {
      if (tx['timestamp'] == null) return false;
      final txDate = (tx['timestamp'] as Timestamp).toDate();
      return now.difference(txDate).inHours < 24;
    }).take(10).toList();

    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('الحركات الأخيرة (24 ساعة)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 14 : 16, color: colors.onSurface)),
        ),
        ...recent.map((tx) {
          final double amount = (tx['amount'] ?? 0.0).toDouble();
          final bool isPositive = amount > 0;
          final Color txColor = isPositive ? Colors.green : colors.error;

          return Card(
            color: colors.surface,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: Icon(isPositive ? Icons.arrow_downward : Icons.arrow_upward, color: txColor),
              title: Text(tx['title'] ?? tx['type'] ?? 'حركة', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
              subtitle: Text('${tx['agentName'] ?? ''} - ${tx['amount']} ريال', style: TextStyle(color: colors.onSurfaceVariant)),
              trailing: Text(tx['timestamp'] != null ? intl.DateFormat('hh:mm a').format((tx['timestamp'] as Timestamp).toDate()) : '', style: TextStyle(color: colors.onSurfaceVariant)),
            ),
          );
        }),
      ],
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
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
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

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverTabBarDelegate(this._tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).colorScheme.surface, child: _tabBar);
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}
