import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data'; // 👈 للتعامل مع الصور
import 'package:image_picker/image_picker.dart'; // 👈 لفتح الاستوديو
import 'package:firebase_storage/firebase_storage.dart'; // 👈 لرفع الصور
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 لحفظ بيانات النافذة المنبثقة

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
    'أبيض': 0xFFFFFFFF, 'أسود': 0xFF000000, 'أزرق داكن': 0xFF0D47A1, 'أصفر شفاف': 0x4DFFC107, 'رمادي فاتح': 0xFFF5F5F5
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
  // 🚀 محرك رفع الصور السحابي الخاص بشاشة البوابات
  // ========================================================
  Future<String?> _uploadImageToFirebase() async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
      if (pickedFile == null) return null;

      _showSnackBar('جاري رفع الصورة إلى السيرفر... ⏳', isSuccess: true);

      final Uint8List bytes = await pickedFile.readAsBytes();
      String fileName = 'system_images/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      _showSnackBar('تم الرفع بنجاح! ✅', isSuccess: true);
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

  Widget _buildLoginPortalTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('الهوية البصرية للتطبيق'),
          _buildTextField('اسم التطبيق', _appNameCtrl, Icons.app_shortcut),
          
          // 👈 حقل اللوجو مدمج مع زر الرفع من الاستوديو
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _appLogoCtrl,
                    decoration: InputDecoration(
                      labelText: 'رابط الشعار (Logo URL)', prefixIcon: const Icon(Icons.image, color: Colors.blueAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), backgroundColor: Colors.blueGrey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    String? url = await _uploadImageToFirebase();
                    if (url != null) setState(() => _appLogoCtrl.text = url);
                  },
                  child: const Icon(Icons.upload_file, color: Colors.white),
                )
              ],
            ),
          ),

          DropdownButtonFormField<int>(
            value: _loginBgColor,
            decoration: const InputDecoration(labelText: 'لون خلفية صفحة الدخول', border: OutlineInputBorder()),
            items: _colorOptions.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
            onChanged: (val) => setState(() => _loginBgColor = val!),
          ),
          
          const Divider(height: 30),
          _buildSectionTitle('الشريط المتحرك (Marquee)'),
          _buildTextField('الرسالة الترحيبية', _welcomeMsgCtrl, Icons.campaign, maxLines: 2),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _marqueeDirection,
                  decoration: const InputDecoration(labelText: 'اتجاه الحركة', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'rtl', child: Text('من اليمين لليسار')),
                    DropdownMenuItem(value: 'ltr', child: Text('من اليسار لليمين')),
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
              name: _appNameCtrl.text, logoUrl: _appLogoCtrl.text, bgColor: _loginBgColor,
              images: sys.loginCarouselImages, welcomeMsg: _welcomeMsgCtrl.text,
              intervalSeconds: _carouselInterval.toInt(), marqueeDir: _marqueeDirection,
              marqueeTextCol: sys.marqueeTextColor, marqueeBgCol: _marqueeBgColor, marqueeFont: sys.marqueeFontSize,
            );
            _showSnackBar('تم تحديث شاشة الدخول بنجاح!');
          }),
        ],
      ),
    );
  }

  Widget _buildAgentPortalTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('إدارة الأقسام (Section Manager)'),
          const Text('استخدم مفتاح التفعيل للإخفاء العام، أو الترس ⚙️ للإخفاء المخصص لوكلاء محددين.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: _availableAgentSections.keys.map((key) {
                bool isHiddenGlobally = _agentHiddenSections.contains(key);
                return ListTile(
                  title: Text(_availableAgentSections[key]!),
                  subtitle: Text(isHiddenGlobally ? 'مخفي عن الجميع 🚫' : 'ظاهر للجميع ✅', style: TextStyle(color: isHiddenGlobally ? Colors.red : Colors.green, fontSize: 12)),
                  leading: Switch(
                    value: !isHiddenGlobally, 
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) _agentHiddenSections.remove(key); 
                        else _agentHiddenSections.add(key); 
                      });
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.blueGrey),
                    onPressed: () => _showTargetedHideDialog(sys, key, _availableAgentSections[key]!),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const Divider(height: 30),
          _buildSectionTitle('إعدادات الخصوصية والتحفيز'),
          SwitchListTile(title: const Text('إخفاء إجمالي الأرباح من الرئيسية'), value: _hideProfit, onChanged: (val) => setState(() => _hideProfit = val)),
          SwitchListTile(title: const Text('تفعيل لوحة الصدارة (Leaderboard)'), value: _leaderboard, onChanged: (val) => setState(() => _leaderboard = val)),
          SwitchListTile(title: const Text('إجبار الوكلاء على لون هويتك'), value: _forceTheme, onChanged: (val) => setState(() => _forceTheme = val)),

          const Divider(height: 30),
          _buildSectionTitle('الاستهداف المباشر (Targeting)'),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: () => _showTargetingContentDialog(sys, 'banner'), icon: const Icon(Icons.image), label: const Text('بانر إعلاني'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => _showTargetingContentDialog(sys, 'alert'), icon: const Icon(Icons.warning, color: Colors.white), label: const Text('تنبيه طوارئ', style: TextStyle(color: Colors.white)))),
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

  Widget _buildUserPortalTab(SystemProvider sys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('إدارة أقسام المستخدمين'),
          Card(
            child: Column(
              children: _availableUserSections.keys.map((key) {
                bool isHiddenGlobally = _userHiddenSections.contains(key);
                return ListTile(
                  title: Text(_availableUserSections[key]!),
                  leading: Switch(
                    value: !isHiddenGlobally, 
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) _userHiddenSections.remove(key); 
                        else _userHiddenSections.add(key); 
                      });
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.blueGrey),
                    onPressed: () => _showTargetedHideDialog(sys, key, _availableUserSections[key]!),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 20),
          _buildSectionTitle('التسويق للمستخدمين'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTargetingContentDialog(sys, 'popup'),
              icon: const Icon(Icons.bolt, color: Colors.amber),
              label: const Text('إعداد النافذة الترحيبية المنبثقة (Promo Pop-up)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            ),
          ),

          const Divider(height: 30),
          _buildSectionTitle('سياسات الدخول للمستخدمين'),
          SwitchListTile(title: const Text('تفعيل وضع الزائر (Guest Mode)'), value: _guestMode, onChanged: (val) => setState(() => _guestMode = val)),
          SwitchListTile(title: const Text('إلزامية التحقق من الهوية (KYC)'), value: _kycRequired, onChanged: (val) => setState(() => _kycRequired = val)),
          SwitchListTile(title: const Text('نظام الولاء والنقاط'), value: _loyaltySystem, onChanged: (val) => setState(() => _loyaltySystem = val)),

          const Divider(height: 30),
          _buildSectionTitle('روابط التواصل الاجتماعي'),
          _buildTextField('رابط واتساب الدعم', _waCtrl, Icons.chat),
          _buildTextField('رابط صفحة فيسبوك', _fbCtrl, Icons.facebook),
          _buildTextField('رابط قناة تليجرام', _tgCtrl, Icons.telegram),

          const SizedBox(height: 20),
          _buildSaveButton('حفظ إعدادات المستخدمين', () async {
            await sys.updateUserPortalSettings(
              guestMode: _guestMode, kyc: _kycRequired, loyalty: _loyaltySystem,
              universalHidden: _userHiddenSections, 
              social: {'whatsapp': _waCtrl.text, 'facebook': _fbCtrl.text, 'telegram': _tgCtrl.text},
            );
            _showSnackBar('تم تحديث بوابة المستخدمين!');
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
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

  void _showTargetedHideDialog(SystemProvider sys, String sectionId, String sectionName) {
    TextEditingController targetPhonesCtrl = TextEditingController();
    bool hideAction = true; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('استهداف قسم: $sectionName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تطبيق الإجراء على أرقام هواتف محددة فقط:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                DropdownButtonFormField<bool>(
                  value: hideAction,
                  decoration: const InputDecoration(labelText: 'نوع الإجراء', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('إخفاء القسم عن هؤلاء')),
                    DropdownMenuItem(value: false, child: Text('إظهار القسم لهؤلاء (كاستثناء)')),
                  ],
                  onChanged: (val) => setDialogState(() => hideAction = val!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetPhonesCtrl,
                  decoration: const InputDecoration(labelText: 'أرقام الهواتف (مفصول بينها بفاصلة)', hintText: '777..., 711...'),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () async {
                  if (targetPhonesCtrl.text.isEmpty) return;
                  List<String> phones = targetPhonesCtrl.text.split(',').map((e) => e.trim()).toList();
                  
                  await sys.toggleSectionForSpecificUsers(sectionId: sectionId, targetPhones: phones, hide: hideAction);
                  
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showSnackBar('تم تطبيق القاعدة على ${phones.length} مستخدم بنجاح!');
                },
                child: const Text('تنفيذ الأمر', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTargetingContentDialog(SystemProvider sys, String type) {
    String targetType = 'all'; 
    TextEditingController targetPhonesCtrl = TextEditingController();
    TextEditingController contentCtrl = TextEditingController(); 

    String dialogTitle = type == 'banner' ? 'نشر إعلان موجه' : (type == 'popup' ? 'النافذة المنبثقة الترحيبية' : 'تنبيه طوارئ');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👈 إذا كان إعلان أو نافذة، نظهر حقل رفع الصورة من الاستوديو!
                  if (type == 'alert')
                    TextField(
                      controller: contentCtrl,
                      decoration: const InputDecoration(labelText: 'نص التنبيه'),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: contentCtrl,
                            decoration: const InputDecoration(labelText: 'رابط الصورة الإعلانية'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.upload_file, color: Colors.blue),
                          onPressed: () async {
                            String? url = await _uploadImageToFirebase();
                            if (url != null) setDialogState(() => contentCtrl.text = url);
                          },
                        )
                      ],
                    ),

                  const SizedBox(height: 15),
                  const Text('الاستهداف:', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile(title: const Text('الجميع (وكلاء ومستخدمين)'), value: 'all', groupValue: targetType, onChanged: (val) => setDialogState(() => targetType = val.toString())),
                  RadioListTile(title: const Text('أشخاص محددين (حسب الرقم)'), value: 'specific', groupValue: targetType, onChanged: (val) => setDialogState(() => targetType = val.toString())),
                  
                  if (targetType == 'specific')
                    TextField(
                      controller: targetPhonesCtrl,
                      decoration: const InputDecoration(labelText: 'أرقام الهواتف (مفصول بفاصلة)'),
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
                  } else if (type == 'alert') {
                    await sys.setEmergencyAlert(isActive: true, text: contentCtrl.text, targetType: targetType, targetPhones: phones);
                  } else if (type == 'popup') {
                    // 👈 تم ربط النافذة المنبثقة بقاعدة البيانات بشكل حقيقي 100%
                    await FirebaseFirestore.instance.collection('system').doc('main_info').update({
                       'userPromoPopup': {'isActive': true, 'imageUrl': contentCtrl.text, 'targetType': targetType, 'targetPhones': phones}
                    });
                  }
                  
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showSnackBar('تم إرسال ونشر المحتوى بنجاح!');
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
