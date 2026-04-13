import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; 

import '../../../core/providers/system_provider.dart'; 
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart'; 

class BannersScreen extends StatefulWidget {
  const BannersScreen({super.key});

  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CollectionReference _bannersCollection = FirebaseFirestore.instance.collection('banners');

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
  // 1. نافذة اختيار الألوان (مساعدة)
  // ==========================================
  void _showColorPicker(String title, Color initialColor, Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: ColorPicker(pickerColor: initialColor, onColorChanged: onColorChanged, pickerAreaHeightPercent: 0.8, enableAlpha: false),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('اعتماد اللون'))],
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة إضافة إعلان جديد (بكل التفاصيل والاستهداف)
  // ==========================================
  void _showAddBannerDialog() {
    bool targetEndUsers = true;
    bool targetMainAgents = true;
    bool targetSubAgents = false;
    bool targetStaff = false;

    final TextEditingController titleController = TextEditingController();
    final TextEditingController imgUrlController = TextEditingController();
    final TextEditingController ctaController = TextEditingController();
    final TextEditingController linkController = TextEditingController();
    final TextEditingController startDateController = TextEditingController();
    final TextEditingController endDateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(children: [Icon(Icons.add_photo_alternate, color: Colors.blueAccent), SizedBox(width: 8), Text('إضافة إعلان / بنر داخلي', style: TextStyle(fontWeight: FontWeight.bold))]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('المعلومات الأساسية 🔴'),
                  _buildTextField('عنوان الإعلان (داخلي لك)', Icons.title, controller: titleController),
                  _buildTextField('رابط الصورة (URL)', Icons.image, controller: imgUrlController),
                  
                  const SizedBox(height: 10),
                  _buildSectionHeader('التوجيه والإجراء 🟢'),
                  _buildTextField('نص الزر (مثال: اشترِ الآن)', Icons.smart_button, controller: ctaController),
                  _buildTextField('مسار التوجيه عند النقر (رابط أو قسم)', Icons.link, controller: linkController),
                  
                  const SizedBox(height: 10),
                  _buildSectionHeader('الجدولة الزمنية 🟢'),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('يبدأ (YYYY-MM-DD)', Icons.play_arrow, controller: startDateController)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField('ينتهي (YYYY-MM-DD)', Icons.stop, controller: endDateController)),
                    ],
                  ),

                  const SizedBox(height: 10),
                  _buildSectionHeader('الاستهداف (لمن يظهر؟) 🎯'),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        CheckboxListTile(title: const Text('المستخدمين النهائيين'), dense: true, value: targetEndUsers, onChanged: (v) => setStateDialog(() => targetEndUsers = v!)),
                        CheckboxListTile(title: const Text('الوكلاء الرئيسيين'), dense: true, value: targetMainAgents, onChanged: (v) => setStateDialog(() => targetMainAgents = v!)),
                        CheckboxListTile(title: const Text('الوكلاء الفرعيين'), dense: true, value: targetSubAgents, onChanged: (v) => setStateDialog(() => targetSubAgents = v!)),
                        CheckboxListTile(title: const Text('الموظفين'), dense: true, value: targetStaff, onChanged: (v) => setStateDialog(() => targetStaff = v!)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  if (titleController.text.isNotEmpty && imgUrlController.text.isNotEmpty) {
                    // تحديد الاستهداف كنص للعرض في القائمة
                    String targetText = 'مخصص';
                    if (targetEndUsers && targetMainAgents && targetSubAgents && targetStaff) targetText = 'الجميع';
                    else if (targetEndUsers && !targetMainAgents) targetText = 'المستخدمين';
                    else if (!targetEndUsers && targetMainAgents) targetText = 'الوكلاء';

                    await _bannersCollection.add({
                      'title': titleController.text,
                      'imageUrl': imgUrlController.text,
                      'ctaText': ctaController.text,
                      'linkUrl': linkController.text,
                      'startDate': startDateController.text,
                      'endDate': endDateController.text,
                      'target': targetText,
                      'targetConfig': {
                        'endUsers': targetEndUsers,
                        'mainAgents': targetMainAgents,
                        'subAgents': targetSubAgents,
                        'staff': targetStaff,
                      },
                      'status': 'نشط',
                      'views': 0,
                      'clicks': 0,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إطلاق الحملة بنجاح! 🚀'), backgroundColor: Colors.green));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء كتابة العنوان ووضع رابط الصورة! ❌'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('حفظ ونشر', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. دوال التحكم بالبنرات (مربوطة بـ Firestore)
  // ==========================================
  void _toggleBannerStatus(String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف مؤقتاً' : 'نشط';
    await _bannersCollection.doc(docId).update({'status': newStatus});
  }

  void _deleteBanner(String docId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الإعلان 🗑️', style: TextStyle(color: Colors.red)),
          content: const Text('هل أنت متأكد من مسح هذه الحملة نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _bannersCollection.doc(docId).delete();
                if(mounted) Navigator.pop(context);
              },
              child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. بناء الواجهة الرئيسية
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الإعلانات والبنرات الداخليـة'),
      drawer: CustomDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${systemProvider.adminMainBalance.toStringAsFixed(0)}',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: themeProvider.primaryColor == const Color(0xFFFFFFFF) ? Colors.blueAccent : themeProvider.primaryColor,
              indicatorColor: themeProvider.primaryColor == const Color(0xFFFFFFFF) ? Colors.blueAccent : themeProvider.primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.campaign), text: 'إعدادات الشريط العلوي'),
                Tab(icon: Icon(Icons.photo_library), text: 'قائمة البنرات التسويقية'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMarqueeSettingsTab(systemProvider), // التبويب الأول
                  _buildBannersListTab(),                 // التبويب الثاني
                ],
              ),
            ),
          ],
        ),
      ),
      // زر إضافة حملة يظهر فقط في تبويب البنرات (التبويب الثاني)
      floatingActionButton: _tabController.index == 1 
          ? FloatingActionButton.extended(
              onPressed: _showAddBannerDialog,
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('حملة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ) 
          : null,
    );
  }

  // ==========================================
  // 🟢 التبويب الأول: إعدادات الشريط العلوي المتحرك
  // ==========================================
  Widget _buildMarqueeSettingsTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إدارة الشريط الإخباري (يظهر أعلى كل الشاشات)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
          const SizedBox(height: 15),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('تفعيل إظهار الشريط', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('إذا تم الإيقاف، سيختفي من جميع لوحات التحكم'),
                    value: sys.showNewsBar,
                    activeColor: Colors.green,
                    onChanged: (v) => sys.updateSystemStatusSettings(maintenance: sys.isMaintenanceMode, forcedUpdate: sys.isForcedUpdate, showNews: v),
                  ),
                  const Divider(),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'نص الشريط الإخباري', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_note)),
                    controller: TextEditingController(text: sys.announcements.isNotEmpty ? sys.announcements.first : ''),
                    onSubmitted: (text) async {
                       await FirebaseFirestore.instance.collection('system').doc('main_info').update({'announcements': [text]});
                       if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير الخبر بجميع اللوحات!'), backgroundColor: Colors.green));
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text('اضغط "Enter" في الكيبورد لحفظ النص 👆', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text('المظهر والتحكم الحركي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          
          Card(
            elevation: 1,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: ListTile(title: const Text('لون الخلفية'), trailing: CircleAvatar(backgroundColor: Color(sys.marqueeBgColor)), onTap: () => _showColorPicker('اختر لون الخلفية', Color(sys.marqueeBgColor), (c) { FirebaseFirestore.instance.collection('system').doc('main_info').update({'marqueeBgColor': c.value}); }))),
                    Container(height: 30, width: 1, color: Colors.grey.shade300),
                    Expanded(child: ListTile(title: const Text('لون النص'), trailing: CircleAvatar(backgroundColor: Color(sys.marqueeTextColor)), onTap: () => _showColorPicker('اختر لون النص', Color(sys.marqueeTextColor), (c) { FirebaseFirestore.instance.collection('system').doc('main_info').update({'marqueeTextColor': c.value}); }))),
                  ],
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.speed, color: Colors.blue),
                  title: const Text('سرعة مرور الخبر'),
                  subtitle: Slider(value: sys.newsScrollSpeed, min: 10, max: 150, activeColor: Colors.blue, onChanged: (v) => sys.updateNewsSpeed(v)),
                  trailing: Text('${sys.newsScrollSpeed.toInt()} px/s', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.text_fields, color: Colors.orange),
                  title: const Text('حجم الخط'),
                  subtitle: Slider(value: sys.marqueeFontSize, min: 10, max: 24, activeColor: Colors.orange, onChanged: (v) {
                    FirebaseFirestore.instance.collection('system').doc('main_info').update({'marqueeFontSize': v});
                  }),
                  trailing: Text(sys.marqueeFontSize.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.purple),
                  title: const Text('اتجاه الحركة'),
                  trailing: DropdownButton<String>(
                    value: sys.marqueeDirection,
                    items: const [DropdownMenuItem(value: 'rtl', child: Text('من اليمين (عربي)')), DropdownMenuItem(value: 'ltr', child: Text('من اليسار (إنجليزي)'))],
                    onChanged: (v) { FirebaseFirestore.instance.collection('system').doc('main_info').update({'marqueeDirection': v}); },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🟢 التبويب الثاني: قائمة البنرات التسويقية (مع الكروت والإحصائيات)
  // ==========================================
  Widget _buildBannersListTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _bannersCollection.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد بنرات حالياً. أنشئ حملتك الأولى من الزر بالأسفل! 🚀', style: TextStyle(color: Colors.grey, fontSize: 14)));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 80), // مساحة سفلية للزر العائم
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id; 
            
            // حساب الإحصائيات (Views, Clicks, CTR)
            int views = data['views'] ?? 0;
            int clicks = data['clicks'] ?? 0;
            double ctr = views > 0 ? (clicks / views) * 100 : 0.0;
            
            bool isPaused = data['status'] == 'موقوف مؤقتاً';
            bool isExpired = data['status'] == 'منتهي';

            Color statusColor = isPaused ? Colors.orange : (isExpired ? Colors.grey : Colors.green);

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: statusColor.withOpacity(0.5), width: 2)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // العنوان والصورة المصغرة والحالة
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(data['imageUrl'] ?? '', width: 80, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 80, height: 60, color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title'] ?? 'بدون عنوان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, decoration: (isPaused || isExpired) ? TextDecoration.lineThrough : null)),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                child: Text(data['status'] ?? 'غير معروف', style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 3),
                              Text('الاستهداف: ${data['target'] ?? 'غير محدد'}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                            ],
                          ),
                        ),
                        // زر الحذف وإيقاف/تشغيل
                        Row(
                          children: [
                            if (!isExpired)
                              IconButton(icon: Icon(isPaused ? Icons.play_circle_fill : Icons.pause_circle_filled, color: isPaused ? Colors.green : Colors.orange, size: 28), onPressed: () => _toggleBannerStatus(docId, data['status'])),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteBanner(docId)),
                          ],
                        )
                      ],
                    ),
                    const Divider(),
                    // الإحصائيات 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(Icons.visibility, 'مشاهدات', '$views', Colors.blue),
                        _buildStatItem(Icons.touch_app, 'نقرات', '$clicks', Colors.purple),
                        _buildStatItem(Icons.analytics, 'تفاعل (CTR)', '${ctr.toStringAsFixed(1)}%', ctr > 5 ? Colors.green : Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- دوال مساعدة في التصميم ---
  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0, top: 10.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)));
  }

  Widget _buildTextField(String hint, IconData icon, {TextEditingController? controller, bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: hint + (isRequired ? ' *' : ''),
          prefixIcon: Icon(icon, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
