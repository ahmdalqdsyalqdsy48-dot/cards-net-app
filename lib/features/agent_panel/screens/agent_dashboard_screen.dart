import 'package:flutter/material.dart';
import '../../../core/widgets/custom_header.dart'; 
import '../widgets/custom_agent_drawer.dart'; 
import 'mikrotik_categories_screen.dart';
import 'quick_pos_screen.dart'; 

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  DateTimeRange? _selectedDateRange;

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ?? DateTimeRange(start: DateTime.now(), end: DateTime.now()),
      firstDate: DateTime(2023), 
      lastDate: DateTime(2030),  
      helpText: 'حدد فترة الفلترة (من - إلى)',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد الفلترة',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث إحصائيات شبكتك للفترة من ${_formatDate(picked.start)} إلى ${_formatDate(picked.end)} 📊'), backgroundColor: Colors.green)
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  void _navigateTo(String screenName) {
    if (screenName == 'إدارة الميكروتك والفئات') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const MikrotikCategoriesScreen()));
    } else if (screenName == 'شاشة الكاشير') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const QuickPosScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('قريباً: $screenName 🚀')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'لوحة تحكم الوكيل'),
      drawer: const CustomAgentDrawer(
        agentName: 'شبكة الصقر للواي فاي',
        phoneNumber: '777777777',
        role: 'وكيل معتمد (Agent)',
        currentBalance: 125000.0,
      ), 
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // 1. شريط الفلترة العلوية
            // ==========================================
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
                      icon: const Icon(Icons.calendar_month, color: Colors.blueAccent),
                      label: Text(
                        _selectedDateRange == null 
                            ? 'فلترة مبيعاتي (اليوم)' 
                            : 'من ${_formatDate(_selectedDateRange!.start)} إلى ${_formatDate(_selectedDateRange!.end)}',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                    child: IconButton(
                      icon: const Icon(Icons.receipt_long, color: Colors.white),
                      tooltip: 'كشف حساب سريع',
                      onPressed: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري استخراج كشف الحساب...')));
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ==========================================
                  // 2. بطاقات الإحصائيات (مخصصة للتقارير فقط)
                  // ==========================================
                  const Text("إحصائيات الشبكة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2, 
                    shrinkWrap: true, 
                    physics: const NeverScrollableScrollPhysics(), 
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2, // تغيير الحجم ليكون مناسباً أكثر
                    children: [
                      _buildDashboardCard(
                        title: 'الرصيد المتاح',
                        value: '125,000 ريال',
                        icon: Icons.account_balance_wallet,
                        color: Colors.green,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تفاصيل المركز المالي'))),
                      ),
                      _buildDashboardCard(
                        title: 'أرباح اليوم',
                        value: '4,500 ريال',
                        icon: Icons.trending_up,
                        color: Colors.blue,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تقرير الأرباح اليومية'))),
                      ),
                      _buildDashboardCard(
                        title: 'كروت مباعة (اليوم)',
                        value: '145 كرت',
                        icon: Icons.sell,
                        color: Colors.purple,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجل المبيعات المباشرة'))),
                      ),
                      _buildDashboardCard(
                        title: 'طلبات شحن واردة',
                        value: '2 طلبات جديدة',
                        icon: Icons.notifications_active,
                        color: Colors.orange,
                        isAlert: true,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجل طلبات البقالات'))),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // ==========================================
                  // 3. الإجراءات السريعة (مخصصة للعمليات)
                  // ==========================================
                  const Text("إجراءات سريعة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
                  const SizedBox(height: 15),
                  _buildQuickActionsGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isAlert = false, 
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAlert 
              ? (isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50) 
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isAlert ? Colors.red.shade300 : color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  radius: 18,
                  child: Icon(icon, color: color, size: 20),
                ),
                if (isAlert) 
                  const Icon(Icons.circle, color: Colors.red, size: 12), 
              ],
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isAlert ? Colors.red : null)), 
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      children: [
        _buildActionItem("بيع سريع", Icons.point_of_sale, Colors.blue, () => _navigateTo('شاشة الكاشير')),
        _buildActionItem("توليد كروت", Icons.autorenew, Colors.green, () => _navigateTo('إدارة الميكروتك والفئات')),
        _buildActionItem("تغذية بقالة", Icons.account_balance_wallet, Colors.purple, () => _navigateTo('تغذية بقالة')),
        _buildActionItem("تسديد دين", Icons.money_off, Colors.red, () => _navigateTo('تسديد دين')),
        _buildActionItem("نواقص المخزون", Icons.warning_amber_rounded, Colors.orange, () => _navigateTo('إدارة الميكروتك والفئات')),
        _buildActionItem("تذكرة دعم", Icons.support_agent, Colors.indigo, () => _navigateTo('تذكرة دعم')),
      ],
    );
  }

  Widget _buildActionItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
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
