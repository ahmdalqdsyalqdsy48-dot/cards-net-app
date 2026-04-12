import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// مكتبات الـ PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';

import 'financial_center_screen.dart';
import 'staff_support_screen.dart';
import 'reports_screen.dart';
import 'agent_management_screen.dart';
import 'sms_gateway_screen.dart';
import 'settings_screen.dart';
import 'banners_screen.dart'; // 👈 أضفنا استيراد شاشة الإعلانات

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  // ==========================================
  // دالة فتح التقويم وإرسال الفلتر للعقل المدبر 📅
  // ==========================================
  Future<void> _selectDateRange(SystemProvider provider) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: provider.dashboardDateRange ?? DateTimeRange(start: DateTime.now(), end: DateTime.now()),
      firstDate: DateTime(2023), 
      lastDate: DateTime(2030),  
      helpText: 'حدد فترة الفلترة (من - إلى)',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد الفلترة',
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );

    if (picked != null && picked != provider.dashboardDateRange) {
      provider.setDashboardDateRange(picked); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث الإحصائيات للفترة من ${_formatDate(picked.start)} إلى ${_formatDate(picked.end)} 📊', textDirection: TextDirection.rtl), backgroundColor: Colors.green)
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  // ==========================================
  // 📄 دالة إنشاء وتصدير الـ PDF الحقيقي
  // ==========================================
  Future<void> _generateAndPrintPDF(SystemProvider provider, String topAgent, int agentsDanger, double pendingTotal) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز تقرير الـ PDF... 📄', textDirection: TextDirection.rtl)));
    
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    String dateText = provider.dashboardDateRange == null 
        ? 'تقرير مبيعات اليوم' 
        : 'تقرير من: ${_formatDate(provider.dashboardDateRange!.start)} إلى ${_formatDate(provider.dashboardDateRange!.end)}';

    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('غرفة العمليات - نظام كروت نت', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text(dateText, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.center,
                data: <List<String>>[
                  ['البيان', 'القيمة'],
                  ['إجمالي المبيعات المحققة', '${provider.filteredSales.toStringAsFixed(0)} ريال'],
                  ['إجمالي الأرباح', '${provider.filteredProfit.toStringAsFixed(0)} ريال'],
                  ['طلبات الشحن المعلقة', '${provider.pendingRechargeRequests.length} طلبات (${pendingTotal.toStringAsFixed(0)} ريال)'],
                  ['وكلاء في مرحلة الخطر', '$agentsDanger وكلاء'],
                  ['الوكيل الأنشط بالفترة', topAgent],
                  ['إجمالي تذاكر الدعم المفتوحة', '${provider.openTicketsCount} تذاكر'],
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Text('تم إنشاء هذا التقرير تلقائياً بواسطة نظام Super Admin', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'KrootNet_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemProvider = Provider.of<SystemProvider>(context);
    
    final adminBalance = systemProvider.adminMainBalance;
    final userName = systemProvider.currentUserName;
    final String userPhone = systemProvider.currentUserPhone;

    final totalCards = systemProvider.totalSystemCards;
    final pendingRequests = systemProvider.pendingRechargeRequests;
    final pendingCount = pendingRequests.length;
    final double pendingTotal = pendingRequests.fold(0.0, (sum, req) => sum + ((req['amount'] ?? 0.0) as num).toDouble());

    final agentsInDanger = systemProvider.agentsList.where((agent) {
      double balance = ((agent['balance'] ?? 0.0) as num).toDouble();
      double dangerLimit = ((agent['dangerLimit'] ?? 0.0) as num).toDouble();
      return balance <= dangerLimit;
    }).length;

    final double todaySales = systemProvider.filteredSales; 
    final double todayProfit = systemProvider.filteredProfit;  
    final int openTicketsCount = systemProvider.openTicketsCount;    
    final int criticalTicketsCount = systemProvider.criticalTicketsCount; 
    final int smsBalance = systemProvider.smsBalance;        
    
    String topAgentName = 'لا يوجد وكلاء';
    if (systemProvider.agentsList.isNotEmpty) {
      try {
        final topAgent = systemProvider.agentsList.reduce((curr, next) {
          final currBalance = ((curr['balance'] ?? 0) as num).toDouble();
          final nextBalance = ((next['balance'] ?? 0) as num).toDouble();
          return currBalance > nextBalance ? curr : next;
        });
        topAgentName = topAgent['name'] ?? 'وكيل غير معروف';
      } catch (e) { topAgentName = 'غير محدد'; }
    }

    return Scaffold(
      appBar: const CustomHeader(title: 'غرفة العمليات المركزية'),
      
      drawer: CustomDrawer(
        userName: userName,
        phoneNumber: userPhone,
        role: systemProvider.hasPermission('الرئيسية (غرفة العمليات)') && adminBalance > 0 ? 'مالك النظام' : 'موظف مخصص',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ==========================================
            // شريط الفلترة (يظهر فقط لمن لديه صلاحية مالية أو تقارير)
            // ==========================================
            if (systemProvider.hasPermission('المركز المالي والمحافظ') || systemProvider.hasPermission('التقارير الشاملة'))
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
                      onPressed: () => _selectDateRange(systemProvider), 
                      icon: const Icon(Icons.calendar_month, color: Colors.blueAccent),
                      label: Text(
                        systemProvider.dashboardDateRange == null 
                            ? 'فلترة الإحصائيات (اليوم)' 
                            : 'من ${_formatDate(systemProvider.dashboardDateRange!.start)} إلى ${_formatDate(systemProvider.dashboardDateRange!.end)}',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis, 
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
                        _generateAndPrintPDF(systemProvider, topAgentName, agentsInDanger, pendingTotal);
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // ==========================================
            // شبكة البطاقات الذكية (تعتمد على الصلاحيات) 🔥
            // ==========================================
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, 
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1, 
                children: [
                  
                  // 1. بطاقة المبيعات
                  if (systemProvider.hasPermission('المركز المالي والمحافظ'))
                  _buildDashboardCard(
                    title: 'المبيعات (مفلترة)',
                    value: todaySales.toStringAsFixed(0),
                    subValue: '+ أرباح: ${todayProfit.toStringAsFixed(0)}',
                    icon: Icons.monetization_on,
                    color: Colors.green,
                    onTap: () => _navigateTo(const FinancialCenterScreen()),
                  ),
                  
                  // 2. بطاقة طلبات الشحن
                  if (systemProvider.hasPermission('المركز المالي والمحافظ'))
                  _buildDashboardCard(
                    title: 'طلبات شحن معلقة',
                    value: '$pendingCount طلبات',
                    subValue: pendingCount > 0 ? 'بإجمالي: ${pendingTotal.toStringAsFixed(0)} ريال' : 'لا توجد طلبات جديدة',
                    icon: Icons.download,
                    color: pendingCount > 0 ? Colors.redAccent : Colors.grey,
                    isAlert: pendingCount > 0,
                    onTap: () => _navigateTo(const FinancialCenterScreen()),
                  ),
                  
                  // 3. بطاقة رادار الخطر
                  if (systemProvider.hasPermission('إدارة الوكلاء الشاملة'))
                  _buildDashboardCard(
                    title: 'رادار الخطر',
                    value: '$agentsInDanger وكلاء',
                    subValue: agentsInDanger > 0 ? 'تجاوزوا حد الخطر المسموح!' : 'جميع الوكلاء في أمان',
                    icon: Icons.warning_amber_rounded,
                    color: agentsInDanger > 0 ? Colors.orange : Colors.grey,
                    isAlert: agentsInDanger > 0,
                    onTap: () => _navigateTo(const AgentManagementScreen()),
                  ),
                  
                  // 4. بطاقة تذاكر الدعم
                  if (systemProvider.hasPermission('إدارة الموظفين والدعم'))
                  _buildDashboardCard(
                    title: 'تذاكر الدعم',
                    value: '$openTicketsCount مفتوحة',
                    subValue: '$criticalTicketsCount منها أولوية قصوى',
                    icon: Icons.support_agent,
                    color: Colors.blue,
                    isAlert: criticalTicketsCount > 0, 
                    onTap: () => _navigateTo(const StaffSupportScreen()),
                  ),
                  
                  // 5. بطاقة المخزون
                  if (systemProvider.hasPermission('التقارير الشاملة'))
                  _buildDashboardCard(
                    title: 'إجمالي المخزون',
                    value: '$totalCards كرت',
                    subValue: 'كروت متوفرة بالنظام',
                    icon: Icons.inventory_2,
                    color: Colors.teal,
                    onTap: () => _navigateTo(const ReportsScreen()),
                  ),
                  
                  // 6. بطاقة الوكيل الأنشط
                  if (systemProvider.hasPermission('إدارة الوكلاء الشاملة'))
                  _buildDashboardCard(
                    title: 'الوكيل الأنشط',
                    value: topAgentName, 
                    subValue: 'الأعلى رصيداً حالياً', 
                    icon: Icons.star,
                    color: Colors.amber.shade600,
                    onTap: () => _navigateTo(const AgentManagementScreen()),
                  ),
                  
                  // 7. بطاقة الـ SMS
                  if (systemProvider.hasPermission('بوابة رسائل الـ SMS'))
                  _buildDashboardCard(
                    title: 'رصيد الـ SMS',
                    value: smsBalance.toString(),
                    subValue: 'رسالة متبقية',
                    icon: Icons.sms,
                    color: Colors.purple,
                    onTap: () => _navigateTo(const SmsGatewayScreen()),
                  ),

                  // 8. بطاقة الإعلانات
                  if (systemProvider.hasPermission('الإعلانات التسويقية'))
                  _buildDashboardCard(
                    title: 'الإعلانات والبنرات',
                    value: 'نشطة',
                    subValue: 'إدارة الحملات الحية',
                    icon: Icons.campaign,
                    color: Colors.pink,
                    onTap: () => _navigateTo(const BannersScreen()),
                  ),
                  
                  // 9. بطاقة الإعدادات (تظهر فقط للمالك أو من لديه صلاحية إعدادات)
                  if (systemProvider.hasPermission('الإعدادات العامة'))
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
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isAlert ? Colors.red : null), overflow: TextOverflow.ellipsis), 
            const SizedBox(height: 4),
            Text(subValue, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
