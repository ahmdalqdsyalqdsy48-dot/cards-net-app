import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/providers/theme_provider.dart'; // 🆕 استدعاء ThemeProvider

import 'financial_center_screen.dart';
import 'staff_support_screen.dart';
import 'reports_screen.dart';
import 'agent_management_screen.dart';
import 'sms_gateway_screen.dart';
import 'settings_screen.dart';
import 'banners_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {

  Future<void> _selectDateRange(SystemProvider provider, UiProvider uiProvider) async {
    uiProvider.playSound('click');
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: provider.dashboardDateRange ?? DateTimeRange(start: DateTime.now(), end: DateTime.now()),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'حدد فترة الفلترة (من - إلى)',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد الفلترة',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );

    if (picked != null && picked != provider.dashboardDateRange) {
      provider.setDashboardDateRange(picked);
      uiProvider.playSound('success');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث الإحصائيات للفترة من ${_formatDate(picked.start)} إلى ${_formatDate(picked.end)} 📊', textDirection: TextDirection.rtl), backgroundColor: Colors.green)
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  void _navigateTo(Widget screen, UiProvider uiProvider) {
    uiProvider.playSound('click');
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _generateAndPrintPDF(SystemProvider provider, UiProvider uiProvider, String topAgent, int agentsDanger, double pendingTotal) async {
    uiProvider.playSound('click');
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
    uiProvider.playSound('success');
  }

  void _showPendingRequestsModal(BuildContext context, List<QueryDocumentSnapshot> requests, UiProvider uiProvider) {
    uiProvider.playSound('click');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              const Text('طلبات شحن الأرصدة المعلقة 💸', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: requests.isEmpty 
                  ? const Center(child: Text('لا توجد طلبات معلقة حالياً', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        var req = requests[index].data() as Map<String, dynamic>;
                        String docId = requests[index].id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.downloading, color: Colors.white)),
                            title: Text('طلب من: ${req['agentName'] ?? req['agentPhone']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('المبلغ المطلوب: ${req['amount']} ريال\nطريقة الدفع: ${req['paymentMethod'] ?? 'غير محدد'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _handleRequest(docId, req, true, uiProvider)),
                                IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _handleRequest(docId, req, false, uiProvider)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRequest(String docId, Map<String, dynamic> reqData, bool isApprove, UiProvider uiProvider) async {
    Navigator.pop(context);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      String agentPhone = reqData['agentPhone'];
      double amount = (reqData['amount'] as num).toDouble();

      DocumentReference reqRef = FirebaseFirestore.instance.collection('recharge_requests').doc(docId);
      batch.update(reqRef, {'status': isApprove ? 'approved' : 'rejected', 'processedAt': FieldValue.serverTimestamp()});

      if (isApprove) {
        DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(agentPhone);
        batch.update(userRef, {'balance': FieldValue.increment(amount)});

        DocumentReference notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'targetUserId': agentPhone,
          'title': 'تم شحن رصيدك بنجاح! 🎉',
          'body': 'تمت الموافقة على طلبك وتمت إضافة مبلغ $amount ريال إلى محفظتك.',
          'type': 'success',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        uiProvider.playSound('success');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الموافقة وإضافة الرصيد للوكيل بنجاح!'), backgroundColor: Colors.green));
      } else {
        DocumentReference notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'targetUserId': agentPhone,
          'title': 'عذراً، تم رفض طلب الشحن ❌',
          'body': 'تم رفض طلب الشحن الخاص بك بقيمة $amount ريال، يرجى مراجعة الإدارة.',
          'type': 'warning',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        uiProvider.playSound('error');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب.'), backgroundColor: Colors.red));
      }

      await batch.commit();
    } catch (e) {
      uiProvider.playSound('error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context); // 🆕
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor; // 🆕 اللون الديناميكي
    
    final systemProvider = Provider.of<SystemProvider>(context);
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    
    final adminBalance = systemProvider.adminMainBalance;
    final userName = systemProvider.currentUserName;
    final String userPhone = systemProvider.currentUserPhone;

    final totalCards = systemProvider.totalSystemCards;
    final double todaySales = systemProvider.filteredSales; 
    final double todayProfit = systemProvider.filteredProfit;  
    final int openTicketsCount = systemProvider.openTicketsCount;    
    final int criticalTicketsCount = systemProvider.criticalTicketsCount; 
    final int smsBalance = systemProvider.smsBalance;        
    
    final agentsInDanger = systemProvider.agentsList.where((agent) {
      double balance = ((agent['balance'] ?? 0.0) as num).toDouble();
      double dangerLimit = ((agent['dangerLimit'] ?? 0.0) as num).toDouble();
      return balance <= dangerLimit;
    }).length;

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // 🆕 خلفية ديناميكية
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
            // شريط الفلترة (يستخدم اللون الأساسي الآن)
            if (systemProvider.hasPermission('المركز المالي والمحافظ') || systemProvider.hasPermission('التقارير الشاملة'))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? primaryColor.withOpacity(0.4).withAlpha(100) : primaryColor.withOpacity(0.8), // 🆕 لون ديناميكي
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _selectDateRange(systemProvider, uiProvider), 
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
                        _generateAndPrintPDF(systemProvider, uiProvider, topAgentName, agentsInDanger, 0);
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // شبكة البطاقات الذكية
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, 
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1, 
                children: [
                  
                  if (systemProvider.hasPermission('المركز المالي والمحافظ'))
                  _buildDashboardCard(
                    title: 'المبيعات (مفلترة)',
                    value: todaySales.toStringAsFixed(0),
                    subValue: '+ أرباح: ${todayProfit.toStringAsFixed(0)}',
                    icon: Icons.monetization_on,
                    color: Colors.green,
                    onTap: () => _navigateTo(const FinancialCenterScreen(), uiProvider),
                  ),
                  
                  if (systemProvider.hasPermission('المركز المالي والمحافظ'))
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('recharge_requests').where('status', isEqualTo: 'pending').snapshots(),
                    builder: (context, snapshot) {
                      int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      double pendingTotal = 0;
                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          pendingTotal += ((doc.data() as Map<String, dynamic>)['amount'] ?? 0).toDouble();
                        }
                      }
                      return _buildDashboardCard(
                        title: 'طلبات شحن معلقة',
                        value: '$pendingCount طلبات',
                        subValue: pendingCount > 0 ? 'بإجمالي: ${pendingTotal.toStringAsFixed(0)} ريال' : 'لا توجد طلبات جديدة',
                        icon: Icons.download,
                        color: pendingCount > 0 ? Colors.redAccent : Colors.grey,
                        isAlert: pendingCount > 0,
                        onTap: () {
                          if (pendingCount > 0) {
                            _showPendingRequestsModal(context, snapshot.data!.docs, uiProvider);
                          } else {
                            uiProvider.playSound('click');
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد طلبات معلقة حالياً')));
                          }
                        },
                      );
                    }
                  ),
                  
                  if (systemProvider.hasPermission('إدارة الوكلاء الشاملة'))
                  _buildDashboardCard(
                    title: 'رادار الخطر',
                    value: '$agentsInDanger وكلاء',
                    subValue: agentsInDanger > 0 ? 'تجاوزوا حد الخطر المسموح!' : 'جميع الوكلاء في أمان',
                    icon: Icons.warning_amber_rounded,
                    color: agentsInDanger > 0 ? Colors.orange : Colors.grey,
                    isAlert: agentsInDanger > 0,
                    onTap: () => _navigateTo(const AgentManagementScreen(), uiProvider),
                  ),
                  
                  if (systemProvider.hasPermission('إدارة الموظفين والدعم'))
                  _buildDashboardCard(
                    title: 'تذاكر الدعم',
                    value: '$openTicketsCount مفتوحة',
                    subValue: '$criticalTicketsCount منها أولوية قصوى',
                    icon: Icons.support_agent,
                    color: Colors.blue,
                    isAlert: criticalTicketsCount > 0, 
                    onTap: () => _navigateTo(const StaffSupportScreen(), uiProvider),
                  ),
                  
                  if (systemProvider.hasPermission('التقارير الشاملة'))
                  _buildDashboardCard(
                    title: 'إجمالي المخزون',
                    value: '$totalCards كرت',
                    subValue: 'كروت متوفرة بالنظام',
                    icon: Icons.inventory_2,
                    color: Colors.teal,
                    onTap: () => _navigateTo(const ReportsScreen(), uiProvider),
                  ),
                  
                  if (systemProvider.hasPermission('إدارة الوكلاء الشاملة'))
                  _buildDashboardCard(
                    title: 'الوكيل الأنشط',
                    value: topAgentName, 
                    subValue: 'الأعلى رصيداً حالياً', 
                    icon: Icons.star,
                    color: Colors.amber.shade600,
                    onTap: () => _navigateTo(const AgentManagementScreen(), uiProvider),
                  ),
                  
                  if (systemProvider.hasPermission('بوابة رسائل الـ SMS'))
                  _buildDashboardCard(
                    title: 'رصيد الـ SMS',
                    value: smsBalance.toString(),
                    subValue: 'رسالة متبقية',
                    icon: Icons.sms,
                    color: Colors.purple,
                    onTap: () => _navigateTo(const SmsGatewayScreen(), uiProvider),
                  ),

                  if (systemProvider.hasPermission('الإعلانات التسويقية'))
                  _buildDashboardCard(
                    title: 'الإعلانات والبنرات',
                    value: 'نشطة',
                    subValue: 'إدارة الحملات الحية',
                    icon: Icons.campaign,
                    color: Colors.pink,
                    onTap: () => _navigateTo(const BannersScreen(), uiProvider),
                  ),
                  
                  if (systemProvider.hasPermission('الإعدادات العامة'))
                  _buildDashboardCard(
                    title: 'إعدادات النظام',
                    value: 'تحكم كامل',
                    subValue: 'هوية، حماية، سياسات',
                    icon: Icons.settings,
                    color: Colors.blueGrey,
                    onTap: () => _navigateTo(const GlobalSettingsScreen(), uiProvider), 
                  ),
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
              : Theme.of(context).cardColor, // 🆕 لون ديناميكي للبطاقات
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
