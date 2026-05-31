import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/backup_provider.dart';
import '../../../core/providers/ui_provider.dart';
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

  bool _isBackingUp = false;
  double _progressValue = 0.0;
  String _progressText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<UiProvider>().playSound('click');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final backup = context.read<BackupProvider>();
      _isAutoBackupEnabled = backup.isAutoBackupEnabled;
      _backupFrequency = backup.backupFrequency;
      _backupTime = backup.backupTime;
      _emailController.text = backup.emergencyEmail;
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    context.read<UiProvider>().playSound('click');
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

  Future<void> _takeManualBackup(BackupProvider backup) async {
    if (_emailController.text.isEmpty) {
      context.read<UiProvider>().playSound('error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تعيين بريد الطوارئ أولاً!', textDirection: TextDirection.rtl), backgroundColor: Colors.red)
      );
      return;
    }

    context.read<UiProvider>().playSound('click');
    setState(() {
      _isBackingUp = true;
      _progressValue = 0.1;
      _progressText = 'جاري الاتصال بقاعدة البيانات... 📡';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() { _progressValue = 0.4; _progressText = 'جاري تجميع بيانات الوكلاء والديون... 🗂️'; });

      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      setState(() { _progressValue = 0.7; _progressText = 'جاري ضغط البيانات (Zipping)... 🗜️'; });

      await backup.takeManualBackup();

      if (!mounted) return;
      setState(() { _progressValue = 0.9; _progressText = 'جاري الإرسال لبريد الطوارئ... 📧'; });

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() { _progressValue = 1.0; _progressText = 'تمت العملية بنجاح! ✅'; });

      context.read<UiProvider>().playSound('success');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم أخذ النسخة الاحتياطية بنجاح! 📦', textDirection: TextDirection.rtl), backgroundColor: Colors.green)
      );

    } catch (e) {
      context.read<UiProvider>().playSound('error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل أخذ النسخة: $e', textDirection: TextDirection.rtl), backgroundColor: Colors.red)
      );
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() { _isBackingUp = false; _progressValue = 0.0; _progressText = ''; });
    }
  }

  void _showRestoreDialog(BackupProvider backupProvider, Map<String, dynamic> backupData) {
    context.read<UiProvider>().playSound('click');
    TextEditingController pinController = TextEditingController();
    bool isError = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Directionality(
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
                Text('أنت على وشك إعادة النظام بالزمن إلى نسخة (${backupData['date']}). ستفقد أي بيانات جديدة بعد هذا التاريخ.', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
              TextButton(onPressed: () { context.read<UiProvider>().playSound('click'); Navigator.pop(ctx); }, child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  if (pinController.text == auth.currentUserPin) {
                    context.read<UiProvider>().playSound('success');
                    Navigator.pop(ctx);
                    backupProvider.logRestoreAttempt(true, backupData['date']);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحقق. جاري استعادة النظام... 🔄', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
                  } else {
                    context.read<UiProvider>().playSound('error');
                    setStateDialog(() => isError = true);
                    backupProvider.logRestoreAttempt(false, backupData['date']);
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

  void _confirmDeleteBackup(BackupProvider backup, String docId) {
    context.read<UiProvider>().playSound('warning');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد من حذف هذه النسخة الاحتياطية نهائياً من السحابة؟ لا يمكن التراجع عن هذا الإجراء.'),
          actions: [
            TextButton(onPressed: () { context.read<UiProvider>().playSound('click'); Navigator.pop(ctx); }, child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                context.read<UiProvider>().playSound('success');
                backup.deleteBackup(docId);
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
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final backup = context.watch<BackupProvider>();

    return Scaffold(
      appBar: const CustomHeader(title: 'النسخ الاحتياطي السحابي'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
            context.read<UiProvider>().playSound('success');
          },
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
                    _buildAutoBackupTab(backup),
                    _buildCloudSyncTab(backup),
                    _buildManageRestoreTab(backup),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoBackupTab(BackupProvider backup) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
              context.read<UiProvider>().playSound('click');
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
                context.read<UiProvider>().playSound('click');
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
                  context.read<UiProvider>().playSound('success');
                  backup.updateAutoBackupSettings(_isAutoBackupEnabled, _backupFrequency, _backupTime, _emailController.text);
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

  Widget _buildCloudSyncTab(BackupProvider backup) {
    bool isDriveLinked = backup.isDriveLinked;
    bool isDropboxLinked = backup.isDropboxLinked;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                  context.read<UiProvider>().playSound('click');
                  backup.toggleCloudLink('drive', !isDriveLinked);
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
                  context.read<UiProvider>().playSound('click');
                  backup.toggleCloudLink('dropbox', !isDropboxLinked);
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

  Widget _buildManageRestoreTab(BackupProvider backup) {
    final backups = backup.backupsList;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                onPressed: () => _takeManualBackup(backup),
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
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('لا توجد نسخ احتياطية مسجلة حالياً.', style: TextStyle(color: Colors.grey))),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: backups.length,
                itemBuilder: (context, index) {
                  final backupItem = backups[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      leading: const Icon(Icons.cloud_done, color: Colors.green),
                      title: Text(backupItem['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), textDirection: TextDirection.ltr),
                      subtitle: Text('الحجم: ${backupItem['size']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDeleteBackup(backup, backupItem['docId'])),
                          ElevatedButton(
                            onPressed: () => _showRestoreDialog(backup, backupItem),
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
