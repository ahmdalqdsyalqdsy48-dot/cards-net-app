import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

import 'financial_center_screen.dart';
import 'staff_support_screen.dart';
import 'reports_screen.dart';
import 'agent_management_screen.dart';
import 'sms_gateway_screen.dart';
import 'settings_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  DateTimeRange? _selectedDateRange;

  // ==========================================
  // دالة فتح التقويم الحقيقي 📅
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
        SnackBar(content: Text('تم تحديث الإحصائيات للفترة من ${_formatDate(picked.start)} إلى ${_formatDate(picked.end)} 📊', textDirection: TextDirection.rtl), backgroundColor: Colors.green)
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ==========================================
    // استدعاء البيانات الحية من العقل المدبر 🧠
    // ==========================================
    final systemProvider = Provider.of<SystemProvider>(context);
    
    // بيانات المالك للقائمة الجانبية
    final adminBalance = systemProvider.adminMainBalance;
    final userName = systemProvider.currentUserName;
    final userPhone = systemProvider.currentUserPhone;

    // حسابات البطاقات الديناميكية
    final totalCards = systemProvider.totalSystemCards;
    
    // حساب طلبات الشحن
    final pendingRequests = systemProvider.pendingRechargeRequests;
    final pendingCount = pendingRequests.length;
    final double pendingTotal = pendingRequests.fold(0.0, (sum, req) => sum + ((req['amount'] ?? 0.0) as num).toDouble());

    // حساب الوكلاء في خطر (الرصيد أقل من أو يساوي حد الخطر)
    final agentsInDanger = systemProvider.agentsList.where((agent) {
      double balance = ((agent['balance'] ?? 0.0) as num).toDouble();
      double dangerLimit = ((agent['dangerLimit'] ?? 0.0) as num).toDouble();
      return balance <= dangerLimit;
    }).length;

    return Scaffold(
      appBar: const CustomHeader(title: 'غرفة العمليات المركزية'),
      
      // 👈 تم ربط القائمة الجانبية ببيانات المالك الحقيقية
      drawer: CustomDrawer(
        userName: userName,
        phoneNumber: userPhone,
        role: 'مالك النظام (Super Admin)',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
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
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تصدير التقرير للفترة المحددة... 📄', textDirection: TextDirection.rtl)));
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // ==========================================
            // شبكة البطاقات (تم دمج الأرقام الحية) 🔥
            // ==========================================
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, 
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1, 
                children: [
                  _buildDashboardCard(
                    title: 'مبيعات اليوم',
                    value: '1,250,000', // ثابت مؤقتاً
                    subValue: '+ أرباح: 45,000',
                    icon: Icons.monetization_on,
                    color: Colors.green,
                    onTap: () => _navigateTo(const FinancialCenterScreen()),
                  ),
                  
                  // 👈 بطاقة طلبات الشحن الديناميكية
                  _buildDashboardCard(
                    title: 'طلبات شحن معلقة',
                    value: '$pendingCount طلبات',
                    subValue: pendingCount > 0 ? 'بإجمالي: ${pendingTotal.toStringAsFixed(0)} ريال' : 'لا توجد طلبات جديدة',
                    icon: Icons.download,
                    color: pendingCount > 0 ? Colors.redAccent : Colors.grey,
                    isAlert: pendingCount > 0,
                    onTap: () => _navigateTo(const FinancialCenterScreen()),
                  ),
                  
                  // 👈 بطاقة رادار الخطر الديناميكية
                  _buildDashboardCard(
                    title: 'رادار الخطر',
                    value: '$agentsInDanger وكلاء',
                    subValue: agentsInDanger > 0 ? 'تجاوزوا حد الخطر المسموح!' : 'جميع الوكلاء في أمان',
                    icon: Icons.warning_amber_rounded,
                    color: agentsInDanger > 0 ? Colors.orange : Colors.grey,
                    isAlert: agentsInDanger > 0,
                    onTap: () => _navigateTo(const AgentManagementScreen()),
                  ),
                  
                  _buildDashboardCard(
                    title: 'تذاكر الدعم',
                    value: '5 مفتوحة', // ثابت مؤقتاً
                    subValue: '2 منها أولوية قصوى',
                    icon: Icons.support_agent,
                    color: Colors.blue,
                    onTap: () => _navigateTo(const StaffSupportScreen()),
                  ),
                  
                  // 👈 بطاقة المخزون الكلي الديناميكية
                  _buildDashboardCard(
                    title: 'إجمالي المخزون',
                    value: '$totalCards كرت',
                    subValue: 'كروت متوفرة بالنظام',
                    icon: Icons.inventory_2,
                    color: Colors.teal,
                    onTap: () => _navigateTo(const ReportsScreen()),
                  ),
                  
                  _buildDashboardCard(
                    title: 'الوكيل الأنشط',
                    value: 'شبكة الصقر', // ثابت مؤقتاً
                    subValue: 'مبيعات: 450 كرت اليوم',
                    icon: Icons.star,
                    color: Colors.amber.shade600,
                    onTap: () => _navigateTo(const AgentManagementScreen()),
                  ),
                  
                  _buildDashboardCard(
                    title: 'رصيد الـ SMS',
                    value: '4,500', // ثابت مؤقتاً
                    subValue: 'رسالة متبقية',
                    icon: Icons.sms,
                    color: Colors.purple,
                    onTap: () => _navigateTo(const SmsGatewayScreen()),
                  ),
                  
                  _buildDashboardCard(
                    title: 'إعدادات النظام',
                    value: 'تحكم كامل',
                    subValue: 'هوية، حماية، سياسات',
                    icon: Icons.settings,
                    color: Colors.blueGrey,
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
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isAlert ? Colors.red : null)), 
            const SizedBox(height: 4),
            Text(subValue, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
