import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';

class SmsGatewayScreen extends StatefulWidget {
  const SmsGatewayScreen({super.key});

  @override
  State<SmsGatewayScreen> createState() => _SmsGatewayScreenState();
}

class _SmsGatewayScreenState extends State<SmsGatewayScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // قاعدة بيانات وهمية لقوالب الرسائل
  final List<Map<String, dynamic>> _templates = [
    {'title': 'كود التحقق (OTP)', 'body': 'كود الدخول السري هو {code}، يرجى عدم مشاركته مع أحد. - شبكة الصقر'},
    {'title': 'نجاح الشحن', 'body': 'تم إيداع {amount} ريال في محفظتك بنجاح. الرصيد الحالي: {balance}.'},
    {'title': 'تنبيه التجميد (الرادار)', 'body': 'عزيزي الوكيل، محفظتك فارغة تقريباً وسيتم تجميد شبكتك قريباً. يرجى الشحن.'},
  ];

  // قاعدة بيانات وهمية لسجل الإرسال
  final List<Map<String, dynamic>> _smsLogs = [
    {'phone': '774578241', 'text': 'كود الدخول السري هو 4589...', 'time': 'اليوم 10:30 ص', 'status': 'تم التسليم 🟢'},
    {'phone': '711223344', 'text': 'تم إيداع 50,000 ريال في محفظتك...', 'time': 'اليوم 09:15 ص', 'status': 'تم التسليم 🟢'},
    {'phone': '733000000', 'text': 'عزيزي الوكيل، محفظتك فارغة...', 'time': 'أمس 11:00 م', 'status': 'فشل (الرقم مغلق) 🔴'},
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
  // نافذة فحص الاتصال (التبويب الأول) 🔄
  // ==========================================
  void _testConnection() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 15),
              Text('جاري فحص الاتصال بمزود الخدمة...'),
            ],
          ),
        ),
      ),
    );

    // محاكاة الاتصال لثانيتين ثم إظهار النتيجة
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // إغلاق نافذة التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم الاتصال بنجاح! الرصيد متاح والربط سليم.'), backgroundColor: Colors.green)
      );
    });
  }

  // ==========================================
  // نافذة تعديل قالب الرسالة (التبويب الثاني) 📝
  // ==========================================
  void _editTemplate(int index) {
    TextEditingController bodyController = TextEditingController(text: _templates[index]['body']);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل قالب: ${_templates[index]['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡 استخدم المتغيرات بين الأقواس ليقوم النظام باستبدالها آلياً (مثل: {amount}, {code})', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              TextField(
                controller: bodyController,
                maxLines: 4,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                setState(() => _templates[index]['body'] = bodyController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ القالب بنجاح.'), backgroundColor: Colors.green));
              },
              child: const Text('حفظ التعديلات'),
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
        title: const Text('بوابة رسائل الـ SMS', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blueAccent),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(icon: Icon(Icons.electrical_services), text: 'إعدادات الربط API'),
            Tab(icon: Icon(Icons.sms), text: 'القوالب الآلية'),
            Tab(icon: Icon(Icons.history), text: 'السجل والرصيد'),
          ],
        ),
      ),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildApiSetupTab(),
            _buildTemplatesTab(),
            _buildLogsTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // التبويب الأول: إعدادات الربط API 🔌
  // ==========================================
  Widget _buildApiSetupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('بيانات مزود الخدمة (SMS Gateway):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 16)),
          const SizedBox(height: 15),
          _buildTextField('اسم مزود الخدمة (مثال: بوابة رسائل يمن)', Icons.business),
          _buildTextField('رابط الربط الأساسي (API URL)', Icons.link),
          _buildTextField('مفتاح الربط السري (API Key)', Icons.key, isPassword: true),
          _buildTextField('اسم المرسل (Sender ID - يظهر للمستلم)', Icons.badge),
          
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _testConnection,
              icon: const Icon(Icons.loop, color: Colors.white),
              label: const Text('فحص الاتصال (إرسال رسالة تجريبية)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
          const SizedBox(height: 15),
          const Text('💡 عند الضغط على فحص الاتصال، سيقوم النظام بإرسال رسالة تجريبية إلى رقم هاتفك المسجل للتأكد من نجاح الربط.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // ==========================================
  // التبويب الثاني: قوالب الرسائل الآلية 📝
  // ==========================================
  Widget _buildTemplatesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blue.shade100)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_templates[index]['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                    IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editTemplate(index), tooltip: 'تعديل القالب'),
                  ],
                ),
                const Divider(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_templates[index]['body'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // التبويب الثالث: سجل الإرسال والرصيد 📊
  // ==========================================
  Widget _buildLogsTab() {
    return Column(
      children: [
        // عداد الرصيد المتبقي
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Column(
            children: const [
              Text('رصيد باقة الرسائل المتبقي', style: TextStyle(color: Colors.white70, fontSize: 14)),
              SizedBox(height: 5),
              Text('4,500 رسالة', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        
        // جدول المراقبة للسجل
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(alignment: Alignment.centerRight, child: Text('سجل الإرسال الأخير:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _smsLogs.length,
            itemBuilder: (context, index) {
              final log = _smsLogs[index];
              final isSuccess = log['status'].contains('🟢');

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    child: Icon(isSuccess ? Icons.mark_email_read : Icons.error_outline, color: isSuccess ? Colors.green : Colors.red),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(log['phone'], style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1), textDirection: TextDirection.ltr),
                      Text(log['status'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSuccess ? Colors.green : Colors.red)),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(log['text'], style: const TextStyle(fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(log['time'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

  // أداة بناء حقول الإدخال
  Widget _buildTextField(String label, IconData icon, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextField(
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
