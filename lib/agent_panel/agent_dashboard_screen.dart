import 'package:flutter/material.dart';
import '../../core/widgets/custom_header.dart'; // استدعاء الهيدر الموحد

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  // متغير لحفظ النطاق الزمني المختار من التقويم
  DateTimeRange? _selectedDateRange;

  // ==========================================
  // دالة فتح التقويم (مطابقة للوحة المالك) 📅
  // ==========================================
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

  // دالة الانتقال بين شاشات الوكيل
  void _navigateTo(String screenName) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('جاري الانتقال إلى: $screenName')));
    // سيتم استبدالها لاحقاً بـ Navigator.push
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'لوحة تحكم الوكيل'),
      drawer: _buildAgentDrawer(), // القائمة الجانبية المتطابقة بالشكل
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // 1. شريط الفلترة العلوية بالتقويم (مثل المالك تماماً)
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade800, // لون أزرق مميز للوكيل
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

            // ==========================================
            // 2. المنطقة القابلة للتمرير (البطاقات + الإجراءات السريعة)
            // ==========================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- شبكة البطاقات ---
                  GridView.count(
                    crossAxisCount: 2, 
                    shrinkWrap: true, // ضروري جداً لكي يعمل بداخل ListView
                    physics: const NeverScrollableScrollPhysics(), // منع التمرير الداخلي للشبكة
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1, 
                    children: [
                      _buildDashboardCard(
                        title: 'الرصيد المتاح',
                        value: '125,000 ريال',
                        subValue: '+ أرباح اليوم: 4,500',
                        icon: Icons.account_balance_wallet,
                        color: Colors.green,
                        onTap: () => _navigateTo('المركز المالي للوكيل'),
                      ),
                      _buildDashboardCard(
                        title: 'نواقص المخزون',
                        value: 'فئة 1000',
                        subValue: 'المتبقي 3 كروت فقط!',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                        isAlert: true,
                        onTap: () => _navigateTo('إدارة الميكروتك والفئات'),
                      ),
                      _buildDashboardCard(
                        title: 'مبيعات الشبكة',
                        value: '145 كرت',
                        subValue: 'مباشر + نقاط البيع',
                        icon: Icons.storefront,
                        color: Colors.blue,
                        onTap: () => _navigateTo('تقارير المبيعات'),
                      ),
                      _buildDashboardCard(
                        title: 'طلبات شحن واردة',
                        value: '2 طلبات',
                        subValue: 'من بقالة الأمانة والسعادة',
                        icon: Icons.notifications_active,
                        color: Colors.orange,
                        isAlert: true,
                        onTap: () => _navigateTo('طلبات نقاط البيع'),
                      ),
                      _buildDashboardCard(
                        title: 'المتجر السريع',
                        value: 'كاشير',
                        subValue: 'بيع مباشر للزبائن',
                        icon: Icons.point_of_sale,
                        color: Colors.teal,
                        onTap: () => _navigateTo('شاشة الكاشير'),
                      ),
                      _buildDashboardCard(
                        title: 'البقالات النشطة',
                        value: '12 بقالة',
                        subValue: 'إجمالي الرصيد لديهم: 85 ألف',
                        icon: Icons.people_alt,
                        color: Colors.purple,
                        onTap: () => _navigateTo('إدارة نقاط البيع'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // --- قسم الإجراءات السريعة ---
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

  // ==========================================
  // تصميم البطاقة المنسوخ 100% من كود المالك
  // ==========================================
  Widget _buildDashboardCard({
    required String title,
    required String value,
    required String subValue,
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
            const SizedBox(height: 4),
            Text(subValue, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // الإجراءات السريعة (Quick Actions)
  // ==========================================
  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true, // ضروري هنا أيضاً
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      children: [
        _buildActionItem("بيع سريع", Icons.point_of_sale, Colors.blue, () => _navigateTo('شاشة الكاشير')),
        _buildActionItem("توليد كروت", Icons.autorenew, Colors.green, () => _navigateTo('إدارة الميكروتك والفئات')),
        _buildActionItem("تغذية بقالة", Icons.account_balance_wallet, Colors.purple, () => _navigateTo('إدارة نقاط البيع')),
        _buildActionItem("إضافة فئة", Icons.add_circle_outline, Colors.orange, () => _navigateTo('إدارة الميكروتك والفئات')),
        _buildActionItem("كشف حساب", Icons.receipt_long, Colors.teal, () => _navigateTo('المركز المالي للوكيل')),
        _buildActionItem("تذكرة دعم", Icons.support_agent, Colors.redAccent, () {}),
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

  // ==========================================
  // القائمة الجانبية (مخصصة للوكيل بنفس شكل المالك)
  // ==========================================
  Widget _buildAgentDrawer() {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.shade800),
              accountName: const Text('شبكة الصقر للواي فاي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: const Text('وكيل معتمد | الرصيد: 125,000 ريال'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.router, size: 40, color: Colors.blue),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(leading: const Icon(Icons.dashboard, color: Colors.blue), title: const Text('الرئيسية'), onTap: () {}),
                  ListTile(leading: const Icon(Icons.point_of_sale, color: Colors.green), title: const Text('المتجر السريع (الكاشير)'), onTap: () {}),
                  ListTile(leading: const Icon(Icons.category, color: Colors.orange), title: const Text('إدارة الفئات والميكروتك'), onTap: () {}),
                  ListTile(leading: const Icon(Icons.storefront, color: Colors.purple), title: const Text('نقاط البيع (البقالات)'), onTap: () {}),
                  ListTile(leading: const Icon(Icons.account_balance_wallet, color: Colors.teal), title: const Text('المركز المالي للوكيل'), onTap: () {}),
                  ListTile(leading: const Icon(Icons.analytics, color: Colors.redAccent), title: const Text('التقارير والمبيعات'), onTap: () {}),
                  const Divider(),
                  ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text('إعدادات الربط والشبكة'), onTap: () {}),
                  ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('تسجيل الخروج'), onTap: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
