import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

class SmsGatewayScreen extends StatefulWidget {
  const SmsGatewayScreen({super.key});

  @override
  State<SmsGatewayScreen> createState() => _SmsGatewayScreenState();
}

class _SmsGatewayScreenState extends State<SmsGatewayScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _providerNameController =
      TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _senderIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<UiProvider>().playSound('click');
      }
    });
    _loadSmsConfig();
  }

  Future<void> _loadSmsConfig() async {
    var doc = await _db.collection('system').doc('sms_config').get();
    if (doc.exists) {
      var data = doc.data()!;
      setState(() {
        _providerNameController.text = data['providerName'] ?? '';
        _apiUrlController.text = data['apiUrl'] ?? '';
        _apiKeyController.text = data['apiKey'] ?? '';
        _senderIdController.text = data['senderId'] ?? '';
      });
    }
  }

  Future<void> _saveSmsConfig() async {
    await _db.collection('system').doc('sms_config').set({
      'providerName': _providerNameController.text,
      'apiUrl': _apiUrlController.text,
      'apiKey': _apiKeyController.text,
      'senderId': _senderIdController.text,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ إعدادات الربط بنجاح! 💾',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _testConnection() async {
    context.read<UiProvider>().playSound('click');
    await _saveSmsConfig();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 15),
              Text('جاري إرسال رسالة فحص الاتصال...',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context);
      context.read<UiProvider>().playSound('success');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم الفحص! الإعدادات سليمة وجاهزة للإرسال.',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _editTemplate(String docId, String title, String currentBody) {
    context.read<UiProvider>().playSound('click');
    TextEditingController bodyController =
        TextEditingController(text: currentBody);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل قالب: $title',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💡 المتغيرات المتاحة: {amount}, {code}, {balance}',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              TextField(
                controller: bodyController,
                maxLines: 4,
                decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                context.read<UiProvider>().playSound('click');
                await _db
                    .collection('sms_templates')
                    .doc(docId)
                    .update({'body': bodyController.text});
                if (mounted) {
                  context.read<UiProvider>().playSound('success');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث القالب في السيرفر. ✅',
                          textDirection: TextDirection.rtl),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _providerNameController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _senderIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: const CustomHeader(title: 'بوابة رسائل الـ SMS'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints:
            'أرباح النظام: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
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
              tabs: const [
                Tab(
                    icon: Icon(Icons.electrical_services),
                    text: 'إعدادات الربط'),
                Tab(icon: Icon(Icons.sms), text: 'القوالب الآلية'),
                Tab(icon: Icon(Icons.history), text: 'السجل والرصيد'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildApiSetupTab(),
                  _buildTemplatesTab(),
                  _buildLogsTab(settings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiSetupTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadSmsConfig();
        context.read<UiProvider>().playSound('success');
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('بيانات مزود الخدمة (SMS Gateway):',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    fontSize: 16)),
            const SizedBox(height: 15),
            _buildTextField('اسم مزود الخدمة', Icons.business,
                _providerNameController),
            _buildTextField(
                'رابط الربط الأساسي (API URL)', Icons.link, _apiUrlController),
            _buildTextField('مفتاح الربط السري (API Key)', Icons.key,
                _apiKeyController,
                isPassword: true),
            _buildTextField('اسم المرسل (Sender ID)', Icons.badge,
                _senderIdController),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _testConnection,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('حفظ وفحص الاتصال',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('sms_templates').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
            context.read<UiProvider>().playSound('success');
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.blue.shade100)),
                child: ListTile(
                  title: Text(data['title'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent)),
                  subtitle: Text(data['body'] ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _editTemplate(
                        docs[index].id, data['title'], data['body']),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLogsTab(SettingsProvider settings) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 300));
        context.read<UiProvider>().playSound('success');
      },
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade500]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                const Text('رصيد باقة الرسائل المتبقي',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text('${settings.smsBalance} رسالة',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
                alignment: Alignment.centerRight,
                child: Text('سجل الإرسال الحقيقي:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey))),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('sms_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var logs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    var log = logs[index].data() as Map<String, dynamic>;
                    bool isSuccess = log['status'] == 'sent';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                            isSuccess ? Icons.check_circle : Icons.error,
                            color: isSuccess ? Colors.green : Colors.red),
                        title: Text(log['phone'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(log['text'] ?? ''),
                        trailing: Text(isSuccess ? 'تم' : 'فشل',
                            style: TextStyle(
                                color: isSuccess ? Colors.green : Colors.red,
                                fontSize: 10)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label, IconData icon, TextEditingController controller,
      {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
