import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';

import '../screens/user_dashboard_screen.dart';
import '../screens/user_wallet_screen.dart';
import '../screens/network_store_screen.dart';
import '../screens/my_cards_screen.dart';
import '../screens/rewards_screen.dart';
import '../screens/user_transactions_screen.dart';
import '../screens/user_support_screen.dart';
import '../screens/user_settings_screen.dart';
import '../../auth/screens/sso_login_screen.dart';

class CustomUserDrawer extends StatefulWidget {
  final String userName;
  final String phoneNumber;
  final String? profileImageUrl;

  const CustomUserDrawer({
    super.key,
    required this.userName,
    required this.phoneNumber,
    this.profileImageUrl,
  });

  @override
  State<CustomUserDrawer> createState() => _CustomUserDrawerState();
}

class _CustomUserDrawerState extends State<CustomUserDrawer> {
  bool _isBalanceHidden = true; // إخفاء الرصيد افتراضيًا
  String? _currentLocalImageUrl;
  Map<String, dynamic>? _userTier;

  @override
  void initState() {
    super.initState();
    _currentLocalImageUrl = widget.profileImageUrl;
    _loadUserTier();
  }

  Future<void> _loadUserTier() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sys = Provider.of<SystemProvider>(context, listen: false);
      sys.getUserHighestTier().then((tier) {
        if (mounted) setState(() => _userTier = tier);
      });
    });
  }

  void _playSound() {
    Provider.of<UiProvider>(context, listen: false).playSound('click');
  }

  void _navigateTo(BuildContext context, Widget screen) {
    _playSound();
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _showQRCodeDialog(BuildContext context, String realPhone) {
    _playSound();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('استقبال رصيد', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('امسح الباركود لتحويل الرصيد إليّ مباشرة', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            Icon(Icons.qr_code_2, size: 150, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text(realPhone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [
          TextButton(onPressed: () { _playSound(); Navigator.pop(context); }, child: const Text('إغلاق')),
        ],
      ),
    );
  }

  // دوال الصورة الشخصية
  Future<void> _updateProfileImage() async {
    _playSound();
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 400);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final base64 = base64Encode(bytes);
    final sys = Provider.of<SystemProvider>(context, listen: false);
    await FirebaseFirestore.instance.collection('users').doc(sys.currentUserPhone).update({'profileImageBase64': base64});
    setState(() => _currentLocalImageUrl = base64);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة بنجاح', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
    Navigator.pop(context);
    _playSound();
  }

  Future<void> _deleteProfileImage() async {
    _playSound();
    final sys = Provider.of<SystemProvider>(context, listen: false);
    await FirebaseFirestore.instance.collection('users').doc(sys.currentUserPhone).update({'profileImageBase64': FieldValue.delete()});
    setState(() => _currentLocalImageUrl = null);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الصورة', textDirection: TextDirection.rtl), backgroundColor: Colors.orange));
    Navigator.pop(context);
    _playSound();
  }

  void _showProfileImageActionDialog() {
    _playSound();
    final sys = Provider.of<SystemProvider>(context, listen: false);
    bool hasImage = _currentLocalImageUrl != null && _currentLocalImageUrl!.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إدارة الصورة الشخصية', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5), width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  image: hasImage ? DecorationImage(image: MemoryImage(base64Decode(_currentLocalImageUrl!)), fit: BoxFit.cover) : null,
                ),
                child: !hasImage ? const Icon(Icons.person, size: 60, color: Colors.blueGrey) : null,
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _updateProfileImage,
                    icon: Icon(hasImage ? Icons.sync : Icons.add_photo_alternate, color: Colors.white, size: 18),
                    label: Text(hasImage ? 'تغيير' : 'إضافة', style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                  ),
                  if (hasImage)
                    ElevatedButton.icon(
                      onPressed: _deleteProfileImage,
                      icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
                      label: const Text('حذف', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _generateGradientColors(Color baseColor) {
    final hsv = HSVColor.fromColor(baseColor);
    final darker = hsv.withValue((hsv.value - 0.2).clamp(0.0, 1.0)).toColor();
    final lighter = hsv.withValue((hsv.value + 0.1).clamp(0.0, 1.0)).toColor();
    return [darker, lighter];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;

    final String dynamicUserName = systemProvider.currentUserName;
    final String dynamicUserPhone = systemProvider.currentUserPhone;
    final bool isPos = systemProvider.currentUserRole == 'pos';

    // تحميل الصورة من Firestore عند الحاجة
    if (_currentLocalImageUrl == null) {
      FirebaseFirestore.instance.collection('users').doc(systemProvider.currentUserPhone).get().then((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final base64 = data['profileImageBase64'] as String?;
          if (base64 != null && mounted) {
            setState(() => _currentLocalImageUrl = base64);
          }
        }
      });
    }
    bool hasImage = _currentLocalImageUrl != null && _currentLocalImageUrl!.isNotEmpty;

    final nameColors = isDark ? _generateGradientColors(primaryColor) : [Colors.blue.shade800, Colors.blue.shade500];
    final phoneColors = isDark ? _generateGradientColors(primaryColor) : [Colors.teal.shade800, Colors.teal.shade500];
    final tierColors = isDark ? _generateGradientColors(primaryColor) : [Colors.orange.shade800, Colors.orange.shade500];
    final balanceColors = isDark ? _generateGradientColors(primaryColor) : [Colors.purple.shade800, Colors.purple.shade500];

    String tierText;
    if (isPos) {
      tierText = 'نقطة بيع معتمدة 🏪';
    } else if (_userTier != null) {
      tierText = 'المستوى: ${_userTier!['title']}';
    } else {
      tierText = 'المستوى: عضو جديد 🆕';
    }

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(), // تمرير سلس
                padding: EdgeInsets.zero,
                children: [
                  SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      color: primaryColor.withOpacity(0.05),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  icon: Icon(Icons.qr_code_scanner, color: primaryColor, size: 28),
                                  onPressed: () => _showQRCodeDialog(context, dynamicUserPhone),
                                ),
                              ),
                              GestureDetector(
                                onTap: _showProfileImageActionDialog,
                                child: Container(
                                  width: 90, height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(color: primaryColor.withOpacity(0.5), width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                                    image: hasImage ? DecorationImage(image: MemoryImage(base64Decode(_currentLocalImageUrl!)), fit: BoxFit.cover) : null,
                                  ),
                                  child: !hasImage ? Icon(Icons.person, size: 45, color: primaryColor.withOpacity(0.7)) : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _buildGradientCard(text: dynamicUserName, icon: Icons.person, colors: nameColors),
                          _buildGradientCard(text: dynamicUserPhone, icon: Icons.phone, colors: phoneColors),
                          _buildGradientCard(text: tierText, icon: isPos ? Icons.verified : Icons.stars, colors: tierColors),
                          GestureDetector(
                            onTap: () {
                              _playSound();
                              setState(() => _isBalanceHidden = !_isBalanceHidden);
                            },
                            child: _buildGradientCard(
                              text: _isBalanceHidden ? 'الرصيد: ******' : '${isPos ? "الرصيد العام" : "المحفظة"}: ${systemProvider.currentUserBalance.toStringAsFixed(0)} ريال',
                              icon: Icons.account_balance_wallet,
                              colors: balanceColors,
                              trailingIcon: _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('المالية والمشتريات', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  _buildDrawerItem(context, 'الرئيسية', Icons.dashboard, Colors.blue, const UserDashboardScreen()),
                  if (!isPos)
                    _buildDrawerItem(context, 'المحفظة الذكية والتحويلات', Icons.account_balance_wallet, Colors.teal, const UserWalletScreen()),
                  _buildDrawerItem(context, isPos ? 'سوق الجملة للشبكات' : 'سوق الشبكات ونقاط البيع', Icons.storefront, Colors.orange, const NetworkStoreScreen()),
                  _buildDrawerItem(context, isPos ? 'سجل المبيعات والكروت' : 'كروتي ومشترياتي', Icons.receipt_long, isPos ? Colors.purple : Colors.green, const MyCardsScreen()),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('الامتيازات والسجلات', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (!isPos)
                    _buildDrawerItem(context, 'برنامج الولاء والمكافآت', Icons.stars, Colors.amber.shade700, const RewardsScreen()),
                  _buildDrawerItem(context, 'سجل العمليات المالية', Icons.history, Colors.indigo, const UserTransactionsScreen()),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('الإعدادات والدعم', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  _buildDrawerItem(context, 'الدعم الفني والشكاوى', Icons.support_agent, Colors.redAccent, const UserSupportScreen()),
                  _buildDrawerItem(context, 'الملف الشخصي والإعدادات', Icons.settings, Colors.blueGrey, const UserSettingsScreen()),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, color: Colors.red, size: 20),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                _playSound();
                final sys = Provider.of<SystemProvider>(context, listen: false);
                sys.clearAllData();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SSOLoginScreen()), (route) => false);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientCard({required String text, required IconData icon, required List<Color> colors, IconData? trailingIcon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
          if (trailingIcon != null) Icon(trailingIcon, color: Colors.white70, size: 17),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, Color iconColor, Widget targetScreen) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
      trailing: Icon(Icons.arrow_forward_ios, size: 11, color: textColor.withOpacity(0.5)),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }
}
