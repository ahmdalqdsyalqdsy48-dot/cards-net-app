import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/system_provider.dart'; 
import '../../../core/providers/ui_provider.dart'; // 👈 استدعاء محرك الصوت
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

  // دالة مساعدة لتشغيل الأصوات بسهولة
  void _play(BuildContext context, String type) => 
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // 1. نافذة إضافة وكيل جديد (بأصوات تفاعلية)
  // ==========================================
  void _showAddAgentDialog(SystemProvider provider) {
    _play(context, 'click');
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final networkController = TextEditingController();
    final locationController = TextEditingController(); 
    final profitController = TextEditingController();
    final passwordController = TextEditingController(); 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
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
                    _buildTextField('اسم الشبكة', Icons.wifi, controller: networkController),
                    _buildTextField('موقع الشبكة', Icons.location_on, controller: locationController),
                    _buildTextField('نسبة ربح النظام %', Icons.percent, controller: profitController, isNumber: true),
                    _buildTextField('كلمة المرور', Icons.lock, controller: passwordController),
                  ],
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(onPressed: () { _play(context, 'click'); Navigator.pop(context); }, child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: isLoading ? null : () async {
                    String phone = phoneController.text.trim();
                    String name = nameController.text.trim();

                    if (name.isNotEmpty && phone.isNotEmpty) {
                      setStateDialog(() => isLoading = true); 

                      try {
                        await provider.addAgent(
                          name: name,
                          phone: phone,
                          password: passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : phone,
                          networkName: networkController.text.trim(),
                          profitMargin: profitController.text.trim(),
                          location: locationController.text.trim(),
                        );

                        if (mounted) {
                          _play(context, 'success'); // 👈 صوت النجاح
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة الوكيل بنجاح! ✅'), backgroundColor: Colors.green));
                        }
                      } catch (error) {
                        _play(context, 'error'); // 👈 صوت الخطأ
                        setStateDialog(() => isLoading = false);
                      }
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
  // 2. تجميد الوكيل (مع صوت تبديل الحالة)
  // ==========================================
  void _toggleFreeze(Map<String, dynamic> agent, SystemProvider provider) {
    _play(context, 'click');
    bool isGoingToFreeze = agent['status'] == 'نشط';

    try {
      provider.toggleUserStatus(agent['phone'], agent['status']);
      _play(context, 'success');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isGoingToFreeze ? 'تم تجميد حساب الوكيل ⏸️' : 'تم إعادة تنشيط الوكيل ▶️'), 
        backgroundColor: isGoingToFreeze ? Colors.orange : Colors.green,
      ));
    } catch (e) {
      _play(context, 'error');
    }
  }

  // ==========================================
  // 3. حذف الوكيل (مع صوت الحذف النهائي)
  // ==========================================
  void _deleteAgent(Map<String, dynamic> agent, SystemProvider provider) {
    _play(context, 'click');
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.red)),
          content: Text('هل أنت متأكد من مسح بيانات الوكيل (${agent['name']}) نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await provider.deleteAgent(agent['phone']);
                  _play(context, 'success');
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  _play(context, 'error');
                }
              },
              child: const Text('نعم، احذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final realAgentsList = systemProvider.agentsList; 

    final filteredAgents = realAgentsList.where((agent) => 
      (agent['name']?.toString() ?? '').contains(_searchQuery) || 
      (agent['phone']?.toString() ?? '').contains(_searchQuery)
    ).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الوكلاء'),
      drawer: CustomDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
        role: 'مالك النظام',
        balanceOrPoints: 'رصيد النظام: ${systemProvider.adminMainBalance.toStringAsFixed(0)}', 
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
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
                      onPressed: () => _showAddAgentDialog(systemProvider),
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: const Text('إضافة وكيل جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (value) {
                      if(value.length == 1) _play(context, 'click');
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو الهاتف...',
                      prefixIcon: const Icon(Icons.search),
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
                  ? const Center(child: Text('لا يوجد وكلاء حالياً', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filteredAgents.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final agent = filteredAgents[index];
                        final isFrozen = agent['status'] == 'مجمد';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: isFrozen ? Colors.red.withOpacity(0.5) : Colors.transparent),
                          ),
                          child: ListTile(
                            onTap: () {
                              _play(context, 'click');
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AgentProfileScreen(agentData: agent)));
                            },
                            contentPadding: const EdgeInsets.all(12),
                            title: Text(agent['name'] ?? 'مجهول', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('الرصيد: ${agent['balance'] ?? 0} ريال', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                Text('العمولة: ${agent['profitMargin'] ?? '0%'} | الهاتف: ${agent['phone']}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: Icon(isFrozen ? Icons.play_arrow : Icons.pause, color: isFrozen ? Colors.green : Colors.orange), 
                                  onPressed: () => _toggleFreeze(agent, systemProvider)),
                                IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), 
                                  onPressed: () => _deleteAgent(agent, systemProvider)),
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

  Widget _buildTextField(String label, IconData icon, {TextEditingController? controller, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
