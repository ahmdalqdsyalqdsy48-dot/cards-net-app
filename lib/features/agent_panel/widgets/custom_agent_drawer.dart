import 'package:flutter/material.dart';

// 👇 استدعاء الشاشات لربطها بالقائمة الجانبية
import '../screens/agent_dashboard_screen.dart';
import '../screens/quick_pos_screen.dart';
import '../screens/mikrotik_categories_screen.dart';
import '../screens/sub_agents_screen.dart'; // 👈 تم إضافة استدعاء شاشة البقالات
import '../../auth/screens/sso_login_screen.dart';

class CustomAgentDrawer extends StatefulWidget {
  final String agentName;
  final String phoneNumber;
  final String role;
  final double currentBalance;

  const CustomAgentDrawer({
    super.key,
    required this.agentName,
    required this.phoneNumber,
    required this.role,
    required this.currentBalance,
  });

  @override
  State<CustomAgentDrawer> createState() => _CustomAgentDrawerState();
}

class _CustomAgentDrawerState extends State<CustomAgentDrawer> {
  // متغير للتحكم في إظهار أو إخفاء الرصيد
  bool _isBalanceVisible = true;

  // ==========================================
  // دالة إظهار قائمة تعديل الشعار (صورة الملف الشخصي)
  // ==========================================
  void _showProfileImageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min, // لكي تأخذ القائمة مساحة على قدر المحتوى فقط
              children: [
                const Text('تعديل شعار الشبكة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.blue),
                  title: const Text('عرض الصورة'),
                  onTap: () {
                    Navigator.pop(context); // إغلاق القائمة
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم عرض الصورة بحجم كامل')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate, color: Colors.green),
                  title: const Text('إضافة / تغيير الصورة'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم فتح المعرض لاختيار صورة جديدة')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('حذف الصورة'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الشعار بنجاح!'), backgroundColor: Colors.red));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // دالة مساعدة للتنقل للأقسام غير المكتملة
  // ==========================================
  void _showComingSoonMessage() {
    Navigator.pop(context); // إغلاق القائمة الجانبية أولاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('قريباً.. هذه الميزة قيد التطوير 🚀', textDirection: TextDirection.rtl),
        backgroundColor: Colors.blueGrey,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Directionality(
        textDirection: TextDirection.rtl, // فرض اتجاه اللغة لليمين
        child: Column(
          children: [
            // ==========================================
            // 1. الترويسة العلوية الغنية (Header)
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 20, right: 16, left: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade800,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showProfileImageMenu(context),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.router, size: 45, color: Colors.blueAccent),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(widget.agentName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  // بطاقة الدور (برتقالي)
                  _buildColorBadge(widget.role, Icons.admin_panel_settings, Colors.orange.shade700),
                  const SizedBox(height: 8),
                  
                  // بطاقة رقم الهاتف (أخضر)
                  _buildColorBadge(widget.phoneNumber, Icons.phone, Colors.green.shade600),
                  const SizedBox(height: 8),

                  // بطاقة المحفظة مع زر الإخفاء (بنفسجي)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.purple.shade700, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _isBalanceVisible ? "المحفظة: ${widget.currentBalance.toStringAsFixed(0)} ريال" : "المحفظة: *********",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isBalanceVisible = !_isBalanceVisible;
                            });
                          },
                          child: Icon(_isBalanceVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white70, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // 2. قائمة الأقسام المجمعة والمقسمة منطقياً
            // ==========================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                children: [
                  // تم استبدال الألوان المتدرجة بتصميم أنيق وصلب
                  _buildSectionTitle('عمليات البيع والشبكة', Colors.blue.shade700),
                  
                  // 👇 ربط شاشة لوحة القيادة
                  _buildDrawerItem(
                    title: 'الرئيسية (غرفة القيادة)', 
                    icon: Icons.dashboard, 
                    iconColor: Colors.blue, 
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const AgentDashboardScreen()),
                        (route) => false,
                      );
                    }
                  ),

                  // 👇 ربط شاشة الكاشير السريع
                  _buildDrawerItem(
                    title: 'المتجر السريع (الكاشير)', 
                    icon: Icons.point_of_sale, 
                    iconColor: Colors.green, 
                    onTap: () {
                      Navigator.pop(context); // إغلاق القائمة
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const QuickPosScreen()));
                    }
                  ),

                  // 👇 ربط شاشة الميكروتك
                  _buildDrawerItem(
                    title: 'إدارة الفئات والميكروتك', 
                    icon: Icons.router, 
                    iconColor: Colors.orange, 
                    onTap: () {
                      Navigator.pop(context); // إغلاق القائمة
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MikrotikCategoriesScreen()));
                    }
                  ),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),

                  _buildSectionTitle('الإدارة والتسويق', Colors.orange.shade800),
                  
                  // 👇 تم ربط شاشة إدارة البقالات هنا
                  _buildDrawerItem(
                    title: 'إدارة نقاط البيع (البقالات)', 
                    icon: Icons.storefront, 
                    iconColor: Colors.purple, 
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SubAgentsScreen()));
                    }
                  ),
                  
                  _buildDrawerItem(title: 'التسويق والعروض', icon: Icons.campaign, iconColor: Colors.pinkAccent, onTap: _showComingSoonMessage),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),

                  _buildSectionTitle('المالية والمحاسبة', Colors.teal.shade700),
                  _buildDrawerItem(title: 'محفظة الوكيل', icon: Icons.account_balance_wallet, iconColor: Colors.teal, onTap: _showComingSoonMessage),
                  _buildDrawerItem(title: 'كشف الحساب المتقدم', icon: Icons.receipt_long, iconColor: Colors.cyan, onTap: _showComingSoonMessage),
                  _buildDrawerItem(title: 'التقارير التحليلية', icon: Icons.analytics, iconColor: Colors.redAccent, onTap: _showComingSoonMessage),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),

                  _buildSectionTitle('الإعدادات والدعم', Colors.deepPurple.shade700),
                  _buildDrawerItem(title: 'الدعم الفني الموحد', icon: Icons.support_agent, iconColor: Colors.indigo, onTap: _showComingSoonMessage),
                  _buildDrawerItem(title: 'إعدادات النظام الموسعة', icon: Icons.settings, iconColor: Colors.blueGrey, onTap: _showComingSoonMessage),

                  const SizedBox(height: 20),
                  
                  // 👇 برمجة زر تسجيل الخروج
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const SSOLoginScreen()),
                        (route) => false, // مسح كل الشاشات السابقة لعدم التمكن من العودة بالزر الخلفي
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // أدوات مساعدة 
  // ==========================================

  Widget _buildColorBadge(String text, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // 👇 دالة جديدة للعناوين بدلاً من الألوان المتدرجة (Gradient) لتكون أكثر تناسقاً
  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }

  // 👇 تم تحديث الدالة وفرض الاتجاه لليمين وحل مشكلة الأيقونات المعكوسة
  Widget _buildDrawerItem({required String title, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return Directionality(
      textDirection: TextDirection.rtl, // تأكيد فرض الاتجاه
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(icon, color: iconColor), 
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        trailing: Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.grey.shade500), // السهم يتجه لليسار للدلالة على الدخول للقسم
        onTap: onTap,
      ),
    );
  }
}
