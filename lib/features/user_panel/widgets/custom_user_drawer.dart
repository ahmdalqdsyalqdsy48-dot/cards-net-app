import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 1. استدعاء مكتبة العقل المدبر

// استدعاء مزودات النظام والألوان التي أنشأناها
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/system_provider.dart'; // 👈 2. استدعاء الخادم المحلي الشامل

// الاستدعاءات الخاصة بالشاشات
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
  // 💡 تركنا هذه المتغيرات لكي لا تظهر أخطاء في الشاشات القديمة التي تستدعي القائمة
  // لكننا سنتجاهلها في الداخل ونستخدم البيانات الحقيقية من الخادم
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
  // متغيرات الحالة (State) للتحكم في الواجهة
  bool _isBalanceHidden = false;
  String? _currentLocalImageUrl; 

  @override
  void initState() {
    super.initState();
    _currentLocalImageUrl = widget.profileImageUrl;
  }

  // دالة الانتقال بين الشاشات
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); 
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // نافذة الباركود (QR Code) - تم تحديثها لتستقبل الرقم الحقيقي
  void _showQRCodeDialog(BuildContext context, String realPhone) {
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
            // عرض رقم الهاتف الحقيقي المسجل في النظام
            Text(realPhone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  // نافذة إدارة الصورة الشخصية
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
                child: !hasImage ? const Icon(Icons.person, size: 60, color: Colors.blueGrey) : null,
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم فتح المعرض لاختيار صورة.')));
                    },
                    icon: Icon(hasImage ? Icons.sync : Icons.add_photo_alternate, color: Colors.white, size: 18),
                    label: Text(hasImage ? 'تغيير' : 'إضافة', style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                  ),
                  if (hasImage) 
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _currentLocalImageUrl = null);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الصورة.'), backgroundColor: Colors.red));
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

  @override
  Widget build(BuildContext context) {
    bool hasImage = _currentLocalImageUrl != null;
    
    // 👇 3. الاستماع للخادم المحلي ومزود الألوان
    final themeProvider = Provider.of<ThemeProvider>(context);
    final systemProvider = Provider.of<SystemProvider>(context);
    final primaryColor = themeProvider.primaryColor;

    // ✨ جلب البيانات الحقيقية من الذاكرة بدلاً من المتغيرات الثابتة
    final String dynamicUserName = systemProvider.currentUserName;
    final String dynamicUserPhone = systemProvider.currentUserPhone;

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ==========================================
                  // 1. الترويسة العلوية الفخمة (بنظام البطاقات)
                  // ==========================================
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
                                  // تمرير الرقم الحقيقي للنافذة المنبثقة
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
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                                    image: hasImage 
                                        ? DecorationImage(image: NetworkImage(_currentLocalImageUrl!), fit: BoxFit.cover) 
                                        : null,
                                  ),
                                  child: !hasImage ? Icon(Icons.person, size: 45, color: primaryColor.withOpacity(0.7)) : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // عرض الاسم الحقيقي هنا
                          _buildGradientCard(
                            text: dynamicUserName, 
                            icon: Icons.person,
                            colors: [Colors.blue.shade800, Colors.blue.shade500],
                          ),

                          // عرض رقم الهاتف الحقيقي هنا
                          _buildGradientCard(
                            text: dynamicUserPhone, 
                            icon: Icons.phone,
                            colors: [Colors.teal.shade800, Colors.teal.shade500],
                          ),

                          _buildGradientCard(
                            text: 'المستوى: عضو ذهبي 🥇',
                            icon: Icons.stars,
                            colors: [Colors.orange.shade800, Colors.orange.shade500],
                          ),

                          // 👇 4. قراءة الرصيد الحقيقي من الخادم المحلي الشامل (SystemProvider)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isBalanceHidden = !_isBalanceHidden;
                              });
                            },
                            child: _buildGradientCard(
                              text: _isBalanceHidden ? 'المحفظة: ******' : 'المحفظة: ${systemProvider.currentUserBalance.toStringAsFixed(0)} ريال',
                              icon: Icons.account_balance_wallet,
                              colors: [Colors.purple.shade800, Colors.purple.shade500],
                              trailingIcon: _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                        ],
                      ),
                    ),
                  ),

                  // ==========================================
                  // 2. خيارات القائمة الفائقة
                  // ==========================================
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('المالية والمشتريات', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'الرئيسية', Icons.dashboard, Colors.blue, const UserDashboardScreen()),
                  _buildDrawerItem(context, 'المحفظة الذكية والتحويلات', Icons.account_balance_wallet, Colors.teal, const UserWalletScreen()),
                  _buildDrawerItem(context, 'سوق الشبكات ونقاط البيع', Icons.storefront, Colors.orange, const NetworkStoreScreen()),
                  _buildDrawerItem(context, 'كروتي ومشترياتي', Icons.receipt_long, Colors.green, const MyCardsScreen()),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('الامتيازات والسجلات', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'برنامج الولاء والمكافآت', Icons.stars, Colors.amber.shade700, const RewardsScreen()),
                  _buildDrawerItem(context, 'سجل العمليات المالية', Icons.history, Colors.indigo, const UserTransactionsScreen()),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('الإعدادات والدعم', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'الدعم الفني والشكاوى', Icons.support_agent, Colors.redAccent, const UserSupportScreen()),
                  _buildDrawerItem(context, 'الملف الشخصي والإعدادات', Icons.settings, Colors.blueGrey, const UserSettingsScreen()),
                ],
              ),
            ),
            
            // ==========================================
            // 3. الفوتر
            // ==========================================
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, color: Colors.red, size: 20),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

  // ==========================================
  // أدوات مساعدة 
  // ==========================================

  Widget _buildGradientCard({required String text, required IconData icon, required List<Color> colors, IconData? trailingIcon}) {
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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))], 
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) Icon(trailingIcon, color: Colors.white70, size: 17),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, Color iconColor, Widget targetScreen) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 11, color: Colors.grey),
      onTap: () => _navigateTo(context, targetScreen),
    );
  }
}
