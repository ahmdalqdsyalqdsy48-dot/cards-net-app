import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/agent_admin_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';
import 'agent_profile_screen.dart';

class AgentManagementScreen extends StatefulWidget {
  const AgentManagementScreen({super.key});

  @override
  State<AgentManagementScreen> createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen> {
  String _searchQuery = '';

  void _play(String type) => context.read<UiProvider>().playSound(type);

  // دالة مساعدة للصلاحيات
  bool _can(String permission) {
    final auth = context.read<AuthProvider>();
    return auth.currentUserRole == 'super_admin' || auth.hasPermission(permission);
  }

  void _showSnackBar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // 1. نافذة إضافة وكيل جديد
  // ==========================================
  void _showAddAgentDialog(AgentAdminProvider agentAdmin) {
    if (!_can('إضافة وكيل')) return;
    _play('click');
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final profitController = TextEditingController();
    final passwordController = TextEditingController();
    final balanceController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          bool isLoading = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.person_add, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('إضافة وكيل جديد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField('الاسم الرباعي للوكيل', Icons.person, controller: nameController),
                    _buildTextField('رقم الهاتف (اسم المستخدم)', Icons.phone, controller: phoneController, isNumber: true),
                    _buildTextField('نسبة رسوم النظام %', Icons.percent, controller: profitController, isNumber: true,
                        hint: 'النسبة التي يخصمها النظام من مبيعات الوكيل'),
                    _buildTextField('كلمة المرور', Icons.lock, controller: passwordController),
                    const Divider(height: 20),
                    _buildTextField('الرصيد الابتدائي (اختياري)', Icons.account_balance_wallet, controller: balanceController, isNumber: true),
                    const SizedBox(height: 5),
                    const Text('اتركه فارغاً إذا كنت لا تريد إضافة رصيد الآن.',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () { _play('click'); Navigator.pop(ctx); },
                    child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading ? null : () async {
                    String phone = phoneController.text.trim();
                    String name = nameController.text.trim();

                    if (name.isNotEmpty && phone.isNotEmpty) {
                      setStateDialog(() => isLoading = true);

                      try {
                        await agentAdmin.addAgent(
                          name: name,
                          phone: phone,
                          password: passwordController.text.trim().isNotEmpty
                              ? passwordController.text.trim()
                              : phone,
                          profitMargin: profitController.text.trim(),
                          initialBalance: double.tryParse(balanceController.text.trim()) ?? 0,
                        );

                        if (mounted) {
                          _play('success');
                          Navigator.pop(ctx);
                          _showSnackBar('تم إضافة الوكيل بنجاح! ✅');
                        }
                      } catch (error) {
                        _play('error');
                        setStateDialog(() => isLoading = false);
                        if (mounted) _showSnackBar('فشل الحفظ ❌: $error', error: true);
                      }
                    } else {
                      _play('error');
                      _showSnackBar('يرجى إدخال الاسم ورقم الهاتف على الأقل! ❌', error: true);
                    }
                  },
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ واعتماد', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 2. نافذة تعديل بيانات وكيل حالي
  // ==========================================
  void _showEditAgentDialog(Map<String, dynamic> agent, AgentAdminProvider agentAdmin) {
    if (!_can('تعديل وكيل')) return;
    _play('click');
    final nameController = TextEditingController(text: agent['name']);
    final phoneController = TextEditingController(text: agent['phone']);
    final profitController = TextEditingController(
      text: agent['profitMargin']?.toString().replaceAll('%', '') ?? '0',
    );
    final passwordController = TextEditingController(text: agent['password']);

    final oldPhone = agent['phone'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          bool isLoading = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.edit, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 10),
                  Text('تعديل بيانات الوكيل',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField('الاسم الرباعي', Icons.person, controller: nameController),
                    _buildTextField('رقم الهاتف (الآيدي للحساب)', Icons.phone, controller: phoneController, isNumber: true),
                    // 🆕 حقل نسبة رسوم النظام في التعديل
                    _buildTextField('نسبة رسوم النظام %', Icons.percent, controller: profitController, isNumber: true,
                        hint: 'النسبة التي يخصمها النظام من مبيعات الوكيل'),
                    _buildTextField('كلمة المرور', Icons.lock, controller: passwordController),
                  ],
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(onPressed: () { _play('click'); Navigator.pop(ctx); }, child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading ? null : () async {
                    setStateDialog(() => isLoading = true);

                    try {
                      await agentAdmin.updateAgentDetails(
                        oldPhone: oldPhone,
                        newPhone: phoneController.text.trim(),
                        newName: nameController.text.trim(),
                        newNetwork: '',
                        newLocation: '',
                        newProfit: '${profitController.text.trim()}%',
                        newPassword: passwordController.text.trim(),
                      );

                      if (mounted) {
                        _play('success');
                        Navigator.pop(ctx);
                        _showSnackBar('تم تطبيق التعديلات بنجاح ✅');
                      }
                    } catch (error) {
                      _play('error');
                      setStateDialog(() => isLoading = false);
                      if (mounted) _showSnackBar('فشل التعديل ❌: $error', error: true);
                    }
                  },
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 3. تجميد / تنشيط الوكيل
  // ==========================================
  void _toggleFreeze(Map<String, dynamic> agent, AgentAdminProvider agentAdmin) {
    if (!_can('تجميد/تنشيط وكيل')) return;
    _play('click');
    bool isGoingToFreeze = agent['status'] == 'نشط';

    try {
      agentAdmin.toggleUserStatus(agent['phone'], agent['status']);
      _play('success');
      _showSnackBar(isGoingToFreeze ? 'تم تجميد حساب الوكيل ⏸️' : 'تم إعادة تنشيط الوكيل ▶️');
    } catch (e) {
      _play('error');
      _showSnackBar('فشل تغيير الحالة ❌: $e', error: true);
    }
  }

  // ==========================================
  // 4. حذف الوكيل
  // ==========================================
  void _deleteAgent(Map<String, dynamic> agent, AgentAdminProvider agentAdmin) {
    if (!_can('حذف وكيل')) return;
    _play('click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من مسح بيانات الوكيل (${agent['name']}) نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                try {
                  agentAdmin.deleteAgent(agent['phone']);
                  _play('success');
                  Navigator.pop(ctx);
                  _showSnackBar('تم الحذف النهائي من السيرفر 🗑️');
                } catch (e) {
                  _play('error');
                  Navigator.pop(ctx);
                  _showSnackBar('فشل الحذف ❌: $e', error: true);
                }
              },
              child: const Text('نعم، احذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAgentDetails(Map<String, dynamic> agent) {
    _play('click');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgentProfileScreen(agentData: agent)),
    );
  }

  // ==========================================
  // بناء واجهة المستخدم
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final agentAdmin = context.read<AgentAdminProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    final realAgentsList = wallet.agentsList;

    final filteredAgents = realAgentsList.where((agent) =>
        (agent['name']?.toString() ?? '').contains(_searchQuery) ||
        (agent['phone']?.toString() ?? '').contains(_searchQuery)
    ).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const CustomHeader(title: 'إدارة الوكلاء'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: auth.currentUserRole == 'super_admin' ? 'مالك النظام' : 'موظف مخصص',
        balanceOrPoints: 'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 300));
          _play('success');
          _showSnackBar('تم تحديث الصفحة بنجاح ✅');
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // الرأس المتحرك (يختفي مع التمرير)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (_can('إضافة وكيل'))
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddAgentDialog(agentAdmin),
                          icon: const Icon(Icons.person_add, color: Colors.white),
                          label: const Text('إضافة وكيل جديد',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      onChanged: (value) {
                        if (value.length == 1) _play('click');
                        setState(() => _searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو الهاتف...',
                        prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('${filteredAgents.length} وكيل',
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ),
                  const Divider(),
                ],
              ),
            ),
            // قائمة الوكلاء
            filteredAgents.isEmpty
                ? const SliverFillRemaining(
                    child: Center(
                        child: Text('لا يوجد وكلاء مطابقين للبحث أو لم يتم إضافة وكلاء بعد.',
                            style: TextStyle(color: Colors.grey))))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final agent = filteredAgents[index];
                        final isFrozen = agent['status'] == 'مجمد';
                        final phone = agent['phone'] ?? '';

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _loadAgentNetworks(phone),
                          initialData: {'networks': [], 'accountNumber': agent['accountNumber']},
                          builder: (context, snapshot) {
                            final data = snapshot.data ?? {'networks': [], 'accountNumber': agent['accountNumber']};
                            final networks = data['networks'] as List<Map<String, dynamic>>;
                            final accountNumber = data['accountNumber'] as String?;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              elevation: 3,
                              color: colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: isFrozen ? colorScheme.error.withOpacity(0.3) : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // الصف الأول: الاسم والحالة
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            agent['name'] ?? 'مجهول',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: colorScheme.onSurface,
                                              decoration: isFrozen ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isFrozen ? Colors.red : Colors.green,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            agent['status'] ?? 'نشط',
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    // رقم الحساب
                                    if (accountNumber != null && accountNumber.isNotEmpty)
                                      _buildInfoRow(Icons.credit_card, 'رقم الحساب', accountNumber, Colors.teal),
                                    // رقم الهاتف
                                    _buildInfoRow(Icons.phone_android, 'رقم الهاتف', phone, Colors.indigo),
                                    // نسبة رسوم النظام
                                    _buildInfoRow(Icons.percent, 'رسوم النظام', agent['profitMargin'] ?? '0%', Colors.orange),
                                    // الرصيد
                                    _buildInfoRow(Icons.account_balance_wallet, 'الرصيد', '${agent['balance'] ?? 0} ريال', Colors.green),
                                    // الشبكات
                                    if (networks.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text('الشبكات:', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                                      ...networks.map((net) => Padding(
                                        padding: const EdgeInsets.only(right: 16, top: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.wifi, size: 16, color: net['isActive'] == true ? Colors.green : Colors.red),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(net['name'] ?? 'بدون اسم', style: TextStyle(color: colorScheme.onSurface))),
                                            if (net['location'] != null && net['location'].toString().isNotEmpty)
                                              Text(net['location'].toString(), style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                                          ],
                                        ),
                                      )),
                                    ] else ...[
                                      _buildInfoRow(Icons.wifi_off, 'الشبكات', 'لم يضف شبكات بعد', Colors.grey),
                                    ],
                                    const Divider(),
                                    // أزرار التحكم
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        if (_can('عرض الوكلاء'))
                                          _buildActionButton(Icons.visibility, 'تفاصيل', Colors.blue, () => _showAgentDetails(agent)),
                                        if (_can('تعديل وكيل'))
                                          _buildActionButton(Icons.edit, 'تعديل', Colors.orange, () => _showEditAgentDialog(agent, agentAdmin)),
                                        if (_can('تجميد/تنشيط وكيل'))
                                          _buildActionButton(
                                            isFrozen ? Icons.play_arrow : Icons.pause,
                                            isFrozen ? 'تنشيط' : 'تجميد',
                                            isFrozen ? Colors.green : Colors.red,
                                            () => _toggleFreeze(agent, agentAdmin),
                                          ),
                                        if (_can('حذف وكيل'))
                                          _buildActionButton(Icons.delete_forever, 'حذف', Colors.red, () => _deleteAgent(agent, agentAdmin)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: filteredAgents.length,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // 🆕 تحميل شبكات الوكيل من Firestore
  Future<Map<String, dynamic>> _loadAgentNetworks(String phone) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('networks')
          .where('agentPhone', isEqualTo: phone)
          .get();
      
      final networks = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'] ?? '',
          'location': data['location'] ?? '',
          'isActive': data['isActive'] ?? true,
        };
      }).toList();

      // جلب رقم الحساب من وثيقة المستخدم
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(phone).get();
      final accountNumber = userDoc.data()?['accountNumber'] as String?;

      return {
        'networks': networks,
        'accountNumber': accountNumber,
      };
    } catch (e) {
      return {'networks': [], 'accountNumber': null};
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon,
      {TextEditingController? controller, bool isNumber = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(tooltip, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
