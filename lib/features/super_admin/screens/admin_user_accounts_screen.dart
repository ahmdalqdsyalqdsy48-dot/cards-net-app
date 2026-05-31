import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
  String _searchQuery = '';
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _play(String type) =>
      context.read<UiProvider>().playSound(type);

  void _loadUsers() {
    final agentAdmin = context.read<AgentAdminProvider>();
    setState(() {
      _allUsers = agentAdmin.getAllUsersWithAccountDetails();
      _isLoading = false;
    });
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

  Future<void> _generateMissingAccounts() async {
    final agentAdmin = context.read<AgentAdminProvider>();
    _play('click');
    try {
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
              decoration: const InputDecoration(
                  labelText: 'رقم الحساب الجديد',
                  border: OutlineInputBorder()),
              validator: (val) =>
                  (val == null || val.isEmpty) ? 'أدخل رقماً' : null,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, controller.text.trim());
                }
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
          content: Text(ban
              ? 'هل أنت متأكد من حظر هذا الحساب؟'
              : 'هل تريد فك الحظر عن هذا الحساب؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: ban ? Colors.red : Colors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ban ? 'حظر' : 'فك الحظر',
                  style: const TextStyle(color: Colors.white)),
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

  Future<void> _searchAdmin(String query) async {
    if (query.trim().isEmpty) {
      _loadUsers();
      return;
    }
    final agentAdmin = context.read<AgentAdminProvider>();
    try {
      final result = await agentAdmin.searchUserByAdmin(query);
      if (!mounted) return;
      setState(() {
        if (result != null) {
          _allUsers = [
            {
              'phone': result['phone'],
              'accountNumber': result['accountNumber'] ?? 'غير متوفر',
              'name': result['name'] ?? 'غير معروف',
              'role': result['role'] ?? 'مستخدم',
              'isBanned': result['isBanned'] ?? false,
              'privacyShowPhone': result['privacy_showPhone'] ?? true,
            }
          ];
        } else {
          _allUsers = [];
          _showSnack('لم يتم العثور على مستخدم', error: true);
        }
      });
    } catch (e) {
      _showSnack('$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();

    final filteredUsers = _searchQuery.isEmpty
        ? _allUsers
        : _allUsers.where((u) {
            final name = u['name']?.toString().toLowerCase() ?? '';
            final acc = u['accountNumber']?.toString().toLowerCase() ?? '';
            final phone = u['phone']?.toString().toLowerCase() ?? '';
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || acc.contains(q) || phone.contains(q);
          }).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة أرقام الحسابات'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () async {
            _loadUsers();
            await Future.delayed(const Duration(milliseconds: 300));
            _play('success');
          },
          child: Column(
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
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _searchAdmin(_searchQuery),
                      child: const Text('بحث إداري'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _generateMissingAccounts,
                      icon: const Icon(Icons.generating_tokens),
                      label: const Text('توليد الأرقام المفقودة'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700),
                    ),
                    const Spacer(),
                    Text('${filteredUsers.length} مستخدم'),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredUsers.isEmpty
                        ? const Center(
                            child: Text('لا توجد نتائج',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final isBanned = user['isBanned'] == true;

                              return Card(
                                color: isBanned
                                    ? Colors.red.shade50
                                    : Theme.of(context).cardColor,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        isBanned ? Colors.red : Colors.teal,
                                    child: Icon(
                                      isBanned ? Icons.block : Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    user['name'] ?? '',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: isBanned
                                            ? TextDecoration.lineThrough
                                            : null),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'الحساب: ${user['accountNumber']}  |  الهاتف: ${user['phone']}'),
                                      Text(
                                        'الدور: ${user['role']}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        _editAccountNumber(user);
                                      } else if (action == 'ban') {
                                        _toggleBan(user);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit,
                                                color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('تعديل رقم الحساب'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'ban',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isBanned
                                                  ? Icons.lock_open
                                                  : Icons.block,
                                              color: isBanned
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(isBanned
                                                ? 'فك الحظر'
                                                : 'حظر'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
