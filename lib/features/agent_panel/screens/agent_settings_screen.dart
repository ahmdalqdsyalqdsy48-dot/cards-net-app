import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AgentSettingsScreen extends StatefulWidget {
  const AgentSettingsScreen({super.key});

  @override
  State<AgentSettingsScreen> createState() => _AgentSettingsScreenState();
}

class _AgentSettingsScreenState extends State<AgentSettingsScreen> {
  // متغيرات حالة الإعدادات
  bool _isPrinterConnected = false;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _autoPrintEnabled = false;

  // ==========================================
  // نافذة البحث عن طابعة بلوتوث 🖨️
  // ==========================================
  void _showPrinterDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.print, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('إعدادات طابعة البلوتوث', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('يرجى التأكد من تشغيل البلوتوث في هاتفك وتشغيل الطابعة الحرارية.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              if (_isPrinterConnected)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                  child: const Row(
                    children: [
                      Icon(Icons.bluetooth_connected, color: Colors.green),
                      SizedBox(width: 10),
                      Text('متصل: MTP-II Printer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                )
              else
                const CircularProgressIndicator(),
              const SizedBox(height: 15),
              if (!_isPrinterConnected) const Text('جاري البحث عن أجهزة...', style: TextStyle(color: Colors.blueGrey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _isPrinterConnected ? Colors.red : Colors.blueAccent),
              onPressed: () {
                setState(() {
                  _isPrinterConnected = !_isPrinterConnected;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isPrinterConnected ? 'تم الاتصال بالطابعة الحرارية بنجاح! 🖨️' : 'تم قطع الاتصال بالطابعة.'),
                    backgroundColor: _isPrinterConnected ? Colors.green : Colors.red,
                  )
                );
              },
              child: Text(_isPrinterConnected ? 'قطع الاتصال' : 'محاكاة الاتصال', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // نافذة تغيير كلمة المرور 🔐
  // ==========================================
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('كلمة المرور القديمة', Icons.lock_outline),
              const SizedBox(height: 10),
              _buildTextField('كلمة المرور الجديدة', Icons.lock),
              const SizedBox(height: 10),
              _buildTextField('تأكيد كلمة المرور', Icons.check_circle_outline),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح.'), backgroundColor: Colors.green));
              },
              child: const Text('حفظ التغييرات', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomHeader(title: 'إعدادات النظام الموسعة'),
      drawer: const CustomAgentDrawer(
        agentName: 'شبكة الصقر للواي فاي',
        phoneNumber: '777777777',
        role: 'وكيل معتمد (Agent)',
        currentBalance: 125000.0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. قسم الطباعة والكاشير
              const Text('إعدادات الكاشير والطباعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.print, color: _isPrinterConnected ? Colors.green : Colors.grey),
                      title: const Text('طابعة البلوتوث الحرارية', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_isPrinterConnected ? 'متصل وجاهز للطباعة' : 'غير متصل', style: TextStyle(color: _isPrinterConnected ? Colors.green : Colors.red)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, elevation: 0),
                        onPressed: _showPrinterDialog,
                        child: const Text('إعداد', style: TextStyle(color: Colors.blueAccent)),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.autorenew, color: Colors.orange),
                      title: const Text('الطباعة التلقائية بعد البيع'),
                      subtitle: const Text('طباعة الكرت فوراً دون نافذة تأكيد'),
                      value: _autoPrintEnabled,
                      activeColor: Colors.orange,
                      onChanged: (val) => setState(() => _autoPrintEnabled = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 2. قسم الحساب والأمان
              const Text('الحساب والأمان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_reset, color: Colors.redAccent),
                      title: const Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: _showChangePasswordDialog,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.verified_user, color: Colors.teal),
                      title: const Text('تحديث بيانات المتجر (البقالة)'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب التواصل مع الإدارة لتغيير اسم البقالة.')));
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 3. قسم التنبيهات والإشعارات
              const Text('إعدادات التطبيق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active, color: Colors.blue),
                      title: const Text('إشعارات النظام'),
                      subtitle: const Text('استقبال تنبيهات العروض والرصيد'),
                      value: _notificationsEnabled,
                      activeColor: Colors.blue,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_up, color: Colors.purple),
                      title: const Text('أصوات التطبيق'),
                      subtitle: const Text('صوت نجاح عملية البيع والطباعة'),
                      value: _soundEnabled,
                      activeColor: Colors.purple,
                      onChanged: (val) => setState(() => _soundEnabled = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              // زر حفظ أسفل الشاشة
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعداداتك بنجاح! ✅'), backgroundColor: Colors.green));
                  },
                  child: const Text('حفظ جميع التغييرات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // أداة مساعدة لبناء حقول النصوص
  Widget _buildTextField(String hint, IconData icon) {
    return TextField(
      obscureText: true,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: Colors.blueGrey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}
