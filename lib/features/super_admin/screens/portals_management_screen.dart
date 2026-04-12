import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isSaving = false; // 👈 مؤشر تحميل عام للعمليات

  // ==========================================
  // متغيرات تبويب (تسجيل الدخول)
  // ==========================================
  late TextEditingController _appNameCtrl;
  late TextEditingController _appLogoCtrl;
  late TextEditingController _welcomeMsgCtrl;
  late double _carouselInterval;
  String _marqueeDirection = 'rtl';
  int _loginBgColor = 0xFFFFFFFF;
  int _marqueeBgColor = 0x4DFFC107;

  final Map<String, int> _colorOptions = {
    'أبيض نقي': 0xFFFFFFFF, 'أسود ملكي': 0xFF000000, 'أزرق داكن': 0xFF0D47A1, 'أصفر شفاف': 0x4DFFC107, 'رمادي هادئ': 0xFFF5F5F5
  };

  // ==========================================
  // متغيرات تبويب (الوكلاء)
  // ==========================================
  late bool _hideProfit;
  late bool _leaderboard;
  late bool _forceTheme;
  List<String> _agentHiddenSections = [];
  
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
  List<String> _userHiddenSections = [];
  late TextEditingController _waCtrl;
  late TextEditingController _fbCtrl;
  late TextEditingController _tgCtrl;

  final Map<String, String> _availableUserSections = {
    'buy_cards': 'شراء كروت التجزئة',
    'history': 'سجل المشتريات',
    'agent_request': 'طلب ترقية لوكيل',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    final sys = Provider.of<SystemProvider>(context, listen: false);
    
    _appNameCtrl = TextEditingController(text: sys.appName);
    _appLogoCtrl = TextEditingController(text: sys.appLogoUrl);
    _welcomeMsgCtrl = TextEditingController(text: sys.loginWelcomeMessage);
    _carouselInterval = sys.carouselIntervalSeconds.toDouble();
    _marqueeDirection = sys.marqueeDirection;
    _loginBgColor = sys.loginBgColor;
    _marqueeBgColor = sys.marqueeBgColor;

    _hideProfit = sys.hideProfitEnabled;
    _leaderboard = sys.leaderboardEnabled;
    _forceTheme = sys.forceAgentTheme;
    _agentHiddenSections = List.from(sys.agentUniversalHiddenSections);

    _guestMode = sys.guestModeEnabled;
    _kycRequired = sys.kycRequired;
    _loyaltySystem = sys.loyaltySystemEnabled;
    _userHiddenSections = List.from(sys.userUniversalHiddenSections);
    _waCtrl = TextEditingController(text: sys.socialLinks['whatsapp'] ?? '');
    _fbCtrl = TextEditingController(text: sys.socialLinks['facebook'] ?? '');
    _tgCtrl = TextEditingController(text: sys.socialLinks['telegram'] ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appNameCtrl.dispose();
    _appLogoCtrl.dispose();
    _welcomeMsgCtrl.dispose();
    _waCtrl.dispose();
    _fbCtrl.dispose();
    _tgCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textDirection: TextDirection.rtl), backgroundColor: isSuccess ? Colors.green : Colors.red),
    );
  }

  // ========================================================
  // محرك رفع الصور السحابي
  // ========================================================
  Future<String?> _uploadImageToFirebase() async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
      if (pickedFile == null) return null;

      _showSnackBar('جاري رفع الصورة إلى السحابة... ⏳');

      final Uint8List bytes = await pickedFile.readAsBytes();
      String fileName = 'system_assets/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      _showSnackBar('تم الرفع بنجاح! ✅');
      return downloadUrl;
    } catch (e) {
      _showSnackBar('خطأ أثناء الرفع: $e', isSuccess: false);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة بوابات النظام 🌐'),
      drawer: CustomDrawer(
        userName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${sys.adminMainBalance.toStringAsFixed(0)} ريال',
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
                Tab(icon: Icon(Icons.login), text: 'بوابة الدخول'),
                Tab(icon: Icon(Icons.storefront), text: 'بوابة الوكلاء'),
                Tab(icon: Icon(Icons.people), text: 'بوابة المستخدمين'),
              ],
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
  // تبويب بوابة الدخول
  // ==========================================
  Widget _buildLoginPortalTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('الهوية البصرية للتطبيق'),
          _buildTextField('اسم التطبيق الأساسي', _appNameCtrl, Icons.app_shortcut),
          
          // حقل اللوجو مع المعاينة الحية
          Row(
            children: [
              Expanded(child: _buildTextField('رابط الشعار (Logo URL)', _appLogoCtrl, Icons.image)),
              const SizedBox(width: 8),
              _buildUploadIconButton(() async {
                String? url = await _uploadImageToFirebase();
                if (url != null) setState(() => _appLogoCtrl.text = url);
              }),
            ],
          ),
          
          // صندوق المعاينة الحية للوجو
          if (_appLogoCtrl.text.isNotEmpty)
            _buildLivePreview(_appLogoCtrl.text, "معاينة اللوجو"),

          DropdownButtonFormField<int>(
            value: _loginBgColor,
            decoration: InputDecoration(labelText: 'لون خلفية صفحة الدخول', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            items: _colorOptions.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
            onChanged: (val) => setState(() => _loginBgColor = val!),
          ),
          
          const Divider(height: 40),
          _buildSectionTitle('الشريط المتحرك والرسالة الترحيبية'),
          _buildTextField('الرسالة الترحيبية (تظهر للمستخدمين)', _welcomeMsgCtrl, Icons.campaign, maxLines: 2),
          
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _marqueeDirection,
                  decoration: const InputDecoration(labelText: 'اتجاه الحركة', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'rtl', child: Text('من اليمين (عربي)')),
                    DropdownMenuItem(value: 'ltr', child: Text('من اليسار (English)')),
                  ],
                  onChanged: (val) => setState(() => _marqueeDirection = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _marqueeBgColor,
                  decoration: const InputDecoration(labelText: 'لون خلفية الشريط', border: OutlineInputBorder()),
                  items: _colorOptions.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
                  onChanged: (val) => setState(() => _marqueeBgColor = val!),
                ),
              ),
            ],
          ),
          
          const Divider(height: 40),
          _buildSectionTitle('إعدادات السلايدر (Carousel)'),
          Card(
            elevation: 0, color: Colors.blue.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Text('سرعة تبديل الصور التلقائي: ${_carouselInterval.toInt()} ثوانٍ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _carouselInterval, min: 2, max: 15, divisions: 13,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) => setState(() => _carouselInterval = val),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          _buildSaveButton('حفظ تحديثات الهوية', () async {
            setState(() => _isSaving = true);
            await sys.updateAdvancedLoginSettings(
              name: _appNameCtrl.text, logoUrl: _appLogoCtrl.text, bgColor: _loginBgColor,
              images: sys.loginCarouselImages, welcomeMsg: _welcomeMsgCtrl.text,
              intervalSeconds: _carouselInterval.toInt(), marqueeDir: _marqueeDirection,
              marqueeTextCol: sys.marqueeTextColor, marqueeBgCol: _marqueeBgColor, marqueeFont: sys.marqueeFontSize,
            );
            setState(() => _isSaving = false);
            _showSnackBar('تم تحديث هوية التطبيق بنجاح! 🚀');
          }),
        ],
      ),
    );
  }

  // ==========================================
  // تبويب بوابة الوكلاء
  // ==========================================
  Widget _buildAgentPortalTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('إدارة ظهور الأقسام للوكلاء'),
          const Text('تحكم في ما يظهر بلوحة الوكيل العامة، أو استخدم الترس ⚙️ للاستهداف الخاص.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          
          ..._availableAgentSections.keys.map((key) {
            bool isHiddenGlobally = _agentHiddenSections.contains(key);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(_availableAgentSections[key]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isHiddenGlobally ? 'مخفي حالياً عن كافة الوكلاء 🚫' : 'ظاهر للجميع بشكل افتراضي ✅', style: TextStyle(color: isHiddenGlobally ? Colors.red : Colors.green, fontSize: 11)),
                leading: Switch(
                  value: !isHiddenGlobally, 
                  activeColor: Colors.green,
                  onChanged: (val) {
                    setState(() {
                      if (val) _agentHiddenSections.remove(key); 
                      else _agentHiddenSections.add(key); 
                    });
                  },
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.settings_suggest_rounded, color: Colors.blueAccent),
                  onPressed: () => _showTargetedHideDialog(sys, key, _availableAgentSections[key]!),
                ),
              ),
            );
          }).toList(),
          
          const Divider(height: 40),
          _buildSectionTitle('سياسات المحفظة والخصوصية'),
          _buildSwitchTile('إخفاء إجمالي الأرباح من واجهة الوكيل', _hideProfit, (v) => setState(() => _hideProfit = v)),
          _buildSwitchTile('تفعيل نظام لوحة الصدارة (Leaderboard)', _leaderboard, (v) => setState(() => _leaderboard = v)),
          _buildSwitchTile('إجبار تطبيق ثيم المالك (Force Branding)', _forceTheme, (v) => setState(() => _forceTheme = v)),

          const Divider(height: 40),
          _buildSectionTitle('أدوات الاستهداف السريع'),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: () => _showTargetingContentDialog(sys, 'banner'), icon: const Icon(Icons.add_photo_alternate), label: const Text('إعلان موجه'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () => _showTargetingContentDialog(sys, 'alert'), icon: const Icon(Icons.warning_amber_rounded, color: Colors.white), label: const Text('إرسال إنذار', style: TextStyle(color: Colors.white)))),
            ],
          ),

          const SizedBox(height: 25),
          _buildSaveButton('تطبيق السياسات على الوكلاء', () async {
            setState(() => _isSaving = true);
            await sys.updateAgentPortalSettings(hideProfit: _hideProfit, leaderboard: _leaderboard, forceTheme: _forceTheme, universalHidden: _agentHiddenSections);
            setState(() => _isSaving = false);
            _showSnackBar('تم تعميم السياسات الجديدة بنجاح! 💼');
          }),
        ],
      ),
    );
  }

  // ==========================================
  // تبويب بوابة المستخدمين
  // ==========================================
  Widget _buildUserPortalTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('إدارة أقسام المستخدمين العاديين'),
          ..._availableUserSections.keys.map((key) {
            bool isHiddenGlobally = _userHiddenSections.contains(key);
            return CheckboxListTile(
              title: Text(_availableUserSections[key]!),
              subtitle: Text(isHiddenGlobally ? 'مخفي عن المستخدمين' : 'متاح للاستخدام', style: TextStyle(fontSize: 11, color: isHiddenGlobally ? Colors.red : Colors.grey)),
              value: !isHiddenGlobally,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                setState(() {
                  if (val!) _userHiddenSections.remove(key); 
                  else _userHiddenSections.add(key); 
                });
              },
            );
          }).toList(),

          const Divider(height: 40),
          _buildSectionTitle('التسويق والنوافذ المنبثقة'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTargetingContentDialog(sys, 'popup'),
              icon: const Icon(Icons.auto_awesome, color: Colors.amber),
              label: const Text('إعداد عرض النافذة الترحيبية (Popup)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white),
            ),
          ),

          const Divider(height: 40),
          _buildSectionTitle('سياسات الدخول والأمان'),
          _buildSwitchTile('تفعيل وضع التصفح للزوار (Guest Mode)', _guestMode, (v) => setState(() => _guestMode = v)),
          _buildSwitchTile('إلزامية رفع الهوية (KYC) للشراء', _kycRequired, (v) => setState(() => _kycRequired = v)),
          _buildSwitchTile('تفعيل محرك النقاط والولاء', _loyaltySystem, (v) => setState(() => _loyaltySystem = v)),

          const Divider(height: 40),
          _buildSectionTitle('روابط الدعم الاجتماعي'),
          _buildTextField('رابط WhatsApp المباشر', _waCtrl, Icons.whatsapp),
          _buildTextField('رابط Facebook الرسمي', _fbCtrl, Icons.facebook),
          _buildTextField('رابط Telegram', _tgCtrl, Icons.telegram),

          const SizedBox(height: 25),
          _buildSaveButton('حفظ إعدادات بوابة المستخدمين', () async {
            setState(() => _isSaving = true);
            await sys.updateUserPortalSettings(
              guestMode: _guestMode, kyc: _kycRequired, loyalty: _loyaltySystem,
              universalHidden: _userHiddenSections, 
              social: {'whatsapp': _waCtrl.text, 'facebook': _fbCtrl.text, 'telegram': _tgCtrl.text},
            );
            setState(() => _isSaving = false);
            _showSnackBar('تم تحديث إعدادات المستخدمين بنجاح!');
          }),
        ],
      ),
    );
  }

  // ==========================================
  // أدوات بناء الواجهة (Helper Widgets)
  // ==========================================

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)));

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextField(
      controller: ctrl, maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.blueAccent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
    ),
  );

  Widget _buildSwitchTile(String title, bool val, Function(bool) onChanged) => SwitchListTile(title: Text(title, style: const TextStyle(fontSize: 14)), value: val, activeColor: Colors.blueAccent, onChanged: onChanged);

  Widget _buildUploadIconButton(VoidCallback onPressed) => Container(
    decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
    child: IconButton(icon: const Icon(Icons.cloud_upload, color: Colors.white), onPressed: onPressed),
  );

  Widget _buildLivePreview(String url, String title) => Container(
    margin: const EdgeInsets.only(bottom: 15),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
    child: Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, height: 60, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.red))),
      ],
    ),
  );

  Widget _buildSaveButton(String text, VoidCallback onPressed) => SizedBox(
    width: double.infinity, height: 55,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      onPressed: _isSaving ? null : onPressed,
      child: _isSaving 
        ? const CircularProgressIndicator(color: Colors.white) 
        : Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    ),
  );

  // ==========================================
  // النوافذ المنبثقة (Dialogs)
  // ==========================================

  void _showTargetedHideDialog(SystemProvider sys, String sectionId, String sectionName) {
    TextEditingController phonesCtrl = TextEditingController();
    bool hideAction = true; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تحكم مخصص: $sectionName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('سيتم تطبيق الإجراء على هؤلاء فقط:', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 10),
                DropdownButtonFormField<bool>(
                  value: hideAction,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [DropdownMenuItem(value: true, child: Text('إخفاء القسم عنهم')), DropdownMenuItem(value: false, child: Text('إظهار القسم (استثناء)'))],
                  onChanged: (v) => setDialogState(() => hideAction = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: phonesCtrl, decoration: const InputDecoration(labelText: 'أرقام الوكلاء (777..., 711...)', border: OutlineInputBorder()), maxLines: 2),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (phonesCtrl.text.isEmpty) return;
                  List<String> phones = phonesCtrl.text.split(',').map((e) => e.trim()).toList();
                  await sys.toggleSectionForSpecificUsers(sectionId: sectionId, targetPhones: phones, hide: hideAction);
                  if (context.mounted) { Navigator.pop(context); _showSnackBar('تم تنفيذ الأمر بنجاح!'); }
                }, 
                child: const Text('تنفيذ الأمر')
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTargetingContentDialog(SystemProvider sys, String type) {
    String targetType = 'all'; 
    TextEditingController phonesCtrl = TextEditingController();
    TextEditingController contentCtrl = TextEditingController(); 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(type == 'banner' ? 'إعلان موجه' : (type == 'popup' ? 'نافذة منبثقة' : 'تنبيه طوارئ')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (type == 'alert')
                    TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'نص التنبيه العاجل'))
                  else
                    Row(
                      children: [
                        Expanded(child: TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'رابط الصورة'))),
                        IconButton(icon: const Icon(Icons.upload_file), onPressed: () async {
                          String? url = await _uploadImageToFirebase();
                          if (url != null) setDialogState(() => contentCtrl.text = url);
                        }),
                      ],
                    ),
                  
                  // معاينة حية داخل النافذة
                  if (type != 'alert' && contentCtrl.text.isNotEmpty)
                    _buildLivePreview(contentCtrl.text, "معاينة الصورة"),

                  const Divider(),
                  RadioListTile(title: const Text('الجميع'), value: 'all', groupValue: targetType, onChanged: (v) => setDialogState(() => targetType = v.toString())),
                  RadioListTile(title: const Text('مستهدفين'), value: 'specific', groupValue: targetType, onChanged: (v) => setDialogState(() => targetType = v.toString())),
                  
                  if (targetType == 'specific')
                    TextField(controller: phonesCtrl, decoration: const InputDecoration(labelText: 'الأرقام (مفصولة بفاصلة)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  List<String> phones = targetType == 'specific' ? phonesCtrl.text.split(',').map((e) => e.trim()).toList() : [];
                  if (type == 'banner') await sys.postTargetedBanner(imageUrl: contentCtrl.text, targetType: targetType, targetPhones: phones);
                  else if (type == 'alert') await sys.setEmergencyAlert(isActive: true, text: contentCtrl.text, targetType: targetType, targetPhones: phones);
                  else if (type == 'popup') await FirebaseFirestore.instance.collection('system').doc('main_info').update({'userPromoPopup': {'isActive': true, 'imageUrl': contentCtrl.text, 'targetType': targetType, 'targetPhones': phones}});
                  
                  if (context.mounted) { Navigator.pop(context); _showSnackBar('تم النشر بنجاح! ✅'); }
                }, 
                child: const Text('نشر الآن')
              ),
            ],
          ),
        ),
      ),
    );
  }
}
