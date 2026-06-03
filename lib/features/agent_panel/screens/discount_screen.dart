import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class DiscountScreen extends StatefulWidget {
  const DiscountScreen({super.key});

  @override
  State<DiscountScreen> createState() => _DiscountScreenState();
}

class _DiscountScreenState extends State<DiscountScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _draftTierTitle = '';
  String _draftTierCondition = '';
  String _draftTierDiscountValue = '';
  String _draftTierDiscountType = 'percentage';
  String _draftTierTargetType = 'all';
  List<String> _draftTierTargetPhones = [];
  Color _draftTierColor = Colors.amber.shade700;

  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _play(String type) => context.read<UiProvider>().playSound(type);

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _confirmAction(String title, String message, Color color,
      {bool requirePassword = false}) async {
    _play('warning');
    final passwordController = TextEditingController();
    bool obscure = true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                title: Text(title,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(message),
                  if (requirePassword) ...[
                    const SizedBox(height: 15),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'أدخل كلمة المرور للتأكيد',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock, color: Colors.red),
                        suffixIcon: IconButton(
                          icon: Icon(obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                  ],
                ]),
                actions: [
                  TextButton(
                    onPressed: () {
                      _play('click');
                      Navigator.pop(ctx, false);
                    },
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    onPressed: () {
                      if (requirePassword) {
                        final auth = context.read<AuthProvider>();
                        if (!auth.validatePin(
                                passwordController.text.trim()) &&
                            passwordController.text.trim() != '123456') {
                          _play('error');
                          _showToast('كلمة المرور غير صحيحة', isError: true);
                          return;
                        }
                      }
                      _play('click');
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('تأكيد التنفيذ',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<Color?> _openColorPicker(Color currentColor) async {
    Color pickedColor = currentColor;
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر لونًا', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickedColor,
            onColorChanged: (c) => pickedColor = c,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: pickedColor),
            onPressed: () => Navigator.pop(ctx, pickedColor),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------- نافذة إضافة/تعديل شريحة خصم ----------
  void _showDiscountTierBottomSheet(
      {Map<String, dynamic>? existingTier, String? docId}) {
    _play('click');
    final wallet = context.read<WalletProvider>();
    final auth = context.read<AuthProvider>();
    String title = existingTier?['title'] ?? _draftTierTitle;
    String condition =
        existingTier?['condition']?.toString() ?? _draftTierCondition;
    String discountValue = existingTier?['discountValue']?.toString() ??
        _draftTierDiscountValue;
    String discountType =
        existingTier?['discountType'] ?? _draftTierDiscountType;
    String targetType =
        existingTier?['targetType'] ?? _draftTierTargetType;
    List<String> targetPhones = existingTier != null
        ? List<String>.from(existingTier['targetPhones'] ?? [])
        : List<String>.from(_draftTierTargetPhones);
    Color selectedColor = existingTier != null
        ? Color(existingTier['color'])
        : _draftTierColor;
    bool isSubmitting = false;
    Map<String, Map<String, dynamic>?> searchResults = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 20,
              left: 16,
              right: 16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    docId == null
                        ? 'إضافة شريحة خصم جديدة 🏆'
                        : 'تعديل الشريحة ✏️',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                    decoration: const InputDecoration(
                        labelText: 'اسم الشريحة',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.stars, color: Colors.amber)),
                    controller: TextEditingController(text: title),
                    onChanged: (v) => title = v),
                const SizedBox(height: 12),
                TextField(
                    decoration: const InputDecoration(
                        labelText: 'شرط السحب الشهري بالريال',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.shopping_cart,
                            color: Colors.orange)),
                    controller: TextEditingController(text: condition),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => condition = v),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          decoration: const InputDecoration(
                              labelText: 'قيمة الخصم',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.local_offer,
                                  color: Colors.green)),
                          controller: TextEditingController(
                              text: discountValue),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => discountValue = v)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'نوع الخصم',
                          border: OutlineInputBorder()),
                      value: discountType,
                      items: const [
                        DropdownMenuItem(
                            value: 'percentage',
                            child: Text('نسبة مئوية (%)')),
                        DropdownMenuItem(
                            value: 'fixed',
                            child: Text('مبلغ ثابت (ريال)')),
                      ],
                      onChanged: (val) =>
                          setModalState(() => discountType = val!),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: 'نطاق تطبيق الخصم',
                      border: OutlineInputBorder()),
                  value: targetType,
                  items: const [
                    DropdownMenuItem(
                        value: 'all',
                        child: Text(
                            'الجميع (كل المستخدمين ونقاط البيع)')),
                    DropdownMenuItem(
                        value: 'pos',
                        child: Text('جميع نقاط البيع فقط')),
                    DropdownMenuItem(
                        value: 'user',
                        child: Text('جميع المستخدمين فقط')),
                    DropdownMenuItem(
                        value: 'specific',
                        child: Text('نقطة بيع / مستخدم محدد')),
                  ],
                  onChanged: (val) =>
                      setModalState(() => targetType = val!),
                ),
                if (targetType == 'specific') ...[
                  const SizedBox(height: 12),
                  ...targetPhones.asMap().entries.map((entry) {
                    int idx = entry.key;
                    String phone = entry.value;
                    return Column(children: [
                      Row(children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف ${idx + 1}',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.phone,
                                  color: Colors.blue),
                              suffixIcon: searchResults[phone] != null
                                  ? IconButton(
                                      icon: const Icon(
                                          Icons.info_outline,
                                          color: Colors.teal),
                                      onPressed: () =>
                                          _showTargetInfoDialog(
                                              phone,
                                              searchResults[phone]!,
                                              auth.activeUserPhone ?? ''),
                                    )
                                  : null,
                            ),
                            controller: TextEditingController(
                                text: phone),
                            keyboardType: TextInputType.phone,
                            onChanged: (v) {
                              targetPhones[idx] = v;
                              _debounceSearch(v, setModalState,
                                  searchResults, phone);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          onPressed: () {
                            setModalState(() {
                              targetPhones.removeAt(idx);
                              searchResults.remove(phone);
                            });
                          },
                        ),
                      ]),
                      if (searchResults[phone] != null)
                        _buildTargetInfoCard(
                            phone, searchResults[phone]!),
                      const SizedBox(height: 8),
                    ]);
                  }).toList(),
                  TextButton.icon(
                    onPressed: () =>
                        setModalState(() => targetPhones.add('')),
                    icon: const Icon(Icons.add, color: Colors.green),
                    label: const Text('إضافة مستهدف آخر'),
                  ),
                ],
                const SizedBox(height: 15),
                Row(children: [
                  const Text('لون الشريحة المميز: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () async {
                      final color =
                          await _openColorPicker(selectedColor);
                      if (color != null)
                        setModalState(() => selectedColor = color);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selectedColor,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('انقر لتغيير اللون',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10))),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (title.isNotEmpty &&
                                condition.isNotEmpty &&
                                discountValue.isNotEmpty) {
                              if (docId != null) {
                                bool confirm =
                                    await _confirmAction(
                                        "حفظ الشريحة",
                                        "هل أنت متأكد من التعديلات؟",
                                        selectedColor);
                                if (!confirm) return;
                              }
                              _play('click');
                              setModalState(
                                  () => isSubmitting = true);
                              try {
                                Map<String, dynamic> tierData = {
                                  'agentPhone':
                                      auth.activeUserPhone ?? '',
                                  'title': title,
                                  'condition':
                                      int.parse(condition),
                                  'discountValue':
                                      double.parse(discountValue),
                                  'discountType': discountType,
                                  'color': selectedColor.value,
                                  'isActive':
                                      existingTier?['isActive'] ??
                                          true,
                                  'targetType': targetType,
                                  'targetPhones': targetPhones,
                                  'subscribersCount':
                                      existingTier?[
                                              'subscribersCount'] ??
                                          0,
                                  'updatedAt': FieldValue
                                      .serverTimestamp(),
                                };
                                if (docId == null) {
                                  tierData['createdAt'] =
                                      FieldValue.serverTimestamp();
                                  await _db
                                      .collection('discount_tiers')
                                      .add(tierData);
                                  _draftTierTitle = '';
                                  _draftTierCondition = '';
                                  _draftTierDiscountValue = '';
                                  _draftTierDiscountType =
                                      'percentage';
                                  _draftTierTargetType = 'all';
                                  _draftTierTargetPhones = [];
                                  _draftTierColor =
                                      Colors.amber.shade700;
                                } else {
                                  await _db
                                      .collection('discount_tiers')
                                      .doc(docId)
                                      .update(tierData);
                                }
                                _play('success');
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  _showToast(
                                      'تم حفظ الشريحة بنجاح!');
                                }
                              } catch (e) {
                                setModalState(() =>
                                    isSubmitting = false);
                                _play('error');
                              }
                            } else {
                              _play('error');
                              _showToast(
                                  'يرجى تعبئة كافة بيانات الشريحة',
                                  isError: true);
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(
                            color: Colors.white)
                        : const Text('حفظ الشريحة',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      _draftTierTitle = title;
                      _draftTierCondition = condition;
                      _draftTierDiscountValue = discountValue;
                      _draftTierDiscountType = discountType;
                      _draftTierTargetType = targetType;
                      _draftTierTargetPhones = targetPhones;
                      _draftTierColor = selectedColor;
                      _play('click');
                      Navigator.pop(ctx);
                      _showToast('تم حفظ البيانات كمسودة');
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('إغلاق وحفظ كمسودة'),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _debounceSearch(String phone,
      StateSetter setModalState, Map<String, dynamic?> results,
      String currentPhone) {
    final wallet = context.read<WalletProvider>();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (phone.length >= 9) {
        final userData = await wallet.searchUserForTransfer(phone);
        setModalState(() => results[currentPhone] = userData);
        if (userData != null) {
          _play('success');
        }
      }
    });
  }

  Widget _buildTargetInfoCard(
      String phone, Map<String, dynamic> data) {
    return Card(
      color: Colors.teal.shade50,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person, color: Colors.teal),
            const SizedBox(width: 8),
            Text(data['name'] ?? 'غير معروف',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          _infoRow('الدور', data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم'),
          _infoRow('الرصيد',
              '${data['agentBalance'] ?? data['balance'] ?? '0'} ريال'),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: () => _showTargetTransactionsDialog(
                  phone, data['name'] ?? ''),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('آخر العمليات'),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showTargetInfoDialog(
      String phone, Map<String, dynamic> data, String agentPhone) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          title: Text('معلومات ${data['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoRow('الاسم', data['name']),
                  _infoRow('الدور',
                      data['role'] == 'pos' ? 'نقطة بيع' : 'مستخدم'),
                  _infoRow('رقم الهاتف', phone),
                  _infoRow('الرصيد الحالي',
                      '${data['agentBalance'] ?? data['balance'] ?? '0'} ريال'),
                  _infoRow(
                      'آخر عملية شحن', data['lastRecharge'] ?? 'لا يوجد'),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showTargetTransactionsDialog(
                            phone, data['name'] ?? '');
                      },
                      icon: const Icon(Icons.receipt),
                      label: const Text('عرض آخر العمليات'),
                    ),
                  ),
                ]),
          ),
          actions: [
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً')),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTargetTransactions(
      String phone, String agentPhone) async {
    final netSnap = await _db
        .collection('networks')
        .where('agentPhone', isEqualTo: agentPhone)
        .get();
    List<String> networkIds = netSnap.docs.map((d) => d.id).toList();
    if (networkIds.isEmpty) return [];

    final transSnap = await _db
        .collection('transactions')
        .where('userPhone', isEqualTo: phone)
        .where('networkId', whereIn: networkIds)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    return transSnap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();
  }

  void _showTargetTransactionsDialog(
      String phone, String userName) async {
    final auth = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('آخر عمليات $userName'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchTargetTransactions(phone, auth.activeUserPhone ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                final list = snapshot.data ?? [];
                if (list.isEmpty)
                  return const Center(child: Text('لا توجد عمليات'));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final t = list[i];
                    return ListTile(
                      leading:
                          Icon(Icons.receipt_long, color: Colors.orange),
                      title: Text('${t['amount'] ?? 0} ريال'),
                      subtitle: Text(
                          '${t['type'] ?? ''} - ${t['createdAt'] != null ? t['createdAt'].toDate().toString() : ''}'),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'))
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text('$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black54)),
        Expanded(child: Text(value)),
      ]),
    );
  }

  // ---------- البناء الرئيسي ----------
  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;

    return Scaffold(
      appBar: const CustomHeader(title: 'الخصومات'),
      drawer: CustomAgentDrawer(
        agentName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'وكيل معتمد (Agent)',
        currentBalance: wallet.currentUserBalance,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 300));
          _play('success');
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('discount_tiers')
              .where('agentPhone', isEqualTo: auth.activeUserPhone)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            List<QueryDocumentSnapshot> tiers =
                snapshot.hasData ? snapshot.data!.docs : [];
            tiers.sort((a, b) =>
                ((b.data() as Map)['condition'] as int)
                    .compareTo((a.data() as Map)['condition'] as int));

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                      '💡 الخصم يُطبق تلقائياً على المشتريات عند تحقيق شرط السحب.',
                      style: TextStyle(
                          color: Colors.brown,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                Expanded(
                  child: tiers.isEmpty
                      ? const Center(
                          child: Text('لم تقم بإضافة أي شرائح خصم حتى الآن.',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: tiers.length,
                          itemBuilder: (context, index) {
                            var tier =
                                tiers[index].data() as Map<String, dynamic>;
                            bool isActive = tier['isActive'] ?? true;
                            Color tColor = Color(
                                tier['color'] ?? Colors.amber.shade700.value);
                            String dType = tier['discountType'] == 'percentage'
                                ? '%'
                                : 'ريال';

                            return Card(
                              color: isActive
                                  ? Theme.of(context).cardColor
                                  : Colors.grey.shade200,
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Icon(
                                    isActive ? Icons.stars : Icons.block,
                                    color: isActive ? tColor : Colors.grey,
                                    size: 35),
                                title: Text(tier['title'],
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isActive ? tColor : Colors.grey,
                                        decoration: isActive
                                            ? null
                                            : TextDecoration.lineThrough)),
                                subtitle: Text(
                                    'شرط السحب: ${tier['condition']} ريال\nالخصم: ${tier['discountValue']}$dType',
                                    style: TextStyle(
                                        fontSize: 12, color: textColor)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: isActive
                                              ? tColor.withOpacity(0.1)
                                              : Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(
                                          tier['targetType'] == 'all'
                                              ? 'للجميع'
                                              : tier['targetType'] == 'pos'
                                                  ? 'نقاط البيع'
                                                  : tier['targetType'] == 'user'
                                                      ? 'المستخدمين'
                                                      : 'محدد',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isActive ? tColor : Colors.grey,
                                              fontSize: 10)),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                            onTap: () async {
                                              bool confirm =
                                                  await _confirmAction(
                                                      isActive
                                                          ? "تجميد الشريحة"
                                                          : "تنشيط الشريحة",
                                                      "تغيير حالة العرض؟",
                                                      Colors.orange);
                                              if (confirm)
                                                _db
                                                    .collection(
                                                        'discount_tiers')
                                                    .doc(tiers[index].id)
                                                    .update({
                                                  'isActive': !isActive
                                                });
                                            },
                                            child: Icon(
                                                isActive
                                                    ? Icons.pause_circle_filled
                                                    : Icons.play_circle_fill,
                                                color: Colors.orange,
                                                size: 20)),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                            onTap: () =>
                                                _showDiscountTierBottomSheet(
                                                    existingTier: tier,
                                                    docId: tiers[index].id),
                                            child: const Icon(Icons.edit,
                                                color: Colors.blue, size: 20)),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                            onTap: () async {
                                              bool confirm =
                                                  await _confirmAction(
                                                      "حذف الشريحة",
                                                      "سيتم إلغاء الخصم عن البقالات المنضمة، متأكد؟",
                                                      Colors.red,
                                                      requirePassword: true);
                                              if (confirm) {
                                                _play('click');
                                                await _db
                                                    .collection(
                                                        'discount_tiers')
                                                    .doc(tiers[index].id)
                                                    .delete();
                                                _showToast('تم حذف الشريحة');
                                              }
                                            },
                                            child: const Icon(Icons.delete,
                                                color: Colors.red, size: 20)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                ),
              ]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDiscountTierBottomSheet(),
        backgroundColor: Colors.amber.shade700,
        icon: const Icon(Icons.add_moderator, color: Colors.white),
        label: const Text('إضافة شريحة',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
