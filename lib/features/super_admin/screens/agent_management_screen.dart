import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 استدعاء مكتبة العقل المدبر

import '../../../core/providers/system_provider.dart'; // 👈 استدعاء الخادم المحلي الشامل
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 
import 'agent_profile_screen.dart'; 

class AgentManagementScreen extends StatefulWidget {
  const AgentManagementScreen({super.key});

  @override
  State<AgentManagementScreen> createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen> {
  // متغير للبحث
  String _searchQuery = '';

  // قائمة الوكلاء (تم تحويلها لمتغير قابل للتعديل والإضافة)
  List<Map<String, dynamic>> _agents = [
    {'id': 1, 'name': 'أحمد القدسي', 'phone': '774578241', 'network': 'شبكة الصقر', 'location': 'تعز - المسبح', 'balance': '150,000', 'status': 'نشط', 'profit': '5%', 'pos': 3},
    {'id': 2, 'name': 'محمد علي', 'phone': '711223344', 'network': 'شبكة النور', 'location': 'صنعاء - حده', 'balance': '20,000', 'status': 'مجمد', 'profit': '7%', 'pos': 1},
  ];

  // ==========================================
  // 1. نافذة إضافة وكيل جديد (تم تفعيلها برمجياً)
  // ==========================================
  void _showAddAgentDialog() {
    // متحكمات لقراءة المدخلات
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final networkController = TextEditingController();
    final profitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
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
                _buildTextField('موقع الشبكة (الحي / المنطقة)', Icons.location_on),
                _buildTextField('نسبة ربح النظام (العمولة)', Icons.percent, controller: profitController, isNumber: true),
                _buildTextField('كلمة المرور الافتراضية', Icons.lock),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () {
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                  // إضافة الوكيل الجديد إلى القائمة
                  setState(() {
                    _agents.add({
                      'id': DateTime.now().millisecondsSinceEpoch,
                      'name': nameController.text,
                      'phone': phoneController.text,
                      'network': networkController.text.isNotEmpty ? networkController.text : 'غير محدد',
                      'location': 'غير محدد',
                      'balance': '0',
                      'status': 'نشط',
                      'profit': '${profitController.text.isNotEmpty ? profitController.text : '5'}%',
                      'pos': 0,
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الوكيل بنجاح! ✅'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال الاسم ورقم الهاتف على الأقل! ❌'), backgroundColor: Colors.red));
                }
              },
              child: const Text('حفظ واعتماد الوكيل', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة تعديل بيانات وكيل حالي (ميزة جديدة)
  // ==========================================
  void _showEditAgentDialog(int index, Map<String, dynamic> agent) {
    final nameController = TextEditingController(text: agent['name']);
    final phoneController = TextEditingController(text: agent['phone']);
    final profitController = TextEditingController(text: agent['profit'].toString().replaceAll('%', ''));

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.orange),
              SizedBox(width: 10),
              Text('تعديل بيانات الوكيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('الاسم الرباعي', Icons.person, controller: nameController),
              _buildTextField('رقم الهاتف', Icons.phone, controller: phoneController, isNumber: true),
              _buildTextField('نسبة الربح', Icons.percent, controller: profitController, isNumber: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                setState(() {
                  _agents[index]['name'] = nameController.text;
                  _agents[index]['phone'] = phoneController.text;
                  _agents[index]['profit'] = '${profitController.text}%';
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح! ✏️'), backgroundColor: Colors.green));
              },
              child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. دالة فتح الملف الشامل للوكيل
  // ==========================================
  void _showAgentDetails(Map<String, dynamic> agent) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgentProfileScreen(agentData: agent)),
    );
  }

  // ==========================================
  // 4. دوال التجميد والحذف
  // ==========================================
  void _toggleFreeze(int index) {
    setState(() {
      _agents[index]['status'] = _agents[index]['status'] == 'نشط' ? 'مجمد' : 'نشط';
    });
    final status = _agents[index]['status'];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(status == 'مجمد' ? 'تم تجميد الوكيل بنجاح ⏸️' : 'تم تنشيط الوكيل بنجاح ▶️'), 
      backgroundColor: status == 'مجمد' ? Colors.orange : Colors.green
    ));
  }

  void _softDeleteAgent(int index) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا الوكيل؟ سيتم طرده من النظام ولكن ستبقى فواتيره القديمة محفوظة لضبط الحسابات الختامية (Soft Delete).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() { _agents.removeAt(index); });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الوكيل نهائياً 🗑️'), backgroundColor: Colors.red));
              },
              child: const Text('نعم، احذف الوكيل', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👈 قراءة رصيد النظام من العقل المدبر لعرضه في القائمة الجانبية
    final systemProvider = Provider.of<SystemProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;

    // تصفية الوكلاء بناءً على البحث
    final filteredAgents = _agents.where((agent) => 
      agent['name'].toString().contains(_searchQuery) || 
      agent['phone'].toString().contains(_searchQuery)
    ).toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الوكلاء'),
      
      drawer: CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'رصيد النظام: ${adminBalance.toStringAsFixed(0)} ريال', // 👈 ديناميكي
      ),
      
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // شريط الإضافة والبحث
            // ==========================================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _showAddAgentDialog,
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: const Text('إضافة وكيل جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // محرك البحث
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

            // ==========================================
            // جدول المراقبة الرئيسي
            // ==========================================
            Expanded(
              child: filteredAgents.isEmpty
                  ? const Center(child: Text('لا يوجد وكلاء مطابقين للبحث.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filteredAgents.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final agent = filteredAgents[index];
                        final isFrozen = agent['status'] == 'مجمد';
                        // لنجد الـ index الأصلي في القائمة الأساسية لتعديله بشكل صحيح
                        final originalIndex = _agents.indexWhere((a) => a['id'] == agent['id']);

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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${agent['name']} - ${agent['network']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isFrozen ? TextDecoration.lineThrough : null)),
                                        Text('الهاتف: ${agent['phone']} | العمولة: ${agent['profit']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        Text('الرصيد: ${agent['balance']} ريال', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    Chip(
                                      label: Text(agent['status'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      backgroundColor: isFrozen ? Colors.red : Colors.green,
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildActionButton(Icons.visibility, 'تفاصيل', Colors.blue, () => _showAgentDetails(agent)),
                                    _buildActionButton(Icons.edit, 'تعديل', Colors.orange, () => _showEditAgentDialog(originalIndex, agent)),
                                    _buildActionButton(
                                      isFrozen ? Icons.play_arrow : Icons.pause,
                                      isFrozen ? 'تنشيط' : 'تجميد',
                                      isFrozen ? Colors.green : Colors.red,
                                      () => _toggleFreeze(originalIndex),
                                    ),
                                    _buildActionButton(Icons.delete_forever, 'حذف', Colors.red.shade900, () => _softDeleteAgent(originalIndex)),
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

  // ==========================================
  // أدوات مساعدة للتصميم
  // ==========================================
  Widget _buildTextField(String label, IconData icon, {TextEditingController? controller, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
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
