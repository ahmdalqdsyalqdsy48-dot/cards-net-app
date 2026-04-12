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
  // 1. إدارة الشريط العلوي المتحرك (Global Marquee)
  // ==========================================
  
  void _showColorPicker(String title, Color initialColor, Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, textDirection: TextDirection.rtl),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: onColorChanged,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('موافق')),
        ],
      ),
    );
  }

  // ==========================================
  // 2. دوال الإعلانات والبنرات (القديمة المحدثة)
  // ==========================================

  void _showAddBannerDialog() {
    int adType = 1; 
    int sendChannel = 1; 
    bool targetEndUsers = true;
    bool targetMainAgents = true;
    bool targetSubAgents = false;
    bool targetStaff = false;

    final TextEditingController titleController = TextEditingController();
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
            title: const Row(children: [Icon(Icons.add_photo_alternate, color: Colors.blueAccent), SizedBox(width: 8), Text('إضافة إعلان جديد')]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField('عنوان الإعلان', Icons.title, controller: titleController),
                  if (adType == 1) _buildTextField('نص زر الإجراء', Icons.smart_button, controller: ctaController),
                  _buildTextField('رابط التوجه (URL)', Icons.link, controller: linkController),
                  const Divider(),
                  const Text('الاستهداف:', style: TextStyle(fontWeight: FontWeight.bold)),
                  CheckboxListTile(title: const Text('المستخدمين'), value: targetEndUsers, onChanged: (v) => setStateDialog(() => targetEndUsers = v!)),
                  CheckboxListTile(title: const Text('الوكلاء'), value: targetMainAgents, onChanged: (v) => setStateDialog(() => targetMainAgents = v!)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    await _bannersCollection.add({
                      'title': titleController.text,
                      'target': targetEndUsers ? 'المستخدمين' : 'الوكلاء',
                      'status': 'نشط',
                      'createdAt': FieldValue.serverTimestamp(),
                      'views': 0, 'clicksApp': 0,
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ الإعلان'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة الإعلانات والخبر المتحرك'),
      drawer: CustomDrawer(
        userName: systemProvider.currentUserName,
        phoneNumber: systemProvider.currentUserPhone,
        role: 'مالك النظام',
        balanceOrPoints: 'أرباح النظام: ${systemProvider.adminMainBalance.toStringAsFixed(0)}',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: themeProvider.primaryColor == const Color(0xFFFFFFFF) ? Colors.blue : themeProvider.primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.campaign), text: 'الشريط العلوي'),
                Tab(icon: Icon(Icons.photo_library), text: 'بنرات السلايدر'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMarqueeSettingsTab(systemProvider, themeProvider),
                  _buildBannersListTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- تبويب إعدادات الشريط العلوي المتحرك ---
  Widget _buildMarqueeSettingsTab(SystemProvider sys, ThemeProvider theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إعدادات الخبر المتحرك العام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('إظهار الشريط في أعلى التطبيق'),
                  value: sys.showNewsBar,
                  onChanged: (v) => sys.updateSystemStatusSettings(maintenance: sys.isMaintenanceMode, forcedUpdate: sys.isForcedUpdate, showNews: v),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'نص الخبر الحالي', border: OutlineInputBorder()),
                    controller: TextEditingController(text: sys.announcements.isNotEmpty ? sys.announcements.first : ''),
                    onSubmitted: (text) async {
                       await FirebaseFirestore.instance.collection('system').doc('main_info').update({'announcements': [text]});
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الخبر بنجاح!')));
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),
          const Text('تخصيص المظهر:', style: TextStyle(fontWeight: FontWeight.bold)),
          
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('لون الخلفية'),
                  trailing: CircleAvatar(backgroundColor: Color(sys.marqueeBgColor)),
                  onTap: () => _showColorPicker('لون خلفية الشريط', Color(sys.marqueeBgColor), (c) {
                    FirebaseFirestore.instance.collection('system').doc('main_info').update({'marqueeBgColor': c.value});
                  }),
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('لون النص'),
                  trailing: CircleAvatar(backgroundColor: Color(sys.marqueeTextColor)),
                  onTap: () => _showColorPicker('لون نص الشريط', Color(sys.marqueeTextColor), (c) {
                    FirebaseFirestore.instance.collection('system').doc('main_info').update({'marqueeTextColor': c.value});
                  }),
                ),
              ),
            ],
          ),

          const Divider(),
          ListTile(
            title: const Text('سرعة حركة الشريط'),
            subtitle: Slider(
              value: sys.newsScrollSpeed, min: 10, max: 150,
              onChanged: (v) => sys.updateNewsSpeed(v),
            ),
            trailing: Text(sys.newsScrollSpeed.toInt().toString()),
          ),
          
          ListTile(
            title: const Text('اتجاه الحركة'),
            trailing: DropdownButton<String>(
              value: sys.marqueeDirection,
              items: const [
                DropdownMenuItem(value: 'rtl', child: Text('من اليمين')),
                DropdownMenuItem(value: 'ltr', child: Text('من اليسار')),
              ],
              onChanged: (v) {
                FirebaseFirestore.instance.collection('system').doc('main_info').update({'marqueeDirection': v});
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- تبويب قائمة البنرات التسويقية ---
  Widget _buildBannersListTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _showAddBannerDialog,
            icon: const Icon(Icons.add),
            label: const Text('إضافة حملة إعلانية جديدة'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _bannersCollection.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.image, color: Colors.blue),
                      title: Text(data['title'] ?? ''),
                      subtitle: Text('الاستهداف: ${data['target']}'),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _bannersCollection.doc(docs[index].id).delete()),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String hint, IconData icon, {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
