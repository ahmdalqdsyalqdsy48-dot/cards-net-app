import 'package:flutter/material.dart';

// 👇 استدعاء جميع الشاشات لربطها بالقائمة الجانبية
import '../screens/user_wallet_screen.dart';
import '../screens/network_store_screen.dart';
import '../screens/my_cards_screen.dart';
import '../screens/rewards_screen.dart';
import '../screens/user_transactions_screen.dart';
import '../screens/user_support_screen.dart';

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

  // 🛠️ دالة مساعدة للانتقال وإغلاق القائمة الجانبية في نفس الوقت
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // إغلاق القائمة الجانبية أولاً
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen)); // الانتقال للشاشة
  }

  @override
  Widget build(BuildContext context) {
    // تحديد ما إذا كان الوضع الليلي مفعلاً لضبط الألوان
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // ==========================================
          // 1. ترويسة القائمة (بيانات المستخدم)
          // ==========================================
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? Colors.blueGrey.shade900 : Colors.blue.shade800,
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blue),
            ),
            accountName: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(phoneNumber, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'رصيد المحفظة: $walletBalance ريال',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // 2. عناصر القائمة الجانبية المربوطة بالشاشات
          // ==========================================
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // زر الرئيسية (يقوم بإغلاق القائمة فقط لأننا فيها بالفعل)
                  _buildMenuItem(Icons.dashboard, 'الرئيسية', () => Navigator.pop(context)),

                  _buildSectionHeader('المالية والمشتريات'),
                  _buildMenuItem(Icons.account_balance_wallet, 'المحفظة الذكية والتحويلات', () => _navigateTo(context, const UserWalletScreen())),
                  _buildMenuItem(Icons.storefront, 'سوق الشبكات ونقاط البيع', () => _navigateTo(context, const NetworkStoreScreen())),
                  _buildMenuItem(Icons.receipt_long, 'كروتي ومشترياتي', () => _navigateTo(context, const MyCardsScreen())),

                  _buildSectionHeader('الامتيازات والسجلات'),
                  _buildMenuItem(Icons.stars, 'برنامج الولاء والمكافآت', () => _navigateTo(context, const RewardsScreen())),
                  _buildMenuItem(Icons.history, 'سجل العمليات المالية', () => _navigateTo(context, const UserTransactionsScreen())),

                  _buildSectionHeader('الإعدادات والدعم'),
                  _buildMenuItem(Icons.support_agent, 'الدعم الفني والشكاوى', () => _navigateTo(context, const UserSupportScreen())),
                  // زر الملف الشخصي يوجه مؤقتاً للدعم حتى نقوم ببرمجته مستقبلاً
                  _buildMenuItem(Icons.person_outline, 'الملف الشخصي والإعدادات', () => _navigateTo(context, const UserSupportScreen())),

                  const Divider(),
                  
                  // زر تسجيل الخروج
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () {
                      // يمكنك لاحقاً ربط هذا الزر بمسح بيانات الدخول والعودة لشاشة الدخول
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الخروج ✅')));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // أداة مساعدة لإنشاء العناوين الفرعية لتنظيم القائمة
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, top: 15, bottom: 5, left: 16),
      child: Text(
        title,
        style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  // أداة مساعدة لإنشاء أزرار القائمة القابلة للنقر
  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
