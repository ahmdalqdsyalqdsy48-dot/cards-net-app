import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; 

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/theme_provider.dart'; // 👈 ضروري لتباين الألوان
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

  // متغيرات تبويب تسجيل الدخول
  late TextEditingController _appNameCtrl, _appLogoCtrl, _welcomeMsgCtrl;
  late double _carouselInterval;
  String _marqueeDirection = 'rtl';
  
  final Color _defaultBgColor = const Color(0xFF0D1B2A);
  final Color _defaultMarqueeBg = const Color(0x4DFFC107);
  final Color _defaultMarqueeText = const Color(0xFFFFFFFF);
  final Color _defaultAppNameColor = const Color(0xFF2196F3);

  late Color _loginBgColor, _marqueeBgColor, _marqueeTextColor, _appNameColor;

  String _appNameAlign = 'center';
  String _appNameFont = 'Cairo';
  final List<String> _fonts = ['Cairo', 'Tajawal', 'Almarai', 'Roboto', 'Changa'];

  List<dynamic> _sliderImages = [];
  Uint8List? _newLogoBytes; // 👈 لتخزين الشعار الجديد قبل الرفع

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
    _welcomeMsgCtrl = TextEditingController(text: sys.loginWelcomeMessage); 
    _carouselInterval = sys.carouselIntervalSeconds.toDouble();
    _marqueeDirection = sys.marqueeDirection;

    _loginBgColor = Color(sys.loginBgColor);
    _marqueeBgColor = Color(sys.marqueeBgColor);
    _marqueeTextColor = Color(sys.marqueeTextColor);
    
    _appNameAlign = sys.appNameAlign; 
    _appNameFont = sys.appNameFont; 
    _appNameColor = Color(sys.appNameColor); 

    _sliderImages = List.from(sys.loginCarouselImages);

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
  // 1. محرك اختيار الشعار (اللوجو)
  // ========================================================
  Future<void> _pickLogoLocally() async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final Uint8List bytes = await pickedFile.readAsBytes();
      setState(() {
        _newLogoBytes = bytes;
        _appLogoCtrl.text = 'سيتم الرفع عند الحفظ...'; // إشعار بصري للمستخدم
      });
    } catch (e) {
      _showSnack('حدث خطأ أثناء اختيار الشعار', isErr: true);
    }
  }

  // ========================================================
  // 2. محرك اختيار صور السلايدر
  // ========================================================
  Future<void> _pickMultipleImagesLocally() async {
    final picker = ImagePicker();
    try {
      final List<XFile> pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      for (var file in pickedFiles) {
        final Uint8List bytes = await file.readAsBytes();
        setState(() {
          _sliderImages.add(bytes); 
        });
      }
      _showSnack('تم إضافة ${pickedFiles.length} صور. اضغط حفظ للرفع.', isErr: false);
    } catch (e) {
      _showSnack('حدث خطأ أثناء اختيار الصور', isErr: true);
    }
  }

  // ========================================================
  // 3. محرك الرفع الفعلي (محمي بـ Timeout قوي جداً)
  // ========================================================
  Future<List<String>> _uploadPendingImages() async {
    List<String> finalUrls = [];
    
    for (int i = 0; i < _sliderImages.length; i++) {
      var item = _sliderImages[i];
      if (item is String) {
        finalUrls.add(item);
      } else if (item is Uint8List) {
        String path = 'portal_assets/slider_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(path);
        
        // 👈 إضافة Timeout قوي لمنع التعليق اللانهائي
        await ref.putData(item, SettableMetadata(contentType: 'image/jpeg')).timeout(const Duration(seconds: 20));
        String url = await ref.getDownloadURL();
        finalUrls.add(url);
      }
    }
    return finalUrls;
  }

  Future<String?> _uploadLogoIfChanged() async {
    if (_newLogoBytes == null) return null;
    try {
      String path = 'portal_assets/logo_${DateTime.now().millisecondsSinceEpoch}.png';
      Reference ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(_newLogoBytes!, SettableMetadata(contentType: 'image/png')).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e) {
      throw 'فشل رفع الشعار!';
    }
  }

  // ========================================================
  // 4. عجلة الألوان المتجاوبة
  // ========================================================
  void _openColorPicker(String title, Color currentColor, Color defaultColor, Function(Color) onColorSelected, Color textColor) {
    Color tempColor = currentColor;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(title, style: TextStyle(color: textColor)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (c) => tempColor = c,
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(onPressed: () { onColorSelected(defaultColor); Navigator.pop(context); }, child: const Text('إرجاع للافتراضي', style: TextStyle(color: Colors.red))),
            ElevatedButton(onPressed: () { onColorSelected(tempColor); Navigator.pop(context); }, child: const Text('موافق')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final Color textColor = theme.adaptiveTextColor; // 👈 لون النص المتجاوب 100%

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة البوابات الذكية'),
      drawer: CustomDrawer(userName: sys.currentUserName, phoneNumber: sys.currentUserPhone, role: 'مالك النظام', balanceOrPoints: 'أرباح: ${sys.adminMainBalance.toStringAsFixed(0)}'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            TabBar(
              controller: _tabController, 
              labelColor: textColor, // 👈 استجابة التبويبات للون
              indicatorColor: textColor,
              unselectedLabelColor: textColor.withOpacity(0.5),
              tabs: const [Tab(text: 'بوابة الدخول'), Tab(text: 'الوكلاء'), Tab(text: 'المستخدمين')]
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildLoginTab(sys, theme, textColor), _buildAgentTab(), _buildUserTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // بناء تبويب تسجيل الدخول (خالي من الألوان الثابتة)
  // ==========================================
  Widget _buildLoginTab(SystemProvider sys, ThemeProvider theme, Color textColor) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle('الهوية البصرية للتطبيق', textColor),
              _buildAdaptiveTextField('اسم التطبيق', _appNameCtrl, Icons.app_shortcut, textColor),
              
              // 👈 المربع الذي كان أبيض، الآن شفاف وذو حدود تتناسب مع لون المظهر
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.transparent, // بدون لون ثابت
                  borderRadius: BorderRadius.circular(10), 
                  border: Border.all(color: textColor.withOpacity(0.3), width: 1.5) // حدود متجاوبة
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تخصيص ظهور اسم التطبيق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor.withOpacity(0.8))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _appNameAlign,
                            dropdownColor: Theme.of(context).scaffoldBackgroundColor, // لون القائمة المنسدلة متجاوب
                            style: TextStyle(color: textColor, fontFamily: theme.fontFamily),
                            decoration: InputDecoration(
                              labelText: 'مكان الظهور', 
                              labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor.withOpacity(0.3))),
                              isDense: true
                            ),
                            items: const [DropdownMenuItem(value: 'right', child: Text('يمين')), DropdownMenuItem(value: 'center', child: Text('منتصف')), DropdownMenuItem(value: 'left', child: Text('يسار'))],
                            onChanged: (v) => setState(() => _appNameAlign = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _appNameFont,
                            dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                            style: TextStyle(color: textColor, fontFamily: theme.fontFamily),
                            decoration: InputDecoration(
                              labelText: 'نوع الخط', 
                              labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor.withOpacity(0.3))),
                              isDense: true
                            ),
                            items: _fonts.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                            onChanged: (v) => setState(() => _appNameFont = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildColorRow('لون نص اسم التطبيق', _appNameColor, _defaultAppNameColor, (c) => setState(() => _appNameColor = c), textColor),
                  ],
                ),
              ),

              Row(
                children: [
                  Expanded(child: _buildAdaptiveTextField('رابط الشعار (يُفضل PNG شفاف)', _appLogoCtrl, Icons.image, textColor, readOnly: _newLogoBytes != null)),
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: textColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: textColor.withOpacity(0.3))), 
                    child: IconButton(icon: Icon(Icons.upload_file, color: textColor), onPressed: _pickLogoLocally) // 👈 الزر أصبح يعمل
                  ),
                ],
              ),
              
              _buildColorRow('لون خلفية صفحة الدخول', _loginBgColor, _defaultBgColor, (c) => setState(() => _loginBgColor = c), textColor),

              Divider(height: 40, thickness: 1, color: textColor.withOpacity(0.2)),

              _buildTitle('شريط الرسالة الترحيبية المتحرك', textColor),
              _buildAdaptiveTextField('النص الترحيبي', _welcomeMsgCtrl, Icons.campaign, textColor, maxLines: 2),
              Row(
                children: [
                  Expanded(child: _buildColorRow('لون الخلفية', _marqueeBgColor, _defaultMarqueeBg, (c) => setState(() => _marqueeBgColor = c), textColor)),
                  Expanded(child: _buildColorRow('لون النص', _marqueeTextColor, _defaultMarqueeText, (c) => setState(() => _marqueeTextColor = c), textColor)),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _marqueeDirection,
                dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                style: TextStyle(color: textColor, fontFamily: theme.fontFamily),
                decoration: InputDecoration(
                  labelText: 'اتجاه حركة الشريط', 
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor.withOpacity(0.3))),
                ),
                items: const [DropdownMenuItem(value: 'rtl', child: Text('من اليمين (عربي)')), DropdownMenuItem(value: 'ltr', child: Text('من اليسار (إنجليزي)'))],
                onChanged: (v) => setState(() => _marqueeDirection = v!),
              ),

              Divider(height: 40, thickness: 1, color: textColor.withOpacity(0.2)),

              _buildTitle('إدارة صور السلايدر الإعلاني', textColor),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: textColor.withOpacity(0.1), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: textColor.withOpacity(0.3)))),
                  onPressed: _pickMultipleImagesLocally, 
                  icon: Icon(Icons.photo_library, color: textColor),
                  label: Text('اختيار صور من المعرض', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                ),
              ),

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
                        decoration: BoxDecoration(border: Border.all(color: textColor.withOpacity(0.5), width: 1.5), borderRadius: BorderRadius.circular(12)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: img is String 
                                  ? Image.network(img, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.broken_image))
                                  : Image.memory(img as Uint8List, fit: BoxFit.cover),
                            ),
                            Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 28), onPressed: () => setState(() => _sliderImages.removeAt(index)))),
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
              _buildTitle('سرعة التبديل التلقائي (بالثواني)', textColor),
              Slider(value: _carouselInterval, min: 2, max: 15, divisions: 13, label: _carouselInterval.toInt().toString(), activeColor: textColor, inactiveColor: textColor.withOpacity(0.2), onChanged: (v) => setState(() => _carouselInterval = v)),
            ],
          ),
        ),

        // 👈 زر الحفظ المحمي 100% 
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))]),
            child: SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _isSaving ? null : () async {
                  setState(() => _isSaving = true);
                  
                  try {
                    // رفع الشعار لو تم تغييره
                    String? newLogoUrl = await _uploadLogoIfChanged();
                    String finalLogo = newLogoUrl ?? _appLogoCtrl.text;

                    // رفع الصور (محمية بـ Timeout)
                    List<String> finalUrls = await _uploadPendingImages();

                    await sys.updateAdvancedLoginSettings(
                      name: _appNameCtrl.text, logoUrl: finalLogo, bgColor: _loginBgColor.value,
                      images: finalUrls, welcomeMsg: _welcomeMsgCtrl.text,
                      intervalSeconds: _carouselInterval.toInt(), marqueeDir: _marqueeDirection,
                      marqueeTextCol: _marqueeTextColor.value, marqueeBgCol: _marqueeBgColor.value, marqueeFont: sys.marqueeFontSize,
                      appNameAlign: _appNameAlign, appNameFont: _appNameFont, appNameColor: _appNameColor.value,
                    );
                    
                    _showSnack('تم حفظ الإعدادات ورفع الملفات بنجاح! ✅');
                  } catch (error) {
                    _showSnack('خطأ في الاتصال بالخادم، يرجى المحاولة مجدداً!', isErr: true);
                  } finally {
                    setState(() => _isSaving = false);
                  }
                },
                icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, color: Colors.white),
                label: Text(_isSaving ? 'جاري المعالجة والرفع...' : 'حفظ وتطبيق التغييرات', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _moveImage(int oldIndex, int newIndex) {
    setState(() {
      final item = _sliderImages.removeAt(oldIndex);
      _sliderImages.insert(newIndex, item);
    });
  }

  Widget _buildColorRow(String title, Color color, Color defColor, Function(Color) onChanged, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          InkWell(
            onTap: () => _openColorPicker(title, color, defColor, onChanged, textColor),
            child: Container(
              width: 35, height: 35,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: textColor.withOpacity(0.5), width: 1.5), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentTab() { return const Center(child: Text('إعدادات الوكلاء')); }
  Widget _buildUserTab() { return const Center(child: Text('إعدادات المستخدمين')); }
  
  Widget _buildTitle(String t, Color textColor) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 10), child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)));
  
  // 👈 حقل نصي متجاوب الألوان
  Widget _buildAdaptiveTextField(String l, TextEditingController c, IconData i, Color textColor, {int maxLines = 1, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12), 
      child: TextField(
        controller: c, 
        maxLines: maxLines, 
        readOnly: readOnly,
        style: TextStyle(color: textColor), // النص المكتوب
        decoration: InputDecoration(
          labelText: l, 
          labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
          prefixIcon: Icon(i, color: textColor.withOpacity(0.7)), 
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: textColor.withOpacity(0.3))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: textColor, width: 2)),
        )
      )
    );
  }
}
