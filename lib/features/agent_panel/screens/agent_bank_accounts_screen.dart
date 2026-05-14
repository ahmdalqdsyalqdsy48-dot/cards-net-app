// lib/features/agent_panel/screens/agent_bank_accounts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentBankAccountsScreen extends StatefulWidget {
  const AgentBankAccountsScreen({super.key});

  @override
  State<AgentBankAccountsScreen> createState() =>
      _AgentBankAccountsScreenState();
}

class _AgentBankAccountsScreenState extends State<AgentBankAccountsScreen> {
  String _searchQuery = '';

  void _play(BuildContext context, String type) =>
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

  // ==================== 1. نافذة إضافة حساب جديد ====================
  void _showAddAccountDialog(SystemProvider provider) {
    _play(context, 'click');
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final beneficiaryController = TextEditingController();
    final noteController = TextEditingController();

    List<String> selectedNetworkIds = [];
    List<String> selectedNetworkNames = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.account_balance,
                    color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 10),
                const Text('إضافة حساب بنكي جديد',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // اختيار الشبكات المرتبطة (قائمة أزرار متعددة)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: provider.getAgentNetworkNames(),
                    builder: (context, snapshot) {
                      final networks = snapshot.data ?? [];
                      if (networks.isEmpty) {
                        return const Text(
                            'ليس لديك أي شبكة ميكروتك نشطة. أضف شبكة أولاً.',
                            style: TextStyle(color: Colors.red, fontSize: 12));
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text('اختر الشبكات المرتبطة بهذا الحساب:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: networks.map((net) {
                              final netId = net['networkId'] ?? '';
                              final netName = net['networkName'] ?? '';
                              final isSelected =
                                  selectedNetworkIds.contains(netId);
                              return FilterChip(
                                label: Text(netName),
                                selected: isSelected,
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      selectedNetworkIds.add(netId);
                                      selectedNetworkNames.add(netName);
                                    } else {
                                      selectedNetworkIds.remove(netId);
                                      selectedNetworkNames.remove(netName);
                                    }
                                  });
                                },
                                selectedColor: Theme.of(ctx)
                                    .colorScheme
                                    .primaryContainer,
                                checkmarkColor:
                                    Theme.of(ctx).colorScheme.primary,
                              );
                            }).toList(),
                          ),
                          if (selectedNetworkNames.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  'المختارة: ${selectedNetworkNames.join("، ")}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.teal)),
                            ),
                          const SizedBox(height: 15),
                        ],
                      );
                    },
                  ),
                  _buildTextField('اسم البنك / المحفظة',
                      Icons.account_balance_wallet,
                      controller: bankNameController),
                  _buildTextField('رقم الحساب / المحفظة', Icons.numbers,
                      controller: accountNumberController,
                      isAccountNumber: true),
                  _buildTextField('الاسم الرباعي للمستفيد', Icons.person,
                      controller: beneficiaryController),
                  _buildTextField('ملاحظات (اختياري)', Icons.notes,
                      controller: noteController),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    _play(context, 'click');
                    Navigator.pop(ctx);
                  },
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.primary),
                onPressed: () {
                  if (bankNameController.text.isNotEmpty &&
                      accountNumberController.text.isNotEmpty) {
                    Navigator.pop(ctx);
                    _play(context, 'click');
                    final networkName = selectedNetworkNames.isNotEmpty
                        ? selectedNetworkNames.join("، ")
                        : provider.currentUserNetwork;
                    provider
                        .addAgentBankAccount(
                      networkName,
                      provider.currentUserName,
                      bankNameController.text.trim(),
                      accountNumberController.text.trim(),
                      noteController.text.trim(),
                      selectedNetworkIds,
                    )
                        .then((_) {
                      _showSnack('تم حفظ الحساب بنجاح ✅');
                    }).catchError((e) {
                      _showSnack('فشل الحفظ: $e', error: true);
                    });
                  } else {
                    _showSnack('يرجى إدخال اسم البنك ورقم الحساب',
                        error: true);
                  }
                },
                child: Text('حفظ الحساب',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 2. نافذة تعديل حساب ====================
  void _showEditAccountDialog(
      SystemProvider provider, Map<String, dynamic> account) {
    _play(context, 'click');
    final bankNameController =
        TextEditingController(text: account['bankName']);
    final accountNumberController =
        TextEditingController(text: account['accountNumber']);
    final beneficiaryController =
        TextEditingController(text: account['beneficiary'] ?? '');
    final noteController =
        TextEditingController(text: account['note'] ?? '');

    List<String> currentNetworkIds =
        List<String>.from(account['networkIds'] ?? []);
    List<String> selectedNetworkIds = List.from(currentNetworkIds);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.edit, color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 10),
                const Text('تعديل الحساب',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // اختيار الشبكات المرتبطة
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: provider.getAgentNetworkNames(),
                    builder: (context, snapshot) {
                      final networks = snapshot.data ?? [];
                      if (networks.isNotEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Text('اختر الشبكات المرتبطة:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: networks.map((net) {
                                final netId = net['networkId'] ?? '';
                                final netName = net['networkName'] ?? '';
                                final isSelected =
                                    selectedNetworkIds.contains(netId);
                                return FilterChip(
                                  label: Text(netName),
                                  selected: isSelected,
                                  onSelected: (val) {
                                    setDialogState(() {
                                      if (val) {
                                        selectedNetworkIds.add(netId);
                                      } else {
                                        selectedNetworkIds.remove(netId);
                                      }
                                    });
                                  },
                                  selectedColor: Theme.of(ctx)
                                      .colorScheme
                                      .primaryContainer,
                                  checkmarkColor:
                                      Theme.of(ctx).colorScheme.primary,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 15),
                          ],
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                  _buildTextField('اسم البنك / المحفظة',
                      Icons.account_balance_wallet,
                      controller: bankNameController),
                  _buildTextField('رقم الحساب', Icons.numbers,
                      controller: accountNumberController,
                      isAccountNumber: true),
                  _buildTextField('اسم المستفيد', Icons.person,
                      controller: beneficiaryController),
                  _buildTextField('ملاحظات', Icons.notes,
                      controller: noteController),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    _play(context, 'click');
                    Navigator.pop(ctx);
                  },
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  _play(context, 'click');
                  provider
                      .updateAgentBankAccount(
                    account['docId'],
                    selectedNetworkNames.isNotEmpty
                        ? selectedNetworkNames.join("، ")
                        : (account['networkName'] ?? ''),
                    provider.currentUserName,
                    bankNameController.text.trim(),
                    accountNumberController.text.trim(),
                    noteController.text.trim(),
                    selectedNetworkIds,
                  )
                      .then((_) {
                    _showSnack('تم التعديل بنجاح ✏️');
                  }).catchError((e) {
                    _showSnack('فشل التعديل: $e', error: true);
                  });
                },
                child: Text('حفظ التعديلات',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 3. دوال التحكم (حالة / حذف / نسخ / مشاركة) ====================
  void _toggleAccountStatus(
      SystemProvider provider, Map<String, dynamic> account) {
    _play(context, 'click');
    provider
        .toggleAgentBankAccountStatus(account['docId'], account['status'])
        .then((_) {
      _showSnack('تم تغيير الحالة');
    }).catchError((e) {
      _showSnack('فشل تغيير الحالة: $e', error: true);
    });
  }

  void _deleteAccount(SystemProvider provider, String docId) {
    _play(context, 'click');
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تحذير الحذف ⚠️',
              style: TextStyle(
                  color: colors.error, fontWeight: FontWeight.bold)),
          content: const Text(
              'هل أنت متأكد من حذف هذا الحساب نهائياً من قاعدة البيانات؟'),
          actions: [
            TextButton(
                onPressed: () {
                  _play(context, 'click');
                  Navigator.pop(ctx);
                },
                child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error),
              onPressed: () {
                Navigator.pop(ctx);
                _play(context, 'click');
                provider.deleteAgentBankAccount(docId).then((_) {
                  _showSnack('تم الحذف بنجاح 🗑️');
                }).catchError((e) {
                  _showSnack('فشل الحذف: $e', error: true);
                });
              },
              child: Text('نعم، احذف الحساب',
                  style: TextStyle(color: colors.onError)),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAccountDetails(Map<String, dynamic> account) {
    _play(context, 'success');
    final buffer = StringBuffer();
    buffer.writeln('🏦 ${account['bankName']}');
    buffer.writeln('🔢 الحساب: ${account['accountNumber']}');
    buffer.writeln('👤 باسم: ${account['beneficiary'] ?? ''}');
    if ((account['networkName'] ?? '').toString().isNotEmpty) {
      buffer.writeln('🌐 الشبكة: ${account['networkName']}');
    }
    if ((account['note'] ?? '').toString().isNotEmpty &&
        account['note'] != 'لا توجد ملاحظات') {
      buffer.writeln('📝 ملاحظة: ${account['note']}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showSnack('تم نسخ بيانات الحساب بنجاح، جاهزة للإرسال! 📋');
  }

  void _shareAccountDetails(Map<String, dynamic> account) {
    _play(context, 'click');
    final buffer = StringBuffer();
    buffer.writeln('🏦 ${account['bankName']}');
    buffer.writeln('🔢 الحساب: ${account['accountNumber']}');
    buffer.writeln('👤 باسم: ${account['beneficiary'] ?? ''}');
    if ((account['networkName'] ?? '').toString().isNotEmpty) {
      buffer.writeln('🌐 الشبكة: ${account['networkName']}');
    }
    if ((account['note'] ?? '').toString().isNotEmpty &&
        account['note'] != 'لا توجد ملاحظات') {
      buffer.writeln('📝 ملاحظة: ${account['note']}');
    }
    Share.share(buffer.toString(), subject: 'بيانات الحساب البنكي');
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final colors = Theme.of(context).colorScheme;

    // ✅ القائمة تأتي مباشرة من SystemProvider (مثل كود مالك النظام)
    List<Map<String, dynamic>> accounts = sys.myAgentBankAccounts;

    // تصفية حسب البحث
    if (_searchQuery.isNotEmpty) {
      accounts = accounts.where((a) {
        return (a['bankName'] ?? '').toString().contains(_searchQuery) ||
            (a['accountNumber'] ?? '').toString().contains(_searchQuery) ||
            (a['beneficiary'] ?? '').toString().contains(_searchQuery) ||
            (a['networkName'] ?? '').toString().contains(_searchQuery) ||
            (a['note'] ?? '').toString().contains(_searchQuery);
      }).toList();
    }

    return Scaffold(
      appBar: const CustomHeader(title: 'حساباتي البنكية'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد',
        currentBalance: sys.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddAccountDialog(sys),
                  icon: Icon(Icons.add_card, color: colors.onPrimary),
                  label: Text('إضافة حساب بنكي جديد',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            // حقل البحث
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'بحث عن حساب...',
                  prefixIcon: Icon(Icons.search, color: colors.primary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colors.primaryContainer.withOpacity(0.3),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'يمكنك سحب أي حساب لإعادة ترتيب أولويات الظهور للعملاء.',
                          style: TextStyle(
                              fontSize: 12, color: colors.primary))),
                ],
              ),
            ),
            Expanded(
              child: accounts.isEmpty
                  ? Center(
                      child: Text(
                          'لا توجد حسابات مضافة حالياً.\nاضغط على الزر أعلاه لإضافة حساب.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colors.onSurfaceVariant)))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await sys.loadUserData(sys.currentUserPhone);
                        setState(() {});
                      },
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: accounts.length,
                        onReorder: (oldIndex, newIndex) {
                          sys.reorderAgentBankAccounts(
                              oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          final bool isActive =
                              (account['status'] ?? '') == 'نشط';

                          return Card(
                            key: ValueKey(account['docId']),
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(
                                  color: isActive
                                      ? colors.outlineVariant
                                      : colors.error.withOpacity(0.5),
                                  width: 2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.drag_indicator,
                                                color: Colors.grey),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  if ((account['networkName'] ??
                                                              '')
                                                          .toString()
                                                          .isNotEmpty)
                                                    Text(
                                                        'شبكة: ${account['networkName']}',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: colors
                                                                .primary)),
                                                  Text(
                                                      account['bankName'] ??
                                                          '',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          color: colors
                                                              .primary)),
                                                  Text(
                                                      account['accountNumber'] ??
                                                          '',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 18,
                                                          color: colors
                                                              .onSurface),
                                                      textDirection:
                                                          TextDirection.ltr),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                            account['status'] ?? '',
                                            style: TextStyle(
                                                color: isActive
                                                    ? colors.onPrimary
                                                    : colors.onError,
                                                fontSize: 11)),
                                        backgroundColor: isActive
                                            ? Colors.green
                                            : colors.errorContainer,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                  Divider(
                                      color: colors.outlineVariant),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                          child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'المستفيد: ${account['beneficiary'] ?? ''}',
                                              style: TextStyle(
                                                  color: colors
                                                      .onSurfaceVariant,
                                                  fontSize: 12)),
                                          if (account['note'] != null &&
                                              account['note']
                                                  .toString()
                                                  .isNotEmpty &&
                                              account['note'] !=
                                                  'لا توجد ملاحظات')
                                            Text(
                                              'ملاحظة: ${account['note']}',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: colors
                                                      .onSurfaceVariant),
                                            ),
                                          if (account['createdAt'] != null)
                                            Text(
                                              'تاريخ الإضافة: ${_formatTimestamp(account['createdAt'])}',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: colors
                                                      .onSurfaceVariant),
                                            ),
                                        ],
                                      )),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildSmallButton(
                                            Icons.copy,
                                            'نسخ البيانات',
                                            colors.primary,
                                            () => _copyAccountDetails(
                                                account),
                                          ),
                                          _buildSmallButton(
                                            Icons.share,
                                            'مشاركة',
                                            colors.primary,
                                            () => _shareAccountDetails(
                                                account),
                                          ),
                                          _buildSmallButton(
                                            Icons.edit,
                                            'تعديل',
                                            colors.primary,
                                            () => _showEditAccountDialog(
                                                sys, account),
                                          ),
                                          _buildSmallButton(
                                            isActive
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            isActive
                                                ? 'إيقاف'
                                                : 'تفعيل',
                                            isActive
                                                ? colors.error
                                                : Colors.green,
                                            () => _toggleAccountStatus(
                                                sys, account),
                                          ),
                                          _buildSmallButton(
                                            Icons.delete,
                                            'حذف',
                                            colors.error,
                                            () => _deleteAccount(
                                                sys,
                                                account['docId']),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return '';
  }

  Widget _buildTextField(String label, IconData icon,
      {TextEditingController? controller, bool isAccountNumber = false}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType:
            isAccountNumber ? TextInputType.text : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: colors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildSmallButton(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(),
    );
  }
}
