import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class PortalsManagementScreen extends StatefulWidget {
  const PortalsManagementScreen({super.key});

  @override
  State<PortalsManagementScreen> createState() => _PortalsManagementScreenState();
}

class _PortalsManagementScreenState extends State<PortalsManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaving = false;

  // 1. أقسام الوكلاء
  final Map<String, String> _agentSections = {
    'agent_dashboard_screen': 'الرئيسية (لوحة التحكم)',
    'quick_pos_screen': 'نقطة البيع السريعة',
    'mikrotik_categories_screen': 'فئات كروت الميكروتيك',
    'agent_wallet_screen': 'المحفظة والرصيد',
    'advanced_statement_screen': 'كشف الحساب المتقدم',
    'sub_agents_screen': 'إدارة الوكلاء الفرعيين',
    'analytics_reports_screen': 'التقارير والتحليلات',
    'marketing_offers_screen': 'العروض التسويقية',
    'agent_support_screen': 'الدعم الفني',
    'agent_settings_screen': 'إعدادات الحساب',
  };

  // 2. أقسام المستخدمين
  final Map<String, String> _userSections = {
    'user_dashboard_screen': 'الرئيسية (لوحة التحكم)',
    'network_store_screen': 'متجر الشبكات المتاحة',
    'my_cards_screen': 'كروتي المشتراة',
    'user_wallet_screen': 'المحفظة المالية',
    'user_transactions_screen': 'سجل العمليات والتحويلات',
    'rewards_screen': 'نظام المكافآت والجوائز',
    'user_support_screen': 'الدعم الفني والمساعدة',
    'user_settings_screen': 'إعدادات الملف الشخصي',
  };

  late TextEditingController _appNameCtrl, _welcomeMsgCtrl;
  late double _carouselInterval;
  String _marqueeDirection = 'rtl';
  int _loginBgColor = 0xFFFFFFFF, _marqueeBgColor = 0x4DFFC107;
  
  // 👈 قائمة الصور المتعددة للسلايدر
  List<String> _sliderImages = [];

  late bool _hideProfit, _leaderboard, _forceTheme;
  List<String> _agentHiddenList = [];

  late bool _guestMode, _kycRequired, _loyaltySystem;
  List<String> _userHiddenList = [];
  late TextEditingController _waCtrl, _fbCtrl, _tgCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final sys = Provider.of<SystemProvider>(context, listen: false);

    _appNameCtrl = TextEditingController(text: sys.appName);
    _welcomeMsgCtrl = TextEditingController(text: sys.loginWelcomeMessage);
    _carouselInterval = sys.carouselIntervalSeconds.toDouble();
    _marqueeDirection = sys.marqueeDirection;
    _loginBgColor = sys.loginBgColor;
    _marqueeBgColor = sys.marqueeBgColor;
    
    // 👈 جلب الصور المحفوظة مسبقاً
    _sliderImages = List.from(sys.loginCarouselImages);

    _hideProfit = sys.hideProfitEnabled;
    _leaderboard = sys.leaderboardEnabled;
    _forceTheme = sys.forceAgentTheme;
    _agentHiddenList = List.from(sys.agentUniversalHiddenSections);

    _guestMode = sys.guestModeEnabled;
    _kycRequired = sys.kycRequired;
    _loyaltySystem = sys.loyaltySystemEnabled;
    _userHiddenList = List.from(sys.userUniversalHiddenSections);
    _waCtrl = TextEditingController(text: sys.socialLinks['whatsapp'] ?? '');
    _fbCtrl = TextEditingController(text: sys.socialLinks['facebook'] ?? '');
    _tgCtrl = TextEditingController(text: sys.socialLinks['telegram'] ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appNameCtrl.dispose();
    _welcomeMsgCtrl.dispose();
    _waCtrl.dispose(); _fbCtrl.dispose(); _tgCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String m, {bool isErr = false}) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, textDirection: TextDirection.rtl), backgroundColor: isErr ? Colors.red : Colors.green));
  }

  // ========================================================
  // 🚀 محرك الرفع المتعدد للصور (Multi-Image Upload)
  // ========================================================
  Future<void> _uploadMultipleImages() async {
    final picker = ImagePicker();
    try {
      // السماح باختيار أكثر من صورة
      final List<XFile> pickedFiles = await picker.pickMultiImage(maxWidth: 800, imageQuality: 85);
      if (pickedFiles.isEmpty) return;

      setState(() => _isSaving = true);
      _showSnack('جاري رفع ${pickedFiles.length} صور للسيرفر... ☁️');

      for (var file in pickedFiles) {
        final Uint8List bytes = await file.readAsBytes();
        String path = 'portal_assets/slider_${DateTime.now().millisecondsSinceEpoch}_${pickedFiles.indexOf(file)}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(path);
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        String url = await ref.getDownloadURL();
        
        setState(() {
          _sliderImages.add(url); // إضافة الصورة للقائمة فور رفعها
        });
      }

      setState(() => _isSaving = false);
      _showSnack('تم رفع الصور بنجاح ✅');
    } catch (e) { 
      setState(() => _isSaving = false);
      _showSnack('خطأ في الرفع: $e', isErr: true); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة البوابات الذكية'),
      drawer: CustomDrawer(
        userName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'مالك النظام',
        balanceOrPoints: 'أرباح النظام: ${sys.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              indicatorColor: Colors.blueAccent,
              tabs: const [Tab(text: 'الدخول'), Tab(text: 'الوكلاء'), Tab(text: 'المستخدمين')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildLoginTab(sys), _buildAgentTab(sys), _buildUserTab(sys)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- تبويب الدخول ---
  Widget _buildLoginTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle('الهوية البصرية'),
          _buildTextField('اسم التطبيق', _appNameCtrl, Icons.edit),
          
          DropdownButtonFormField<int>(
            value: _loginBgColor,
            decoration: const InputDecoration(labelText: 'لون الخلفية الأساسي', border: OutlineInputBorder()),
            items: _colorOptions.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
            onChanged: (v) => setState(() => _loginBgColor = v!),
          ),

          const SizedBox(height: 20),
          _buildTitle('إدارة صور واجهة الدخول (السلايدر)'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _isSaving ? null : _uploadMultipleImages, 
              icon: const Icon(Icons.collections, color: Colors.white), 
              label: const Text('اختيار ورفع صور متعددة من المعرض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ),
          
          // عرض الصور المرفوعة
          if (_sliderImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _sliderImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(image: NetworkImage(_sliderImages[index]), fit: BoxFit.cover)
                        ),
                      ),
                      Positioned(
                        top: 0, right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => setState(() => _sliderImages.removeAt(index)),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
          ],

          _buildTitle('سرعة تقليب الصور: ${_carouselInterval.toInt()} ثواني'),
          Slider(value: _carouselInterval, min: 2, max: 15, divisions: 13, onChanged: (v) => setState(() => _carouselInterval = v)),

          _buildTitle('شريط الرسالة الترحيبية'),
          _buildTextField('الرسالة الترحيبية', _welcomeMsgCtrl, Icons.campaign, maxLines: 2),
          
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _marqueeDirection,
                  decoration: const InputDecoration(labelText: 'اتجاه الحركة', border: OutlineInputBorder()),
                  items: const [DropdownMenuItem(value: 'rtl', child: Text('من اليمين')), DropdownMenuItem(value: 'ltr', child: Text('من اليسار'))],
                  onChanged: (v) => setState(() => _marqueeDirection = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _marqueeBgColor,
                  decoration: const InputDecoration(labelText: 'لون شريط الأخبار', border: OutlineInputBorder()),
                  items: _colorOptions.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
                  onChanged: (v) => setState(() => _marqueeBgColor = v!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),
          _buildSaveBtn('حفظ تحديثات الدخول', () async {
            setState(() => _isSaving = true);
            await sys.updateAdvancedLoginSettings(
              name: _appNameCtrl.text, logoUrl: '', bgColor: _loginBgColor,
              images: _sliderImages, welcomeMsg: _welcomeMsgCtrl.text, // 👈 تم حفظ قائمة الصور للسيرفر
              intervalSeconds: _carouselInterval.toInt(), marqueeDir: _marqueeDirection,
              marqueeTextCol: sys.marqueeTextColor, marqueeBgCol: _marqueeBgColor, marqueeFont: sys.marqueeFontSize,
            );
            setState(() => _isSaving = false);
            _showSnack('تم تحديث صفحة الدخول! 🚀');
          }),
        ],
      ),
    );
  }

  // --- تبويب الوكلاء ---
  Widget _buildAgentTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle('ظهور الأقسام للوكلاء'),
          ..._agentSections.keys.map((key) {
            bool isHidden = _agentHiddenList.contains(key);
            return Card(
              child: ListTile(
                title: Text(_agentSections[key]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                leading: Switch(value: !isHidden, activeColor: Colors.green, onChanged: (v) => setState(() { v ? _agentHiddenList.remove(key) : _agentHiddenList.add(key); })),
                trailing: IconButton(icon: const Icon(Icons.settings, color: Colors.blueAccent), onPressed: () => _showTargetedDialog(sys, key, _agentSections[key]!)),
              ),
            );
          }).toList(),
          
          _buildTitle('سياسات الخصوصية والتحفيز'),
          _buildSwitch('إخفاء الأرباح من الرئيسية', _hideProfit, (v) => setState(() => _hideProfit = v)),
          _buildSwitch('تفعيل لوحة الصدارة (Leaderboard)', _leaderboard, (v) => setState(() => _leaderboard = v)),
          _buildSwitch('إجبار الوكلاء على لون هويتك', _forceTheme, (v) => setState(() => _forceTheme = v)),

          _buildTitle('أدوات الاستهداف'),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: () => _showContentDialog(sys, 'banner'), icon: const Icon(Icons.photo), label: const Text('إعلان موجه'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => _showContentDialog(sys, 'alert'), icon: const Icon(Icons.warning, color: Colors.white), label: const Text('تنبيه طوارئ', style: TextStyle(color: Colors.white)))),
            ],
          ),

          const SizedBox(height: 25),
          _buildSaveBtn('تطبيق السياسات على الوكلاء', () async {
            setState(() => _isSaving = true);
            await sys.updateAgentPortalSettings(hideProfit: _hideProfit, leaderboard: _leaderboard, forceTheme: _forceTheme, universalHidden: _agentHiddenList);
            setState(() => _isSaving = false);
            _showSnack('تم تعميم التغييرات بنجاح! 💼');
          }),
        ],
      ),
    );
  }

  // --- تبويب المستخدمين ---
  Widget _buildUserTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle('ظهور الأقسام للمستخدمين'),
          ..._userSections.keys.map((key) {
            bool isHidden = _userHiddenList.contains(key);
            return CheckboxListTile(title: Text(_userSections[key]!), value: !isHidden, onChanged: (v) => setState(() { v! ? _userHiddenList.remove(key) : _userHiddenList.add(key); }));
          }).toList(),

          _buildTitle('سياسات الدخول والأمان'),
          _buildSwitch('تفعيل وضع الزائر (تصفح فقط)', _guestMode, (v) => setState(() => _guestMode = v)),
          _buildSwitch('إلزامية رفع الهوية للشراء', _kycRequired, (v) => setState(() => _kycRequired = v)),
          _buildSwitch('تفعيل نظام النقاط والجوائز', _loyaltySystem, (v) => setState(() => _loyaltySystem = v)),

          _buildTitle('روابط التواصل الاجتماعي'),
          _buildTextField('رابط واتساب الدعم', _waCtrl, Icons.chat),
          _buildTextField('رابط قناة تليجرام', _tgCtrl, Icons.send),

          const SizedBox(height: 20),
          _buildSaveBtn('حفظ إعدادات المستخدمين', () async {
            setState(() => _isSaving = true);
            await sys.updateUserPortalSettings(
              guestMode: _guestMode, kyc: _kycRequired, loyalty: _loyaltySystem,
              universalHidden: _userHiddenList, 
              social: {'whatsapp': _waCtrl.text, 'facebook': _fbCtrl.text, 'telegram': _tgCtrl.text},
            );
            setState(() => _isSaving = false);
            _showSnack('تم تحديث بوابة المستخدمين! ✅');
          }),
        ],
      ),
    );
  }

  // --- الأدوات المساعدة ---
  Widget _buildTitle(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15)));
  Widget _buildTextField(String l, TextEditingController c, IconData i, {int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, maxLines: maxLines, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: Colors.blueAccent), border: const OutlineInputBorder())));
  Widget _buildSwitch(String t, bool v, Function(bool) c) => SwitchListTile(title: Text(t, style: const TextStyle(fontSize: 14)), value: v, activeColor: Colors.blueAccent, onChanged: c);
  Widget _buildSaveBtn(String t, VoidCallback p) => SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _isSaving ? null : p, child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));

  void _showTargetedDialog(SystemProvider sys, String sid, String sname) {
    TextEditingController p = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: Text('تحكم خاص بـ $sname'), content: TextField(controller: p, decoration: const InputDecoration(hintText: 'الأرقام مفصولة بفاصلة (مثلاً 777..., 711...)', border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), ElevatedButton(onPressed: () async { List<String> list = p.text.split(',').map((e) => e.trim()).toList(); await sys.toggleSectionForSpecificUsers(sectionId: sid, targetPhones: list, hide: true); if(mounted){Navigator.pop(c); _showSnack('تم التنفيذ!');} }, child: const Text('تنفيذ'))]));
  }

  void _showContentDialog(SystemProvider sys, String type) {
    TextEditingController content = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(type == 'banner' ? 'نشر إعلان موجه' : 'تنبيه طوارئ'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: content, decoration: InputDecoration(labelText: type == 'banner' ? 'رابط الصورة' : 'نص التنبيه', border: const OutlineInputBorder()))]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), ElevatedButton(onPressed: () async { if (type == 'banner') await sys.postTargetedBanner(imageUrl: content.text, targetType: 'all', targetPhones: []); else await sys.setEmergencyAlert(isActive: true, text: content.text, targetType: 'all', targetPhones: []); if(mounted){Navigator.pop(c); _showSnack('تم النشر! ✅');} }, child: const Text('نشر للجميع'))]));
  }

  final Map<String, int> _colorOptions = {'أبيض': 0xFFFFFFFF, 'أسود': 0xFF000000, 'أزرق داكن': 0xFF0D47A1, 'أصفر': 0x4DFFC107, 'رمادي': 0xFFF5F5F5};
}
