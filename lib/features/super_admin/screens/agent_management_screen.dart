import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  void _play(BuildContext context, String type) =>
      context.read<UiProvider>().playSound(type);

  // ==========================================
  // 1. نافذة إضافة وكيل جديد
  // ==========================================
  void _showAddAgentDialog(AgentAdminProvider agentAdmin) {
    _play(context, 'click');
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('إضافة وكيل جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField('الاسم الرباعي للوكيل', Icons.person, controller: nameController),
                    _buildTextField('رقم الهاتف (اسم المستخدم)', Icons.phone, controller: phoneController, isNumber: true),
                    _buildTextField('نسبة ربح النظام %', Icons.percent, controller: profitController, isNumber: true),
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
                    onPressed: () { _play(context, 'click'); Navigator.pop(ctx); },
                    child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
                  ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
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
                          _play(context, 'success');
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم إضافة الوكيل بنجاح! ✅'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (error) {
                        _play(context, 'error');
                        setStateDialog(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الحفظ ❌: $error'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    } else {
                      _play(context, 'error');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال الاسم ورقم الهاتف على الأقل! ❌'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ واعتماد', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  // ==========================================
  // 2. نافذة تعديل بيانات وكيل حالي
  // ==========================================
  void _showEditAgentDialog(Map<String, dynamic> agent, AgentAdminProvider agentAdmin) {
    _play(context, 'click');
    final nameController = TextEditingController(text: agent['name']);
    final phoneController = TextEditingController(text: agent['phone']);
    final profitController = TextEditingController(text: agent['profitMargin'].toString().replaceAll('%', ''));
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit, color: Colors.orange),
                  SizedBox(width: 10),
                  Text('تعديل بيانات الوكيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField('الاسم الرباعي', Icons.person, controller: nameController),
                    _buildTextField('رقم الهاتف (الآيدي للحساب)', Icons.phone, controller: phoneController, isNumber: true),
                    _buildTextField('نسبة الربح %', Icons.percent, controller: profitController, isNumber: true),
                    _buildTextField('كلمة المرور', Icons.lock, controller: passwordController),
                  ],
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(onPressed: () { _play(context, 'click'); Navigator.pop(ctx); }, child: const Text('إلغاء')),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
                        _play(context, 'success');
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تطبيق التعديلات بنجاح ✅'), backgroundColor: Colors.green));
                      }
                    } catch (error) {
                      _play(context, 'error');
                      setStateDialog(() => isLoading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التعديل ❌: $error'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  // ==========================================
  // 3. تجميد / تنشيط الوكيل
  // ==========================================
  void _toggleFreeze(Map<String, dynamic> agent, AgentAdminProvider agentAdmin) {
    _play(context, 'click');
    bool isGoingToFreeze = agent['status'] == 'نشط';

    try {
      agentAdmin.toggleUserStatus(agent['phone'], agent['status']);
      _play(context, 'success');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isGoingToFreeze ? 'تم تجميد حساب الوكيل ⏸️' : 'تم إعادة تنشيط الوكيل ▶️'),
        backgroundColor: isGoingToFreeze ? Colors.orange : Colors.green,
      ));
    } catch (e) {
      _play(context, 'error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تغيير الحالة ❌: $e'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // 4. حذف الوكيل
  // ==========================================
  void _deleteAgent(Map<String, dynamic> agent, AgentAdminProvider agentAdmin) {
    _play(context, 'click');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من مسح بيانات الوكيل (${agent['name']}) نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                try {
                  agentAdmin.deleteAgent(agent['phone']);
                  _play(context, 'success');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف النهائي من السيرفر 🗑️'), backgroundColor: Colors.red));
                } catch (e) {
                  _play(context, 'error');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف ❌: $e'), backgroundColor: Colors.red));
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
    _play(context, 'click');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgentProfileScreen(agentData: agent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final agentAdmin = context.read<AgentAdminProvider>();

    final realAgentsList = wallet.agentsList;

    final filteredAgents = realAgentsList.where((agent) =>
        (agent['name']?.toString() ?? '').contains(_searchQuery) ||
        (agent['phone']?.toString() ?? '').contains(_searchQuery)
    ).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الوكلاء'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام',
        balanceOrPoints: 'رصيد النظام: ${settings.adminMainBalance.toStringAsFixed(0)}',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 300));
          _play(context, 'success');
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddAgentDialog(agentAdmin),
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: const Text('إضافة وكيل جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (value) {
                      if (value.length == 1) _play(context, 'click');
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو الهاتف...',
                      prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredAgents.isEmpty
                  ? const Center(child: Text('لا يوجد وكلاء مطابقين للبحث أو لم يتم إضافة وكلاء بعد.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filteredAgents.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final agent = filteredAgents[index];
                        final isFrozen = agent['status'] == 'مجمد';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: isFrozen ? Colors.red.withOpacity(0.3) : Colors.transparent, width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${agent['name'] ?? 'مجهول'} - ${agent['networkName'] ?? 'بدون شبكة'}',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isFrozen ? TextDecoration.lineThrough : null),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text('الهاتف: ${agent['phone']} | العمولة: ${agent['profitMargin'] ?? '0%'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          Text('الرصيد: ${agent['balance'] ?? 0} ريال | الموقع: ${agent['location'] ?? 'غير محدد'}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      label: Text(agent['status'] ?? 'غير محدد', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      backgroundColor: isFrozen ? Colors.red : Colors.green,
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildActionButton(Icons.visibility, 'تفاصيل', Colors.blue, () => _showAgentDetails(agent)),
                                    _buildActionButton(Icons.edit, 'تعديل', Colors.orange, () => _showEditAgentDialog(agent, agentAdmin)),
                                    _buildActionButton(
                                      isFrozen ? Icons.play_arrow : Icons.pause,
                                      isFrozen ? 'تنشيط' : 'تجميد',
                                      isFrozen ? Colors.green : Colors.red,
                                      () => _toggleFreeze(agent, agentAdmin),
                                    ),
                                    _buildActionButton(Icons.delete_forever, 'حذف', Colors.red.shade900, () => _deleteAgent(agent, agentAdmin)),
                                  ],
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
    );
  }

  Widget _buildTextField(String label, IconData icon, {TextEditingController? controller, bool isNumber = false, bool isReadOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        readOnly: isReadOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: isReadOnly ? Colors.grey : Colors.blueAccent),
          filled: isReadOnly,
          fillColor: isReadOnly ? Colors.grey.shade200 : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
