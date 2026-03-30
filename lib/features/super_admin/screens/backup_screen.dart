import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 1. استدعاء مكتبة العقل المدبر

import '../../../core/providers/system_provider.dart'; // 👈 2. استدعاء الخادم المحلي الشامل
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // متغيرات النسخ الآلي
  bool _isAutoBackupEnabled = true;
  String _backupFrequency = 'يومياً';
  String _backupTime = '04:00 فجراً';
  
  // البريد الإلكتروني المخصص للطوارئ
  String _emergencyEmail = 'admin@cardsnet.com'; 

  // متغيرات الربط السحابي
  bool _isDriveLinked = true;
  bool _isDropboxLinked = false;

  // قاعدة بيانات تجريبية للنسخ السابقة (قابلة للحذف والإضافة)
  final List<Map<String, dynamic>> _backups = [
    {'id': 1, 'date': '2026-03-23 04:00 AM', 'size': '45 MB', 'type': 'آلي (سحابي)', 'icon': Icons.cloud_done, 'color': Colors.green},
    {'id': 2, 'date': '2026-03-20 11:30 PM', 'size': '42 MB', 'type': 'يدوي (محلي)', 'icon': Icons.save, 'color': Colors.blue},
    {'id': 3, 'date': '2026-03-15 04:00 AM', 'size': '38 MB', 'type': 'آلي (سحابي)', 'icon': Icons.cloud_done, 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================
  // نافذة أخذ نسخة يدوية فورية 💾
  // ==========================================
  void _takeManualBackup() {
    showDialog(
      context: context,
      barrierDismissible: false, // يمنع إغلاق النافذة أثناء التحميل
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 20),
              Text('جاري ضغط قاعدة البيانات وتشفيرها...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );

    // محاكاة لعملية النسخ التي تأخذ 3 ثوانٍ
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context); // إغلاق نافذة التحميل
      setState(() {
        // إضافة النسخة الجديدة إلى أعلى القائمة
        _backups.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch,
          'date': 'الآن (نسخة حديثة)',
          'size': '46 MB',
          'type': 'يدوي (محلي)',
          'icon': Icons.save,
          'color': Colors.blue,
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم أخذ النسخة الاحتياطية بنجاح! ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green)
      );
    });
  }

  // ==========================================
  // نافذة استعادة النظام (تتطلب PIN) 🔄🔴
  // ==========================================
  void _showRestoreDialog(Map<String, dynamic> backup) {
    TextEditingController pinController = TextEditingController();
    bool isError = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // نستخدم StatefulBuilder لتحديث حالة النافذة (Error) من الداخل
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('استعادة النظام ⚠️', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('أنت على وشك إعادة النظام بالزمن إلى نسخة (${backup['date']}). ستفقد أي بيانات جديدة بعد هذا التاريخ.', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                const Text('للتأكيد، يرجى إدخال رمز PIN السريع (6 أرقام):', style: TextStyle(color: Colors.blueGrey)),
                const SizedBox(height: 10),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '******',
                    errorText: isError ? 'رمز PIN غير صحيح!' : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  // محاكاة التحقق من رمز PIN
                  if (pinController.text == '123456') { 
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحقق. جاري استعادة النظام... 🔄', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
                  } else {
                    setStateDialog(() => isError = true);
                  }
                },
                child: const Text('تأكيد الاستعادة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة حذف نسخة احتياطية
  void _deleteBackup(int index) {
    setState(() => _backups.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح النسخة لتوفير المساحة 🗑️', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    // 👈 3. جلب الأرباح الحقيقية للنظام من العقل المدبر
    final systemProvider = Provider.of<SystemProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;

    return Scaffold(
      appBar: const CustomHeader(title: 'النسخ الاحتياطي السحابي'),
      // 👈 تم إزالة const لتمرير الرصيد المتغير بأمان
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
                tabs: const [
                  Tab(icon: Icon(Icons.autorenew), text: 'النسخ الآلي'),
                  Tab(icon: Icon(Icons.cloud_sync), text: 'الربط السحابي'),
                  Tab(icon: Icon(Icons.manage_history), text: 'إدارة واستعادة'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAutoBackupTab(),
                  _buildCloudSyncTab(),
                  _buildManageRestoreTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // التبويب الأول: إعدادات النسخ الآلي ⚙️
  // ==========================================
  Widget _buildAutoBackupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('تفعيل النسخ الاحتياطي التلقائي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            subtitle: const Text('يقوم النظام بأخذ نسخة احتياطية آلياً دون تدخلك.'),
            value: _isAutoBackupEnabled,
            activeColor: Colors.blueAccent,
            onChanged: (val) {
              setState(() => _isAutoBackupEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'تم تفعيل النسخ الآلي ✅' : 'تم إيقاف النسخ الآلي ❌', textDirection: TextDirection.rtl)));
            },
          ),
          const Divider(),
          if (_isAutoBackupEnabled) ...[
            const Text('وتيرة النسخ التلقائي:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _backupFrequency,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              items: ['يومياً', 'أسبوعياً', 'شهرياً'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => _backupFrequency = val!),
            ),
            const SizedBox(height: 20),
            const Text('توقيت النسخ (يفضل وقت السكون):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _backupTime,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              items: ['02:00 فجراً', '03:00 فجراً', '04:00 فجراً', '12:00 منتصف الليل'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => _backupTime = val!),
            ),
            
            const SizedBox(height: 20),
            const Text('بريد الطوارئ (لاستقبال نسخة مضغوطة):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: _emergencyEmail),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'مثال: my.email@gmail.com',
                prefixIcon: const Icon(Icons.mark_email_read, color: Colors.orange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => _emergencyEmail = val,
            ),
            const SizedBox(height: 15),
            const Text('💡 سيقوم النظام بضغط البيانات ليلاً وتشفيرها ثم إرسالها إلى هذا الإيميل كخط دفاع أخير لضمان عدم ضياع أي فاتورة.', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.5)),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // التبويب الثاني: الربط السحابي ☁️
  // ==========================================
  Widget _buildCloudSyncTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('حفظ النسخة في السيرفر فقط خطر جداً. اربط نظامك بحساباتك السحابية ليتم رفع النسخة المشفرة إليها آلياً.', style: TextStyle(color: Colors.blueGrey, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: _isDriveLinked ? Colors.green : Colors.transparent)),
            child: ListTile(
              leading: Image.network('https://upload.wikimedia.org/wikipedia/commons/d/da/Google_Drive_logo.png', width: 30, errorBuilder: (context, error, stackTrace) => const Icon(Icons.cloud, color: Colors.green)),
              title: const Text('Google Drive', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_isDriveLinked ? 'متصل ($_emergencyEmail)' : 'غير متصل'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _isDriveLinked ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1), elevation: 0),
                onPressed: () {
                  setState(() => _isDriveLinked = !_isDriveLinked);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isDriveLinked ? 'تم ربط Google Drive بنجاح ✅' : 'تم إلغاء الربط ❌', textDirection: TextDirection.rtl)));
                },
                child: Text(_isDriveLinked ? 'إلغاء الربط' : 'ربط الحساب', style: TextStyle(color: _isDriveLinked ? Colors.red : Colors.blue)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: _isDropboxLinked ? Colors.blue : Colors.transparent)),
            child: ListTile(
              leading: const Icon(Icons.cloud, color: Colors.blue, size: 30),
              title: const Text('Dropbox', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_isDropboxLinked ? 'متصل' : 'غير متصل'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _isDropboxLinked ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1), elevation: 0),
                onPressed: () {
                  setState(() => _isDropboxLinked = !_isDropboxLinked);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isDropboxLinked ? 'تم ربط Dropbox بنجاح ✅' : 'تم إلغاء الربط ❌', textDirection: TextDirection.rtl)));
                },
                child: Text(_isDropboxLinked ? 'إلغاء الربط' : 'ربط الحساب', style: TextStyle(color: _isDropboxLinked ? Colors.red : Colors.blue)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // التبويب الثالث: إدارة النسخ والاستعادة 📥🔄
  // ==========================================
  Widget _buildManageRestoreTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _takeManualBackup,
            icon: const Icon(Icons.save, color: Colors.white, size: 24),
            label: const Text('أخذ نسخة احتياطية فورية الآن 💾', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade900,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 5,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(alignment: Alignment.centerRight, child: Text('النسخ المتوفرة للاستعادة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
        ),
        Expanded(
          child: _backups.isEmpty 
            ? const Center(child: Text('لا توجد نسخ احتياطية مسجلة حالياً.', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _backups.length,
            itemBuilder: (context, index) {
              final backup = _backups[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(backup['icon'], color: backup['color'], size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(backup['date'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textDirection: TextDirection.ltr),
                                Text('الحجم: ${backup['size']} | النوع: ${backup['type']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildActionButton(Icons.download, 'تحميل للجهاز', Colors.blue, () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تحميل النسخة إلى جهازك... ⬇️', textDirection: TextDirection.rtl)));
                          }),
                          _buildActionButton(Icons.delete, 'حذف', Colors.red.shade300, () => _deleteBackup(index)),
                          ElevatedButton.icon(
                            onPressed: () => _showRestoreDialog(backup),
                            icon: const Icon(Icons.restore, color: Colors.white, size: 18),
                            label: const Text('استعادة النظام', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade800,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                          ),
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

  Widget _buildActionButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, color: color), tooltip: tooltip, onPressed: onTap);
  }
}
