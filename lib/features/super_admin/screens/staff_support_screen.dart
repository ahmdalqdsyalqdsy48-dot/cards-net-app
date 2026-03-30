import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 1. استدعاء مكتبة العقل المدبر

import '../../../core/providers/system_provider.dart'; // 👈 2. استدعاء الخادم المحلي
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 

class StaffSupportScreen extends StatefulWidget {
  const StaffSupportScreen({super.key});

  @override
  State<StaffSupportScreen> createState() => _StaffSupportScreenState();
}

class _StaffSupportScreenState extends State<StaffSupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1. قاعدة بيانات للموظفين (أصبحت تفاعلية وقابلة للتعديل)
  final List<Map<String, dynamic>> _staff = [
    {'name': 'محمود المالي', 'phone': '771122334', 'role': 'محاسب', 'salary': '80,000 ريال', 'status': 'نشط'},
    {'name': 'سالم الدعم', 'phone': '712345678', 'role': 'خدمة عملاء', 'salary': '60,000 ريال', 'status': 'موقوف'},
  ];

  // 2. قاعدة بيانات لتذاكر الدعم الفني
  final List<Map<String, dynamic>> _tickets = [
    {'id': '#1024', 'agent': 'شبكة الصقر', 'subject': 'تأخر وصول الحوالة للمحفظة', 'priority': 'عالية 🔴', 'status': 'مفتوحة'},
    {'id': '#1025', 'agent': 'وكالة النور', 'subject': 'استفسار عن نسبة الباقة', 'priority': 'عادية 🟢', 'status': 'قيد المعالجة'},
    {'id': '#1026', 'agent': 'العالمية', 'subject': 'نسيت كلمة المرور الخاصة بي', 'priority': 'متوسطة 🟡', 'status': 'مغلقة'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. نافذة إضافة موظف جديد 👥 (تم تفعيلها برمجياً)
  // ==========================================
  void _showAddStaffDialog() {
    // متحكمات لقراءة المدخلات
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final salaryController = TextEditingController();
    
    // خريطة الصلاحيات الـ 12 الشاملة
    Map<String, bool> permissions = {
      'الرئيسية (غرفة العمليات)': false,
      'إدارة الوكلاء الشاملة': false,
      'المركز المالي والمحافظ': false,
      'التقارير الشاملة': false,
      'إدارة الاشتراكات والباقات': false,
      'الحسابات البنكية': false,
      'إدارة الموظفين والدعم': false,
      'الإعلانات التسويقية': false,
      'بوابة رسائل الـ SMS': false,
      'السجل الأسود للنشاط (للقراءة)': false,
      'الإعدادات العامة': false,
      'النسخ الاحتياطي': false,
    };
    
    bool selectAll = false; // زر التحديد الشامل

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1, color: Colors.blue),
                SizedBox(width: 10),
                Text('إضافة موظف جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('الاسم الرباعي', Icons.person, controller: nameController),
                  _buildTextField('رقم الهاتف', Icons.phone, controller: phoneController, isNumber: true),
                  _buildTextField('كلمة المرور الافتراضية', Icons.lock),
                  _buildTextField('الراتب الشهري (اختياري)', Icons.monetization_on, controller: salaryController, isNumber: true),
                  
                  const Divider(),
                  const Text('الصلاحيات الممنوحة للموظف:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  
                  // زر تحديد الكل السحري
                  CheckboxListTile(
                    title: const Text('تحديد كافة الصلاحيات ✅', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    value: selectAll,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                      setStateDialog(() {
                        selectAll = val!;
                        permissions.updateAll((key, value) => selectAll);
                      });
                    },
                  ),
                  
                  // صندوق القائمة القابلة للتمرير
                  Container(
                    height: 200, 
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.grey.shade50,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: permissions.keys.map((String key) {
                        return CheckboxListTile(
                          title: Text(key, style: const TextStyle(fontSize: 13)),
                          value: permissions[key],
                          activeColor: Colors.green,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          dense: true,
                          onChanged: (val) {
                            setStateDialog(() {
                              permissions[key] = val!;
                              if (!val) selectAll = false;
                              if (permissions.values.every((element) => element == true)) selectAll = true;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                    setState(() {
                      _staff.add({
                        'name': nameController.text,
                        'phone': phoneController.text,
                        'role': 'موظف مخصص',
                        'salary': salaryController.text.isNotEmpty ? '${salaryController.text} ريال' : 'غير محدد',
                        'status': 'نشط',
                      });
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الموظف وصلاحياته بنجاح! ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم ورقم هاتف الموظف! ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                  }
                },
                child: const Text('حفظ الموظف'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // دوال التحكم بالموظفين (حذف / إيقاف)
  // ==========================================
  void _toggleStaffStatus(int index) {
    setState(() {
      _staff[index]['status'] = _staff[index]['status'] == 'نشط' ? 'موقوف' : 'نشط';
    });
  }

  void _deleteStaff(int index) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الموظف 🗑️', style: TextStyle(color: Colors.red)),
          content: const Text('هل أنت متأكد من حذف هذا الموظف؟ سيتم إلغاء وصوله للنظام فوراً.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() => _staff.removeAt(index));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الموظف بنجاح.', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
              },
              child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _paySalary(String staffName) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسليم الراتب 💸', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          content: Text('هل تقر بتسليم الراتب للموظف "$staffName"؟\n\n(سيقوم النظام آلياً بتسجيل المبلغ كـ "مصروفات تشغيلية" لخصمه من صافي أرباحك في التقارير الختامية).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الراتب كمصروفات تشغيلية بنجاح. ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
              },
              child: const Text('نعم، أقر بالتسليم', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // دوال التبويب الثاني (تذاكر الدعم الفني) 🎧
  // ==========================================
  void _showTicketChat(Map<String, dynamic> ticket) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تذكرة ${ticket['id']} - ${ticket['agent']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade900 : Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Text('الوكيل: ${ticket['subject']} \n(منذ ساعتين)', style: const TextStyle()),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14, color: Colors.orange),
                        SizedBox(width: 5),
                        Text('ملاحظة داخلية (محمود المحاسب):\nتم مراجعة كشف البنك، الحوالة لم تصل بعد.', style: TextStyle(fontSize: 12, color: Colors.brown)),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'اكتب ردك للوكيل هنا...',
                    suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الرد للوكيل بنجاح ✉️', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                    }),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                 Navigator.pop(context);
                 _showInternalNoteDialog();
              }, 
              child: const Text('➕ إضافة ملاحظة سرية', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق الدردشة')),
          ],
        ),
      ),
    );
  }

  void _showInternalNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.amber.shade50,
          title: const Text('ملاحظة داخلية سرية 🔒', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          content: const TextField(
            maxLines: 3,
            decoration: InputDecoration(hintText: 'اكتب الملاحظة التي لن يراها الوكيل أبداً...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () => Navigator.pop(context), child: const Text('حفظ الملاحظة', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  void _showAssignTicketDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إحالة التذكرة ↪️', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر الموظف الذي تريد تحويل التذكرة إليه:'),
              const SizedBox(height: 10),
              ListTile(title: const Text('محمود المالي (محاسب)'), leading: const Icon(Icons.person), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إحالة التذكرة بنجاح.', textDirection: TextDirection.rtl))); }),
              ListTile(title: const Text('سالم الدعم (خدمة عملاء)'), leading: const Icon(Icons.person), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إحالة التذكرة بنجاح.', textDirection: TextDirection.rtl))); }),
            ],
          ),
        ),
      ),
    );
  }

  // 👈 دالة إغلاق التذكرة
  void _closeTicket(int index) {
    setState(() {
      _tickets[index]['status'] = 'مغلقة';
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق التذكرة وأرشفتها بنجاح. ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.blueGrey));
  }

  @override
  Widget build(BuildContext context) {
    // 👈 3. جلب الأرباح الحقيقية للنظام من العقل المدبر
    final systemProvider = Provider.of<SystemProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الموظفين والدعم'),
      // 👈 تمرير الرصيد بأمان
      drawer: CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: Colors.transparent,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.people_alt), text: 'الموظفين والصلاحيات'),
                  Tab(icon: Icon(Icons.support_agent), text: 'تذاكر الدعم الفني'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStaffTab(),
                  _buildTicketsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // واجهة التبويب الأول: الموظفين 👥
  // ==========================================
  Widget _buildStaffTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: _showAddStaffDialog,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('إضافة موظف جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ),
        Expanded(
          child: _staff.isEmpty 
            ? const Center(child: Text('لا يوجد موظفين حالياً.', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _staff.length,
            itemBuilder: (context, index) {
              final emp = _staff[index];
              final isActive = emp['status'] == 'نشط';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: isActive ? Colors.transparent : Colors.red.withOpacity(0.3), width: 1.5)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${emp['name']} (${emp['role']})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough)),
                          Chip(label: Text(emp['status'], style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: isActive ? Colors.green : Colors.red),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('هاتف: ${emp['phone']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          Text('الراتب: ${emp['salary']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildIconButton(Icons.settings, 'تعديل', Colors.blue, () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نافذة التعديل ستتوفر قريباً ⚙️', textDirection: TextDirection.rtl))); }),
                          _buildIconButton(isActive ? Icons.pause_circle : Icons.play_circle, isActive ? 'إيقاف' : 'تفعيل', isActive ? Colors.orange : Colors.green, () => _toggleStaffStatus(index)),
                          _buildIconButton(Icons.delete, 'حذف', Colors.red, () => _deleteStaff(index)),
                          _buildIconButton(Icons.monetization_on, 'تسليم الراتب', Colors.green, () => _paySalary(emp['name'])),
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
    );
  }

  // ==========================================
  // واجهة التبويب الثاني: تذاكر الدعم 🎧
  // ==========================================
  Widget _buildTicketsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final isClosed = ticket['status'] == 'مغلقة';

        return Card(
          elevation: isClosed ? 0 : 3,
          color: isClosed ? Theme.of(context).cardColor.withOpacity(0.5) : Theme.of(context).cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isClosed ? Colors.grey.shade300 : Colors.transparent)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${ticket['id']} | ${ticket['agent']}', style: TextStyle(fontWeight: FontWeight.bold, color: isClosed ? Colors.grey : null)),
                    Text(ticket['priority'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(ticket['subject'], style: TextStyle(fontSize: 14, color: isClosed ? Colors.grey : Colors.blueGrey)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIconButton(Icons.chat, 'فتح التذكرة', isClosed ? Colors.grey : Colors.blue, () => _showTicketChat(ticket)),
                    _buildIconButton(Icons.lock, 'ملاحظة سرية', isClosed ? Colors.grey : Colors.orange, _showInternalNoteDialog),
                    if (!isClosed) _buildIconButton(Icons.shortcut, 'إحالة إلى..', Colors.purple, _showAssignTicketDialog),
                    if (!isClosed) _buildIconButton(Icons.check_circle, 'إغلاق', Colors.green, () => _closeTicket(index)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // دوال مساعدة للتصميم
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

  Widget _buildIconButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
