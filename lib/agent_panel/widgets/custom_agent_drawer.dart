import 'package:flutter/material.dart';

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
  // متغير للتحكم في إظهار أو إخفاء الرصيد (خصوصية الوكيل)
  bool _isBalanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // 1. الترويسة العلوية الغنية (Header) - البطاقات الملونة
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
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.router, size: 45, color: Colors.blueAccent),
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
                  // --- المجموعة الأولى: عمليات البيع والشبكة ---
                  _buildGradientTitle('عمليات البيع والشبكة', [Colors.blue.shade700, Colors.lightBlueAccent]),
                  _buildDrawerItem(title: 'الرئيسية (غرفة القيادة)', icon: Icons.dashboard, onTap: () {}),
                  _buildDrawerItem(title: 'المتجر السريع (الكاشير)', icon: Icons.point_of_sale, onTap: () {}),
                  _buildDrawerItem(title: 'إدارة الفئات والميكروتك', icon: Icons.router, onTap: () {}),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),

                  // --- المجموعة الثانية: الإدارة والتسويق ---
                  _buildGradientTitle('الإدارة والتسويق', [Colors.orange.shade700, Colors.amber]),
                  _buildDrawerItem(title: 'إدارة نقاط البيع (البقالات)', icon: Icons.storefront, onTap: () {}),
                  _buildDrawerItem(title: 'التسويق والعروض', icon: Icons.campaign, onTap: () {}),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),

                  // --- المجموعة الثالثة: المالية والمحاسبة ---
                  _buildGradientTitle('المالية والمحاسبة', [Colors.green.shade700, Colors.teal]),
                  _buildDrawerItem(title: 'محفظة الوكيل', icon: Icons.account_balance_wallet, onTap: () {}),
                  _buildDrawerItem(title: 'كشف الحساب المتقدم', icon: Icons.receipt_long, onTap: () {}),
                  _buildDrawerItem(title: 'التقارير التحليلية', icon: Icons.analytics, onTap: () {}),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),

                  // --- المجموعة الرابعة: الإعدادات والدعم ---
                  _buildGradientTitle('الإعدادات والدعم', [Colors.purple.shade700, Colors.deepPurpleAccent]),
                  _buildDrawerItem(title: 'الدعم الفني الموحد', icon: Icons.support_agent, onTap: () {}),
                  _buildDrawerItem(title: 'إعدادات النظام الموسعة', icon: Icons.settings, onTap: () {}),

                  const SizedBox(height: 20),
                  
                  // زر تسجيل الخروج
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () {},
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
  // أدوات مساعدة (Helpers) للحفاظ على نظافة الكود
  // ==========================================

  // 1. أداة بناء البطاقات الملونة في الترويسة
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

  // 2. أداة بناء العناوين ذات الألوان المتدرجة (Gradients)
  Widget _buildGradientTitle(String title, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 8, top: 8),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ),
    );
  }

  // 3. أداة بناء عناصر القائمة مع سهم التنقل (<)
  Widget _buildDrawerItem({required String title, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      // سهم التنقل يشير لليسار لأن اتجاه النص من اليمين لليسار (RTL)
      trailing: Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}
