import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart'; 
import '../widgets/custom_agent_drawer.dart'; 
import 'mikrotik_categories_screen.dart';
import 'quick_pos_screen.dart'; 
import 'sub_agents_screen.dart';
import 'agent_wallet_screen.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  DateTimeRange? _selectedDateRange;

  void _play(String type) => context.read<UiProvider>().playSound(type);

  Future<void> _selectDateRange() async {
    _play('click');
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ?? DateTimeRange(start: DateTime.now(), end: DateTime.now()),
      firstDate: DateTime(2023), 
      lastDate: DateTime(2030),  
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _play('success');
    }
  }

  void _navigateTo(Widget screen) {
    _play('click');
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // حساب إحصائيات اليوم
    final today = DateTime.now();
    final agentSales = wallet.transactionsLedger.where((t) => 
      t['agentPhone'] == auth.activeUserPhone && 
      t['timestamp'] != null && 
      (t['timestamp'] as dynamic).toDate().day == today.day
    ).toList();

    double todayProfit = agentSales.fold(0, (sum, item) => sum + (item['profit'] ?? 0));
    int todayCards = agentSales.length;

    // تصفية الرسائل الإدارية
    final adminMessages = settings.targetedNews.where((n) => n['target'] == 'agent' || n['target'] == 'الكل').toList();

    return Scaffold(
      appBar: const CustomHeader(title: 'لوحة تحكم الوكيل'),
      drawer: CustomAgentDrawer(
        agentName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'وكيل معتمد',
        currentBalance: wallet.currentUserBalance,
      ), 
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 300));
            _play('success');
          },
          child: Column(
            children: [
              // شريط الرسائل الإدارية
              if (adminMessages.isNotEmpty)
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade800, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.campaign, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('إشعار من الإدارة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                            Text(adminMessages.last['text'], style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _play('click'); })
                    ],
                  ),
                ),

              // شريط الفلترة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.blue.shade800, 
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: Text(_selectedDateRange == null ? 'مبيعات اليوم' : 'من ${_selectedDateRange!.start.day} إلى ${_selectedDateRange!.end.day}'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue.shade800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: IconButton(icon: const Icon(Icons.print, color: Colors.white), onPressed: () => _play('click')),
                    )
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text("الإحصائيات المالية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    
                    GridView.count(
                      crossAxisCount: 2, 
                      shrinkWrap: true, 
                      physics: const NeverScrollableScrollPhysics(), 
                      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
                      children: [
                        _buildStatCard('رصيدك الحالي', '${wallet.currentUserBalance.toStringAsFixed(0)} ر.ي', Icons.account_balance_wallet, Colors.green, () => _navigateTo(const AgentWalletScreen())),
                        _buildStatCard('أرباح اليوم', '$todayProfit ر.ي', Icons.trending_up, Colors.blue, () {}),
                        _buildStatCard('كروت مباعة', '$todayCards كرت', Icons.sell, Colors.purple, () {}),
                        _buildStatCard('طلبات شحن', '2 طلب', Icons.notifications_active, Colors.orange, () => _navigateTo(const SubAgentsScreen()), hasAlert: true),
                      ],
                    ),

                    const SizedBox(height: 25),
                    const Text("إجراءات سريعة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 15),

                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 15, crossAxisSpacing: 15,
                      children: [
                        _buildActionItem("بيع سريع", Icons.point_of_sale, Colors.blue, () => _navigateTo(const QuickPosScreen())),
                        _buildActionItem("الفئات", Icons.category, Colors.teal, () => _navigateTo(const MikrotikCategoriesScreen())),
                        _buildActionItem("البقالات", Icons.storefront, Colors.orange, () => _navigateTo(const SubAgentsScreen())),
                        _buildActionItem("المحفظة", Icons.wallet, Colors.indigo, () => _navigateTo(const AgentWalletScreen())),
                        _buildActionItem("التقارير", Icons.analytics, Colors.redAccent, () => _play('click')),
                        _buildActionItem("الدعم", Icons.headset_mic, Colors.blueGrey, () => _play('click')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback onTap, {bool hasAlert = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (hasAlert) const Icon(Icons.circle, color: Colors.red, size: 10),
              ],
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
