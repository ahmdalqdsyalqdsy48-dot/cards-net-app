import 'package:flutter/material.dart';
// سنقوم بإنشاء هذه الشاشات تباعاً ونقوم بتفعيل الاستدعاءات (Imports)
// import '../screens/user_dashboard_screen.dart'; 
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

  // دالة مساعدة للانتقال بين الشاشات
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // إغلاق القائمة الجانبية
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // رسالة مؤقتة للشاشات التي سنبنيها في الخطوات القادمة
  void _showComingSoon(BuildContext context, String title) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('قريباً.. جاري برمجة شاشة ($title) 🚀'),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl, // لضمان عرض القائمة باللغة العربية
        child: Column(
          children: [
            // ==========================================
            // 1. الترويسة العلوية (بيانات الزبون والمحفظة)
            // ==========================================
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade500],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  userName.substring(0, 1), // عرض أول حرف من اسم الزبون
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
              ),
              accountName: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              accountEmail: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phoneNumber, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  // بطاقة الرصيد الأنيقة
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
                  _buildDrawerItem(context, 'الرئيسية', Icons.dashboard, Colors.blue, () => _showComingSoon(context, 'الرئيسية')),
                  
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('المالية والمشتريات', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'المحفظة الذكية والتحويلات', Icons.account_balance_wallet, Colors.teal, () => _showComingSoon(context, 'المحفظة الذكية')),
                  _buildDrawerItem(context, 'سوق الشبكات ونقاط البيع', Icons.storefront, Colors.orange, () => _showComingSoon(context, 'سوق الشبكات')),
                  _buildDrawerItem(context, 'كروتي ومشترياتي', Icons.receipt_long, Colors.green, () => _showComingSoon(context, 'كروتي ومشترياتي')),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('الامتيازات والسجلات', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'برنامج الولاء والمكافآت', Icons.stars, Colors.amber.shade700, () => _showComingSoon(context, 'المكافآت')),
                  _buildDrawerItem(context, 'سجل العمليات المالية', Icons.history, Colors.indigo, () => _showComingSoon(context, 'سجل العمليات')),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('الإعدادات والدعم', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'الدعم الفني والشكاوى', Icons.support_agent, Colors.redAccent, () => _showComingSoon(context, 'الدعم الفني')),
                  _buildDrawerItem(context, 'الملف الشخصي والإعدادات', Icons.person, Colors.blueGrey, () => _showComingSoon(context, 'الملف الشخصي')),
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

  // أداة مساعدة لبناء أزرار القائمة بشكل مرتب لتقليل تكرار الكود
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
