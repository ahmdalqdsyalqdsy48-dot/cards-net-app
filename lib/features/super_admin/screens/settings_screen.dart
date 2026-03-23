import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';

class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // متغيرات التحكم في الحالة (Switches)
  bool _isMaintenanceMode = false;
  bool _isForcedUpdate = true;
  bool _isFingerprintEnabled = true;
  bool _isCurrencyAutoRounding = true;
  bool _showNewsBar = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام الشخصية', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blueAccent),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(icon: Icon(Icons.palette), text: 'المظهر الشخصي'),
            Tab(icon: Icon(Icons.security), text: 'الأمان والأصوات'),
            Tab(icon: Icon(Icons.settings_input_component), text: 'حالة النظام'),
            Tab(icon: Icon(Icons.gavel), text: 'السياسات والحدود'),
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
            _buildAppearanceTab(),
            _buildSecurityTab(),
            _buildSystemStatusTab(),
            _buildPolicyTab(),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ جميع الإعدادات وتطبيقها على النظام فوراً! ✅'), backgroundColor: Colors.green));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 50)),
          child: const Text('حفظ جميع التغييرات النهائية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ==========================================
  // 1. تبويب المظهر والتخصيص 🎨
  // ==========================================
  Widget _buildAppearanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('تخصيص ألوان اللوحة (Gradients)'),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildColorCircle([Colors.blue, Colors.blueAccent]),
                _buildColorCircle([Colors.redAccent, Colors.red]),
                _buildColorCircle([Colors.purple, Colors.deepPurple]),
                _buildColorCircle([Colors.teal, Colors.green]),
                _buildColorCircle([Colors.orange, Colors.deepOrange]),
                _buildColorCircle([Colors.black, Colors.grey]),
              ],
            ),
          ),
          const Divider(height: 40),
          _buildSectionTitle('إدارة الخطوط والمظهر'),
          ListTile(
            leading: const Icon(Icons.font_download, color: Colors.blue),
            title: const Text('نوع الخط وحجمه'),
            subtitle: const Text('عادي، عريض، مزخرف'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode, color: Colors.indigo),
            title: const Text('تفعيل الوضع الليلي (Dark Mode)'),
            value: false,
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. تبويب الأمان والأصوات 🔐
  // ==========================================
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildActionCard(Icons.lock_reset, 'تغيير كلمة المرور', 'تحديث باسورد المالك'),
          _buildActionCard(Icons.pin, 'إعداد رمز PIN السريع', 'رمز مكون من 6 أرقام للعمليات الحساسة'),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint, color: Colors.green),
            title: const Text('الدخول بالبصمة (Biometrics)'),
            value: _isFingerprintEnabled,
            onChanged: (val) => setState(() => _isFingerprintEnabled = val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up, color: Colors.orange),
            title: const Text('أصوات النظام (إشعارات، كاشير)'),
            value: true,
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. تبويب حالة النظام والصيانة 🚧
  // ==========================================
  Widget _buildSystemStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildActionCard(Icons.branding_watermark, 'هوية النظام', 'اسم التطبيق، الشعار، والعملة'),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.handyman, color: Colors.red),
            title: const Text('وضع الصيانة العامة 🚧'),
            subtitle: const Text('تسجيل خروج الجميع وعرض رسالة "نحن نحدث النظام"'),
            value: _isMaintenanceMode,
            onChanged: (val) => setState(() => _isMaintenanceMode = val),
            activeColor: Colors.red,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.system_update, color: Colors.blue),
            title: const Text('التحديث الإجباري ⚠️'),
            subtitle: const Text('منع استخدام الإصدارات القديمة'),
            value: _isForcedUpdate,
            onChanged: (val) => setState(() => _isForcedUpdate = val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.new_label, color: Colors.redAccent),
            title: const Text('شريط الأخبار العاجلة 🚨'),
            subtitle: const Text('عرض شريط متحرك في أعلى التطبيق'),
            value: _showNewsBar,
            onChanged: (val) => setState(() => _showNewsBar = val),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. تبويب السياسات والحدود ⚖️
  // ==========================================
  Widget _buildPolicyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.calculate, color: Colors.blueGrey),
            title: const Text('جبر كسور الصرافة آلياً'),
            subtitle: const Text('تحميل عمولة التحويل على الوكيل'),
            value: _isCurrencyAutoRounding,
            onChanged: (val) => setState(() => _isCurrencyAutoRounding = val),
          ),
          _buildActionCard(Icons.money_off, 'الحد الأدنى للشحن', 'ضبط أقل مبلغ يمكن للوكيل طلبه'),
          _buildActionCard(Icons.description, 'الشروط والأحكام', 'محرر نصوص الصفحات القانونية'),
          _buildActionCard(Icons.support, 'أرقام الدعم الفني العام', 'تعديل أرقام التواصل في تطبيق الوكيل'),
        ],
      ),
    );
  }

  // أدوات مساعدة للتصميم
  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey));
  }

  Widget _buildColorCircle(List<Color> colors) {
    return Container(
      width: 50,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {},
      ),
    );
  }
}
