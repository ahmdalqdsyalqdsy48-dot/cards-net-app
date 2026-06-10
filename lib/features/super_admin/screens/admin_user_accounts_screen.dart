import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/agent_admin_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class AdminUserAccountsScreen extends StatefulWidget {
  const AdminUserAccountsScreen({super.key});

  @override
  State<AdminUserAccountsScreen> createState() =>
      _AdminUserAccountsScreenState();
}

class _AdminUserAccountsScreenState extends State<AdminUserAccountsScreen> {
  // ----- قائمة المستخدمين -----
  String _searchQuery = '';
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoading = true;
  String _selectedRoleFilter = 'الكل';

  // ----- بطاقة تفصيلية / إعادة تعيين -----
  Map<String, dynamic>? _selectedUserData;
  String? _selectedUserPhone;
  String? _selectedUserRole;
  bool _isSearchingUser = false;

  List<Map<String, dynamic>> _lastTransactions = [];
  Map<String, dynamic>? _extraData;

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
  final TextEditingController _advancedSearchController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscurePin = true;
  bool _usePinInstead = true;

  bool _isProcessing = false;
  String? _previewResult;

  final List<String> _roleFilters = [
    'الكل',
    'مستخدم',
    'وكيل',
    'بقالة',
    'موظف',
    'مدير عام',
  ];

  Map<String, String> _roleFilterMap = {
    'الكل': 'all',
    'مستخدم': 'user',
    'وكيل': 'agent',
    'بقالة': 'pos',
    'موظف': 'staff',
    'مدير عام': 'super_admin',
  };

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _renameController.dispose();
    _mergeFromController.dispose();
    _mergeToController.dispose();
    _advancedSearchController.dispose();
    super.dispose();
  }

  void _play(String type) => context.read<UiProvider>().playSound(type);
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

  // ========== قائمة المستخدمين ==========
  void _loadUsers() {
    final agentAdmin = context.read<AgentAdminProvider>();
    setState(() {
      _allUsers = agentAdmin.getAllUsersWithAccountDetails();
      _isLoading = false;
    });
  }

  Future<void> _generateMissingAccounts() async {
    final agentAdmin = context.read<AgentAdminProvider>();
    _play('click');
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('توليد الأرقام المفقودة'),
            content: const Text('سيتم توليد أرقام حسابات لجميع المستخدمين الذين ليس لديهم رقم حساب. هل تريد المتابعة؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('توليد')),
            ],
          ),
        ),
      );
      if (confirm != true) return;

      int count = await agentAdmin.adminGenerateMissingAccountNumbers();
      _play('success');
      _showSnack('تم توليد $count رقم حساب جديد.');
      _loadUsers();
    } catch (e) {
      _play('error');
      _showSnack('فشل: $e', error: true);
    }
  }

  Future<void> _editAccountNumber(Map<String, dynamic> user) async {
    final controller = TextEditingController(text: user['accountNumber']);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل رقم حساب ${user['name']}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'رقم الحساب الجديد', border: OutlineInputBorder()),
              validator: (val) => (val == null || val.isEmpty) ? 'أدخل رقماً' : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result != null && result != user['accountNumber']) {
      final agentAdmin = context.read<AgentAdminProvider>();
      try {
        await agentAdmin.adminUpdateUserAccountNumber(user['phone'], result);
        _play('success');
        _showSnack('تم تغيير الرقم إلى $result');
        _loadUsers();
      } catch (e) {
        _play('error');
        _showSnack('$e', error: true);
      }
    }
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    final agentAdmin = context.read<AgentAdminProvider>();
    final bool ban = !(user['isBanned'] ?? false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(ban ? 'حظر ${user['name']}' : 'فك حظر ${user['name']}'),
          content: Text(ban ? 'هل أنت متأكد من حظر هذا الحساب؟' : 'هل تريد فك الحظر عن هذا الحساب؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ban ? Colors.red : Colors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ban ? 'حظر' : 'فك الحظر', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      try {
        await agentAdmin.adminToggleUserBan(user['phone'], ban);
        _play('success');
        _showSnack(ban ? 'تم حظر الحساب' : 'تم فك الحظر');
        _loadUsers();
      } catch (e) {
        _play('error');
        _showSnack('$e', error: true);
      }
    }
  }

  // ========== بطاقة تفصيلية (منقولة من AdvancedResetScreen) ==========
  Future<void> _selectUser(Map<String, dynamic> user) async {
    _play('click');
    final phone = user['phone'] ?? '';
    final role = (user['role'] ?? 'user').toString();
    setState(() {
      _selectedUserData = user;
      _selectedUserPhone = phone;
      _selectedUserRole = role;
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
    _loadLastTransactions(phone);
    _loadExtraData(phone, role);
  }

  void _closeDetailView() {
    setState(() {
      _selectedUserData = null;
      _selectedUserPhone = null;
      _selectedUserRole = null;
      _lastTransactions = [];
      _extraData = null;
    });
  }

  Future<void> _loadLastTransactions(String phone) async {
    final snap = await FirebaseFirestore.instance
        .collection('transactions')
        .where('fromPhone', isEqualTo: phone)
        .orderBy('timestamp', descending: true)
        .limit(7)
        .get();
    if (mounted) {
      setState(() => _lastTransactions = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList());
    }
  }

  Future<void> _loadExtraData(String phone, String role) async {
    Map<String, dynamic> extra = {};
    if (role == 'agent') {
      final netsSnap = await FirebaseFirestore.instance.collection('networks').where('agentPhone', isEqualTo: phone).get();
      int activeNets = 0, stoppedNets = 0;
      for (var d in netsSnap.docs) {
        if (d['isActive'] == true) activeNets++; else stoppedNets++;
      }
      extra['activeNetworks'] = activeNets;
      extra['stoppedNetworks'] = stoppedNets;
      final posSnap = await FirebaseFirestore.instance.collection('users').where('pos_agents', arrayContains: phone).get();
      int activePos = 0, stoppedPos = 0;
      for (var d in posSnap.docs) {
        if (d['status'] == 'نشط') activePos++; else stoppedPos++;
      }
      extra['activePos'] = activePos;
      extra['stoppedPos'] = stoppedPos;
    } else if (role == 'user' || role == 'pos') {
      final wallets = (_selectedUserData?['wallets'] as Map<String, dynamic>?) ?? {};
      double total = wallets.values.fold(0.0, (a, b) => a + (b as num).toDouble());
      extra['totalBalance'] = total;
      extra['wallets'] = wallets;
      final agentList = context.read<WalletProvider>().agentsList;
      final agentNames = <String, String>{};
      for (var a in agentList) {
        agentNames[a['phone']] = a['name'] ?? a['phone'];
      }
      extra['agentNames'] = agentNames;
    }
    if (mounted) setState(() => _extraData = extra);
  }

  Map<String, dynamic> _collectOptions() => {
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

  Future<void> _previewReset() async {
    context.read<UiProvider>().playSound('click');
    if (_selectedUserPhone == null) {
      _showSnack('الرجاء اختيار مستخدم أولاً', error: true);
      return;
    }
    setState(() => _previewResult = null);
    final agentAdmin = context.read<AgentAdminProvider>();
    try {
      final res = await agentAdmin.previewResetImpact(
        phone: _selectedUserPhone!,
        accountNumber: '',
        targetType: _selectedUserRole == 'agent' ? 'agent' : 'user',
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
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_usePinInstead ? 'PIN' : 'كلمة المرور', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Switch(value: _usePinInstead, onChanged: (v) { setState(() => _usePinInstead = v); setDialogState(() => _usePinInstead = v); }),
                ]),
                const SizedBox(height: 12),
                if (_usePinInstead)
                  TextField(
                    controller: pinController, obscureText: _obscurePin, keyboardType: TextInputType.number, maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'رمز PIN (6 أرقام)', prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility), onPressed: () { setState(() => _obscurePin = !_obscurePin); setDialogState(() => _obscurePin = !_obscurePin); }),
                      border: const OutlineInputBorder(),
                    ),
                  )
                else
                  TextField(
                    controller: passController, obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () { setState(() => _obscurePassword = !_obscurePassword); setDialogState(() => _obscurePassword = !_obscurePassword); }),
                      border: const OutlineInputBorder(),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  bool ok = false;
                  if (_usePinInstead) {
                    try {
                      final doc = await FirebaseFirestore.instance.collection('users').doc(auth.activeUserPhone).get();
                      final storedPin = doc.data()?['pin'] ?? '123456';
                      ok = storedPin == pinController.text;
                    } catch (e) { ok = false; }
                  } else {
                    try {
                      final doc = await FirebaseFirestore.instance.collection('users').doc(auth.activeUserPhone).get();
                      ok = (doc.data()?['password'] ?? '') == passController.text;
                    } catch (e) { ok = false; }
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

  Future<void> _executeReset() async {
    context.read<UiProvider>().playSound('click');
    if (_selectedUserPhone == null) { _showSnack('الرجاء اختيار مستخدم أولاً', error: true); return; }
    final bool verified = await _showAuthDialog();
    if (!verified) { _showSnack('فشل التحقق من الهوية', error: true); return; }
    setState(() => _isProcessing = true);
    try {
      final agentAdmin = context.read<AgentAdminProvider>();
      await agentAdmin.executeReset(
        phone: _selectedUserPhone!, accountNumber: '',
        targetType: _selectedUserRole == 'agent' ? 'agent' : 'user',
        options: _collectOptions(), adminPassword: '',
        renameTo: _renameAccount ? _renameController.text.trim() : null,
        mergeFrom: _mergeRecords ? _mergeFromController.text.trim() : null,
        mergeTo: _mergeRecords ? _mergeToController.text.trim() : null,
        exportBeforeDelete: _exportBeforeDelete,
      );
      context.read<UiProvider>().playSound('success');
      _showSnack('تم تنفيذ الإجراء بنجاح');
      _loadUsers();
      _closeDetailView();
    } catch (e) {
      context.read<UiProvider>().playSound('error');
      _showSnack('فشل: $e', error: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ========== واجهة المستخدم ==========
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final colors = Theme.of(context).colorScheme;

    final roleFilterValue = _roleFilterMap[_selectedRoleFilter] ?? 'all';
    final filteredUsers = _allUsers.where((u) {
      if (roleFilterValue != 'all' && (u['role'] ?? '') != roleFilterValue) return false;
      if (_searchQuery.isNotEmpty) {
        final name = u['name']?.toString().toLowerCase() ?? '';
        final acc = u['accountNumber']?.toString().toLowerCase() ?? '';
        final phone = u['phone']?.toString().toLowerCase() ?? '';
        final q = _searchQuery.toLowerCase();
        return name.contains(q) || acc.contains(q) || phone.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: const CustomHeader(title: 'إدارة حسابات المستخدمين'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () async { _loadUsers(); await Future.delayed(const Duration(milliseconds: 300)); _play('success'); },
          child: _selectedUserData != null
              ? _buildDetailView(colors)
              : _buildListView(colors, filteredUsers, roleFilterValue),
        ),
      ),
    );
  }

  // ---------- شاشة القائمة الرئيسية ----------
  Widget _buildListView(ColorScheme colors, List<Map<String, dynamic>> filteredUsers, String roleFilterValue) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو رقم الحساب أو الهاتف',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _generateMissingAccounts,
                icon: const Icon(Icons.generating_tokens),
                label: const Text('توليد الأرقام المفقودة'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _roleFilters.map((role) {
              final isSelected = _selectedRoleFilter == role;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(role),
                  selected: isSelected,
                  selectedColor: colors.primary,
                  labelStyle: TextStyle(color: isSelected ? colors.onPrimary : colors.onSurface),
                  onSelected: (v) {
                    _play('click');
                    setState(() => _selectedRoleFilter = role);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('${filteredUsers.length} مستخدم', style: TextStyle(color: colors.onSurfaceVariant)),
        ),
        const Divider(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredUsers.isEmpty
                  ? const Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final isBanned = user['isBanned'] == true;
                        return Card(
                          color: isBanned ? Colors.red.shade50 : colors.surface,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _selectUser(user),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person, color: colors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          user['name'] ?? '',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.onSurface, decoration: isBanned ? TextDecoration.lineThrough : null),
                                        ),
                                      ),
                                      if (isBanned)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                                          child: const Text('محظور', style: TextStyle(color: Colors.white, fontSize: 11)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.credit_card, color: colors.secondary, size: 18),
                                      const SizedBox(width: 8),
                                      Text('الحساب: ${user['accountNumber'] ?? 'غير متوفر'}', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14)),
                                      const Spacer(),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: user['accountNumber'] ?? ''));
                                          _showSnack('تم نسخ رقم الحساب');
                                        },
                                        child: Icon(Icons.copy, size: 16, color: colors.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.phone_android, color: Colors.teal, size: 18),
                                      const SizedBox(width: 8),
                                      Text('الهاتف: ${user['phone']}', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.badge, color: Colors.orange, size: 18),
                                      const SizedBox(width: 8),
                                      Text('الدور: ${user['role']}', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(color: colors.outlineVariant),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: colors.primary, size: 20),
                                        onPressed: () => _editAccountNumber(user),
                                        tooltip: 'تعديل رقم الحساب',
                                      ),
                                      IconButton(
                                        icon: Icon(isBanned ? Icons.lock_open : Icons.block, color: isBanned ? Colors.green : Colors.red, size: 20),
                                        onPressed: () => _toggleBan(user),
                                        tooltip: isBanned ? 'فك الحظر' : 'حظر',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ---------- شاشة التفاصيل وإعادة التعيين ----------
  Widget _buildDetailView(ColorScheme colors) {
    final data = _selectedUserData!;
    final role = _selectedUserRole!;
    final walletProvider = context.read<WalletProvider>();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeDetailView,
              ),
              const Text('العودة للقائمة', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [colors.primaryContainer, colors.surface],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(Icons.person, 'الاسم', data['name'] ?? '', Colors.blue),
                  const Divider(),
                  _buildDetailRow(Icons.credit_card, 'رقم الحساب', data['accountNumber'] ?? 'غير متوفر', Colors.teal, copyable: true),
                  const Divider(),
                  _buildDetailRow(Icons.phone_android, 'رقم الهاتف', _selectedUserPhone ?? '', Colors.indigo),
                  const Divider(),
                  _buildDetailRow(Icons.badge, 'الدور',
                      role == 'agent' ? 'وكيل' : role == 'pos' ? 'نقطة بيع' : role == 'user' ? 'مستخدم' : role, Colors.orange),
                  if (role == 'agent') ...[
                    const Divider(),
                    _buildDetailRow(Icons.account_balance_wallet, 'الرصيد', '${(data['balance'] ?? 0).toString()} ريال', Colors.green),
                    if (_extraData != null) ...[
                      const Divider(),
                      _buildDetailRow(Icons.wifi, 'الشبكات', 'نشطة: ${_extraData!['activeNetworks'] ?? 0} / موقوفة: ${_extraData!['stoppedNetworks'] ?? 0}', Colors.blueGrey),
                      const Divider(),
                      _buildDetailRow(Icons.storefront, 'نقاط البيع', 'نشطة: ${_extraData!['activePos'] ?? 0} / موقوفة: ${_extraData!['stoppedPos'] ?? 0}', Colors.purple),
                    ],
                  ] else if (role == 'user' || role == 'pos') ...[
                    if (_extraData != null) ...[
                      const Divider(),
                      _buildDetailRow(Icons.account_balance_wallet, 'إجمالي الرصيد', '${_extraData!['totalBalance'] ?? 0} ريال', Colors.green, bold: true),
                      if ((_extraData!['wallets'] as Map?)?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        const Text('الأرصدة حسب الوكلاء:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...(_extraData!['wallets'] as Map).entries.map((e) {
                          final agentNames = (_extraData!['agentNames'] as Map<String, String>?) ?? {};
                          final agentName = agentNames[e.key] ?? e.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 16, bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.person, size: 16, color: colors.secondary),
                                const SizedBox(width: 6),
                                Text('$agentName: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${e.value} ريال', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (_lastTransactions.isNotEmpty) ...[
            Text('آخر العمليات', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
            const SizedBox(height: 8),
            ..._lastTransactions.take(5).map((txn) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(txn['title'] ?? 'عملية', style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${txn['amount']} ريال', style: const TextStyle(fontSize: 12)),
                    trailing: Text(
                      txn['timestamp'] != null ? (txn['timestamp'] as Timestamp).toDate().toString().substring(0, 10) : '',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                )),
            const SizedBox(height: 20),
          ],

          Text('الإجراءات المتاحة', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
          const SizedBox(height: 8),
          _buildActionCheckboxes(role),
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
                  onPressed: _previewReset,
                  icon: const Icon(Icons.preview),
                  label: const Text('معاينة التأثير'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _executeReset,
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
              decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
              child: Text(_previewResult!, style: TextStyle(color: colors.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color, {bool bold = false, bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: Theme.of(context).colorScheme.onSurface)),
          ),
          if (copyable)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSnack('تم نسخ $label');
              },
              child: Icon(Icons.copy, size: 16, color: color),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCheckboxes(String role) {
    return Column(
      children: [
        _buildCheckbox('تصفير الرصيد', _resetBalance, (v) => setState(() => _resetBalance = v!)),
        if (role == 'agent') ...[
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
      dense: true,
    );
  }
}
