import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; 

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

  // ==========================================
  // متغيرات تبويب (تسجيل الدخول - البوابة الخارجية)
  // ==========================================
  late TextEditingController _appNameCtrl, _appLogoCtrl, _welcomeMsgCtrl;
  late double _carouselInterval;
  String _marqueeDirection = 'rtl';
  
  // الألوان الافتراضية للرجوع إليها
  final Color _defaultBgColor = const Color(0xFF0D1B2A);
  final Color _defaultMarqueeBg = const Color(0x4DFFC107);
  final Color _defaultMarqueeText = const Color(0xFFFFFFFF);
  final Color _defaultAppNameColor = const Color(0xFF2196F3);

  // الألوان الحالية
  late Color _loginBgColor, _marqueeBgColor, _marqueeTextColor, _appNameColor;

  // خصائص اسم التطبيق 
  String _appNameAlign = 'center';
  String _appNameFont = 'Cairo';
  final List<String> _fonts = ['Cairo', 'Tajawal', 'Almarai', 'Roboto', 'Changa'];

  // قائمة الصور الهجينة (روابط للصور القديمة، و Uint8List للجديدة)
  List<dynamic> _sliderImages = [];

  // ==========================================
  // متغيرات الوكلاء والمستخدمين
  // ==========================================
  late bool _hideProfit, _leaderboard, _forceTheme, _guestMode, _kycRequired, _loyaltySystem;
  List<String> _agentHiddenList = [], _userHiddenList = [];
  late TextEditingController _waCtrl, _fbCtrl, _tgCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  void _loadData() {
    final sys = Provider.of<SystemProvider>(context, listen: false);
    
    _appNameCtrl = TextEditingController(text: sys.appName);
    _appLogoCtrl = TextEditingController(text: sys.appLogoUrl);
    // 👈 هذا المتغير مفصول تماماً عن شريط الأخبار الداخلي
    _welcomeMsgCtrl = TextEditingController(text: sys.loginWelcomeMessage); 
    _carouselInterval = sys.carouselIntervalSeconds.toDouble();
    _marqueeDirection = sys.marqueeDirection;

    _loginBgColor = Color(sys.loginBgColor);
    _marqueeBgColor = Color(sys.marqueeBgColor);
    _marqueeTextColor = Color(sys.marqueeTextColor);
    
    _appNameAlign = sys.appNameAlign; 
    _appNameFont = sys.appNameFont; 
    _appNameColor = Color(sys.appNameColor); 

    // جلب الصور السابقة كروابط 
    _sliderImages = List.from(sys.loginCarouselImages);

    // متغيرات التبويبات الأخرى
    _hideProfit = sys.hideProfitEnabled; _leaderboard = sys.leaderboardEnabled; _forceTheme = sys.forceAgentTheme;
    _agentHiddenList = List.from(sys.agentUniversalHiddenSections);
    _guestMode = sys.guestModeEnabled; _kycRequired = sys.kycRequired; _loyaltySystem = sys.loyaltySystemEnabled;
    _userHiddenList = List.from(sys.userUniversalHiddenSections);
    _waCtrl = TextEditingController(text: sys.socialLinks['whatsapp'] ?? '');
    _fbCtrl = TextEditingController(text: sys.socialLinks['facebook'] ?? '');
    _tgCtrl = TextEditingController(text: sys.socialLinks['telegram'] ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appNameCtrl.dispose(); _appLogoCtrl.dispose(); _welcomeMsgCtrl.dispose();
    _waCtrl.dispose(); _fbCtrl.dispose(); _tgCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String m, {bool isErr = false}) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, textDirection: TextDirection.rtl), backgroundColor: isErr ? Colors.red : Colors.green));
  }

  // ========================================================
  // 1. محرك اختيار الصور (بدون أي ضغط، دقة أصلية 100%)
  // ========================================================
  Future<void> _pickMultipleImagesLocally() async {
    final picker = ImagePicker();
    try {
      // تم إزالة imageQuality لرفع الصورة بجودتها الأصلية تماماً
      final List<XFile> pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      for (var file in pickedFiles) {
        final Uint8List bytes = await file.readAsBytes();
        setState(() {
          _sliderImages.add(bytes); 
        });
      }
      _showSnack('تم إضافة ${pickedFiles.length} صور للمعاينـة. اضغط حفظ لرفعها.', isErr: false);
    } catch (e) {
      _showSnack('حدث خطأ أثناء اختيار الصور', isErr: true);
    }
  }

  // ========================================================
  // 2. محرك الرفع الفعلي (محمي بـ Try-Catch لضمان عدم التعليق)
  // ========================================================
  Future<List<String>> _uploadPendingImages() async {
    List<String> finalUrls = [];
    
    for (int i = 0; i < _sliderImages.length; i++) {
      var item = _sliderImages[i];
      if (item is String) {
        // الصورة مرفوعة مسبقاً
        finalUrls.add(item);
      } else if (item is Uint8List) {
        // صورة جديدة بحجمها الأصلي
        String path = 'portal_assets/slider_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(path);
        
        // رفع البيانات الأصلية مباشرة
        await ref.putData(item, SettableMetadata(contentType: 'image/jpeg'));
        String url = await ref.getDownloadURL();
        finalUrls.add(url);
      }
    }
    return finalUrls;
  }

  // ========================================================
  // 3. عجلة الألوان 
  // ========================================================
  void _openColorPicker(String title, Color currentColor, Color defaultColor, Function(Color) onColorSelected) {
    Color tempColor = currentColor;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (c) => tempColor = c,
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                onColorSelected(defaultColor); 
                Navigator.pop(context);
              },
              child: const Text('إرجاع للافتراضي', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                onColorSelected(tempColor); 
                Navigator.pop(context);
              },
              child: const Text('موافق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة البوابات الذكية'),
      drawer: CustomDrawer(userName: sys.currentUserName, phoneNumber: sys.currentUserPhone, role: 'مالك النظام', balanceOrPoints: 'أرباح: ${sys.adminMainBalance.toStringAsFixed(0)}'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            TabBar(controller: _tabController, labelColor: Colors.blueAccent, tabs: const [Tab(text: 'بوابة الدخول'), Tab(text: 'الوكلاء'), Tab(text: 'المستخدمين')]),
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

  // ==========================================
  // بناء تبويب تسجيل الدخول 
  // ==========================================
  Widget _buildLoginTab(SystemProvider sys) {
    // 👈 الذكاء اللوني: لحل مشكلة اختفاء النصوص في الوضع الليلي
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color containerBg = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    final Color containerBorder = isDark ? Colors.grey.shade600 : Colors.grey.shade300;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. الهوية البصرية 
              _buildTitle('الهوية البصرية للتطبيق'),
              _buildTextField('اسم التطبيق', _appNameCtrl, Icons.app_shortcut),
              
              // 👈 خيارات اسم التطبيق (متجاوبة الألوان الآن)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: containerBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: containerBorder)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تخصيص ظهور اسم التطبيق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _appNameAlign,
                            decoration: const InputDecoration(labelText: 'مكان الظهور', isDense: true),
                            items: const [DropdownMenuItem(value: 'right', child: Text('يمين')), DropdownMenuItem(value: 'center', child: Text('منتصف')), DropdownMenuItem(value: 'left', child: Text('يسار'))],
                            onChanged: (v) => setState(() => _appNameAlign = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _appNameFont,
                            decoration: const InputDecoration(labelText: 'نوع الخط', isDense: true),
                            items: _fonts.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                            onChanged: (v) => setState(() => _appNameFont = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildColorRow('لون نص اسم التطبيق', _appNameColor, _defaultAppNameColor, (c) => setState(() => _appNameColor = c)),
                  ],
                ),
              ),

              Row(
                children: [
                  Expanded(child: _buildTextField('رابط الشعار (يُفضل PNG شفاف)', _appLogoCtrl, Icons.image)),
                  const SizedBox(width: 8),
                  Container(decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.upload, color: Colors.white), onPressed: () { /* رفع لوجو مستقل مستقبلاً */ })),
                ],
              ),
              
              _buildColorRow('لون خلفية صفحة الدخول', _loginBgColor, _defaultBgColor, (c) => setState(() => _loginBgColor = c)),

              const Divider(height: 40, thickness: 2),

              // 2. شريط الأخبار المتحرك (Marquee الخاص ببوابة الدخول)
              _buildTitle('شريط الرسالة الترحيبية المتحرك (يظهر في الدخول فقط)'),
              _buildTextField('النص الترحيبي', _welcomeMsgCtrl, Icons.campaign, maxLines: 2),
              Row(
                children: [
                  Expanded(child: _buildColorRow('لون الخلفية', _marqueeBgColor, _defaultMarqueeBg, (c) => setState(() => _marqueeBgColor = c))),
                  Expanded(child: _buildColorRow('لون النص', _marqueeTextColor, _defaultMarqueeText, (c) => setState(() => _marqueeTextColor = c))),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _marqueeDirection,
                decoration: const InputDecoration(labelText: 'اتجاه حركة الشريط', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'rtl', child: Text('من اليمين (عربي)')), DropdownMenuItem(value: 'ltr', child: Text('من اليسار (إنجليزي)'))],
                onChanged: (v) => setState(() => _marqueeDirection = v!),
              ),

              const Divider(height: 40, thickness: 2),

              // 3. إدارة الصور المتعددة (السلايدر الترحيبي)
              _buildTitle('إدارة صور السلايدر الإعلاني (في صفحة الدخول)'),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _pickMultipleImagesLocally, 
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: const Text('اختيار صور من المعرض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),

              // عرض الصور القابلة للترتيب والحذف
              if (_sliderImages.isNotEmpty) ...[
                const SizedBox(height: 15),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sliderImages.length,
                    itemBuilder: (context, index) {
                      var img = _sliderImages[index];
                      return Container(
                        margin: const EdgeInsets.only(left: 10),
                        width: 200,
                        decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 2), borderRadius: BorderRadius.circular(12)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: img is String 
                                  ? Image.network(img, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.broken_image))
                                  : Image.memory(img as Uint8List, fit: BoxFit.cover),
                            ),
                            // زر الحذف
                            Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 28), onPressed: () => setState(() => _sliderImages.removeAt(index)))),
                            // أسهم الترتيب
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                color: Colors.black54,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(icon: const Icon(Icons.arrow_circle_right, color: Colors.white), onPressed: index < _sliderImages.length - 1 ? () => _moveImage(index, index + 1) : null),
                                    Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    IconButton(icon: const Icon(Icons.arrow_circle_left, color: Colors.white), onPressed: index > 0 ? () => _moveImage(index, index - 1) : null),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 15),
              _buildTitle('سرعة التبديل التلقائي (بالثواني)'),
              Slider(value: _carouselInterval, min: 2, max: 15, divisions: 13, label: _carouselInterval.toInt().toString(), activeColor: Colors.blueAccent, onChanged: (v) => setState(() => _carouselInterval = v)),

              const SizedBox(height: 80), // مساحة للزر العائم
            ],
          ),
        ),

        // 👈 الزر الرئيسي للحفظ (محمي بـ Try-Catch لضمان عدم التعليق اللانهائي)
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
            child: SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _isSaving ? null : () async {
                  setState(() => _isSaving = true);
                  
                  try {
                    // 1. رفع الصور بحجمها الأصلي
                    List<String> finalUrls = await _uploadPendingImages();

                    // 2. تحديث قاعدة البيانات
                    await sys.updateAdvancedLoginSettings(
                      name: _appNameCtrl.text, logoUrl: _appLogoCtrl.text, bgColor: _loginBgColor.value,
                      images: finalUrls, welcomeMsg: _welcomeMsgCtrl.text,
                      intervalSeconds: _carouselInterval.toInt(), marqueeDir: _marqueeDirection,
                      marqueeTextCol: _marqueeTextColor.value, marqueeBgCol: _marqueeBgColor.value, marqueeFont: sys.marqueeFontSize,
                      appNameAlign: _appNameAlign, appNameFont: _appNameFont, appNameColor: _appNameColor.value,
                    );
                    
                    _showSnack('تم رفع الصور وحفظ الإعدادات بنجاح! 🚀');
                  } catch (error) {
                    // في حال رفض السيرفر، أو انقطاع النت، سيتوقف التحميل ويظهر الخطأ
                    _showSnack('فشلت العملية، تأكد من الاتصال بالإنترنت: $error', isErr: true);
                  } finally {
                    // إيقاف مؤشر التحميل دائماً حتى لو حدث خطأ
                    setState(() => _isSaving = false);
                  }
                },
                icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save_rounded, color: Colors.white),
                label: Text(_isSaving ? 'جاري رفع الصور بحجمها الأصلي...' : 'حفظ وتطبيق التغييرات', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // أداة مساعدة لتحريك الصور داخل القائمة
  void _moveImage(int oldIndex, int newIndex) {
    setState(() {
      final item = _sliderImages.removeAt(oldIndex);
      _sliderImages.insert(newIndex, item);
    });
  }

  // أداة بناء صف الألوان
  Widget _buildColorRow(String title, Color color, Color defColor, Function(Color) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          InkWell(
            onTap: () => _openColorPicker(title, color, defColor, onChanged),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
            ),
          ),
        ],
      ),
    );
  }

  // --- بقية التبويبات والمساعدات (تم تركها كما هي) ---
  Widget _buildAgentTab(SystemProvider sys) { return const Center(child: Text('إعدادات الوكلاء')); }
  Widget _buildUserTab(SystemProvider sys) { return const Center(child: Text('إعدادات المستخدمين')); }
  Widget _buildTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 10), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)));
  Widget _buildTextField(String l, TextEditingController c, IconData i, {int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, maxLines: maxLines, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: Colors.blueAccent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))));
}
