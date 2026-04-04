import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

import '../../../core/providers/system_provider.dart'; 
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // متغيرات محلية لواجهة الإعدادات (قبل الحفظ للسحابة)
  bool _isAutoBackupEnabled = true;
  String _backupFrequency = 'يومياً';
  String _backupTime = '04:00 فجراً';
  final TextEditingController _emailController = TextEditingController();
  
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // سحب الإعدادات من السحابة مرة واحدة عند فتح الشاشة
    if (!_isInit) {
      final provider = Provider.of<SystemProvider>(context, listen: false);
      _isAutoBackupEnabled = provider.isAutoBackupEnabled;
      _backupFrequency = provider.backupFrequency;
      _backupTime = provider.backupTime;
      _emailController.text = provider.emergencyEmail;
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ==========================================
  // نافذة أخذ نسخة يدوية سحابية ☁️💾
  // ==========================================
  void _takeManualBackup(SystemProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 20),
              Text('جاري ضغط قاعدة البيانات ورفعها للسحابة...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );

    // محاكاة لعملية الرفع ثم الحفظ في السحابة
    Future.delayed(const Duration(seconds: 3), () async {
      await provider.takeManualBackup(); // 👈 أمر السحابة
      if (mounted) {
        Navigator.pop(context); // إغلاق نافذة التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم أخذ النسخة الاحتياطية بنجاح! ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green)
        );
      }
    });
  }

  // ==========================================
  // نافذة استعادة النظام (مراقبة بالصندوق الأسود) 🔄🔴
  // ==========================================
  void _showRestoreDialog(SystemProvider provider, Map<String, dynamic> backup) {
    TextEditingController pinController = TextEditingController();
    bool isError = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( 
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
                  if (pinController.text == '123456') { 
                    Navigator.pop(context);
                    provider.logRestoreAttempt(true, backup['date']); // 👈 توثيق الاستعادة الناجحة
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحقق. جاري استعادة النظام... 🔄', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
                  } else {
                    setStateDialog(() => isError = true);
                    provider.logRestoreAttempt(false, backup['date']); // 👈 توثيق محاولة الاختراق
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

  @override
  Widget build(BuildContext context) {
    // 👈 جلب البيانات الحية من العقل المدبر
    final systemProvider = Provider.of<SystemProvider>(context);
    
    // بيانات القائمة الجانبية
    final adminBalance = systemProvider.adminMainBalance;
    final userName = systemProvider.currentUserName;
    final userPhone = systemProvider.currentUserPhone;

    return Scaffold(
      appBar: const CustomHeader(title: 'النسخ الاحتياطي السحابي'),
      // 👈 تم ربط القائمة الجانبية بالسحابة
      drawer: CustomDrawer(
        userName: userName,
        phoneNumber: userPhone,
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
                  _buildAutoBackupTab(systemProvider), // 👈 تمرير العقل المدبر
                  _buildCloudSyncTab(systemProvider),  // 👈 تمرير العقل المدبر
                  _buildManageRestoreTab(systemProvider), // 👈 تمرير العقل المدبر
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
  Widget _buildAutoBackupTab(SystemProvider provider) {
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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'مثال: my.email@gmail.com',
                prefixIcon: const Icon(Icons.mark_email_read, color: Colors.orange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 15),
            const Text('💡 سيقوم النظام بضغط البيانات ليلاً وتشفيرها ثم إرسالها إلى هذا الإيميل كخط دفاع أخير لضمان عدم ضياع أي فاتورة.', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.5)),
            
            const SizedBox(height: 20),
            // 👈 زر حفظ الإعدادات في السحابة
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  provider.updateAutoBackupSettings(_isAutoBackupEnabled, _backupFrequency, _backupTime, _emailController.text);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات السحابية بنجاح ☁️✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                },
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                label: const Text('حفظ الإعدادات السحابية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // التبويب الثاني: الربط السحابي ☁️
  // ==========================================
  Widget _buildCloudSyncTab(SystemProvider provider) {
    bool isDriveLinked = provider.isDriveLinked;
    bool isDropboxLinked = provider.isDropboxLinked;
    String email = provider.emergencyEmail;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('حفظ النسخة في السيرفر فقط خطر جداً. اربط نظامك بحساباتك السحابية ليتم رفع النسخة المشفرة إليها آلياً.', style: TextStyle(color: Colors.blueGrey, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isDriveLinked ? Colors.green : Colors.transparent)),
            child: ListTile(
              leading: Image.network('https://upload.wikimedia.org/wikipedia/commons/d/da/Google_Drive_logo.png', width: 30, errorBuilder: (context, error, stackTrace) => const Icon(Icons.cloud, color: Colors.green)),
              title: const Text('Google Drive', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isDriveLinked ? 'متصل (${email.isNotEmpty ? email : 'عبر الهاتف'})' : 'غير متصل'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isDriveLinked ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1), elevation: 0),
                onPressed: () {
                  provider.toggleCloudLink('drive', !isDriveLinked); // 👈 إرسال للسحابة
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!isDriveLinked ? 'تم ربط Google Drive بنجاح ✅' : 'تم إلغاء الربط ❌', textDirection: TextDirection.rtl)));
                },
                child: Text(isDriveLinked ? 'إلغاء الربط' : 'ربط الحساب', style: TextStyle(color: isDriveLinked ? Colors.red : Colors.blue)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isDropboxLinked ? Colors.blue : Colors.transparent)),
            child: ListTile(
              leading: const Icon(Icons.cloud, color: Colors.blue, size: 30),
              title: const Text('Dropbox', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isDropboxLinked ? 'متصل' : 'غير متصل'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isDropboxLinked ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1), elevation: 0),
                onPressed: () {
                  provider.toggleCloudLink('dropbox', !isDropboxLinked); // 👈 إرسال للسحابة
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!isDropboxLinked ? 'تم ربط Dropbox بنجاح ✅' : 'تم إلغاء الربط ❌', textDirection: TextDirection.rtl)));
                },
                child: Text(isDropboxLinked ? 'إلغاء الربط' : 'ربط الحساب', style: TextStyle(color: isDropboxLinked ? Colors.red : Colors.blue)),
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
  Widget _buildManageRestoreTab(SystemProvider provider) {
    // 👈 قراءة قائمة النسخ من السحابة مباشرة
    final backups = provider.backupsList;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _takeManualBackup(provider),
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
          child: backups.isEmpty 
            ? const Center(child: Text('لا توجد نسخ احتياطية مسجلة حالياً.', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: backups.length,
            itemBuilder: (context, index) {
              final backup = backups[index];
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
                          Icon(Icons.cloud_done, color: Colors.green, size: 28), // أيقونة سحابية ثابتة
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(backup['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textDirection: TextDirection.ltr),
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
                          _buildActionButton(Icons.delete, 'حذف', Colors.red.shade300, () {
                             provider.deleteBackup(backup['docId']); // 👈 أمر حذف سحابي
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح النسخة من السيرفر 🗑️', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                          }),
                          ElevatedButton.icon(
                            onPressed: () => _showRestoreDialog(provider, backup),
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
