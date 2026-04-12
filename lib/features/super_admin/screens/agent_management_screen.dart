import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/system_provider.dart'; 
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

  // ==========================================
  // 1. نافذة إضافة وكيل جديد (تم تحديثها لتشمل حالة التحميل ومنع ضياع البيانات)
  // ==========================================
  void _showAddAgentDialog(SystemProvider provider) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final networkController = TextEditingController();
    final locationController = TextEditingController(); 
    final profitController = TextEditingController();
    final passwordController = TextEditingController(); 

    showDialog(
      context: context,
      barrierDismissible: false, // 👈 منع إغلاق النافذة بالخطأ أثناء الكتابة
      builder: (context) => StatefulBuilder( // 👈 استخدام StatefulBuilder لتحديث الزر الداخلي
        builder: (context, setStateDialog) {
          bool isLoading = false; // حالة التحميل

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
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
                    _buildTextField('موقع الشبكة (الحي / المنطقة)', Icons.location_on, controller: locationController),
                    _buildTextField('نسبة ربح النظام (العمولة)', Icons.percent, controller: profitController, isNumber: true),
                    _buildTextField('كلمة المرور الافتراضية', Icons.lock, controller: passwordController),
                  ],
                ),
              ),
              actions: [
                if (!isLoading) // إخفاء زر الإلغاء أثناء التحميل
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: isLoading ? null : () async {
                    String phone = phoneController.text.trim();
                    String name = nameController.text.trim();

                    if (name.isNotEmpty && phone.isNotEmpty) {
                      setStateDialog(() => isLoading = true); // 👈 تشغيل مؤشر التحميل

                      String defaultPassword = passwordController.text.trim().isNotEmpty 
                          ? passwordController.text.trim() 
                          : phone;

                      try {
                        // 1. انتظار رد السيرفر
                        await provider.addAgent(
                          name: name,
                          phone: phone,
                          password: defaultPassword,
                          networkName: networkController.text.trim(),
                          profitMargin: profitController.text.trim(),
                          location: locationController.text.trim(),
                        );

                        // 2. إذا نجح الحفظ، نغلق النافذة ونعرض إشعار النجاح
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء حساب الوكيل بنجاح! ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                        }
                      } catch (error) {
                        // 3. إذا فشل، نوقف التحميل ليتدارك المدير الخطأ بدون إغلاق النافذة
                        setStateDialog(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ ❌: $error', textDirection: TextDirection.rtl), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال الاسم ورقم الهاتف على الأقل! ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                    }
                  },
                  // 👈 تغيير شكل الزر أثناء التحميل
                  child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ واعتماد الوكيل', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  // ==========================================
  // 2. نافذة تعديل بيانات وكيل حالي (مع حالة التحميل)
  // ==========================================
  void _showEditAgentDialog(Map<String, dynamic> agent, SystemProvider provider) {
    final nameController = TextEditingController(text: agent['name']);
    final phoneController = TextEditingController(text: agent['phone']);
    final networkController = TextEditingController(text: agent['networkName'] ?? '');
    final locationController = TextEditingController(text: agent['location'] ?? '');
    final profitController = TextEditingController(text: agent['profitMargin'].toString().replaceAll('%', ''));
    final passwordController = TextEditingController(text: agent['password']);

    final oldPhone = agent['phone']; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isLoading = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
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
                    _buildTextField('اسم الشبكة', Icons.wifi, controller: networkController),
                    _buildTextField('موقع الشبكة', Icons.location_on, controller: locationController),
                    _buildTextField('نسبة الربح', Icons.percent, controller: profitController, isNumber: true),
                    _buildTextField('كلمة المرور', Icons.lock, controller: passwordController),
                  ],
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: isLoading ? null : () async {
                    setStateDialog(() => isLoading = true);

                    try {
                      await provider.updateAgentDetails(
                        oldPhone: oldPhone,
                        newPhone: phoneController.text.trim(),
                        newName: nameController.text.trim(),
                        newNetwork: networkController.text.trim(),
                        newLocation: locationController.text.trim(),
                        newProfit: '${profitController.text.trim()}%',
                        newPassword: passwordController.text.trim(),
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تطبيق التعديلات بنجاح ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                      }
                    } catch (error) {
                      setStateDialog(() => isLoading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التعديل ❌: $error', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
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
  // 3. دوال التجميد والحذف (الخلفية)
  // ==========================================
  void _toggleFreeze(Map<String, dynamic> agent, SystemProvider provider) {
    final messenger = ScaffoldMessenger.of(context);
    bool isGoingToFreeze = agent['status'] == 'نشط';

    try {
      provider.toggleUserStatus(agent['phone'], agent['status']);
      messenger.showSnackBar(SnackBar(
        content: Text(isGoingToFreeze ? 'تم تجميد الوكيل بنجاح ⏸️' : 'تم تنشيط الوكيل بنجاح ▶️', textDirection: TextDirection.rtl), 
        backgroundColor: isGoingToFreeze ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 2)
      ));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('فشل تغيير الحالة ❌: $error', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
    }
  }

  void _deleteAgent(Map<String, dynamic> agent, SystemProvider provider) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا الوكيل؟ سيتم مسح بياناته من النظام نهائياً.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  provider.deleteAgent(agent['phone']); 
                  Navigator.pop(context);
                  messenger.showSnackBar(const SnackBar(content: Text('تم الحذف النهائي من السيرفر 🗑️', textDirection: TextDirection.rtl), backgroundColor: Colors.red, duration: Duration(seconds: 2)));
                } catch (error) {
                  Navigator.pop(context);
                  messenger.showSnackBar(SnackBar(content: Text('فشل الحذف ❌: $error', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                }
              },
              child: const Text('نعم، احذف الوكيل', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAgentDetails(Map<String, dynamic> agent) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgentProfileScreen(agentData: agent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;
    final realAgentsList = systemProvider.agentsList; 

    // تصفية الوكلاء الحقيقيين بناءً على البحث
    final filteredAgents = realAgentsList.where((agent) => 
      (agent['name']?.toString() ?? '').contains(_searchQuery) || 
      (agent['phone']?.toString() ?? '').contains(_searchQuery)
    ).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الوكلاء'),
      
      drawer: CustomDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'رصيد النظام: ${adminBalance.toStringAsFixed(0)} ريال', 
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن وكيل بالاسم أو رقم الهاتف...',
                      prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                            side: BorderSide(color: isFrozen ? Colors.red.withOpacity(0.3) : Colors.transparent, width: 1.5)
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
                                    _buildActionButton(Icons.edit, 'تعديل', Colors.orange, () => _showEditAgentDialog(agent, systemProvider)),
                                    _buildActionButton(
                                      isFrozen ? Icons.play_arrow : Icons.pause,
                                      isFrozen ? 'تنشيط' : 'تجميد',
                                      isFrozen ? Colors.green : Colors.red,
                                      () => _toggleFreeze(agent, systemProvider),
                                    ),
                                    _buildActionButton(Icons.delete_forever, 'حذف', Colors.red.shade900, () => _deleteAgent(agent, systemProvider)),
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
