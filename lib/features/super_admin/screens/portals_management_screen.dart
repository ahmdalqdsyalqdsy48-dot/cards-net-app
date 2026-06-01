import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/widgets/custom_drawer.dart';

class PortalsManagementScreen extends StatefulWidget {
  const PortalsManagementScreen({super.key});

  @override
  State<PortalsManagementScreen> createState() =>
      _PortalsManagementScreenState();
}

class _PortalsManagementScreenState extends State<PortalsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaving = false;

  late TextEditingController _appNameCtrl, _appLogoCtrl, _welcomeMsgCtrl, _sliderUrlCtrl;
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

  List<String> _sliderImageUrls = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<UiProvider>().playSound('click');
      }
    });
    _sliderUrlCtrl = TextEditingController();
    _loadData();
  }

  void _loadData() {
    final settings = context.read<SettingsProvider>();

    _appNameCtrl = TextEditingController(text: settings.appName);
    _appLogoCtrl = TextEditingController(text: settings.appLogoUrl);
    _welcomeMsgCtrl = TextEditingController(text: settings.loginWelcomeMessage);
    _carouselInterval = settings.carouselIntervalSeconds.toDouble();
    _marqueeDirection = settings.marqueeDirection;

    _loginBgColor = Color(settings.loginBgColor);
    _marqueeBgColor = Color(settings.marqueeBgColor);
    _marqueeTextColor = Color(settings.marqueeTextColor);

    _appNameAlign = settings.appNameAlign;
    _appNameFont = settings.appNameFont;
    _appNameColor = Color(settings.appNameColor);

    _sliderImageUrls = List<String>.from(settings.loginCarouselImages);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appNameCtrl.dispose();
    _appLogoCtrl.dispose();
    _welcomeMsgCtrl.dispose();
    _sliderUrlCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String m, {bool isErr = false}) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m, textDirection: TextDirection.rtl),
          backgroundColor: isErr ? Colors.red : Colors.green,
        ),
      );
  }

  void _addSliderUrl() {
    String url = _sliderUrlCtrl.text.trim();
    if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
      context.read<UiProvider>().playSound('click');
      setState(() {
        _sliderImageUrls.add(url);
        _sliderUrlCtrl.clear();
      });
    } else {
      context.read<UiProvider>().playSound('error');
      _showSnack('يرجى إدخال رابط مباشر صحيح يبدأ بـ http أو https', isErr: true);
    }
  }

  void _openColorPicker(String title, Color currentColor, Color defaultColor,
      Function(Color) onColorSelected, Color textColor) {
    context.read<UiProvider>().playSound('click');
    Color tempColor = currentColor;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
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
            TextButton(
              onPressed: () {
                onColorSelected(defaultColor);
                Navigator.pop(ctx);
              },
              child: const Text('إرجاع للافتراضي',
                  style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                onColorSelected(tempColor);
                Navigator.pop(ctx);
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
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final Color textColor = theme.adaptiveTextColor;

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة البوابات الذكية'),
      drawer: CustomDrawer(
        userName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'مالك النظام',
        balanceOrPoints:
            'أرباح: ${settings.adminMainBalance.toStringAsFixed(0)} ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: textColor,
              indicatorColor: textColor,
              unselectedLabelColor: textColor.withOpacity(0.5),
              tabs: const [
                Tab(text: 'بوابة الدخول'),
                Tab(text: 'الوكلاء'),
                Tab(text: 'المستخدمين')
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(settings, theme, textColor),
                  _buildAgentTab(settings, theme, textColor),
                  _buildUserTab(settings, theme, textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== تبويب بوابة الدخول ======================
  Widget _buildLoginTab(SettingsProvider settings, ThemeProvider theme, Color textColor) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            _loadData();
            await Future.delayed(const Duration(milliseconds: 300));
            context.read<UiProvider>().playSound('success');
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle('الهوية البصرية للتطبيق', textColor),
                _buildAdaptiveTextField('اسم التطبيق', _appNameCtrl, Icons.app_shortcut, textColor),

                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: textColor.withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تخصيص ظهور اسم التطبيق:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textColor.withOpacity(0.8))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _appNameAlign,
                              dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                              style: TextStyle(color: textColor, fontFamily: theme.fontFamily),
                              decoration: InputDecoration(
                                labelText: 'مكان الظهور',
                                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                                enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: textColor.withOpacity(0.3))),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'right', child: Text('يمين')),
                                DropdownMenuItem(value: 'center', child: Text('منتصف')),
                                DropdownMenuItem(value: 'left', child: Text('يسار')),
                              ],
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
                                enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: textColor.withOpacity(0.3))),
                                isDense: true,
                              ),
                              items: _fonts
                                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                  .toList(),
                              onChanged: (v) => setState(() => _appNameFont = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildColorRow('لون نص اسم التطبيق', _appNameColor, _defaultAppNameColor,
                          (c) => setState(() => _appNameColor = c), textColor),
                    ],
                  ),
                ),

                _buildAdaptiveTextField('رابط الشعار المباشر (URL)', _appLogoCtrl, Icons.link, textColor),

                _buildColorRow('لون خلفية صفحة الدخول', _loginBgColor, _defaultBgColor,
                    (c) => setState(() => _loginBgColor = c), textColor),

                Divider(height: 40, thickness: 1, color: textColor.withOpacity(0.2)),

                _buildTitle('شريط الرسالة الترحيبية المتحرك', textColor),
                _buildAdaptiveTextField('النص الترحيبي', _welcomeMsgCtrl, Icons.campaign, textColor, maxLines: 2),
                Row(
                  children: [
                    Expanded(
                      child: _buildColorRow('لون الخلفية', _marqueeBgColor, _defaultMarqueeBg,
                          (c) => setState(() => _marqueeBgColor = c), textColor),
                    ),
                    Expanded(
                      child: _buildColorRow('لون النص', _marqueeTextColor, _defaultMarqueeText,
                          (c) => setState(() => _marqueeTextColor = c), textColor),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _marqueeDirection,
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  style: TextStyle(color: textColor, fontFamily: theme.fontFamily),
                  decoration: InputDecoration(
                    labelText: 'اتجاه حركة الشريط',
                    labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: textColor.withOpacity(0.3))),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'rtl', child: Text('من اليمين (عربي)')),
                    DropdownMenuItem(value: 'ltr', child: Text('من اليسار (إنجليزي)')),
                  ],
                  onChanged: (v) => setState(() => _marqueeDirection = v!),
                ),

                Divider(height: 40, thickness: 1, color: textColor.withOpacity(0.2)),

                _buildTitle('إدارة صور السلايدر الإعلاني (عبر الروابط)', textColor),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildAdaptiveTextField(
                          'ألصق رابط الصورة هنا...', _sliderUrlCtrl, Icons.add_photo_alternate, textColor),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 55,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _addSliderUrl,
                        child: const Text('إضافة',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),

                if (_sliderImageUrls.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _sliderImageUrls.length,
                      itemBuilder: (context, index) {
                        var imgUrl = _sliderImageUrls[index];
                        return Container(
                          margin: const EdgeInsets.only(left: 10),
                          width: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: textColor.withOpacity(0.5), width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(imgUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image,
                                        size: 40, color: Colors.grey)),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                                  onPressed: () => setState(() => _sliderImageUrls.removeAt(index)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 15),
                _buildTitle('سرعة التبديل التلقائي (بالثواني)', textColor),
                Slider(
                  value: _carouselInterval,
                  min: 2,
                  max: 15,
                  divisions: 13,
                  label: _carouselInterval.toInt().toString(),
                  activeColor: textColor,
                  inactiveColor: textColor.withOpacity(0.2),
                  onChanged: (v) => setState(() => _carouselInterval = v),
                ),
              ],
            ),
          ),
        ),

        // زر الحفظ
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5))
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);
                        context.read<UiProvider>().playSound('click');
                        try {
                          await settings.updateAdvancedLoginSettings(
                            name: _appNameCtrl.text,
                            logoUrl: _appLogoCtrl.text,
                            bgColor: _loginBgColor.value,
                            images: _sliderImageUrls,
                            welcomeMsg: _welcomeMsgCtrl.text,
                            intervalSeconds: _carouselInterval.toInt(),
                            marqueeDir: _marqueeDirection,
                            marqueeTextCol: _marqueeTextColor.value,
                            marqueeBgCol: _marqueeBgColor.value,
                            appNameAlign: _appNameAlign,
                            appNameFont: _appNameFont,
                            appNameColor: _appNameColor.value,
                          );
                          context.read<UiProvider>().playSound('success');
                          _showSnack('تم حفظ الإعدادات بنجاح! ✅');
                        } catch (error) {
                          context.read<UiProvider>().playSound('error');
                          _showSnack('حدث خطأ أثناء الحفظ!', isErr: true);
                        } finally {
                          setState(() => _isSaving = false);
                        }
                      },
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, color: Colors.white),
                label: Text(
                  _isSaving ? 'جاري الحفظ...' : 'حفظ وتطبيق التغييرات',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ====================== تبويب الوكلاء ======================
  Widget _buildAgentTab(SettingsProvider settings, ThemeProvider theme, Color textColor) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 300));
        context.read<UiProvider>().playSound('success');
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle('إعدادات بوابة الوكلاء', textColor),
            SwitchListTile(
              title: const Text('إخفاء الأرباح'),
              subtitle: const Text('إخفاء مؤشر الأرباح في لوحة الوكيل'),
              value: settings.hideProfitEnabled,
              activeColor: Colors.blue,
              onChanged: (v) {
                context.read<UiProvider>().playSound('click');
                settings.updateAgentPortalSettings(
                  hideProfit: v,
                  leaderboard: settings.leaderboardEnabled,
                  forceTheme: settings.forceAgentTheme,
                  universalHidden: settings.agentUniversalHiddenSections,
                );
              },
            ),
            SwitchListTile(
              title: const Text('تفعيل لوحة الصدارة'),
              subtitle: const Text('إظهار ترتيب الوكلاء حسب المبيعات'),
              value: settings.leaderboardEnabled,
              activeColor: Colors.blue,
              onChanged: (v) {
                context.read<UiProvider>().playSound('click');
                settings.updateAgentPortalSettings(
                  hideProfit: settings.hideProfitEnabled,
                  leaderboard: v,
                  forceTheme: settings.forceAgentTheme,
                  universalHidden: settings.agentUniversalHiddenSections,
                );
              },
            ),
            SwitchListTile(
              title: const Text('إجبار استخدام ثيم النظام'),
              subtitle: const Text('منع الوكلاء من تغيير الألوان'),
              value: settings.forceAgentTheme,
              activeColor: Colors.blue,
              onChanged: (v) {
                context.read<UiProvider>().playSound('click');
                settings.updateAgentPortalSettings(
                  hideProfit: settings.hideProfitEnabled,
                  leaderboard: settings.leaderboardEnabled,
                  forceTheme: v,
                  universalHidden: settings.agentUniversalHiddenSections,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ====================== تبويب المستخدمين ======================
  Widget _buildUserTab(SettingsProvider settings, ThemeProvider theme, Color textColor) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 300));
        context.read<UiProvider>().playSound('success');
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle('إعدادات بوابة المستخدمين', textColor),
            SwitchListTile(
              title: const Text('تفعيل وضع الضيف'),
              subtitle: const Text('السماح بتصفح التطبيق بدون تسجيل دخول'),
              value: settings.guestModeEnabled,
              activeColor: Colors.blue,
              onChanged: (v) {
                context.read<UiProvider>().playSound('click');
                settings.updateUserPortalSettings(
                  guestMode: v,
                  kyc: settings.kycRequired,
                  loyalty: settings.loyaltySystemEnabled,
                  universalHidden: settings.userUniversalHiddenSections,
                  social: settings.socialLinks,
                );
              },
            ),
            SwitchListTile(
              title: const Text('تفعيل التحقق (KYC)'),
              subtitle: const Text('طلب توثيق الهوية قبل الشراء'),
              value: settings.kycRequired,
              activeColor: Colors.blue,
              onChanged: (v) {
                context.read<UiProvider>().playSound('click');
                settings.updateUserPortalSettings(
                  guestMode: settings.guestModeEnabled,
                  kyc: v,
                  loyalty: settings.loyaltySystemEnabled,
                  universalHidden: settings.userUniversalHiddenSections,
                  social: settings.socialLinks,
                );
              },
            ),
            SwitchListTile(
              title: const Text('تفعيل نظام الولاء'),
              subtitle: const Text('تجميع نقاط واستبدالها'),
              value: settings.loyaltySystemEnabled,
              activeColor: Colors.blue,
              onChanged: (v) {
                context.read<UiProvider>().playSound('click');
                settings.updateUserPortalSettings(
                  guestMode: settings.guestModeEnabled,
                  kyc: settings.kycRequired,
                  loyalty: v,
                  universalHidden: settings.userUniversalHiddenSections,
                  social: settings.socialLinks,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow(String title, Color color, Color defColor,
      Function(Color) onChanged, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          InkWell(
            onTap: () => _openColorPicker(title, color, defColor, onChanged, textColor),
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: textColor.withOpacity(0.5), width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(String t, Color textColor) => Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 10),
      child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)));

  Widget _buildAdaptiveTextField(String l, TextEditingController c, IconData i, Color textColor,
      {int maxLines = 1, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        readOnly: readOnly,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: l,
          labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
          prefixIcon: Icon(i, color: textColor.withOpacity(0.7)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: textColor.withOpacity(0.3))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: textColor, width: 2)),
        ),
      ),
    );
  }
}
