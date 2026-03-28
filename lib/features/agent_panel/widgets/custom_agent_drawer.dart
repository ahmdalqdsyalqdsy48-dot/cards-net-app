import 'package:flutter/material.dart';

// 👇 استدعاء الشاشات الخاصة بالوكيل (تمت إضافة الشاشات الجديدة هنا)
import '../screens/agent_dashboard_screen.dart';
import '../screens/quick_pos_screen.dart';
import '../screens/mikrotik_categories_screen.dart';
import '../screens/sub_agents_screen.dart'; 
import '../screens/agent_wallet_screen.dart'; 
import '../screens/advanced_statement_screen.dart'; 
import '../screens/marketing_offers_screen.dart'; // 👈 الشاشة الجديدة (التسويق)
import '../screens/analytics_reports_screen.dart'; // 👈 الشاشة الجديدة (التقارير)
import '../../auth/screens/sso_login_screen.dart';

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
  // متغيرات الحالة (State)
  bool _isBalanceHidden = false;
  String? _currentLocalImageUrl; 

  @override
  void initState() {
    super.initState();
    _currentLocalImageUrl = widget.profileImageUrl;
  }

  // آلية التنقل الحقيقية لفتح الشاشات
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // إغلاق القائمة الجانبية
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // رسالة قريباً للشاشات التي لم تبرمج بعد
  void _showComingSoonMessage(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('قريباً.. هذه الميزة قيد التطوير 🚀', textDirection: TextDirection.rtl),
        backgroundColor: Colors.blueGrey,
      )
    );
  }

  // ==========================================
  // نافذة إدارة الصورة الشخصية
  // ==========================================
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
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.blue.shade100, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  image: hasImage 
                      ? DecorationImage(image: NetworkImage(_currentLocalImageUrl!), fit: BoxFit.cover) 
                      : null,
                ),
                child: !hasImage ? const Icon(Icons.router, size: 80, color: Colors.blueGrey) : null,
              ),
              const SizedBox(height: 25),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم فتح المعرض لاختيار صورة جديدة.')));
                    },
                    icon: Icon(hasImage ? Icons.sync : Icons.add_photo_alternate, color: Colors.white, size: 18),
                    label: Text(hasImage ? 'تغيير' : 'إضافة صورة', style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                  ),
                  if (hasImage) 
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentLocalImageUrl = null; 
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الشعار بنجاح.'), backgroundColor: Colors.red));
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

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // القائمة الجانبية المدمجة (Header + Items)
            // ==========================================
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 1. الترويسة العلوية الفخمة
                  SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      color: Colors.transparent, 
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showProfileImageActionDialog(context),
                            child: Container(
                              width: 100, 
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withOpacity(0.1),
                                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                                image: hasImage 
                                    ? DecorationImage(image: NetworkImage(_currentLocalImageUrl!), fit: BoxFit.cover) 
                                    : null,
                              ),
                              child: !hasImage ? Icon(Icons.router, size: 50, color: Theme.of(context).primaryColor.withOpacity(0.7)) : null,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // البطاقة 1: اسم الوكيل
                          _buildGradientCard(
                            text: widget.agentName,
                            icon: Icons.store,
                            colors: [Colors.blue.shade800, Colors.blue.shade500],
                          ),

                          // البطاقة 2: رقم الهاتف
                          _buildGradientCard(
                            text: widget.phoneNumber,
                            icon: Icons.phone,
                            colors: [Colors.teal.shade800, Colors.teal.shade500],
                          ),

                          // البطاقة 3: الدور (وكيل)
                          _buildGradientCard(
                            text: widget.role,
                            icon: Icons.admin_panel_settings,
                            colors: [Colors.orange.shade800, Colors.orange.shade500],
                          ),

                          // البطاقة 4: المحفظة (مع ميزة الإخفاء)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isBalanceHidden = !_isBalanceHidden;
                              });
                            },
                            child: _buildGradientCard(
                              text: _isBalanceHidden ? 'المحفظة: ******' : 'المحفظة: ${widget.currentBalance.toStringAsFixed(0)} ريال',
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

                  // 2. أزرار الانتقال
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('عمليات البيع والشبكة', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'الرئيسية (غرفة القيادة)', Icons.dashboard, Colors.blue, const AgentDashboardScreen()),
                  _buildDrawerItem(context, 'المتجر السريع (الكاشير)', Icons.point_of_sale, Colors.green, const QuickPosScreen()),
                  _buildDrawerItem(context, 'إدارة الفئات والميكروتك', Icons.router, Colors.orange, const MikrotikCategoriesScreen()),
                  
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('الإدارة والتسويق', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'إدارة نقاط البيع (البقالات)', Icons.storefront, Colors.purple, const SubAgentsScreen()),
                  // 👇 تم فتح الباب لشاشة التسويق والعروض بنجاح!
                  _buildDrawerItem(context, 'التسويق والعروض', Icons.campaign, Colors.pinkAccent, const MarketingOffersScreen()),

                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('المالية والمحاسبة', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  _buildDrawerItem(context, 'محفظة الوكيل', Icons.account_balance_wallet, Colors.teal, const AgentWalletScreen()),
                  _buildDrawerItem(context, 'كشف الحساب المتقدم', Icons.receipt_long, Colors.cyan, const AdvancedStatementScreen()),
                  // 👇 تم فتح الباب لشاشة التقارير التحليلية بنجاح!
                  _buildDrawerItem(context, 'التقارير التحليلية', Icons.analytics, Colors.redAccent, const AnalyticsReportsScreen()),

                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('الإعدادات والدعم', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  // هؤلاء الشاشتين لا يزالان قيد التطوير فسنتركهم مع رسالة قريباً
                  _buildComingSoonItem(context, 'الدعم الفني الموحد', Icons.support_agent, Colors.indigo),
                  _buildComingSoonItem(context, 'إعدادات النظام الموسعة', Icons.settings, Colors.blueGrey),
                ],
              ),
            ),
            
            // ==========================================
            // 3. الفوتر (تسجيل الخروج ثابت في الأسفل)
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
          ],
        ),
      ),
    );
  }

  // ==========================================
  // أدوات مساعدة 
  // ==========================================

  // بناء البطاقات المتدرجة الأنيقة 
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

  // بناء زر التنقل العادي الذي يفتح الشاشات
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

  // بناء زر التنقل للأقسام غير المكتملة (يظهر رسالة قريباً)
  Widget _buildComingSoonItem(BuildContext context, String title, IconData icon, Color iconColor) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 11, color: Colors.grey),
      onTap: () => _showComingSoonMessage(context),
    );
  }
}
