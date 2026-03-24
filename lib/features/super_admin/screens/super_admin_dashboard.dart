import 'package:flutter/material.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';
// 👈 استدعاء شاشة الإعدادات لكي يعمل زر النقل بنجاح!
import 'settings_screen.dart'; 

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  // متغير لحفظ النطاق الزمني المختار من التقويم
  DateTimeRange? _selectedDateRange;

  // ==========================================
  // دالة فتح التقويم الحقيقي (Date Range Picker) 📅
  // ==========================================
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ?? DateTimeRange(start: DateTime.now(), end: DateTime.now()),
      firstDate: DateTime(2023), // أقدم تاريخ ممكن
      lastDate: DateTime(2030),  // أقصى تاريخ ممكن
      helpText: 'حدد فترة الفلترة (من - إلى)',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد الفلترة',
      builder: (context, child) {
        // دعم الواجهة العربية والوضع الليلي للتقويم
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
        SnackBar(content: Text('تم تحديث الإحصائيات للفترة من ${_formatDate(picked.start)} إلى ${_formatDate(picked.end)} 📊'), backgroundColor: Colors.green)
      );
    }
  }

  // دالة مساعدة لتنسيق التاريخ بشكل جميل
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  // ==========================================
  // دالة الانتقال بين الشاشات 🚀
  // ==========================================
  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'غرفة العمليات المركزية'),
      drawer: const CustomDrawer(
        userName: 'مالك النظام',
        phoneNumber: '774578241',
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: 5,430,000 ريال',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // شريط الفلترة العلوية بالتقويم
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade900,
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
                            ? 'فلترة الإحصائيات (اليوم)' 
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
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      tooltip: 'تصدير تقرير فوري',
                      onPressed: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تصدير التقرير للفترة المحددة...')));
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // ==========================================
            // شبكة البطاقات الـ 8 (The 8 Dashboards)
            // ==========================================
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // عمودين
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1, // للتحكم بنسبة العرض إلى الارتفاع للبطاقات
                children: [
                  // 1. السيولة والأرباح
                  _buildDashboardCard(
                    title: 'مبيعات اليوم',
                    value: '1,250,000',
                    subValue: '+ أرباح: 45,000',
                    icon: Icons.monetization_on,
                    color: Colors.green,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ينقلك لقسم: المركز المالي'))),
                  ),
                  // 2. طلبات الشحن (تنبيه خطير)
                  _buildDashboardCard(
                    title: 'طلبات شحن معلقة',
                    value: '3 طلبات',
                    subValue: 'بإجمالي: 85,000 ريال',
                    icon: Icons.download,
                    color: Colors.redAccent,
                    isAlert: true, // 👈 جعلناها حمراء للتنبيه
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ينقلك لقسم: طلبات الشحن'))),
                  ),
                  // 3. رادار الخطر
                  _buildDashboardCard(
                    title: 'رادار الخطر',
                    value: '2 وكلاء',
                    subValue: 'محافظهم توشك على النفاذ',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ينقلك لقسم: أرصدة المحافظ'))),
                  ),
                  // 4. تذاكر الدعم الفني
                  _buildDashboardCard(
                    title: 'تذاكر الدعم',
                    value: '5 مفتوحة',
                    subValue: '2 منها أولوية قصوى',
                    icon: Icons.support_agent,
                    color: Colors.blue,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ينقلك لقسم: إدارة الموظفين والدعم'))),
                  ),
                  // 5. المخزون العام
                  _buildDashboardCard(
                    title: 'إجمالي المخزون',
                    value: '8.5 مليون',
                    subValue: 'إجمالي قيمة الكروت',
                    icon: Icons.inventory_2,
                    color: Colors.teal,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ينقلك لقسم: التقارير الشاملة'))),
                  ),
                  // 6. الوكيل الأنشط
                  _buildDashboardCard(
                    title: 'الوكيل الأنشط',
                    value: 'شبكة الصقر',
                    subValue: 'مبيعات: 450 كرت اليوم',
                    icon: Icons.star,
                    color: Colors.amber.shade600,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ينقلك لقسم: إدارة الوكلاء'))),
                  ),
                  // 7. رصيد SMS
                  _buildDashboardCard(
                    title: 'رصيد الـ SMS',
                    value: '4,500',
                    subValue: 'رسالة متبقية',
                    icon: Icons.sms,
                    color: Colors.purple,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ينقلك لقسم: بوابة رسائل SMS'))),
                  ),
                  // 8. الإعدادات العامة (الزر المطلوب إصلاحه!)
                  _buildDashboardCard(
                    title: 'إعدادات النظام',
                    value: 'تحكم كامل',
                    subValue: 'هوية، حماية، سياسات',
                    icon: Icons.settings,
                    color: Colors.blueGrey,
                    // 👈 الآن ينقلك فعلياً لشاشة الإعدادات العامة!
                    onTap: () => _navigateTo(const GlobalSettingsScreen()), 
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // أداة بناء بطاقات الرئيسية الاحترافية
  // ==========================================
  Widget _buildDashboardCard({
    required String title,
    required String value,
    required String subValue,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isAlert = false, // خاصية لتحويل البطاقة للون أحمر خفيف في حالات الخطر
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
                  const Icon(Icons.circle, color: Colors.red, size: 12), // نقطة حمراء تنبيهية
              ],
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isAlert ? Colors.red : null)), // اللون يتجاوب مع الوضع الليلي
            const SizedBox(height: 4),
            Text(subValue, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
