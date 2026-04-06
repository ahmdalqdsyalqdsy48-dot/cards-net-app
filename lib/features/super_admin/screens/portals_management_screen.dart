import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_header.dart';

class PortalsManagementScreen extends StatefulWidget {
  const PortalsManagementScreen({super.key});

  @override
  State<PortalsManagementScreen> createState() => _PortalsManagementScreenState();
}

class _PortalsManagementScreenState extends State<PortalsManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ==========================================
  // متغيرات تبويب (تسجيل الدخول)
  // ==========================================
  late TextEditingController _appNameCtrl;
  late TextEditingController _welcomeMsgCtrl;
  late double _carouselInterval;

  // ==========================================
  // متغيرات تبويب (الوكلاء)
  // ==========================================
  late bool _hideProfit;
  late bool _leaderboard;
  late bool _forceTheme;
  List<String> _agentHiddenSections = [];
  
  // الأقسام المتاحة للإخفاء
  final Map<String, String> _availableAgentSections = {
    'buy_cards': 'شراء كروت وجملة',
    'transfer': 'تحويل رصيد',
    'reports': 'التقارير المالية',
    'support': 'الدعم الفني',
  };

  // ==========================================
  // متغيرات تبويب (المستخدمين)
  // ==========================================
  late bool _guestMode;
  late bool _kycRequired;
  late bool _loyaltySystem;
  late TextEditingController _waCtrl;
  late TextEditingController _fbCtrl;
  late TextEditingController _tgCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // جلب البيانات الحالية من الخادم عند فتح الشاشة
    final sys = Provider.of<SystemProvider>(context, listen: false);
    
    // تهيئة متغيرات الدخول
    _appNameCtrl = TextEditingController(text: sys.appName);
    _welcomeMsgCtrl = TextEditingController(text: sys.loginWelcomeMessage);
    _carouselInterval = sys.carouselIntervalSeconds.toDouble();

    // تهيئة متغيرات الوكلاء
    _hideProfit = sys.hideProfitEnabled;
    _leaderboard = sys.leaderboardEnabled;
    _forceTheme = sys.forceAgentTheme;
    _agentHiddenSections = List.from(sys.agentUniversalHiddenSections);

    // تهيئة متغيرات المستخدمين
    _guestMode = sys.guestModeEnabled;
    _kycRequired = sys.kycRequired;
    _loyaltySystem = sys.loyaltySystemEnabled;
    _waCtrl = TextEditingController(text: sys.socialLinks['whatsapp'] ?? '');
    _fbCtrl = TextEditingController(text: sys.socialLinks['facebook'] ?? '');
    _tgCtrl = TextEditingController(text: sys.socialLinks['telegram'] ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appNameCtrl.dispose();
    _welcomeMsgCtrl.dispose();
    _waCtrl.dispose();
    _fbCtrl.dispose();
    _tgCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isSuccess ? Colors.green : Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة بوابات النظام 🌐'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                tabs: const [
                  Tab(icon: Icon(Icons.login), text: 'بوابة الدخول'),
                  Tab(icon: Icon(Icons.storefront), text: 'بوابة الوكلاء'),
                  Tab(icon: Icon(Icons.people), text: 'بوابة المستخدمين'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginPortalTab(sys),
                  _buildAgentPortalTab(sys),
                  _buildUserPortalTab(sys),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. تبويب بوابة الدخول
  // ==========================================
  Widget _buildLoginPortalTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('الهوية البصرية للتطبيق'),
          _buildTextField('اسم التطبيق', _appNameCtrl, Icons.app_shortcut),
          
          const Divider(height: 30),
          _buildSectionTitle('الشريط المتحرك (Marquee)'),
          _buildTextField('الرسالة الترحيبية', _welcomeMsgCtrl, Icons.campaign, maxLines: 2),
          
          const Divider(height: 30),
          _buildSectionTitle('السلايدر الإعلاني'),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text('سرعة تبديل الصور: ${_carouselInterval.toInt()} ثواني', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _carouselInterval, min: 2, max: 10, divisions: 8,
                    onChanged: (val) => setState(() => _carouselInterval = val),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          _buildSaveButton('حفظ إعدادات الدخول', () async {
            await sys.updateAdvancedLoginSettings(
              name: _appNameCtrl.text, logoUrl: sys.appLogoUrl, bgColor: sys.loginBgColor,
              images: sys.loginCarouselImages, welcomeMsg: _welcomeMsgCtrl.text,
              intervalSeconds: _carouselInterval.toInt(), marqueeDir: sys.marqueeDirection,
              marqueeTextCol: sys.marqueeTextColor, marqueeBgCol: sys.marqueeBgColor, marqueeFont: sys.marqueeFontSize,
            );
            _showSnackBar('تم تحديث شاشة الدخول بنجاح!');
          }),
        ],
      ),
    );
  }

  // ==========================================
  // 2. تبويب بوابة الوكلاء
  // ==========================================
  Widget _buildAgentPortalTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('إدارة الأقسام (إخفاء عام على جميع الوكلاء)'),
          Card(
            child: Column(
              children: _availableAgentSections.keys.map((key) {
                bool isHidden = _agentHiddenSections.contains(key);
                return CheckboxListTile(
                  title: Text(_availableAgentSections[key]!),
                  subtitle: Text(isHidden ? 'مخفي 🚫' : 'ظاهر ✅', style: TextStyle(color: isHidden ? Colors.red : Colors.green, fontSize: 12)),
                  value: !isHidden, // إذا كان true يعني ظاهر
                  activeColor: Colors.green,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _agentHiddenSections.remove(key); // إظهار
                      } else {
                        _agentHiddenSections.add(key); // إخفاء
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          
          const Divider(height: 30),
          _buildSectionTitle('إعدادات الخصوصية والتحفيز'),
          SwitchListTile(title: const Text('إخفاء إجمالي الأرباح من الرئيسية'), subtitle: const Text('حماية خصوصية الوكيل من الزبائن'), value: _hideProfit, onChanged: (val) => setState(() => _hideProfit = val)),
          SwitchListTile(title: const Text('تفعيل لوحة الصدارة (Leaderboard)'), subtitle: const Text('إظهار أفضل 5 وكلاء مبيعاً'), value: _leaderboard, onChanged: (val) => setState(() => _leaderboard = val)),
          SwitchListTile(title: const Text('إجبار الوكلاء على لون هويتك'), subtitle: const Text('منع الوكيل من تغيير لون لوحته'), value: _forceTheme, onChanged: (val) => setState(() => _forceTheme = val)),

          const Divider(height: 30),
          _buildSectionTitle('الاستهداف المباشر (Targeting)'),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: () => _showTargetingDialog(sys, 'banner'), icon: const Icon(Icons.image), label: const Text('بانر موجه'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => _showTargetingDialog(sys, 'alert'), icon: const Icon(Icons.warning, color: Colors.white), label: const Text('تنبيه طوارئ', style: TextStyle(color: Colors.white)))),
            ],
          ),

          const SizedBox(height: 20),
          _buildSaveButton('حفظ إعدادات الوكلاء', () async {
            await sys.updateAgentPortalSettings(hideProfit: _hideProfit, leaderboard: _leaderboard, forceTheme: _forceTheme, universalHidden: _agentHiddenSections);
            _showSnackBar('تم تطبيق السياسات على جميع الوكلاء!');
          }),
        ],
      ),
    );
  }

  // ==========================================
  // 3. تبويب بوابة المستخدمين
  // ==========================================
  Widget _buildUserPortalTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('سياسات الدخول للمستخدمين'),
          SwitchListTile(title: const Text('تفعيل وضع الزائر (Guest Mode)'), subtitle: const Text('السماح بالتصفح بدون إنشاء حساب'), value: _guestMode, onChanged: (val) => setState(() => _guestMode = val)),
          SwitchListTile(title: const Text('إلزامية التحقق من الهوية (KYC)'), subtitle: const Text('منع الشراء قبل رفع البطاقة الشخصية'), value: _kycRequired, onChanged: (val) => setState(() => _kycRequired = val)),
          SwitchListTile(title: const Text('نظام الولاء والنقاط'), subtitle: const Text('إعطاء نقاط مقابل كل عملية شراء'), value: _loyaltySystem, onChanged: (val) => setState(() => _loyaltySystem = val)),

          const Divider(height: 30),
          _buildSectionTitle('روابط التواصل الاجتماعي'),
          _buildTextField('رابط واتساب الدعم', _waCtrl, Icons.chat),
          _buildTextField('رابط صفحة فيسبوك', _fbCtrl, Icons.facebook),
          _buildTextField('رابط قناة تليجرام', _tgCtrl, Icons.telegram),

          const SizedBox(height: 20),
          _buildSaveButton('حفظ إعدادات المستخدمين', () async {
            await sys.updateUserPortalSettings(
              guestMode: _guestMode, kyc: _kycRequired, loyalty: _loyaltySystem,
              universalHidden: [], // يمكن إضافتها لاحقاً بنفس طريقة الوكلاء
              social: {'whatsapp': _waCtrl.text, 'facebook': _fbCtrl.text, 'telegram': _tgCtrl.text},
            );
            _showSnackBar('تم تحديث بوابة المستخدمين!');
          }),
        ],
      ),
    );
  }

  // ==========================================
  // أدوات مساعدة (Helpers)
  // ==========================================
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey));
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSaveButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity, height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // نافذة الاستهداف (لإرسال بانر أو تنبيه لأشخاص محددين)
  void _showTargetingDialog(SystemProvider sys, String type) {
    String targetType = 'all'; // all, specific
    TextEditingController targetPhonesCtrl = TextEditingController();
    TextEditingController contentCtrl = TextEditingController(); // سواء رابط صورة أو نص رسالة

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(type == 'banner' ? 'نشر إعلان موجه' : 'تنبيه طوارئ', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: contentCtrl,
                    decoration: InputDecoration(labelText: type == 'banner' ? 'رابط الصورة الإعلانية' : 'نص التنبيه'),
                  ),
                  const SizedBox(height: 15),
                  const Text('الاستهداف:', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile(title: const Text('جميع الوكلاء'), value: 'all', groupValue: targetType, onChanged: (val) => setDialogState(() => targetType = val.toString())),
                  RadioListTile(title: const Text('وكلاء محددين (حسب الرقم)'), value: 'specific', groupValue: targetType, onChanged: (val) => setDialogState(() => targetType = val.toString())),
                  
                  if (targetType == 'specific')
                    TextField(
                      controller: targetPhonesCtrl,
                      decoration: const InputDecoration(labelText: 'أرقام الهواتف (مفصول بينها بفاصلة)', hintText: '777..., 711...'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  List<String> phones = targetType == 'specific' ? targetPhonesCtrl.text.split(',').map((e) => e.trim()).toList() : [];
                  if (type == 'banner') {
                    await sys.postTargetedBanner(imageUrl: contentCtrl.text, targetType: targetType, targetPhones: phones);
                  } else {
                    await sys.setEmergencyAlert(isActive: true, text: contentCtrl.text, targetType: targetType, targetPhones: phones);
                  }
                  Navigator.pop(context);
                  _showSnackBar('تم الإرسال بنجاح!');
                },
                child: const Text('إرسال ونشر'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
