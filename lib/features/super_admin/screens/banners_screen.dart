import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';

class BannersScreen extends StatefulWidget {
  const BannersScreen({super.key});

  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> {
  // قاعدة بيانات وهمية للإعلانات
  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'عرض خصم 10% لكروت يمن موبايل',
      'type': 'صورة بانر (Carousel)',
      'target': 'جميع الوكلاء',
      'status': 'نشط',
      'views': '5,420',
      'clicksApp': '850',
      'clicksEmail': '120',
      'color': Colors.green,
    },
    {
      'title': 'تحديث هام: صيانة لشبكة سبأفون غداً',
      'type': 'شريط إخباري (زجاجي)',
      'target': 'المستخدمين النهائيين',
      'status': 'مجدول',
      'views': '0',
      'clicksApp': '0',
      'clicksEmail': '0',
      'color': Colors.orange,
    },
    {
      'title': 'اشترك بالباقة السنوية واحصل على شهر مجاناً',
      'type': 'صورة مع زر (CTA)',
      'target': 'الوكلاء المجمدين',
      'status': 'منتهي',
      'views': '12,000',
      'clicksApp': '3,200',
      'clicksEmail': '450',
      'color': Colors.red,
    },
  ];

  // ==========================================
  // 1. نافذة إنشاء إعلان جديد (الاستهداف المتقدم) ➕
  // ==========================================
  void _showAddBannerDialog() {
    int adType = 1; // 1: صورة بانر, 2: شريط إخباري
    int sendChannel = 1; // 1: الكل, 2: تطبيق, 3: إيميل
    
    // Checkboxes للاستهداف الدقيق
    bool targetEndUsers = true;
    bool targetMainAgents = true;
    bool targetSubAgents = false;
    bool targetStaff = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.campaign, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('إنشاء حملة إعلانية جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // نوع الإعلان
                  const Text('نوع الإعلان:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(child: RadioListTile(title: const Text('صورة (Carousel)', style: TextStyle(fontSize: 12)), value: 1, groupValue: adType, onChanged: (val) => setStateDialog(() => adType = val as int))),
                      Expanded(child: RadioListTile(title: const Text('شريط زجاجي', style: TextStyle(fontSize: 12)), value: 2, groupValue: adType, onChanged: (val) => setStateDialog(() => adType = val as int))),
                    ],
                  ),
                  if (adType == 1) ...[
                    ElevatedButton.icon(onPressed: (){}, icon: const Icon(Icons.upload_file), label: const Text('رفع الصورة المدمجة')),
                    const SizedBox(height: 10),
                    _buildTextField('نص زر الإجراء (CTA) - مثلاً: اغتنم الفرصة', Icons.smart_button),
                  ] else ...[
                    _buildTextField('نص الشريط الإخباري المتحرك', Icons.text_fields),
                  ],
                  _buildTextField('الرابط عند النقر (URL أو توجيه داخلي)', Icons.link),
                  
                  const Divider(),
                  // قناة الإرسال
                  const Text('قناة الإرسال:', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButtonFormField<int>(
                    value: sendChannel,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('الكل (تطبيق + إيميل)')),
                      DropdownMenuItem(value: 2, child: Text('داخل التطبيق فقط')),
                      DropdownMenuItem(value: 3, child: Text('عبر الإيميل فقط')),
                    ],
                    onChanged: (val) => setStateDialog(() => sendChannel = val!),
                  ),
                  
                  const Divider(),
                  // الاستهداف الدقيق
                  const Text('الاستهداف الدقيق لمن يرى الإعلان:', style: TextStyle(fontWeight: FontWeight.bold)),
                  CheckboxListTile(title: const Text('المستخدمين النهائيين (الزبائن)'), value: targetEndUsers, onChanged: (val) => setStateDialog(() => targetEndUsers = val!)),
                  CheckboxListTile(title: const Text('الوكلاء الرئيسيين'), value: targetMainAgents, onChanged: (val) => setStateDialog(() => targetMainAgents = val!)),
                  CheckboxListTile(title: const Text('وكلاء الوكلاء (الفرعيين)'), value: targetSubAgents, onChanged: (val) => setStateDialog(() => targetSubAgents = val!)),
                  CheckboxListTile(title: const Text('الموظفين الداخليين'), value: targetStaff, onChanged: (val) => setStateDialog(() => targetStaff = val!)),
                  
                  const Divider(),
                  // الجدولة
                  const Text('الجدولة الزمنية:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('بداية (YYYY-MM-DD)', Icons.play_arrow)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField('نهاية (YYYY-MM-DD)', Icons.stop)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إطلاق/جدولة الحملة التسويقية بنجاح! 🚀'), backgroundColor: Colors.green));
                },
                child: const Text('اعتماد الإعلان'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. دوال التحكم بالإعلانات (إيقاف / تشغيل / حذف)
  // ==========================================
  void _toggleBannerStatus(int index) {
    setState(() {
      if (_banners[index]['status'] == 'نشط') {
        _banners[index]['status'] = 'موقوف مؤقتاً';
        _banners[index]['color'] = Colors.grey;
      } else if (_banners[index]['status'] == 'موقوف مؤقتاً') {
        _banners[index]['status'] = 'نشط';
        _banners[index]['color'] = Colors.green;
      }
    });
  }

  void _deleteBanner(int index) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الإعلان 🗑️', style: TextStyle(color: Colors.red)),
          content: const Text('هل أنت متأكد من مسح هذه الحملة الإعلانية نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() => _banners.removeAt(index));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح.'), backgroundColor: Colors.red));
              },
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعلانات التسويقية', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.blueAccent),
      ),
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
            // زر إضافة إعلان جديد
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showAddBannerDialog,
                  icon: const Icon(Icons.campaign, color: Colors.white),
                  label: const Text('إنشاء حملة إعلانية جديدة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),

            // جدول المراقبة والإحصائيات
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _banners.length,
                itemBuilder: (context, index) {
                  final banner = _banners[index];
                  final isExpired = banner['status'] == 'منتهي';

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: banner['color'].withOpacity(0.5), width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Chip(
                                label: Text(banner['status'], style: const TextStyle(color: Colors.white, fontSize: 11)),
                                backgroundColor: banner['color'],
                                padding: EdgeInsets.zero,
                              ),
                              Text(banner['type'], style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(banner['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isExpired ? Colors.grey : Colors.black)),
                          Text('الاستهداف: ${banner['target']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          
                          const Divider(),
                          // الإحصائيات التفصيلية (المشاهدات والنقرات)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatColumn(Icons.visibility, 'المشاهدات', banner['views'], Colors.blue),
                                _buildStatColumn(Icons.touch_app, 'نقرات التطبيق', banner['clicksApp'], Colors.green),
                                _buildStatColumn(Icons.mark_email_read, 'نقرات الإيميل', banner['clicksEmail'], Colors.orange),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          // أزرار التحكم
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!isExpired)
                                IconButton(
                                  icon: Icon(banner['status'] == 'نشط' ? Icons.visibility_off : Icons.visibility, color: banner['status'] == 'نشط' ? Colors.orange : Colors.green),
                                  tooltip: 'إيقاف/تشغيل',
                                  onPressed: () => _toggleBannerStatus(index),
                                ),
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: 'تعديل', onPressed: () {}),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'حذف', onPressed: () => _deleteBanner(index)),
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

  // أداة بناء حقول النصوص في النافذة
  Widget _buildTextField(String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // أداة بناء أعمدة الإحصائيات
  Widget _buildStatColumn(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
      ],
    );
  }
}
