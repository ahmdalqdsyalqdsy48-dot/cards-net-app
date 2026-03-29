import 'package:flutter/material.dart';

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

class CustomUserDrawer extends StatelessWidget {
  final String userName;
  final String phoneNumber;
  final double walletBalance;

  const CustomUserDrawer({
    super.key,
    required this.userName,
    required this.phoneNumber,
    required this.walletBalance,
  });

  // دالة الانتقال بين الشاشات
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); 
    Navigator.pushReplacement( 
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // 👇 دالة جديدة لإظهار نافذة الباركود (QR Code) عند النقر على الأيقونة
  void _showQRCodeDialog(BuildContext context) {
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
            // أيقونة تمثل الباركود (في المستقبل سنستخدم مكتبة qr_flutter لتوليد باركود حقيقي)
            Icon(Icons.qr_code_2, size: 150, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text(phoneNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👇 4. سحب اللون الأساسي للتطبيق ليكون لون الترويسة ديناميكياً
    final primaryColor = Theme.of(context).primaryColor;

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl, 
        child: Column(
          children: [
            // ==========================================
            // 1. الترويسة العلوية الاحترافية المحدثة
            // ==========================================
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: primaryColor, // اللون يتغير حسب الثيم الآن
              ),
              // 👇 1. الصورة الشخصية مع أيقونة الكاميرا
              currentAccountPicture: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    // صورة تجريبية (Placeholder) لترى شكل الصورة الحقيقية
                    backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.camera_alt, size: 14, color: primaryColor),
                  ),
                ],
              ),
              // 👇 3. أيقونة الباركود في الزاوية العلوية اليسرى
              otherAccountsPictures: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                  onPressed: () => _showQRCodeDialog(context), // استدعاء نافذة الباركود
                ),
              ],
              // 👇 2. الاسم مع شارة المستوى الذهبي
              accountName: Row(
                children: [
                  Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber, // لون الشارة الذهبية
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('عضو ذهبي 🥇', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              accountEmail: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phoneNumber, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  // بطاقة الرصيد
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'رصيد المحفظة: $walletBalance ريال', 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // 2. خيارات القائمة الفائقة (Super App Menu)
            // ==========================================
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(context, 'الرئيسية', Icons.dashboard, primaryColor, () => _navigateTo(context, const UserDashboardScreen())),
                  
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('المالية والمشتريات', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'المحفظة الذكية والتحويلات', Icons.account_balance_wallet, primaryColor, () => _navigateTo(context, const UserWalletScreen())),
                  _buildDrawerItem(context, 'سوق الشبكات ونقاط البيع', Icons.storefront, primaryColor, () => _navigateTo(context, const NetworkStoreScreen())),
                  _buildDrawerItem(context, 'كروتي ومشترياتي', Icons.receipt_long, primaryColor, () => _navigateTo(context, const MyCardsScreen())),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('الامتيازات والسجلات', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'برنامج الولاء والمكافآت', Icons.stars, Colors.amber.shade700, () => _navigateTo(context, const RewardsScreen())),
                  _buildDrawerItem(context, 'سجل العمليات المالية', Icons.history, primaryColor, () => _navigateTo(context, const UserTransactionsScreen())),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('الإعدادات والدعم', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'الدعم الفني والشكاوى', Icons.support_agent, primaryColor, () => _navigateTo(context, const UserSupportScreen())),
                  _buildDrawerItem(context, 'الملف الشخصي والإعدادات', Icons.person, primaryColor, () => _navigateTo(context, const UserSettingsScreen())),
                ],
              ),
            ),

            // ==========================================
            // 3. زر تسجيل الخروج
            // ==========================================
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
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

  // أداة مساعدة لبناء أزرار القائمة
  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      onTap: onTap,
    );
  }
}
