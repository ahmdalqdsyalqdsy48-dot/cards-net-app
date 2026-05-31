import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/agent_admin_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class AdvancedResetScreen extends StatefulWidget {
  const AdvancedResetScreen({super.key});

  @override
  State<AdvancedResetScreen> createState() => _AdvancedResetScreenState();
}

class _AdvancedResetScreenState extends State<AdvancedResetScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _targetData;
  String? _targetPhone;
  String? _targetRole;
  bool _isSearching = false;

  bool _resetBalance = false;
  bool _resetNetworks = false;
  bool _resetTransactions = false;
  bool _resetCards = false;
  bool _resetBankAccounts = false;
  bool _resetSubscriptions = false;
  bool _deleteAccount = false;
  bool _renameAccount = false;
  bool _mergeRecords = false;
  bool _exportBeforeDelete = false;

  final TextEditingController _renameController = TextEditingController();
  final TextEditingController _mergeFromController = TextEditingController();
  final TextEditingController _mergeToController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscurePin = true;
  bool _usePinInstead = true;

  bool _isProcessing = false;
  String? _previewResult;

  List<Map<String, dynamic>> _lastTransactions = [];
  Map<String, dynamic>? _extraData;

  @override
  void dispose() {
    _searchController.dispose();
    _renameController.dispose();
    _mergeFromController.dispose();
    _mergeToController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _targetData = null;
        _targetPhone = null;
        _targetRole = null;
        _lastTransactions = [];
        _extraData = null;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final agentAdmin = context.read<AgentAdminProvider>();
      final result = await agentAdmin.searchUserByAdmin(query.trim());
      if (!mounted) return;

      if (result != null) {
        final phone = result['phone'] ?? '';
        final role = result['role'] ?? 'user';
        setState(() {
          _targetData = result;
          _targetPhone = phone;
          _targetRole = role;
        });
        _loadLastTransactions(phone);
        _loadExtraData(phone, role);
      } else {
        setState(() {
          _targetData = null;
          _targetPhone = null;
          _targetRole = null;
          _lastTransactions = [];
          _extraData = null;
        });
      }
    } catch (e) {
      _showSnack('خطأ في البحث: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _loadLastTransactions(String phone) async {
    final snap = await FirebaseFirestore.instance
        .collection('transactions')
        .where('fromPhone', isEqualTo: phone)
        .orderBy('timestamp', descending: true)
        .limit(7)
        .get();
    if (mounted) {
      setState(() {
        _lastTransactions = snap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();
      });
    }
  }

  Future<void> _loadExtraData(String phone, String role) async {
    Map<String, dynamic> extra = {};
    if (role == 'agent') {
      final netsSnap = await FirebaseFirestore.instance
          .collection('networks')
          .where('agentPhone', isEqualTo: phone)
          .get();
      int activeNets = 0, stoppedNets = 0;
      for (var d in netsSnap.docs) {
        if (d['isActive'] == true) activeNets++; else stoppedNets++;
      }
      extra['activeNetworks'] = activeNets;
      extra['stoppedNetworks'] = stoppedNets;

      final posSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('pos_agents', arrayContains: phone)
          .get();
      int activePos = 0, stoppedPos = 0;
      for (var d in posSnap.docs) {
        if (d['status'] == 'نشط') activePos++; else stoppedPos++;
      }
      extra['activePos'] = activePos;
      extra['stoppedPos'] = stoppedPos;
    } else if (role == 'user' || role == 'pos') {
      final wallets = _targetData?['wallets'] as Map<String, dynamic>? ?? {};
      double total = wallets.values.fold(0.0, (a, b) => a + (b as num).toDouble());
      extra['totalBalance'] = total;
      extra['wallets'] = wallets;
    }
    if (mounted) setState(() => _extraData = extra);
  }

  Future<void> _preview() async {
    context.read<UiProvider>().playSound('click');
    if (_targetPhone == null) {
      _showSnack('الرجاء البحث عن مستخدم أولاً', error: true);
      return;
    }
    setState(() => _previewResult = null);
    final agentAdmin = context.read<AgentAdminProvider>();
    try {
      final res = await agentAdmin.previewResetImpact(
        phone: _targetPhone!,
        accountNumber: '',
        targetType: _targetRole == 'agent' ? 'agent' : 'user',
        options: _collectOptions(),
      );
      setState(() => _previewResult = res);
    } catch (e) {
      setState(() => _previewResult = 'خطأ: $e');
    }
  }

  Future<bool> _showAuthDialog() async {
    final auth = context.read<AuthProvider>();
    final pinController = TextEditingController();
    final passController = TextEditingController();

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد هوية المشرف', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_usePinInstead ? 'PIN' : 'كلمة المرور',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: _usePinInstead,
                      onChanged: (v) {
                        setState(() => _usePinInstead = v);
                        setDialogState(() => _usePinInstead = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_usePinInstead)
                  TextField(
                    controller: pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'رمز PIN (6 أرقام)',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() => _obscurePin = !_obscurePin);
                          setDialogState(() => _obscurePin = !_obscurePin);
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  )
                else
                  TextField(
                    controller: passController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                          setDialogState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  bool ok = false;
                  if (_usePinInstead) {
                    ok = auth.validatePin(pinController.text);
                  } else {
                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(auth.activeUserPhone)
                        .get();
                    ok = (doc.data()?['password'] ?? '') == passController.text;
                  }
                  Navigator.pop(ctx, ok);
                },
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ),
      ),
    ) == true;
  }

  Future<void> _execute() async {
    context.read<UiProvider>().playSound('click');
    if (_targetPhone == null) {
      _showSnack('الرجاء البحث عن مستخدم أولاً', error: true);
      return;
    }

    final bool verified = await _showAuthDialog();
    if (!verified) {
      _showSnack('فشل التحقق من الهوية', error: true);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final agentAdmin = context.read<AgentAdminProvider>();
      await agentAdmin.executeReset(
        phone: _targetPhone!,
        accountNumber: '',
        targetType: _targetRole == 'agent' ? 'agent' : 'user',
        options: _collectOptions(),
        adminPassword: '',
        renameTo: _renameAccount ? _renameController.text.trim() : null,
        mergeFrom: _mergeRecords ? _mergeFromController.text.trim() : null,
        mergeTo: _mergeRecords ? _mergeToController.text.trim() : null,
        exportBeforeDelete: _exportBeforeDelete,
      );
      context.read<UiProvider>().playSound('success');
      _showSnack('تم تنفيذ الإجراء بنجاح');
      _clearForm();
    } catch (e) {
      context.read<UiProvider>().playSound('error');
      _showSnack('فشل: $e', error: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Map<String, dynamic> _collectOptions() {
    return {
      'resetBalance': _resetBalance,
      'resetNetworks': _resetNetworks,
      'resetTransactions': _resetTransactions,
      'resetCards': _resetCards,
      'resetBankAccounts': _resetBankAccounts,
      'resetSubscriptions': _resetSubscriptions,
      'deleteAccount': _deleteAccount,
      'renameAccount': _renameAccount,
      'mergeRecords': _mergeRecords,
    };
  }

  void _clearForm() {
    _searchController.clear();
    setState(() {
      _targetData = null;
      _targetPhone = null;
      _targetRole = null;
      _lastTransactions = [];
      _extraData = null;
      _resetBalance = false;
      _resetNetworks = false;
      _resetTransactions = false;
      _resetCards = false;
      _resetBankAccounts = false;
      _resetSubscriptions = false;
      _deleteAccount = false;
      _renameAccount = false;
      _mergeRecords = false;
      _exportBeforeDelete = false;
      _renameController.clear();
      _mergeFromController.clear();
      _mergeToController.clear();
      _previewResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: const CustomHeader(title: 'التحكم الشامل – المحقق الذكي'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام',
        balanceOrPoints: 'أرباح: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () async {
            if (_searchController.text.isNotEmpty) {
              await _search(_searchController.text);
            }
            await Future.delayed(const Duration(milliseconds: 300));
            context.read<UiProvider>().playSound('success');
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ابحث عن المستهدف', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'رقم الهاتف أو رقم الحساب...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: colors.error),
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => _search(v),
                ),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 16),

                if (_targetData != null) ...[
                  _buildInfoCard(colors),
                  const SizedBox(height: 20),

                  if (_lastTransactions.isNotEmpty) ...[
                    Text('آخر العمليات', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                    const SizedBox(height: 8),
                    ..._lastTransactions.take(7).map((txn) => Card(
                          child: ListTile(
                            title: Text(txn['title'] ?? 'عملية'),
                            subtitle: Text('${txn['amount']} ريال'),
                            trailing: Text(txn['timestamp'] != null
                                ? (txn['timestamp'] as Timestamp).toDate().toString().substring(0, 10)
                                : ''),
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],

                  Text('الإجراءات المتاحة', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                  const SizedBox(height: 8),
                  _buildActionCheckboxes(),
                  const SizedBox(height: 20),

                  Text('خيارات متقدمة', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
                  const SizedBox(height: 8),
                  _buildCheckbox('إعادة تسمية الحساب', _renameAccount, (v) => setState(() => _renameAccount = v!)),
                  if (_renameAccount)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _renameController,
                        decoration: const InputDecoration(labelText: 'الاسم الجديد', border: OutlineInputBorder()),
                      ),
                    ),
                  _buildCheckbox('دمج سجلات', _mergeRecords, (v) => setState(() => _mergeRecords = v!)),
                  if (_mergeRecords) ...[
                    TextField(controller: _mergeFromController, decoration: const InputDecoration(labelText: 'رقم هاتف المصدر', border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    TextField(controller: _mergeToController, decoration: const InputDecoration(labelText: 'رقم هاتف الهدف', border: OutlineInputBorder())),
                  ],
                  _buildCheckbox('تصدير البيانات قبل الحذف', _exportBeforeDelete, (v) => setState(() => _exportBeforeDelete = v!)),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _preview,
                          icon: const Icon(Icons.preview),
                          label: const Text('معاينة التأثير'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _execute,
                          icon: _isProcessing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.warning),
                          label: Text(_isProcessing ? 'جاري التنفيذ...' : 'تنفيذ الإجراء'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_previewResult != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_previewResult!, style: TextStyle(color: colors.onSurfaceVariant)),
                    ),
                ] else if (!_isSearching && _searchController.text.isNotEmpty)
                  Text('لم يتم العثور على المستخدم', style: TextStyle(color: colors.error)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colors) {
    final data = _targetData!;
    final role = _targetRole!;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('الاسم', data['name'] ?? ''),
            _infoRow('رقم الهاتف', _targetPhone ?? ''),
            _infoRow('رقم الحساب', data['accountNumber'] ?? ''),
            _infoRow('الدور', role == 'agent' ? 'وكيل' : role == 'pos' ? 'نقطة بيع' : role == 'user' ? 'مستخدم' : role),
            if (role == 'agent') ...[
              _infoRow('الرصيد', '${(data['balance'] ?? 0).toString()} ريال'),
              if (_extraData != null) ...[
                Text('الشبكات: نشطة ${_extraData!['activeNetworks'] ?? 0} / موقوفة ${_extraData!['stoppedNetworks'] ?? 0}'),
                Text('نقاط البيع: نشطة ${_extraData!['activePos'] ?? 0} / موقوفة ${_extraData!['stoppedPos'] ?? 0}'),
              ],
            ] else if (role == 'user' || role == 'pos') ...[
              if (_extraData != null) ...[
                _infoRow('إجمالي الرصيد', '${_extraData!['totalBalance'] ?? 0} ريال'),
                if ((_extraData!['wallets'] as Map?)?.isNotEmpty ?? false)
                  Text('الأرصدة حسب الوكلاء:', style: TextStyle(color: colors.onSurface)),
                ...(_extraData!['wallets'] as Map).entries.map((e) => Text('${e.key}: ${e.value} ريال')),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActionCheckboxes() {
    return Column(
      children: [
        _buildCheckbox('تصفير الرصيد', _resetBalance, (v) => setState(() => _resetBalance = v!)),
        if (_targetRole == 'agent') ...[
          _buildCheckbox('حذف الشبكات', _resetNetworks, (v) => setState(() => _resetNetworks = v!)),
          _buildCheckbox('حذف الحسابات البنكية', _resetBankAccounts, (v) => setState(() => _resetBankAccounts = v!)),
          _buildCheckbox('حذف الاشتراكات والباقات', _resetSubscriptions, (v) => setState(() => _resetSubscriptions = v!)),
        ],
        _buildCheckbox('حذف السجلات المالية', _resetTransactions, (v) => setState(() => _resetTransactions = v!)),
        _buildCheckbox('حذف الكروت المشتراة', _resetCards, (v) => setState(() => _resetCards = v!)),
        _buildCheckbox('حذف الحساب بالكامل (نهائي)', _deleteAccount, (v) => setState(() => _deleteAccount = v!)),
      ],
    );
  }

  Widget _buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
