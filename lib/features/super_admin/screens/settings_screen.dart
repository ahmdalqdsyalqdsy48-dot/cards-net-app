import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen> {
  // متغيرات وهمية للتحكم في حالة النظام
  bool isMaintenanceMode = false;
  bool allowNewRegistrations = true;
  bool enableSystemNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(
        title: 'الإعدادات العامة',
        isOnline: true,
      ),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === 1. هوية التطبيق ===
              _buildSectionTitle('هوية العلامة التجارية'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_note, color: Colors.blue),
                      title: const Text('اسم التطبيق'),
                      subtitle: const Text('كروت نت (Cards Net)'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.image, color: Colors.blue),
                      title: const Text('شعار التطبيق (Logo)'),
                      subtitle: const Text('تغيير أيقونة التطبيق الرئيسية'),
                      trailing: const Icon(Icons.cloud_upload_outlined),
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // === 2. التحكم في حالة النظام (الأزرار السحرية) ===
              _buildSectionTitle('التحكم في النظام'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.handyman, color: Colors.red),
                      title: const Text('وضع الصيانة'),
                      subtitle: const Text('إغلاق التطبيق مؤقتاً عن جميع الوكلاء'),
                      value: isMaintenanceMode,
                      onChanged: (val) => setState(() => isMaintenanceMode = val),
                      activeColor: Colors.red,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.person_add, color: Colors.green),
                      title: const Text('فتح التسجيل الجديد'),
                      subtitle: const Text('السماح للوكلاء بإنشاء حسابات بأنفسهم'),
                      value: allowNewRegistrations,
                      onChanged: (val) => setState(() => allowNewRegistrations = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active, color: Colors.orange),
                      title: const Text('إشعارات النظام العامة'),
                      value: enableSystemNotifications,
                      onChanged: (val) => setState(() => enableSystemNotifications = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // === 3. الأمان والدعم ===
              _buildSectionTitle('الأمان والروابط الخارجية'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.policy, color: Colors.blueGrey),
                      title: const Text('سياسة الخصوصية'),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.share, color: Colors.blueGrey),
                      title: const Text('روابط التواصل الاجتماعي'),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // زر الحفظ النهائي
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('حفظ جميع التغييرات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }
}
