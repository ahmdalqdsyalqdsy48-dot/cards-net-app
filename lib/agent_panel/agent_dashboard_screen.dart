import 'package:flutter/material.dart';
// استدعاء الهيدر الموحد الذي بنيناه سابقاً
import '../../core/widgets/custom_header.dart'; 

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  final String agentName = "شبكة الصقر للواي فاي";
  final double currentBalance = 125000.0;
  final int todaySales = 45;
  final int activePOS = 12;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        // 👇 هنا استخدمنا الهيدر الموحد الخاص بالنظام!
        appBar: const CustomHeader(title: 'لوحة تحكم الوكيل'), 
        drawer: _buildAgentDrawer(), 
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAlertBar(),
              const SizedBox(height: 15),
              _buildBalanceCard(),
              const SizedBox(height: 20),
              const Text("نظرة عامة (اليوم)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              _buildStatsRow(),
              const SizedBox(height: 25),
              const Text("الوصول السريع", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              const SizedBox(height: 15),
              _buildQuickActionsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // القائمة الجانبية للوكيل (بنفس تصميم قائمة المالك ولكن بخيارات مختلفة)
  // ==========================================
  Widget _buildAgentDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade800), // لون مميز للوكيل
            accountName: Text(agentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text("الرصيد: ${currentBalance.toStringAsFixed(0)} ريال"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.router, size: 40, color: Colors.blue),
            ),
          ),
          ListTile(leading: const Icon(Icons.dashboard, color: Colors.blue), title: const Text('الرئيسية'), onTap: () {}),
          ListTile(leading: const Icon(Icons.point_of_sale, color: Colors.green), title: const Text('المتجر السريع (الكاشير)'), onTap: () {}),
          ListTile(leading: const Icon(Icons.category, color: Colors.orange), title: const Text('إدارة الفئات والميكروتك'), onTap: () {}),
          ListTile(leading: const Icon(Icons.storefront, color: Colors.purple), title: const Text('نقاط البيع (البقالات)'), onTap: () {}),
          ListTile(leading: const Icon(Icons.account_balance_wallet, color: Colors.teal), title: const Text('المحفظة والمركز المالي'), onTap: () {}),
          ListTile(leading: const Icon(Icons.analytics, color: Colors.redAccent), title: const Text('التقارير والمبيعات'), onTap: () {}),
          const Divider(),
          ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text('الإعدادات والربط'), onTap: () {}),
        ],
      ),
    );
  }

  // ==========================================
  // شريط التنبيهات
  // ==========================================
  Widget _buildAlertBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 10),
          const Expanded(child: Text("تنبيه: كروت فئة 1000 ريال توشك على النفاذ.", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () {}, child: const Text("توليد الآن", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }

  // ==========================================
  // بطاقة الرصيد
  // ==========================================
  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("الرصيد التشغيلي المتاح", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 5),
          Text("${currentBalance.toStringAsFixed(0)} ريال", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ==========================================
  // الإحصائيات
  // ==========================================
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard("مبيعات اليوم", "$todaySales كرت", Icons.shopping_cart, Colors.green)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard("البقالات النشطة", "$activePOS نقطة", Icons.storefront, Colors.orange)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  // ==========================================
  // الإجراءات السريعة
  // ==========================================
  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      children: [
        _buildActionItem("بيع سريع", Icons.point_of_sale, Colors.blue, () {}),
        _buildActionItem("توليد كروت", Icons.autorenew, Colors.green, () {}),
        _buildActionItem("تغذية بقالة", Icons.account_balance_wallet, Colors.purple, () {}),
        _buildActionItem("إضافة فئة", Icons.add_circle_outline, Colors.orange, () {}),
        _buildActionItem("كشف حساب", Icons.receipt_long, Colors.teal, () {}),
        _buildActionItem("تذكرة دعم", Icons.support_agent, Colors.redAccent, () {}),
      ],
    );
  }

  Widget _buildActionItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 20, child: Icon(icon, color: color)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
