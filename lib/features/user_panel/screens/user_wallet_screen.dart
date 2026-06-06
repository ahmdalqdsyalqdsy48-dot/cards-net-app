// lib/features/user_panel/screens/user_wallet_screen.dart
// تم التحديث: استبدال SystemProvider بـ AuthProvider و WalletProvider، إصلاح كامل

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:expandable/expandable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
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

  // ========== شحن ==========
  List<Map<String, dynamic>> _allBankAccounts = [];
  bool _isLoadingAccounts = false;
  String? _accountsError;

  Map<String, Map<String, List<Map<String, dynamic>>>> _groupedByNetwork = {};

  List<String> _pinnedAccountIds = [];

  String _searchQuery = '';
  String? _filterNetworkName;

  Map<String, dynamic>? _selectedBankAccount;
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _fullNameController = TextEditingController();
  String? _receiptBase64;
  final _picker = ImagePicker();
  bool _isSubmittingRecharge = false;

  String? _editingRequestId;
  List<Map<String, dynamic>> _pendingRequests = [];

  // ========== PIN ==========
  bool _isPinSet = false;
  final _pinController = TextEditingController();
  bool _pinVisible = false;

  // ========== تحويل ==========
  final _searchController = TextEditingController();
  final _transferAmountController = TextEditingController();
  Map<String, dynamic>? _transferTarget;
  bool _isSearching = false;
  bool _isSubmittingTransfer = false;

  // ========== حجز رصيد ==========
  final _holdAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllBankAccounts();
    _loadPinnedAccounts();
    final auth = context.read<AuthProvider>();
    _fullNameController.text = auth.currentUserName;
    auth.updateLastSeen();
    _checkPinStatus();
  }

  void _checkPinStatus() {
    final auth = context.read<AuthProvider>();
    final pin = auth.currentUserPin;
    setState(() {
      _isPinSet = pin.isNotEmpty && pin.length == 6;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _refController.dispose();
    _fullNameController.dispose();
    _searchController.dispose();
    _transferAmountController.dispose();
    _pinController.dispose();
    _holdAmountController.dispose();
    super.dispose();
  }

  void _play(String type) =>
      context.read<UiProvider>().playSound(type);

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error ? Icons.error : Icons.check_circle,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, textDirection: TextDirection.rtl)),
          ],
        ),
        backgroundColor: error ? colors.error : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ========== حوار PIN ==========
  Future<String?> _requestPinDialog() async {
    _pinController.clear();
    _pinVisible = false;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('التحقق من رمز PIN'),
            content: TextField(
              controller: _pinController,
              obscureText: !_pinVisible,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'أدخل رمز PIN (6 أرقام)',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_pinVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    _play('click');
                    setDialogState(() => _pinVisible = !_pinVisible);
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _play('click');
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_pinController.text.length != 6) {
                    _showSnack('الرمز يجب أن يكون 6 أرقام', error: true);
                    return;
                  }
                  _play('click');
                  Navigator.pop(ctx, _pinController.text);
                },
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== جلب الحسابات البنكية ==========
  Future<void> _loadAllBankAccounts() async {
    setState(() {
      _isLoadingAccounts = true;
      _accountsError = null;
    });
    try {
      final wallet = context.read<WalletProvider>();
      final accounts = await wallet.getActiveBankAccountsForUserNetworks();
      if (mounted) {
        setState(() {
          _allBankAccounts = accounts;
          _groupAccounts();
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _accountsError = 'فشل تحميل الحسابات';
          _isLoadingAccounts = false;
        });
      }
    }
  }

  void _groupAccounts() {
    _groupedByNetwork.clear();
    for (var acc in _allBankAccounts) {
      final networkName = (acc['networkName'] ?? 'غير محدد').toString();
      final agentPhone = acc['agentPhone'] ?? acc['agentId'] ?? 'unknown';
      _groupedByNetwork.putIfAbsent(networkName, () => {});
      _groupedByNetwork[networkName]!.putIfAbsent(agentPhone, () => []);
      _groupedByNetwork[networkName]![agentPhone]!.add(acc);
    }
  }

  // ========== Pinned ==========
  Future<void> _loadPinnedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = prefs.getStringList('pinned_accounts') ?? [];
    setState(() => _pinnedAccountIds = pinned);
  }

  Future<void> _togglePinAccount(String docId) async {
    _play('click');
    final prefs = await SharedPreferences.getInstance();
    if (_pinnedAccountIds.contains(docId)) {
      _pinnedAccountIds.remove(docId);
      _showSnack('تم إلغاء التثبيت');
    } else {
      _pinnedAccountIds.insert(0, docId);
      if (_pinnedAccountIds.length > 3) _pinnedAccountIds = _pinnedAccountIds.sublist(0, 3);
      _showSnack('تم تثبيت الحساب في الأعلى');
    }
    await prefs.setStringList('pinned_accounts', _pinnedAccountIds);
    setState(() {});
  }

  bool _isPinned(String docId) => _pinnedAccountIds.contains(docId);

  // ========== فلترة ==========
  List<Map<String, dynamic>> get _filteredAccounts {
    return _allBankAccounts.where((acc) {
      final searchLower = _searchQuery.toLowerCase();
      if (_searchQuery.isEmpty) return _filterNetworkName == null ||
          (acc['networkName'] ?? 'غير محدد') == _filterNetworkName;

      final bankName = (acc['bankName'] ?? '').toLowerCase();
      final agentName = _getAgentNameFromCache(acc['agentPhone'] ?? acc['agentId'] ?? '').toLowerCase();
      final accountNumber = (acc['accountNumber'] ?? '').toLowerCase();
      final beneficiary = (acc['beneficiary'] ?? '').toLowerCase();
      final networkName = (acc['networkName'] ?? 'غير محدد').toLowerCase();
      final note = (acc['note'] ?? '').toLowerCase();

      final matchesSearch = bankName.contains(searchLower) ||
          agentName.contains(searchLower) ||
          accountNumber.contains(searchLower) ||
          beneficiary.contains(searchLower) ||
          networkName.contains(searchLower) ||
          note.contains(searchLower);
      final matchesNetwork = _filterNetworkName == null ||
          (acc['networkName'] ?? 'غير محدد') == _filterNetworkName;
      return matchesSearch && matchesNetwork;
    }).toList();
  }

  List<String> get _distinctNetworkNames {
    return _allBankAccounts.map((a) => (a['networkName'] ?? 'غير محدد').toString()).toSet().toList();
  }

  String _getAgentNameFromCache(String phone) {
    if (phone.isEmpty) return '';
    final wallet = context.read<WalletProvider>();
    final agent = wallet.agentsList.firstWhere(
      (a) => a['phone'] == phone,
      orElse: () => {'name': ''},
    );
    return agent['name'] ?? '';
  }

  String _getAgentNetworkName(String phone) {
    if (phone.isEmpty) return '';
    final wallet = context.read<WalletProvider>();
    final agent = wallet.agentsList.firstWhere(
      (a) => a['phone'] == phone,
      orElse: () => {'networkName': ''},
    );
    return agent['networkName'] ?? '';
  }

  // ========== رفع صورة ==========
  Future<void> _pickReceipt() async {
    _play('click');
    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 40, maxWidth: 600);
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 700000) {
          _showSnack('حجم الصورة كبير جداً، اختر صورة أصغر', error: true);
          return;
        }
        setState(() => _receiptBase64 = base64Encode(bytes));
        _play('success');
      }
    } catch (e) {
      _showSnack('فشل تحميل الصورة', error: true);
    }
  }

  // ========== تقديم طلب الشحن ==========
  Future<void> _submitRecharge() async {
    if (_isSubmittingRecharge) return;
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (_selectedBankAccount == null) {
      _showSnack('اختر حساباً بنكياً من القائمة', error: true);
      return;
    }
    final fullName = _fullNameController.text.trim();
    if (fullName.isEmpty) {
      _showSnack('أدخل اسمك الرباعي', error: true);
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('أدخل مبلغاً صحيحاً', error: true);
      return;
    }
    if (_refController.text.trim().isEmpty) {
      _showSnack('أدخل رقم الحوالة / المرجع', error: true);
      return;
    }

    if (auth.isPinEnabled) {
      final pin = await _requestPinDialog();
      if (pin == null) return;
      if (!auth.validatePin(pin)) {
        _showSnack('رمز PIN غير صحيح', error: true);
        return;
      }
    }

    setState(() => _isSubmittingRecharge = true);
    _play('start');
    try {
      final agentPhone = _selectedBankAccount!['agentPhone'] ?? _selectedBankAccount!['agentId'] ?? '';
      if (agentPhone.isEmpty) throw 'لا يمكن تحديد الوكيل';

      if (_editingRequestId != null) {
        await FirebaseFirestore.instance
            .collection('user_recharges')
            .doc(_editingRequestId)
            .delete();
        _pendingRequests.removeWhere((r) => r['docId'] == _editingRequestId);
      }

      await wallet.requestRechargeFromAgent(
        agentPhone: agentPhone,
        amount: amount,
        paymentMethod: 'حوالة بنكية',
        reference: _refController.text.trim(),
        base64Image: _receiptBase64,
        fullName: fullName,
      );
      _play('success');
      _clearRechargeForm();
      _showSnack('تم إرسال طلب الشحن بنجاح');
    } catch (e) {
      _play('error');
      _showSnack('فشل: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSubmittingRecharge = false);
    }
  }

  void _clearRechargeForm() {
    _amountController.clear();
    _refController.clear();
    _fullNameController.text = context.read<AuthProvider>().currentUserName;
    setState(() {
      _receiptBase64 = null;
      _selectedBankAccount = null;
      _editingRequestId = null;
    });
  }

  void _editRechargeRequest(Map<String, dynamic> request) {
    _play('click');
    setState(() {
      _selectedBankAccount = null;
      _amountController.text = request['amount']?.toString() ?? '';
      _refController.text = request['reference'] ?? '';
      _receiptBase64 = request['receiptBase64'];
      _fullNameController.text = request['fullName'] ?? '';
      _editingRequestId = request['docId'] ?? null;
    });
  }

  void _cancelEdit() {
    _play('click');
    _clearRechargeForm();
  }

  Future<void> _cancelRechargeRequest(String docId) async {
    _play('click');
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
      setState(() {
        _pendingRequests.removeWhere((r) => r['docId'] == docId);
      });
      _showSnack('تم إلغاء الطلب بنجاح');
    }
  }

  // ========== تحويل ==========
  Future<void> _searchForTransfer() async {
    _play('click');
    final wallet = context.read<WalletProvider>();
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final result = await wallet.searchUserByAccountOrName(query);
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
    if (_isSubmittingTransfer) return;
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (_transferTarget == null) return;
    final amount = double.tryParse(_transferAmountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('أدخل مبلغاً صحيحاً', error: true);
      return;
    }
    final targetPhone = _transferTarget!['phone'];
    if (targetPhone == auth.activeUserPhone) {
      _showSnack('لا يمكنك تحويل الرصيد لنفسك', error: true);
      return;
    }
    if (targetPhone == 'مخفي') {
      _showSnack('لا يمكن التحويل لأن الرقم مخفي', error: true);
      return;
    }
    if (amount > wallet.availableBalance) {
      _showSnack('رصيدك المتاح لا يكفي (يوجد رصيد محجوز)', error: true);
      return;
    }

    if (auth.isPinEnabled) {
      final pin = await _requestPinDialog();
      if (pin == null) return;
      if (!auth.validatePin(pin)) {
        _showSnack('رمز PIN غير صحيح', error: true);
        return;
      }
    }

    setState(() => _isSubmittingTransfer = true);
    _play('start');
    try {
      await wallet.transferToUser(targetPhone: targetPhone, amount: amount);
      _play('success');
      _showSnack('تم التحويل بنجاح');
      _transferAmountController.clear();
      setState(() => _transferTarget = null);
      _searchController.clear();
    } catch (e) {
      _play('error');
      _showSnack('فشل التحويل: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSubmittingTransfer = false);
    }
  }

  // ========== QR Scan ==========
  void _startQRScan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
    if (result != null && result is String) {
      try {
        final data = jsonDecode(result);
        if (data['acc'] != null) {
          _searchController.text = data['acc'];
          _searchForTransfer();
          _tabController.animateTo(1);
        } else {
          _showSnack('الكود لا يحتوي على رقم حساب صحيح', error: true);
        }
      } catch (e) {
        _showSnack('الكود غير صالح', error: true);
      }
    }
  }

  // ========== حجز رصيد ==========
  void _showHoldBalanceDialog() {
    final wallet = context.read<WalletProvider>();
    _holdAmountController.text = '';
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حجز جزء من الرصيد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الرصيد الكلي: ${wallet.currentUserBalance.toStringAsFixed(0)} ريال'),
              Text('المحجوز حالياً: ${wallet.heldBalance.toStringAsFixed(0)} ريال'),
              Text('المتاح: ${wallet.availableBalance.toStringAsFixed(0)} ريال'),
              const Divider(),
              TextField(
                controller: _holdAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ المراد حجزه'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  _play('click');
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(_holdAmountController.text);
                if (amount == null || amount < 0) {
                  _showSnack('المبلغ غير صحيح', error: true);
                  return;
                }
                final auth = context.read<AuthProvider>();
                if (auth.isPinEnabled) {
                  final pin = await _requestPinDialog();
                  if (pin == null) return;
                  if (!auth.validatePin(pin)) {
                    _showSnack('رمز PIN غير صحيح', error: true);
                    return;
                  }
                }
                await wallet.setHoldAmount(amount);
                Navigator.pop(ctx);
                _showSnack('تم حجز المبلغ بنجاح');
                setState(() {});
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ========== واجهة رئيسية ==========
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final colors = Theme.of(context).colorScheme;
    final availableBalance = wallet.availableBalance;
    final held = wallet.heldBalance;
    final accountNumber = wallet.currentUserAccountNumber ?? 'غير متوفر';
    final userName = auth.currentUserName;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: const CustomHeader(title: 'محفظتي'),
      drawer: CustomUserDrawer(
        userName: userName,
        phoneNumber: auth.activeUserPhone ?? '',
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
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
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
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.savings, color: colors.onPrimaryContainer),
                              tooltip: 'حجز رصيد',
                              onPressed: () {
                                _play('click');
                                _showHoldBalanceDialog();
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.settings, color: colors.onPrimaryContainer),
                              onPressed: () {
                                _play('click');
                                Navigator.pushNamed(context, '/user_settings');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.credit_card, 'رقم الحساب', accountNumber,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: accountNumber));
                          _showSnack('تم نسخ رقم الحساب');
                        },
                        color: colors.onPrimaryContainer),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        _play('click');
                        setState(() => _isBalanceVisible = !_isBalanceVisible);
                      },
                      child: _buildInfoRow(
                        Icons.account_balance_wallet,
                        'الرصيد المتاح',
                        _isBalanceVisible
                            ? '${intl.NumberFormat('#,###.##').format(availableBalance)} ريال'
                            : '**** ريال',
                        trailing: Icon(
                          _isBalanceVisible ? Icons.visibility_off : Icons.visibility,
                          color: colors.onPrimaryContainer,
                          size: 20,
                        ),
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    if (held > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('المحجوز: ${held.toStringAsFixed(0)} ريال',
                            style: TextStyle(color: Colors.yellow.shade200, fontSize: 13)),
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
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  onTap: (index) => _play('click'),
                  tabs: const [
                    Tab(icon: Icon(Icons.account_balance_wallet), text: 'شحن'),
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
              style: TextStyle(color: color?.withOpacity(0.8) ?? Colors.white70, fontSize: 13)),
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

  // ============= تبويب الشحن =============
  Widget _buildRechargeTab(ColorScheme colors) {
    final pinnedDocs = _allBankAccounts.where((a) => _isPinned(a['docId'])).toList();
    final filtered = _filteredAccounts;

    return RefreshIndicator(
      onRefresh: () async {
        _play('click');
        await _loadAllBankAccounts();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📥 طلب شحن رصيد',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.onSurface)),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'بحث في كل البيانات...',
                prefixIcon: Icon(Icons.search, color: colors.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: colors.error),
                        onPressed: () {
                          _play('click');
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            if (_distinctNetworkNames.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('الشبكات:', style: TextStyle(color: Colors.grey)),
                    ),
                    ..._distinctNetworkNames.map((network) {
                      final isSelected = _filterNetworkName == network;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(network),
                          selected: isSelected,
                          onSelected: (val) {
                            _play('click');
                            setState(() => _filterNetworkName = val ? network : null);
                          },
                          selectedColor: colors.primaryContainer,
                          checkmarkColor: colors.primary,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (pinnedDocs.isNotEmpty && _searchQuery.isEmpty && _filterNetworkName == null) ...[
              Text('⭐ مثبتة',
                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
              ...pinnedDocs.map((acc) => _buildBankAccountCard(acc, colors)),
              const Divider(),
            ],
            if (_isLoadingAccounts)
              const Center(child: CircularProgressIndicator())
            else if (_accountsError != null)
              Center(
                child: Column(
                  children: [
                    Text(_accountsError!, style: TextStyle(color: colors.error)),
                    TextButton(
                      onPressed: _loadAllBankAccounts,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            else if (filtered.isEmpty)
              Text('لا توجد حسابات تطابق البحث.',
                  style: TextStyle(color: colors.onSurfaceVariant))
            else
              ..._buildNetworkGroupedAccounts(colors),
            const SizedBox(height: 20),
            _buildRechargeForm(colors),
            const SizedBox(height: 25),
            _buildPendingRequests(colors),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNetworkGroupedAccounts(ColorScheme colors) {
    List<Widget> widgets = [];
    Map<String, Map<String, List<Map<String, dynamic>>>> filteredGroups = {};
    for (var acc in _filteredAccounts) {
      final network = (acc['networkName'] ?? 'غير محدد').toString();
      final agentPhone = acc['agentPhone'] ?? acc['agentId'] ?? 'unknown';
      filteredGroups.putIfAbsent(network, () => {});
      filteredGroups[network]!.putIfAbsent(agentPhone, () => []);
      filteredGroups[network]![agentPhone]!.add(acc);
    }

    filteredGroups.forEach((networkName, agentsMap) {
      widgets.add(
        ExpandablePanel(
          header: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(networkName,
                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                ),
                Text('${agentsMap.values.fold<int>(0, (sum, list) => sum + list.length)} حسابات',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            children: agentsMap.entries.map((agentEntry) {
              final agentPhone = agentEntry.key;
              final accounts = agentEntry.value;
              final agentName = _getAgentNameFromCache(agentPhone);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ExpandablePanel(
                  header: ListTile(
                    leading: Icon(Icons.person, color: colors.primary),
                    title: Text(agentName.isNotEmpty ? agentName : agentPhone,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${accounts.length} حسابات'),
                  ),
                  collapsed: const SizedBox.shrink(),
                  expanded: Column(
                    children: accounts.map((acc) => _buildBankAccountCard(acc, colors)).toList(),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    });
    return widgets;
  }

  Widget _buildBankAccountCard(Map<String, dynamic> acc, ColorScheme colors) {
    final isSelected = _selectedBankAccount?['docId'] == acc['docId'];
    final bankName = acc['bankName'] ?? '';
    final accountNumber = acc['accountNumber'] ?? '';
    final beneficiary = acc['beneficiary'] ?? '';
    final note = acc['note'] ?? '';
    final hasNote = note.isNotEmpty && note != 'لا توجد ملاحظات';
    final isPinned = _isPinned(acc['docId']);

    return Card(
      elevation: isSelected ? 3 : 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? colors.primary : colors.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(Icons.account_balance, color: colors.primary),
        title: Text(bankName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم الحساب: $accountNumber', textDirection: TextDirection.ltr),
            if (beneficiary.isNotEmpty) Text('المستفيد: $beneficiary'),
            if (hasNote) Text('📝 $note', style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: isPinned ? colors.primary : Colors.grey,
              ),
              onPressed: () => _togglePinAccount(acc['docId']),
              tooltip: isPinned ? 'إلغاء التثبيت' : 'تثبيت',
            ),
            IconButton(
              icon: Icon(Icons.copy, color: colors.primary),
              onPressed: () {
                _play('click');
                Clipboard.setData(ClipboardData(text: '$bankName\n$accountNumber\n$beneficiary'));
                _showSnack('تم نسخ البيانات');
              },
            ),
            Radio(
              value: acc,
              groupValue: _selectedBankAccount,
              onChanged: (val) {
                _play('click');
                setState(() => _selectedBankAccount = val);
              },
            ),
          ],
        ),
        onTap: () {
          _play('click');
          setState(() => _selectedBankAccount = acc);
        },
      ),
    );
  }

  Widget _buildRechargeForm(ColorScheme colors) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: 'اسمك الرباعي',
                prefixIcon: Icon(Icons.person, color: colors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'المبلغ (ريال)',
                prefixIcon: Icon(Icons.attach_money, color: colors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _refController,
              decoration: InputDecoration(
                labelText: 'رقم الحوالة / المرجع',
                prefixIcon: Icon(Icons.receipt, color: colors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: Icon(
                _receiptBase64 == null ? Icons.image : Icons.check_circle,
                color: _receiptBase64 == null ? colors.primary : Colors.green,
              ),
              label: Text(_receiptBase64 == null ? 'إرفاق صورة السند' : 'تم الإرفاق'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
            ),
            if (_receiptBase64 != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    base64Decode(_receiptBase64!),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingRecharge ? null : _submitRecharge,
                icon: Icon(Icons.send, color: colors.onPrimary),
                label: Text(
                  _editingRequestId != null ? 'تحديث الطلب' : 'إرسال طلب الشحن',
                  style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (_editingRequestId != null)
              TextButton.icon(
                onPressed: _cancelEdit,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('تراجع عن التعديل'),
                style: TextButton.styleFrom(foregroundColor: colors.error),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequests(ColorScheme colors) {
    final auth = context.read<AuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📋 طلباتي المعلقة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.onSurface)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('user_recharges')
              .where('userPhone', isEqualTo: auth.activeUserPhone)
              .where('status', isEqualTo: 'قيد الانتظار')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('خطأ في تحميل الطلبات', style: TextStyle(color: colors.error));
            }
            final requests = snapshot.data?.docs.map((doc) {
                  final data = Map<String, dynamic>.from(doc.data() as Map);
                  data['docId'] = doc.id;
                  return data;
                }).toList() ??
                [];
            _pendingRequests = requests;
            if (requests.isEmpty) {
              return Text('لا توجد طلبات معلقة حالياً.',
                  style: TextStyle(color: colors.onSurfaceVariant));
            }
            return Column(
              children: requests.map((req) {
                final amount = (req['amount'] ?? 0.0).toDouble();
                final ts = (req['timestamp'] as Timestamp?)?.toDate();
                final timeStr = ts != null
                    ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(ts)
                    : '';
                final agentPhone = req['targetPhone'] ?? '';
                final agentName = _getAgentNameFromCache(agentPhone);
                final networkName = _getAgentNetworkName(agentPhone);
                final fullName = req['fullName'] ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (networkName.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.wifi, size: 16, color: colors.primary),
                              const SizedBox(width: 4),
                              Text(networkName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary)),
                            ],
                          ),
                        if (fullName.isNotEmpty)
                          Text('المستفيد: $fullName',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('الوكيل: ${agentName.isNotEmpty ? agentName : agentPhone}'),
                        Text('المبلغ: ${amount.toStringAsFixed(0)} ريال'),
                        Text('التاريخ: $timeStr'),
                        const Text('الحالة: ⏳ قيد المراجعة',
                            style: TextStyle(color: Colors.orange)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: colors.primary),
                              onPressed: () => _editRechargeRequest({
                                'targetPhone': agentPhone,
                                'amount': amount,
                                'reference': req['reference'] ?? '',
                                'receiptBase64': req['receiptBase64'] ?? '',
                                'fullName': fullName,
                                'docId': req['docId'],
                              }),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: colors.error),
                              onPressed: () => _cancelRechargeRequest(req['docId']),
                            ),
                          ],
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
    );
  }

  // ============= تبويب التحويل =============
  Widget _buildTransferTab(ColorScheme colors) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💸 تحويل لشخص آخر',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.onSurface)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'رقم الحساب أو الاسم الرباعي',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (v) => _searchForTransfer(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                    onPressed: _isSearching ? null : _searchForTransfer,
                    style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
                    child: Text('بحث', style: TextStyle(color: colors.onPrimary))),
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
                    Text('رقم الحساب: ${_transferTarget!['accountNumber']}'),
                    Text('الرصيد الظاهر: ${_transferTarget!['balance']} ريال'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _transferAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ (ريال)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.money),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmittingTransfer ? null : _executeTransfer,
                  icon: Icon(Icons.send, color: colors.onPrimary),
                  label: Text('تنفيذ التحويل',
                      style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // ============= تبويب QR =============
  Widget _buildQRTab(String accountNumber, String userName, ColorScheme colors) {
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.onSurface)),
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
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
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
                      Clipboard.setData(ClipboardData(text: accountNumber));
                      _showSnack('تم نسخ رقم الحساب');
                    },
                    icon: Icon(Icons.copy, color: colors.onPrimary),
                    label: const Text('نسخ الحساب'),
                    style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _startQRScan,
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

// ==============================
// شاشة مسح QR
// ==============================
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _hasScanned = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح QR'),
        actions: [
          IconButton(
            icon: Icon(Icons.flashlight_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: Icon(Icons.flip_camera_ios),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (!_hasScanned) {
                _hasScanned = true;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    Navigator.pop(context, barcode.rawValue);
                    return;
                  }
                }
                _hasScanned = false;
              }
            },
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('وجّه الكاميرا نحو رمز QR',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
