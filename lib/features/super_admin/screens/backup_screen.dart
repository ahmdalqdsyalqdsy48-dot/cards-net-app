import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

import '../../../core/providers/system_provider.dart'; 
import '../../../core/providers/ui_provider.dart'; // 👈 تمت إضافته لتشغيل الأصوات
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isAutoBackupEnabled = true;
  String _backupFrequency = 'يومياً';
  String _backupTime = '04:00'; 
  final TextEditingController _emailController = TextEditingController();
  
  bool _isInit = false;

  // 👈 متغيرات شريط التقدم الذكي للنسخ الاحتياطي
  bool _isBackingUp = false;
  double _progressValue = 0.0;
  String _progressText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  // 🔊 دالة تشغيل الأصوات
  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // دالة اختيار الوقت الدقيق من ساعة النظام
  Future<void> _selectTime(BuildContext context) async {
    _play('click');
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 4, minute: 0),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _backupTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  // ==========================================
  // 🚀 دالة أخذ النسخة الاحتياطية اليدوية (محدثة بشريط تقدم تفاعلي)
  // ==========================================
  Future<void> _takeManualBackup(SystemProvider provider) async {
    if (_emailController.text.isEmpty) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تعيين بريد الطوارئ أولاً!', textDirection: TextDirection.rtl), backgroundColor: Colors.red)
      );
      return;
    }

    _play('click');
    setState(() {
      _isBackingUp = true;
      _progressValue = 0.1;
      _progressText = 'جاري الاتصال بقاعدة البيانات... 📡';
    });

    try {
      // محاكاة بصرية لمراحل الضغط
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() { _progressValue = 0.4; _progressText = 'جاري تجميع بيانات الوكلاء والديون... 🗂️'; });

      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      setState(() { _progressValue = 0.7; _progressText = 'جاري ضغط البيانات (Zipping)... 🗜️'; });

      // الاستدعاء الفعلي من الـ Provider
      await provider.takeManualBackup(); 

      if (!mounted) return;
      setState(() { _progressValue = 0.9; _progressText = 'جاري الإرسال لبريد الطوارئ... 📧'; });

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() { _progressValue = 1.0; _progressText = 'تمت العملية بنجاح! ✅'; });

      _play('success');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم أخذ النسخة الاحتياطية بنجاح! 📦', textDirection: TextDirection.rtl), backgroundColor: Colors.green)
      );

    } catch (e) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل أخذ النسخة: $e', textDirection: TextDirection.rtl), backgroundColor: Colors.red)
      );
    } finally {
      // إرجاع الزر لحالته الطبيعية
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() { _isBackingUp = false; _progressValue = 0.0; _progressText = ''; });
    }
  }

  void _showRestoreDialog(SystemProvider provider, Map<String, dynamic> backup) {
    _play('click');
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
              TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  if (pinController.text == provider.currentUserPin) { 
                    _play('success');
                    Navigator.pop(context);
                    provider.logRestoreAttempt(true, backup['date']);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحقق. جاري استعادة النظام... 🔄', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
                  } else {
                    _play('error');
                    setStateDialog(() => isError = true);
                    provider.logRestoreAttempt(false, backup['date']);
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

  void _confirmDeleteBackup(SystemProvider provider, String docId) {
    _play('warning');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد من حذف هذه النسخة الاحتياطية نهائياً من السحابة؟ لا يمكن التراجع عن هذا الإجراء.'),
          actions: [
            TextButton(onPressed: () { _play('click'); Navigator.pop(ctx); }, child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _play('success');
                provider.deleteBackup(docId);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح النسخة من السيرفر 🗑️', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
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
    final systemProvider = Provider.of<SystemProvider>(context);
    final adminBalance = systemProvider.adminMainBalance;
    final userName = systemProvider.currentUserName;
    final userPhone = systemProvider.currentUserPhone;

    return Scaffold(
      appBar: const CustomHeader(title: 'النسخ الاحتياطي السحابي'),
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
            TabBar(
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAutoBackupTab(systemProvider),
                  _buildCloudSyncTab(systemProvider),
                  _buildManageRestoreTab(systemProvider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              _play('click');
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
              onChanged: (val) {
                _play('click');
                setState(() => _backupFrequency = val!);
              },
            ),
            const SizedBox(height: 20),
            const Text('توقيت النسخ الدقيق (اختر من الساعة):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            InkWell(
              onTap: () => _selectTime(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _backupTime,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const Icon(Icons.access_time_filled, color: Colors.blueAccent),
                  ],
                ),
              ),
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
            const Text('💡 سيقوم النظام بضغط البيانات في الوقت المحدد وإرسالها للسحابة ولإيميلك الشخصي.', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  _play('success');
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

  Widget _buildCloudSyncTab(SystemProvider provider) {
    bool isDriveLinked = provider.isDriveLinked;
    bool isDropboxLinked = provider.isDropboxLinked;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('اربط نظامك بحساباتك السحابية ليتم رفع النسخة المشفرة إليها آلياً.', style: TextStyle(color: Colors.blueGrey, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isDriveLinked ? Colors.green : Colors.transparent)),
            child: ListTile(
              leading: const Icon(Icons.storage, color: Colors.green),
              title: const Text('Google Drive', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isDriveLinked ? 'متصل' : 'غير متصل'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isDriveLinked ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1), elevation: 0),
                onPressed: () {
                  _play('click');
                  provider.toggleCloudLink('drive', !isDriveLinked);
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
                  _play('click');
                  provider.toggleCloudLink('dropbox', !isDropboxLinked);
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

  Widget _buildManageRestoreTab(SystemProvider provider) {
    final backups = provider.backupsList;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          // 👈 التعديل الجوهري: تبديل الزر القديم بشريط التقدم الديناميكي
          child: _isBackingUp 
            ? Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade200)),
                child: Column(
                  children: [
                    Text(_progressText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progressValue,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade300,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('${(_progressValue * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : ElevatedButton.icon(
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
                child: ListTile(
                  leading: const Icon(Icons.cloud_done, color: Colors.green),
                  title: Text(backup['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), textDirection: TextDirection.ltr),
                  subtitle: Text('الحجم: ${backup['size']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDeleteBackup(provider, backup['docId'])),
                      ElevatedButton(
                        onPressed: () => _showRestoreDialog(provider, backup),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                        child: const Text('استعادة', style: TextStyle(color: Colors.white)),
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
}
