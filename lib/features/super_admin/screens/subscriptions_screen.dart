import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; // 👈 استدعاء الهيدر الجديد

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  // قاعدة بيانات وهمية لاشتراكات الوكلاء مع حالاتهم المختلفة
  final List<Map<String, dynamic>> _subscriptions = [
    {'name': 'أحمد القدسي', 'plan': 'باقة 5% (مفتوح)', 'expiry': '2026-04-10', 'status': 'نشط', 'color': Colors.blue},
    {'name': 'محمد علي', 'plan': 'فترة مجانية (14 يوم)', 'expiry': '2026-03-28', 'status': 'فترة مجانية', 'color': Colors.green},
    {'name': 'شبكة العالمية', 'plan': 'باقة 7% (3 نقاط)', 'expiry': '2026-03-25', 'status': 'إنذار', 'color': Colors.orange},
    {'name': 'وكالة النور', 'plan': 'باقة 5% (مفتوح)', 'expiry': '2026-03-01', 'status': 'مجمد', 'color': Colors.red},
  ];

  // ==========================================
  // 1. نافذة إنشاء خطة / اشتراك جديد ➕
  // ==========================================
  void _showCreatePlanDialog() {
    int targetingFilter = 1; // 1: الكل, 2: محدد, 3: وكيل واحد

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_box, color: Colors.blue),
                SizedBox(width: 8),
                Text('إنشاء خطة / اشتراك جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('نسبة ربح النظام (مثلاً 5% أو 7%)', Icons.percent),
                  _buildTextField('مدة الخطة (بالأشهر)', Icons.calendar_today),
                  _buildTextField('الحد الأقصى لنقاط البيع (أو اترك فارغ للمفتوح)', Icons.storefront),
                  
                  const Divider(),
                  const Text('فلاتر الاستهداف (التخصيص المتقدم):', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile(
                    title: const Text('تطبيق على جميع الوكلاء'),
                    value: 1,
                    groupValue: targetingFilter,
                    onChanged: (val) => setStateDialog(() => targetingFilter = val as int),
                  ),
                  RadioListTile(
                    title: const Text('تطبيق على وكلاء محددين'),
                    value: 2,
                    groupValue: targetingFilter,
                    onChanged: (val) => setStateDialog(() => targetingFilter = val as int),
                  ),
                  RadioListTile(
                    title: const Text('تخصيص لوكيل واحد فقط'),
                    value: 3,
                    groupValue: targetingFilter,
                    onChanged: (val) => setStateDialog(() => targetingFilter = val as int),
                  ),
                  if (targetingFilter == 3)
                    _buildTextField('ابحث عن اسم الوكيل...', Icons.search),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الخطة للروبوت الآلي لتطبيقها.'), backgroundColor: Colors.blue));
                },
                child: const Text('حفظ واعتماد الخطة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة إنشاء كوبون ترويجي 🎟️
  // ==========================================
  void _showCreateCouponDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('توليد كوبون ترويجي', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('كود الكوبون (مثال: YEMEN2026)', Icons.local_offer),
              _buildTextField('نسبة الخصم أو المدة المجانية', Icons.discount),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('توليد الكوبون', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. نافذة تعديل الفترة المجانية / خطة الوكيل ⏳
  // ==========================================
  void _showEditPlanDialog(String agentName) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل فترة: $agentName', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('بمجرد الحفظ، سيصل إشعار فوري للوكيل وسيتبرمج الرادار للعد التنازلي.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              _buildTextField('تاريخ البداية (YYYY-MM-DD)', Icons.play_circle_outline),
              _buildTextField('تاريخ النهاية بدقة (YYYY-MM-DD)', Icons.stop_circle_outlined),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('تحديث العداد')),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. نافذة سجل الخطط التاريخي 📜
  // ==========================================
  void _showHistoryLog(String agentName) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('السجل التاريخي لخطط: $agentName', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: const [
                ListTile(
                  leading: Icon(Icons.history, color: Colors.grey),
                  title: Text('باقة 5% (مفتوح)'),
                  subtitle: Text('من: 01-01-2026 | إلى: الآن\nبواسطة: مالك النظام'),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.history, color: Colors.grey),
                  title: Text('فترة مجانية تجريبية'),
                  subtitle: Text('من: 15-12-2025 | إلى: 31-12-2025\nبواسطة: كوبون YEMEN2026'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // إيقاف واستئناف الخطة ⏸️ ▶️
  // ==========================================
  void _togglePausePlan(int index) {
    setState(() {
      if (_subscriptions[index]['status'] == 'موقوف مؤقتاً') {
        _subscriptions[index]['status'] = 'نشط';
        _subscriptions[index]['color'] = Colors.blue;
      } else {
        _subscriptions[index]['status'] = 'موقوف مؤقتاً';
        _subscriptions[index]['color'] = Colors.grey;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👈 تم تركيب الهيدر الشامل هنا بنجاح!
      appBar: const CustomHeader(title: 'إدارة الاشتراكات'),
      
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
            // === أدوات التخصيص العلوية ===
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _showCreatePlanDialog,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('إنشاء خطة / اشتراك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: _showCreateCouponDialog,
                      icon: const Icon(Icons.local_offer, color: Colors.white),
                      label: const Text('كوبون', style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 👈 زر إعدادات الرادار الذي كان في الهيدر نقلناه هنا ليكون دائماً في متناول يدك!
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings_suggest, color: Colors.blueAccent),
                      tooltip: 'إعدادات الرادار الآلي وفترة السماح',
                      onPressed: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إعدادات فترة السماح (Grace Period) للروبوت.')));
                      },
                    ),
                  ),
                ],
              ),
            ),

            // === جدول المراقبة الرئيسي ===
            Expanded(
              child: ListView.builder(
                itemCount: _subscriptions.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final sub = _subscriptions[index];
                  final isPaused = sub['status'] == 'موقوف مؤقتاً';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 15),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: sub['color'].withOpacity(0.5))),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(sub['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: sub['color'], borderRadius: BorderRadius.circular(20)),
                                child: Text(sub['status'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text('الخطة الحالية: ${sub['plan']}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          Text('تاريخ الانتهاء: ${sub['expiry']}', style: TextStyle(color: sub['color'] == Colors.orange ? Colors.orange : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                          
                          const Divider(),
                          // === أزرار التحكم الفردية ===
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildActionButton(Icons.hourglass_bottom, 'تعديل المدة', Colors.blue, () => _showEditPlanDialog(sub['name'])),
                              _buildActionButton(
                                isPaused ? Icons.play_arrow : Icons.pause_circle_outline,
                                isPaused ? 'استئناف' : 'إيقاف مؤقت',
                                isPaused ? Colors.green : Colors.deepOrange,
                                () => _togglePausePlan(index),
                              ),
                              _buildActionButton(Icons.history_edu, 'السجل التاريخي', Colors.blueGrey, () => _showHistoryLog(sub['name'])),
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

  Widget _buildActionButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
