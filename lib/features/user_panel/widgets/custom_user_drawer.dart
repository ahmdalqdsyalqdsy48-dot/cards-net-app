import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart';
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
  bool _isBalanceHidden = false;
  String? _currentLocalImageUrl;

  @override
  void initState() {
    super.initState();
    _currentLocalImageUrl = widget.profileImageUrl;
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _showQRCodeDialog(BuildContext context, String realPhone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('استقبال رصيد', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('امسح الباركود لتحويل الرصيد إليّ مباشرة',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            Icon(Icons.qr_code_2, size: 150, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text(realPhone,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showProfileImageActionDialog(BuildContext context) {
    bool hasImage = _currentLocalImageUrl != null;

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
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5), width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  image: hasImage
                      ? DecorationImage(image: NetworkImage(_currentLocalImageUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: !hasImage
                    ? const Icon(Icons.person, size: 60, color: Colors.blueGrey)
                    : null,
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('سيتم فتح المعرض لاختيار صورة.')));
                    },
                    icon: Icon(hasImage ? Icons.sync : Icons.add_photo_alternate,
                        color: Colors.white, size: 18),
                    label: Text(hasImage ? 'تغيير' : 'إضافة',
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                  ),
                  if (hasImage)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _currentLocalImageUrl = null);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('تم حذف الصورة.'), backgroundColor: Colors.red));
                      },
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

  /// توليد تدرج لوني ديناميكي من اللون الأساسي
  List<Color> _generateGradientColors(Color baseColor) {
    final hsv = HSVColor.fromColor(baseColor);
    final darker = hsv.withValue((hsv.value - 0.2).clamp(0.0, 1.0)).toColor();
    final lighter = hsv.withValue((hsv.value + 0.1).clamp(0.0, 1.0)).toColor();
    return [darker, lighter];
  }

  /// حساب لون النص المناسب (أبيض أو أسود) بناءً على لون الخلفية
  Color _getTextColorForBackground(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    bool hasImage = _currentLocalImageUrl != null;

    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final primaryColor = themeProvider.primaryColor;
    final isDark = themeProvider.isDarkMode;

    final String dynamicUserName = systemProvider.currentUserName;
    final String dynamicUserPhone = systemProvider.currentUserPhone;
    final bool isPos = systemProvider.currentUserRole == 'pos';

    // استخدام textTheme من الثيم الحالي
    final textTheme = Theme.of(context).textTheme;
    final iconTheme = Theme.of(context).iconTheme;

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ========== الترويسة العلوية ==========
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
                                onTap: () => _showProfileImageActionDialog(context),
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(color: primaryColor.withOpacity(0.5), width: 2),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
                                    ],
                                    image: hasImage
                                        ? DecorationImage(
                                            image: NetworkImage(_currentLocalImageUrl!), fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: !hasImage
                                      ? Icon(Icons.person, size: 45, color: primaryColor.withOpacity(0.7))
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // بطاقات التدرج مع نص متكيف
                          _buildGradientCard(
                            text: dynamicUserName,
                            icon: Icons.person,
                            colors: _generateGradientColors(primaryColor),
                          ),
                          _buildGradientCard(
                            text: dynamicUserPhone,
                            icon: Icons.phone,
                            colors: _generateGradientColors(primaryColor),
                          ),
                          _buildGradientCard(
                            text: isPos ? 'نقطة بيع معتمدة 🏪' : 'المستوى: عضو ذهبي 🥇',
                            icon: isPos ? Icons.verified : Icons.stars,
                            colors: _generateGradientColors(primaryColor),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isBalanceHidden = !_isBalanceHidden);
                            },
                            child: _buildGradientCard(
                              text: _isBalanceHidden
                                  ? 'الرصيد: ******'
                                  : '${isPos ? "الرصيد العام" : "المحفظة"}: ${systemProvider.currentUserBalance.toStringAsFixed(0)} ريال',
                              icon: Icons.account_balance_wallet,
                              colors: _generateGradientColors(primaryColor),
                              trailingIcon: _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                        ],
                      ),
                    ),
                  ),

                  // ========== المالية والمشتريات ==========
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('المالية والمشتريات',
                          style: textTheme.labelSmall?.copyWith(color: Colors.grey))),
                  _buildDrawerItem(context, 'الرئيسية', Icons.dashboard, const UserDashboardScreen()),
                  if (!isPos)
                    _buildDrawerItem(context, 'المحفظة الذكية والتحويلات', Icons.account_balance_wallet,
                        const UserWalletScreen()),
                  _buildDrawerItem(context, isPos ? 'سوق الجملة للشبكات' : 'سوق الشبكات ونقاط البيع',
                      Icons.storefront, const NetworkStoreScreen()),
                  _buildDrawerItem(context, isPos ? 'سجل المبيعات والكروت' : 'كروتي ومشترياتي',
                      Icons.receipt_long, const MyCardsScreen()),
                  const Divider(),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('الامتيازات والسجلات',
                          style: textTheme.labelSmall?.copyWith(color: Colors.grey))),
                  if (!isPos)
                    _buildDrawerItem(context, 'برنامج الولاء والمكافآت', Icons.stars, const RewardsScreen()),
                  _buildDrawerItem(context, 'سجل العمليات المالية', Icons.history, const UserTransactionsScreen()),
                  const Divider(),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('الإعدادات والدعم',
                          style: textTheme.labelSmall?.copyWith(color: Colors.grey))),
                  _buildDrawerItem(context, 'الدعم الفني والشكاوى', Icons.support_agent, const UserSupportScreen()),
                  _buildDrawerItem(context, 'الملف الشخصي والإعدادات', Icons.settings, const UserSettingsScreen()),
                ],
              ),
            ),

            // ========== الفوتر ==========
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, color: Colors.red, size: 20),
              title: const Text('تسجيل الخروج',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SSOLoginScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientCard({
    required String text,
    required IconData icon,
    required List<Color> colors,
    IconData? trailingIcon,
  }) {
    // حساب لون النص المناسب بناءً على متوسط لوني التدرج (أو اللون الأغمق)
    final backgroundColor = colors[0]; // نستخدم اللون الأغمق كمرجع
    final textColor = _getTextColorForBackground(backgroundColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null)
            Icon(trailingIcon, color: textColor.withOpacity(0.8), size: 17),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, Widget targetScreen) {
    final iconTheme = Theme.of(context).iconTheme;
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = Theme.of(context).primaryColor;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: iconTheme.color?.withOpacity(0.8) ?? primaryColor, size: 20),
      title: Text(title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
      trailing: Icon(Icons.arrow_forward_ios, size: 11, color: iconTheme.color?.withOpacity(0.5)),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }
}
