import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; // 👈 تمت إضافة استدعاء الهيدر الجديد هنا

class AgentManagementScreen extends StatefulWidget {
  const AgentManagementScreen({super.key});

  @override
  State<AgentManagementScreen> createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen> {
  // قاعدة بيانات وهمية للوكلاء (لإظهار المنطق البرمجي)
  final List<Map<String, dynamic>> _agents = [
    {'id': 1, 'name': 'أحمد القدسي', 'phone': '774578241', 'network': 'شبكة الصقر', 'location': 'تعز - المسبح', 'balance': '150,000', 'status': 'نشط', 'profit': '5%', 'pos': 3},
    {'id': 2, 'name': 'محمد علي', 'phone': '711223344', 'network': 'شبكة النور', 'location': 'صنعاء - حده', 'balance': '20,000', 'status': 'مجمد', 'profit': '7%', 'pos': 1},
  ];

  // ==========================================
  // 1. نافذة إضافة وكيل جديد (مطابقة لمتطلباتك)
  // ==========================================
  void _showAddAgentDialog() {
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
                _buildTextField('الاسم الرباعي للوكيل', Icons.person),
                _buildTextField('رقم الهاتف (اسم المستخدم)', Icons.phone),
                _buildTextField('اسم الشبكة', Icons.wifi),
                _buildTextField('موقع الشبكة (الحي / المنطقة)', Icons.location_on),
                _buildTextField('كلمة المرور الافتراضية', Icons.lock),
                _buildTextField('نسبة ربح النظام (العمولة)', Icons.percent),
                _buildTextField('رابط تسجيل الدخول (اختياري)', Icons.link),
                _buildTextField('البريد الإلكتروني (اختياري)', Icons.email),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
            ElevatedButton(
              onPressed: () {
                // منطق الحفظ سيتم ربطه بقاعدة البيانات لاحقاً
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الوكيل بنجاح!'), backgroundColor: Colors.green));
              },
              child: const Text('حفظ واعتماد الوكيل'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة تفاصيل الوكيل 👁️
  // ==========================================
  void _showAgentDetails(Map<String, dynamic> agent) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('ملف الوكيل: ${agent['name']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // زر فلترة التاريخ الخاص بالوكيل
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.date_range, size: 16),
                label: const Text('فلترة المبيعات (من - إلى)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50),
              ),
              const Divider(),
              _buildDetailRow('المبيعات الدقيقة:', '450 كرت (هذا الشهر)'),
              _buildDetailRow('مخزون الكروت الحالي:', '1,200 كرت'),
              _buildDetailRow('نقاط البيع (البقالات):', '${agent['pos']} نقاط نشطة'),
              _buildDetailRow('نسبة عمولتك:', agent['profit']),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. دوال التعديل، التجميد، والحذف ✏️ ⏸️ 🗑️
  // ==========================================
  void _toggleFreeze(int index) {
    setState(() {
      if (_agents[index]['status'] == 'نشط') {
        _agents[index]['status'] = 'مجمد';
      } else {
        _agents[index]['status'] = 'نشط';
      }
    });
  }

  void _softDeleteAgent(int index) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.red)),
          content: const Text('هل أنت متأكد من حذف هذا الوكيل؟ سيتم طرده من النظام ولكن ستبقى فواتيره القديمة محفوظة لضبط الحسابات الختامية (Soft Delete).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  _agents.removeAt(index);
                });
                Navigator.pop(context);
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
    return Scaffold(
      // 👈 تم تركيب الهيدر الشامل هنا بنجاح!
      appBar: const CustomHeader(title: 'إدارة الوكلاء'),
      
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // زر الإضافة العلوي
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
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
            ),

            // جدول المراقبة الرئيسي
            Expanded(
              child: _agents.isEmpty
                  ? const Center(child: Text('لا يوجد وكلاء حالياً.'))
                  : ListView.builder(
                      itemCount: _agents.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final agent = _agents[index];
                        final isFrozen = agent['status'] == 'مجمد';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                // بيانات الوكيل
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${agent['name']} - ${agent['network']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text('الهاتف: ${agent['phone']} | الرصيد: ${agent['balance']} ريال', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                      ],
                                    ),
                                    Chip(
                                      label: Text(agent['status'], style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      backgroundColor: isFrozen ? Colors.red : Colors.green,
                                    ),
                                  ],
                                ),
                                const Divider(),
                                // أزرار التحكم الفردية
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildActionButton(Icons.visibility, 'تفاصيل', Colors.blue, () => _showAgentDetails(agent)),
                                    _buildActionButton(Icons.edit, 'تعديل', Colors.orange, () {}),
                                    _buildActionButton(
                                      isFrozen ? Icons.play_arrow : Icons.pause,
                                      isFrozen ? 'تنشيط' : 'تجميد',
                                      isFrozen ? Colors.green : Colors.red,
                                      () => _toggleFreeze(index),
                                    ),
                                    _buildActionButton(Icons.delete_forever, 'حذف', Colors.red.shade900, () => _softDeleteAgent(index)),
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

  // دوال مساعدة لبناء واجهة المستخدم بأسلوب نظيف
  Widget _buildTextField(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
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
