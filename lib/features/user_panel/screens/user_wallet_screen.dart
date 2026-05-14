// lib/features/user_panel/screens/user_wallet_screen.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

class UserWalletScreen extends StatefulWidget {
  const UserWalletScreen({super.key});

  @override
  State<UserWalletScreen> createState() => _UserWalletScreenState();
}

class _UserWalletScreenState extends State<UserWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isBalanceVisible = false;

  // شحن
  Map<String, dynamic>? _selectedNetwork; // الشبكة المختارة
  String? _selectedAgentPhone;
  List<Map<String, dynamic>> _agentBankAccounts = [];
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  String? _receiptBase64;
  final _picker = ImagePicker();

  // تحويل
  final _searchController = TextEditingController();
  final _transferAmountController = TextEditingController();
  Map<String, dynamic>? _transferTarget;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _refController.dispose();
    _searchController.dispose();
    _transferAmountController.dispose();
    super.dispose();
  }

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? colors.error : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadAgentBanks(String agentPhone) async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final banks = await sys.getAgentBankAccountsForUser(agentPhone);
    setState(() {
      _agentBankAccounts = banks;
    });
  }

  Future<void> _pickReceipt() async {
    _play('click');
    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 40, maxWidth: 600);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _receiptBase64 = base64Encode(bytes));
        _play('success');
      }
    } catch (e) {
      _showSnack('فشل تحميل الصورة', error: true);
    }
  }

  Future<void> _submitRecharge() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    if (_selectedAgentPhone == null) {
      _showSnack('اختر شبكة أولاً', error: true);
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('أدخل مبلغاً صحيحاً', error: true);
      return;
    }
    if (_refController.text.isEmpty) {
      _showSnack('أدخل رقم الحوالة', error: true);
      return;
    }
    try {
      await sys.requestRechargeFromAgent(
        agentPhone: _selectedAgentPhone!,
        amount: amount,
        paymentMethod: 'حوالة بنكية',
        reference: _refController.text,
        base64Image: _receiptBase64,
      );
      _play('success');
      setState(() {}); // ✅ تحديث فوري للشاشة
      _showSnack('تم إرسال طلب الشحن للوكيل');
      _clearRechargeForm();
    } catch (e) {
      _showSnack('فشل: $e', error: true);
    }
  }

  void _clearRechargeForm() {
    _amountController.clear();
    _refController.clear();
    setState(() {
      _receiptBase64 = null;
      _selectedNetwork = null;
      _selectedAgentPhone = null;
      _agentBankAccounts = [];
    });
  }

  void _editRechargeRequest(Map<String, dynamic> request) {
    setState(() {
      _selectedAgentPhone = request['targetPhone'];
      _amountController.text = request['amount']?.toString() ?? '';
      _refController.text = request['reference'] ?? '';
      _receiptBase64 = request['receiptBase64'];
    });
    _loadAgentBanks(request['targetPhone']);
  }

  Future<void> _cancelRechargeRequest(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الطلب'),
          content: const Text('هل تريد إلغاء طلب الشحن نهائياً؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('تراجع')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('إلغاء الطلب',
                    style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('user_recharges')
          .doc(docId)
          .delete();
      _play('success');
      setState(() {}); // تحديث فوري
      _showSnack('تم إلغاء الطلب بنجاح');
    }
  }

  Future<void> _searchForTransfer() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final result = await sys.searchUserByAccountOrName(query);
      if (!mounted) return;
      setState(() {
        _transferTarget = result;
        _isSearching = false;
      });
      if (result == null) _showSnack('لم يتم العثور على مستخدم', error: true);
    } catch (e) {
      setState(() => _isSearching = false);
      _showSnack('خطأ: $e', error: true);
    }
  }

  Future<void> _executeTransfer() async {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    if (_transferTarget == null) return;
    final amount = double.tryParse(_transferAmountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('أدخل مبلغاً صحيحاً', error: true);
      return;
    }
    final targetPhone = _transferTarget!['phone'];
    if (targetPhone == 'مخفي') {
      _showSnack('لا يمكن التحويل لأن الرقم مخفي', error: true);
      return;
    }
    try {
      await sys.transferToUser(targetPhone: targetPhone, amount: amount);
      _play('success');
      _showSnack('تم التحويل بنجاح');
      _transferAmountController.clear();
      setState(() => _transferTarget = null);
      _searchController.clear();
    } catch (e) {
      _showSnack('فشل التحويل: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final userBalance = sys.currentUserBalance;
    final accountNumber = sys.currentUserAccountNumber ?? 'غير متوفر';
    final userName = sys.currentUserName;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: const CustomHeader(title: 'محفظتي'),
      drawer: CustomUserDrawer(
        userName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.primaryContainer],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(userName,
                            style: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(Icons.settings,
                              color: colors.onPrimaryContainer),
                          onPressed: () {
                            Navigator.pushNamed(context, '/user_settings');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.credit_card, 'رقم الحساب',
                        accountNumber, onTap: () {
                      Clipboard.setData(ClipboardData(text: accountNumber));
                      _showSnack('تم نسخ رقم الحساب');
                    }, color: colors.onPrimaryContainer),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        setState(
                            () => _isBalanceVisible = !_isBalanceVisible);
                      },
                      child: _buildInfoRow(
                        Icons.account_balance_wallet,
                        'الرصيد',
                        _isBalanceVisible
                            ? '${intl.NumberFormat('#,###.##').format(userBalance)} ريال'
                            : '**** ريال',
                        trailing: Icon(
                          _isBalanceVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: colors.onPrimaryContainer,
                          size: 20,
                        ),
                        color: colors.onPrimaryContainer,
                      ),
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
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.onSurfaceVariant,
                  indicatorColor: colors.primary,
                  indicatorWeight: 4,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(
                        icon: Icon(Icons.account_balance_wallet),
                        text: 'شحن'),
                    Tab(icon: Icon(Icons.send_to_mobile), text: 'تحويل'),
                    Tab(icon: Icon(Icons.qr_code_2), text: 'QR'),
                  ],
                ),
                color: colors.surface,
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildRechargeTab(colors),
              _buildTransferTab(colors),
              _buildQRTab(accountNumber, userName, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {VoidCallback? onTap, Widget? trailing, Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.white, size: 18),
          const SizedBox(width: 10),
          Text('$label: ',
              style: TextStyle(
                  color: color?.withOpacity(0.8) ?? Colors.white70,
                  fontSize: 13)),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: color ?? Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildRechargeTab(ColorScheme colors) {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📥 طلب شحن رصيد',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface)),
            const SizedBox(height: 12),
            // القائمة المنسدلة للشبكات
            FutureBuilder<List<Map<String, dynamic>>>(
              future: sys.getActiveNetworksForRecharge(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final networks = snapshot.data ?? [];
                if (networks.isEmpty) {
                  return Text('لا توجد شبكات متاحة حالياً.',
                      style: TextStyle(color: colors.onSurfaceVariant));
                }
                return Column(
                  children: [
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedNetwork,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'اختر الشبكة',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.wifi),
                      ),
                      items: networks.map((network) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: network,
                          child: Text(
                            network['networkName'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedNetwork = val;
                          _selectedAgentPhone = val?['agentPhone'];
                          _agentBankAccounts = [];
                        });
                        if (val != null) _loadAgentBanks(val['agentPhone']);
                      },
                    ),
                    if (_selectedNetwork != null &&
                        _selectedNetwork!['agentName'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            'الوكيل: ${_selectedNetwork!['agentName']}',
                            style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12)),
                      ),
                    const SizedBox(height: 15),
                  ],
                );
              },
            ),
            // حسابات الوكيل البنكية
            if (_selectedAgentPhone != null &&
                _agentBankAccounts.isNotEmpty) ...[
              Text('حسابات الوكيل:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface)),
              const SizedBox(height: 10),
              ..._agentBankAccounts.map((bank) {
                // ✅ عرض اسم المستفيد الرباعي بدلاً من اسم الوكيل
                final beneficiary = (bank['beneficiary'] ?? '').toString();
                final note = (bank['note'] ?? '').toString();
                final hasNote =
                    note.isNotEmpty && note != 'لا توجد ملاحظات';
                final networkName =
                    (bank['networkName'] ?? '').toString();

                return Card(
                  elevation: 1,
                  color: colors.surface,
                  child: ListTile(
                    leading: Icon(Icons.account_balance,
                        color: colors.primary),
                    title: Text(bank['bankName'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (networkName.isNotEmpty)
                          Text('🌐 $networkName',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.primary)),
                        Text('رقم الحساب: ${bank['accountNumber']}'),
                        if (beneficiary.isNotEmpty)
                          Text('👤 $beneficiary',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        if (hasNote) Text('📝 $note'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.copy, color: colors.primary),
                      onPressed: () {
                        final buffer = StringBuffer();
                        buffer.writeln('🏦 ${bank['bankName']}');
                        buffer.writeln('🔢 الحساب: ${bank['accountNumber']}');
                        if (beneficiary.isNotEmpty) {
                          buffer.writeln('👤 باسم: $beneficiary');
                        }
                        if (networkName.isNotEmpty) {
                          buffer.writeln('🌐 الشبكة: $networkName');
                        }
                        if (hasNote) {
                          buffer.writeln('📝 ملاحظة: $note');
                        }
                        Clipboard.setData(
                            ClipboardData(text: buffer.toString()));
                        _showSnack('تم النسخ');
                      },
                    ),
                  ),
                );
              }),
            ] else if (_selectedAgentPhone != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('لا توجد حسابات بنكية نشطة لهذا الوكيل',
                    style: TextStyle(color: colors.onSurfaceVariant)),
              ),
            const SizedBox(height: 15),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'المبلغ (ريال)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.attach_money)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _refController,
              decoration: InputDecoration(
                  labelText: 'رقم الحوالة / المرجع',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.receipt)),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: Icon(
                  _receiptBase64 == null ? Icons.image : Icons.check_circle,
                  color: _receiptBase64 == null
                      ? colors.primary
                      : Colors.green),
              label: Text(_receiptBase64 == null
                  ? 'إرفاق صورة السند'
                  : 'تم الإرفاق'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                side: BorderSide(
                    color: _receiptBase64 == null
                        ? colors.primary
                        : Colors.green),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitRecharge,
                icon: Icon(Icons.send, color: colors.onPrimary),
                label: Text('إرسال طلب الشحن',
                    style: TextStyle(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const SizedBox(height: 25),
            // طلباتي المعلقة
            Text('📋 طلباتي المعلقة',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_recharges')
                  .where('userPhone', isEqualTo: sys.currentUserPhone)
                  .where('status', isEqualTo: 'قيد الانتظار')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final requests = snapshot.data?.docs ?? [];
                if (requests.isEmpty) {
                  return Text('لا توجد طلبات معلقة حالياً.',
                      style: TextStyle(color: colors.onSurfaceVariant));
                }
                return Column(
                  children: requests.map((doc) {
                    final req = doc.data() as Map<String, dynamic>;
                    final DateTime? ts =
                        (req['timestamp'] as Timestamp?)?.toDate();
                    final String timeStr = ts != null
                        ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(ts)
                        : '';
                    final double amount =
                        (req['amount'] ?? 0.0).toDouble();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: colors.surface,
                      child: ListTile(
                        title: Text(
                            'مبلغ: ${amount.toStringAsFixed(0)} ريال'),
                        subtitle: Text(
                            'الوكيل: ${req['targetPhone']} - $timeStr'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit,
                                  color: colors.primary),
                              onPressed: () => _editRechargeRequest({
                                'targetPhone': req['targetPhone'],
                                'amount': amount,
                                'reference': req['reference'] ?? '',
                                'receiptBase64':
                                    req['receiptBase64'] ?? '',
                              }),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete,
                                  color: colors.error),
                              onPressed: () =>
                                  _cancelRechargeRequest(doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferTab(ColorScheme colors) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💸 تحويل لشخص آخر',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'رقم الحساب أو الاسم الرباعي',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (v) => _searchForTransfer(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                    onPressed: _isSearching ? null : _searchForTransfer,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary),
                    child: Text('بحث',
                        style: TextStyle(color: colors.onPrimary))),
              ],
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(10),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_transferTarget != null) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الاسم: ${_transferTarget!['name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'رقم الحساب: ${_transferTarget!['accountNumber']}'),
                    Text(
                        'الرصيد الظاهر: ${_transferTarget!['balance']} ريال'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _transferAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ (ريال)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.money),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _executeTransfer,
                  icon: Icon(Icons.send, color: colors.onPrimary),
                  label: Text('تنفيذ التحويل',
                      style: TextStyle(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildQRTab(
      String accountNumber, String userName, ColorScheme colors) {
    final qrData = '{"acc":"$accountNumber","name":"$userName"}';
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('استقبال رصيد',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface)),
              const SizedBox(height: 5),
              Text('امسح هذا الكود لتحويل الرصيد إليك',
                  style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 25),
              RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: accountNumber));
                      _showSnack('تم نسخ رقم الحساب');
                    },
                    icon: Icon(Icons.copy, color: colors.onPrimary),
                    label: const Text('نسخ الحساب'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      _showSnack('ميزة مسح QR قيد التطوير');
                    },
                    icon: Icon(Icons.camera_alt, color: colors.primary),
                    label: const Text('مسح QR'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
