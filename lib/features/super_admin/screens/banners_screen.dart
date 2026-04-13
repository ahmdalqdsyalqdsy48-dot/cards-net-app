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
  // 1. أدوات مساعدة (اختيار الألوان)
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
  // 2. نافذة إنشاء حملة جديدة (بالاستهداف الدقيق)
  // ==========================================
  void _showAddBannerDialog() {
    // المتغيرات المحلية للنافذة
    bool targetEndUsers = true, targetMainAgents = true, targetSubAgents = false, targetStaff = false, targetAdmin = false;
    String customPhoneRule = 'none'; // 'none', 'include_only', 'exclude'
    
    final titleCtrl = TextEditingController();
    final imgUrlCtrl = TextEditingController();
    final ctaCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final customPhonesCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(children: [Icon(Icons.campaign, color: Colors.blueAccent), SizedBox(width: 8), Text('إنشاء حملة تسويقية / بنر داخلي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الحقول الإجبارية
                    _buildSectionHeader('المعلومات الأساسية (إجبارية) 🔴'),
                    _buildTextField('عنوان الإعلان (داخلي للمتابعة)', Icons.title, controller: titleCtrl, isRequired: true),
                    _buildTextField('رابط الصورة (URL)', Icons.image, controller: imgUrlCtrl, isRequired: true),
                    
                    const SizedBox(height: 15),
                    
                    // الحقول الاختيارية
                    _buildSectionHeader('التوجيه والإجراء (اختياري) 🟢'),
                    _buildTextField('نص الزر (مثال: اشترِ الآن)', Icons.smart_button, controller: ctaCtrl),
                    _buildTextField('رابط التوجيه عند النقر (مسار الشاشة أو رابط إنترنت)', Icons.link, controller: linkCtrl),
                    
                    const SizedBox(height: 15),

                    _buildSectionHeader('الجدولة الزمنية (اختياري - فارغ = مستمر) 🟢'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('يبدأ في (YYYY-MM-DD)', Icons.play_circle, controller: startCtrl)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField('ينتهي في (YYYY-MM-DD)', Icons.stop_circle, controller: endCtrl)),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // محرك الاستهداف الدقيق (العبقري)
                    _buildSectionHeader('الاستهداف (من يرى الإعلان؟) 🎯'),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          CheckboxListTile(title: const Text('الزبائن النهائيين (Users)', style: TextStyle(fontSize: 13)), value: targetEndUsers, dense: true, onChanged: (v) => setStateDialog(() => targetEndUsers = v!)),
                          CheckboxListTile(title: const Text('الوكلاء الرئيسيين (Main Agents)', style: TextStyle(fontSize: 13)), value: targetMainAgents, dense: true, onChanged: (v) => setStateDialog(() => targetMainAgents = v!)),
                          CheckboxListTile(title: const Text('الوكلاء الفرعيين (Sub Agents)', style: TextStyle(fontSize: 13)), value: targetSubAgents, dense: true, onChanged: (v) => setStateDialog(() => targetSubAgents = v!)),
                          CheckboxListTile(title: const Text('الموظفين (Staff)', style: TextStyle(fontSize: 13)), value: targetStaff, dense: true, onChanged: (v) => setStateDialog(() => targetStaff = v!)),
                          CheckboxListTile(title: const Text('مالك النظام (Super Admin)', style: TextStyle(fontSize: 13)), value: targetAdmin, dense: true, onChanged: (v) => setStateDialog(() => targetAdmin = v!)),
                          
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تخصيص بأرقام الهواتف (مفصولة بفاصلة):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: customPhonesCtrl,
                                  decoration: const InputDecoration(hintText: '777..., 711...', isDense: true, border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 5),
                                DropdownButton<String>(
                                  isExpanded: true,
                                  value: customPhoneRule,
                                  items: const [
                                    DropdownMenuItem(value: 'none', child: Text('لا تفعل شيء (تجاهل الأرقام أعلاه)')),
                                    DropdownMenuItem(value: 'include_only', child: Text('عرض الإعلان لهؤلاء الأشخاص فقط')),
                                    DropdownMenuItem(value: 'exclude', child: Text('إخفاء الإعلان عن هؤلاء الأشخاص فقط')),
                                  ],
                                  onChanged: (v) => setStateDialog(() => customPhoneRule = v!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  if (titleCtrl.text.isEmpty || imgUrlCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة الحقول الإجبارية (العنوان والصورة)!'), backgroundColor: Colors.red));
                    return;
                  }
                  
                  // تجهيز خريطة الاستهداف للسيرفر
                  Map<String, dynamic> targetConfig = {
                    'roles': {
                      'user': targetEndUsers,
                      'agent': targetMainAgents,
                      'sub_agent': targetSubAgents,
                      'staff': targetStaff,
                      'super_admin': targetAdmin,
                    },
                    'customPhones': customPhonesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                    'customRule': customPhoneRule,
                  };

                  await _bannersCollection.add({
                    'title': titleCtrl.text,
                    'imageUrl': imgUrlCtrl.text,
                    'ctaText': ctaCtrl.text,
                    'linkUrl': linkCtrl.text,
                    'startDate': startCtrl.text,
                    'endDate': endCtrl.text,
                    'status': 'نشط',
                    'targetConfig': targetConfig,
                    'views': 0, 'clicks': 0,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إطلاق الحملة التسويقية بنجاح! 🚀'), backgroundColor: Colors.green));
                  }
                },
                child: const Text('حفظ ونشر الإعلان', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. بناء واجهة الشاشة الرئيسية
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: const CustomHeader(title: 'لوحة التحكم بالإعلانات الداخلية'),
      drawer: CustomDrawer(userName: sys.currentUserName, phoneNumber: sys.currentUserPhone, role: 'مالك النظام', balanceOrPoints: 'أرباح النظام: ${sys.adminMainBalance.toStringAsFixed(0)}'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: theme.primaryColor == const Color(0xFFFFFFFF) ? Colors.blueAccent : theme.primaryColor,
              indicatorColor: theme.primaryColor == const Color(0xFFFFFFFF) ? Colors.blueAccent : theme.primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.campaign), text: 'إعدادات الشريط العلوي'),
                Tab(icon: Icon(Icons.photo_library), text: 'إدارة البنرات (الداخلية)'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMarqueeSettingsTab(sys), // التبويب الأول
                  _buildBannersListTab(),      // التبويب الثاني
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1 ? FloatingActionButton.extended(
        onPressed: _showAddBannerDialog,
        backgroundColor: Colors.blue.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('حملة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
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
                       if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير الخبر!'), backgroundColor: Colors.green));
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
                    Container(height: 30, width: 1, color: Colors.grey.shade300), // فاصل
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
          const SizedBox(height: 80), // مساحة للـ FloatingButton لو تم التبديل
        ],
      ),
    );
  }

  // ==========================================
  // 🟢 التبويب الثاني: قائمة البنرات التسويقية (مع الإحصائيات)
  // ==========================================
  Widget _buildBannersListTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _bannersCollection.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد بنرات حالياً. أنشئ حملتك الأولى! 🚀', style: TextStyle(color: Colors.grey, fontSize: 16)));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 80), // مساحة سفلية للزر
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id; 
            
            // حساب نسبة النقر للظهور (CTR)
            int views = data['views'] ?? 0;
            int clicks = data['clicks'] ?? 0;
            double ctr = views > 0 ? (clicks / views) * 100 : 0.0;
            
            bool isPaused = data['status'] == 'موقوف';

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isPaused ? Colors.red.shade200 : Colors.green.shade200, width: 2)),
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
                          child: Image.network(data['imageUrl'] ?? '', width: 80, height: 50, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 80, height: 50, color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title'] ?? 'بدون عنوان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, decoration: isPaused ? TextDecoration.lineThrough : null)),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: isPaused ? Colors.red.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                                child: Text(isPaused ? 'موقوف مؤقتاً' : 'نشط حالياً', style: TextStyle(fontSize: 10, color: isPaused ? Colors.red.shade800 : Colors.green.shade800, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        // زر الحذف وإيقاف/تشغيل
                        Row(
                          children: [
                            IconButton(icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: isPaused ? Colors.green : Colors.orange), onPressed: () {
                              _bannersCollection.doc(docId).update({'status': isPaused ? 'نشط' : 'موقوف'});
                            }),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {
                              _bannersCollection.doc(docId).delete();
                            }),
                          ],
                        )
                      ],
                    ),
                    const Divider(),
                    // الإحصائيات (Views, Clicks, CTR)
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

  // --- دوال مساعدة في التصميم (UI Helpers) ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 10.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
    );
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
