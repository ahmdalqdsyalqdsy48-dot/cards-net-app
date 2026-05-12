import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/agent_dashboard_screen.dart';
import '../screens/quick_pos_screen.dart';
import '../screens/mikrotik_categories_screen.dart';
import '../screens/print_screen.dart';
import '../screens/discount_screen.dart';
import '../screens/archive_screen.dart';
import '../screens/sub_agents_screen.dart';
import '../screens/marketing_offers_screen.dart';
import '../screens/agent_wallet_screen.dart';
import '../screens/advanced_statement_screen.dart';
import '../screens/analytics_reports_screen.dart';
import '../screens/agent_support_screen.dart';
import '../screens/agent_settings_screen.dart';
import '../screens/agent_bank_accounts_screen.dart';
import '../screens/agent_client_list_screen.dart';

import '../../auth/screens/sso_login_screen.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/providers/theme_provider.dart';

class CustomAgentDrawer extends StatefulWidget {
  final String agentName;
  final String phoneNumber;
  final String role;
  final double currentBalance;
  final String? profileImageUrl;

  const CustomAgentDrawer({
    super.key,
    required this.agentName,
    required this.phoneNumber,
    required this.role,
    required this.currentBalance,
    this.profileImageUrl,
  });

  @override
  State<CustomAgentDrawer> createState() => _CustomAgentDrawerState();
}

class _CustomAgentDrawerState extends State<CustomAgentDrawer> {
  bool _isBalanceHidden = false;

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _navigateTo(BuildContext context, Widget screen) {
    _play('click');
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _navigateToPush(BuildContext context, Widget screen) {
    _play('click');
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  List<Color> _generateGradientColors(Color baseColor) {
    final hsv = HSVColor.fromColor(baseColor);
    final darker = hsv.withValue((hsv.value - 0.2).clamp(0.0, 1.0)).toColor();
    final lighter = hsv.withValue((hsv.value + 0.1).clamp(0.0, 1.0)).toColor();
    return [darker, lighter];
  }

  Future<void> _updateProfileImage(SystemProvider sys) async {
    _play('click');
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 30, maxWidth: 400);

    if (pickedFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('جاري تحديث الصورة... ⏳',
              textDirection: TextDirection.rtl)));
      try {
        final Uint8List bytes = await pickedFile.readAsBytes();
        String base64Image = base64Encode(bytes);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(sys.currentUserPhone)
            .update({
          'profileImageBase64': base64Image,
        });

        _play('success');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('تم تحديث صورتك الشخصية بنجاح ✅',
                  textDirection: TextDirection.rtl),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        _play('error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('فشل تحديث الصورة: $e',
                  textDirection: TextDirection.rtl),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _deleteProfileImage(SystemProvider sys) async {
    _play('click');
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(sys.currentUserPhone)
          .update({
        'profileImageBase64': FieldValue.delete(),
      });
      _play('success');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم حذف الصورة الشخصية.',
                textDirection: TextDirection.rtl),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      _play('error');
    }
  }

  void _showProfileImageActionDialog(
      BuildContext context, SystemProvider sys, String? currentBase64) {
    _play('click');
    bool hasImage = currentBase64 != null && currentBase64.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إدارة الصورة الشخصية',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.5), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10)
                  ],
                  image: hasImage
                      ? DecorationImage(
                          image: MemoryImage(base64Decode(currentBase64)),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: !hasImage
                    ? Icon(Icons.person,
                        size: 70,
                        color: Theme.of(context).primaryColor.withOpacity(0.5))
                    : null,
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _updateProfileImage(sys),
                    icon: Icon(
                        hasImage ? Icons.sync : Icons.add_photo_alternate,
                        color: Colors.white,
                        size: 16),
                    label: Text(hasImage ? 'تغيير' : 'إضافة',
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  if (hasImage)
                    ElevatedButton.icon(
                      onPressed: () => _deleteProfileImage(sys),
                      icon: const Icon(Icons.delete_forever,
                          color: Colors.white, size: 16),
                      label: const Text('حذف',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = themeProvider.isDarkMode;
    final Color primaryColor = themeProvider.primaryColor;

    // نصوص واضحة تماماً من colorScheme
    final Color onSurfaceColor = colors.onSurface;
    final Color onSurfaceVariant = colors.onSurfaceVariant;

    final myData = sys.agentsList.firstWhere(
        (a) => a['phone'] == sys.currentUserPhone,
        orElse: () => {});
    final double liveBalance =
        double.tryParse(myData['balance']?.toString() ?? '0') ?? 0.0;
    final String liveName = myData['name'] ?? widget.agentName;
    final String? base64Image = myData['profileImageBase64'];
    bool hasImage = base64Image != null && base64Image.isNotEmpty;

    // كل التدرجات تستخدم primaryColor الآن في كلا الوضعين
    final nameColors = _generateGradientColors(primaryColor);
    final phoneColors = _generateGradientColors(primaryColor);
    final balanceColors = _generateGradientColors(primaryColor);

    return Drawer(
      backgroundColor: colors.surface,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showProfileImageActionDialog(
                                context, sys, base64Image),
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withOpacity(0.1),
                                border: Border.all(
                                    color: primaryColor.withOpacity(0.5),
                                    width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8,
                                      offset: Offset(0, 3))
                                ],
                                image: hasImage
                                    ? DecorationImage(
                                        image: MemoryImage(base64Decode(base64Image)),
                                        fit: BoxFit.cover)
                                    : null,
                              ),
                              child: !hasImage
                                  ? Icon(Icons.person,
                                      size: 50,
                                      color: primaryColor.withOpacity(0.7))
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 15),
                          _buildGradientCard(
                            text: liveName,
                            icon: Icons.store,
                            colors: nameColors,
                          ),
                          _buildGradientCard(
                            text: widget.phoneNumber,
                            icon: Icons.phone,
                            colors: phoneColors,
                          ),
                          GestureDetector(
                            onTap: () {
                              _play('click');
                              setState(() => _isBalanceHidden = !_isBalanceHidden);
                            },
                            child: _buildGradientCard(
                              text: _isBalanceHidden
                                  ? 'المحفظة: ******'
                                  : 'المحفظة: ${liveBalance.toStringAsFixed(0)} ريال',
                              icon: Icons.account_balance_wallet,
                              colors: balanceColors,
                              trailingIcon: _isBalanceHidden
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(color: colors.outlineVariant),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Text('عمليات البيع والشبكة',
                          style: TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.bold))),
                  _buildDrawerItem(
                      context,
                      'الرئيسية (غرفة القيادة)',
                      Icons.dashboard,
                      Colors.blue,
                      const AgentDashboardScreen(),
                      onSurfaceColor),
                  _buildDrawerItem(
                      context,
                      'المتجر السريع (الكاشير)',
                      Icons.point_of_sale,
                      Colors.green,
                      const QuickPosScreen(),
                      onSurfaceColor),

                  // القائمة المنسدلة: الميكروتك والطباعة
                  ExpansionTile(
                    leading: const Icon(Icons.router, color: Colors.orange),
                    title: Text("الميكروتك والطباعة",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: onSurfaceColor)),
                    iconColor: colors.primary,
                    collapsedIconColor: colors.onSurfaceVariant,
                    initiallyExpanded: false,
                    children: [
                      _buildSubItem(
                        context: context,
                        title: 'إدارة الميكروتك والفئات',
                        icon: Icons.dns,
                        iconColor: Colors.orange,
                        screen: const MikrotikCategoriesScreen(),
                        textColor: onSurfaceColor,
                      ),
                      _buildSubItem(
                        context: context,
                        title: 'طباعة الكروت',
                        icon: Icons.print,
                        iconColor: Colors.teal,
                        screen: const PrintScreen(),
                        textColor: onSurfaceColor,
                      ),
                    ],
                  ),

                  // الخصومات
                  _buildDrawerItem(
                      context,
                      'الخصومات 🏆',
                      Icons.local_offer,
                      Colors.amber,
                      const DiscountScreen(),
                      onSurfaceColor),

                  // الأرشيف
                  _buildDrawerItem(
                      context,
                      'الأرشيف المتقدم',
                      Icons.archive,
                      Colors.teal,
                      const ArchiveScreen(),
                      onSurfaceColor),

                  Divider(color: colors.outlineVariant),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Text('الإدارة والتسويق',
                          style: TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.bold))),
                  _buildDrawerItem(
                      context,
                      'إدارة نقاط البيع (البقالات)',
                      Icons.storefront,
                      Colors.purple,
                      const SubAgentsScreen(),
                      onSurfaceColor),
                  _buildDrawerItem(
                      context,
                      'عملائي (المستخدمين والبقالات)',
                      Icons.people,
                      Colors.indigo,
                      const AgentClientListScreen(),
                      onSurfaceColor),
                  _buildDrawerItem(
                      context,
                      'التسويق والعروض',
                      Icons.campaign,
                      Colors.pinkAccent,
                      const MarketingOffersScreen(),
                      onSurfaceColor),

                  Divider(color: colors.outlineVariant),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Text('المالية والمحاسبة',
                          style: TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.bold))),
                  _buildDrawerItem(
                      context,
                      'محفظة الوكيل',
                      Icons.account_balance_wallet,
                      Colors.teal,
                      const AgentWalletScreen(),
                      onSurfaceColor),
                  _buildDrawerItem(
                      context,
                      'حساباتي البنكية 🏦',
                      Icons.account_balance,
                      Colors.deepPurple,
                      const AgentBankAccountsScreen(),
                      onSurfaceColor),
                  _buildDrawerItem(
                      context,
                      'كشف الحساب المتقدم',
                      Icons.receipt_long,
                      Colors.cyan,
                      const AdvancedStatementScreen(),
                      onSurfaceColor),
                  _buildDrawerItem(
                      context,
                      'التقارير التحليلية',
                      Icons.analytics,
                      Colors.redAccent,
                      const AnalyticsReportsScreen(),
                      onSurfaceColor),

                  Divider(color: colors.outlineVariant),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Text('الإعدادات والدعم',
                          style: TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.bold))),
                  _buildDrawerItem(
                      context,
                      'الدعم الفني الموحد',
                      Icons.support_agent,
                      Colors.indigo,
                      const AgentSupportScreen(),
                      onSurfaceColor),
                  _buildDrawerItem(
                      context,
                      'إعدادات النظام الموسعة',
                      Icons.settings,
                      Colors.blueGrey,
                      const AgentSettingsScreen(),
                      onSurfaceColor),
                ],
              ),
            ),

            Divider(color: colors.outlineVariant),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, color: Colors.red, size: 20),
              title: Text('تسجيل الخروج',
                  style: TextStyle(
                      color: onSurfaceColor,
                      fontWeight: FontWeight.bold)),
              onTap: () {
                _play('click');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SSOLoginScreen()),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null)
            Icon(trailingIcon, color: Colors.white70, size: 17),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon,
      Color iconColor, Widget targetScreen, Color textColor) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: textColor)),
      trailing: Icon(Icons.arrow_forward_ios,
          size: 11, color: textColor.withOpacity(0.5)),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }

  Widget _buildSubItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget screen,
    required Color textColor,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: textColor)),
      trailing: Icon(Icons.arrow_forward_ios,
          size: 11, color: textColor.withOpacity(0.5)),
      onTap: () => _navigateToPush(context, screen),
    );
  }
}
