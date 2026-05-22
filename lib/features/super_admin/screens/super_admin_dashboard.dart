import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_drawer.dart';
import '../../../core/widgets/custom_header.dart';
import '../../../core/providers/theme_provider.dart';

import 'financial_center_screen.dart';
import 'staff_support_screen.dart';
import 'reports_screen.dart';
import 'agent_management_screen.dart';
import 'sms_gateway_screen.dart';
import 'settings_screen.dart';
import 'banners_screen.dart';
import 'advanced_reset_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  // تاريخي الفلترة (منفصلان)
  DateTime? _startDate;
  DateTime? _endDate;

  // مفتاح التجديد (RefreshIndicator)
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  // ============ دوال التاريخ ============
  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'اختر تاريخ البداية',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
      _updateDashboardRange();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'اختر تاريخ النهاية',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
      _updateDashboardRange();
    }
  }

  void _updateDashboardRange() {
    final wallet = context.read<WalletProvider>();
    if (_startDate != null && _endDate != null) {
      wallet.setDashboardDateRange(DateTimeRange(start: _startDate!, end: _endDate!));
    } else {
      wallet.setDashboardDateRange(null);
    }
  }

  void _resetDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    context.read<WalletProvider>().setDashboardDateRange(null);
    context.read<UiProvider>().playSound('click');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إعادة التعيين إلى إحصائيات اليوم 📅', textDirection: TextDirection.rtl), backgroundColor: Colors.green),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  // ============ التنقل والطباعة ============
  void _navigateTo(Widget screen) {
    context.read<UiProvider>().playSound('click');
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _generateAndPrintPDF(WalletProvider wallet, UiProvider uiProvider, String topAgent, int agentsDanger, double pendingTotal) async {
    uiProvider.playSound('click');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز تقرير الـ PDF... 📄', textDirection: TextDirection.rtl)));
    
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    String dateText = (wallet.dashboardDateRange == null) 
        ? 'تقرير مبيعات اليوم' 
        : 'تقرير من: ${_formatDate(wallet.dashboardDateRange!.start)} إلى ${_formatDate(wallet.dashboardDateRange!.end)}';

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
                  ['إجمالي المبيعات المحققة', '${wallet.filteredSales.toStringAsFixed(0)} ريال'],
                  ['إجمالي الأرباح', '${wallet.filteredProfit.toStringAsFixed(0)} ريال'],
                  ['طلبات الشحن المعلقة', '${wallet.pendingRechargeRequests.length} طلبات (${pendingTotal.toStringAsFixed(0)} ريال)'],
                  ['وكلاء في مرحلة الخطر', '$agentsDanger وكلاء'],
                  ['الوكيل الأنشط بالفترة', topAgent],
                  ['إجمالي تذاكر الدعم المفتوحة', '${wallet.openTicketsCount} تذاكر'],
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

  // ============ معالجة طلبات الشحن ============
  void _showPendingRequestsModal(BuildContext context, List<QueryDocumentSnapshot> requests) {
    final uiProvider = context.read<UiProvider>();
    uiProvider.playSound('click');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
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
                                IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _handleRequest(docId, req, true)),
                                IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _handleRequest(docId, req, false)),
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

  Future<void> _handleRequest(String docId, Map<String, dynamic> reqData, bool isApprove) async {
    Navigator.pop(context);
    final uiProvider = context.read<UiProvider>();
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

  // ============ البناء الرئيسي ============
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final uiProvider = context.read<UiProvider>();
    
    final adminBalance = settings.adminMainBalance;   // سيتم إضافتها إلى SettingsProvider
    final userName = wallet.currentUserName;
    final String userPhone = auth.activeUserPhone ?? '';
    final totalCards = settings.totalSystemCards;     // سيتم إضافتها إلى SettingsProvider
    final double todaySales = wallet.filteredSales;
    final double todayProfit = wallet.filteredProfit;
    final int openTicketsCount = wallet.openTicketsCount;
    final int criticalTicketsCount = wallet.criticalTicketsCount;
    final int smsBalance = settings.smsBalance;
    
    final agentsInDanger = wallet.agentsList.where((agent) {
      double balance = ((agent['balance'] ?? 0.0) as num).toDouble();
      double dangerLimit = ((agent['dangerLimit'] ?? 0.0) as num).toDouble();
      return balance <= dangerLimit;
    }).length;

    String topAgentName = 'لا يوجد وكلاء';
    if (wallet.agentsList.isNotEmpty) {
      try {
        final topAgent = wallet.agentsList.reduce((curr, next) {
          final currBalance = ((curr['balance'] ?? 0) as num).toDouble();
          final nextBalance = ((next['balance'] ?? 0) as num).toDouble();
          return currBalance > nextBalance ? curr : next;
        });
        topAgentName = topAgent['name'] ?? 'وكيل غير معروف';
      } catch (e) { topAgentName = 'غير محدد'; }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: CustomDrawer(
        userName: userName,
        phoneNumber: userPhone,
        role: auth.hasPermission('الرئيسية (غرفة العمليات)') && adminBalance > 0 ? 'مالك النظام' : 'موظف مخصص',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: () async {
          // تحديث واجهة المستخدم (البيانات حية من المزودات)
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          slivers: [
            // شريط علوي متحرك (يختفي عند التمرير لأسفل)
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              title: const Text('غرفة العمليات المركزية', style: TextStyle(color: Colors.white)),
              backgroundColor: primaryColor,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                // زر إعادة ضبط الفلترة
                if (_startDate != null || _endDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    tooltip: 'إعادة تعيين الفلترة',
                    onPressed: _resetDateFilter,
                  ),
              ],
            ),

            // شريط اختيار التواريخ (نافذتين منفصلتين)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? primaryColor.withOpacity(0.4) : primaryColor.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // زر تاريخ البداية
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () { _pickStartDate(); },
                            icon: const Icon(Icons.date_range, color: Colors.blueAccent),
                            label: Text(
                              _startDate == null ? 'بداية الفترة' : _formatDate(_startDate!),
                              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // زر تاريخ النهاية
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () { _pickEndDate(); },
                            icon: const Icon(Icons.date_range, color: Colors.orangeAccent),
                            label: Text(
                              _endDate == null ? 'نهاية الفترة' : _formatDate(_endDate!),
                              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // زر التقرير PDF
                        Container(
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                          child: IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                            tooltip: 'تصدير تقرير فوري',
                            onPressed: () {
                              _generateAndPrintPDF(wallet, uiProvider, topAgentName, agentsInDanger, 0);
                            },
                          ),
                        ),
                      ],
                    ),
                    // عرض حالة الفلترة الحالية
                    if (_startDate != null || _endDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'الفلترة: ${_startDate != null ? _formatDate(_startDate!) : "أول السنة"} - ${_endDate != null ? _formatDate(_endDate!) : "اليوم"}',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // شبكة البطاقات
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildListDelegate([
                  if (auth.hasPermission('المركز المالي والمحافظ'))
                    _buildDashboardCard(
                      title: 'المبيعات (مفلترة)',
                      value: todaySales.toStringAsFixed(0),
                      subValue: '+ أرباح: ${todayProfit.toStringAsFixed(0)}',
                      icon: Icons.monetization_on,
                      color: Colors.green,
                      onTap: () => _navigateTo(const FinancialCenterScreen()),
                    ),
                  
                  if (auth.hasPermission('المركز المالي والمحافظ'))
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
                              _showPendingRequestsModal(context, snapshot.data!.docs);
                            } else {
                              uiProvider.playSound('click');
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد طلبات معلقة حالياً')));
                            }
                          },
                        );
                      }
                    ),
                  
                  if (auth.hasPermission('إدارة الوكلاء الشاملة'))
                    _buildDashboardCard(
                      title: 'رادار الخطر',
                      value: '$agentsInDanger وكلاء',
                      subValue: agentsInDanger > 0 ? 'تجاوزوا حد الخطر المسموح!' : 'جميع الوكلاء في أمان',
                      icon: Icons.warning_amber_rounded,
                      color: agentsInDanger > 0 ? Colors.orange : Colors.grey,
                      isAlert: agentsInDanger > 0,
                      onTap: () => _navigateTo(const AgentManagementScreen()),
                    ),
                  
                  if (auth.hasPermission('إدارة الموظفين والدعم'))
                    _buildDashboardCard(
                      title: 'تذاكر الدعم',
                      value: '$openTicketsCount مفتوحة',
                      subValue: '$criticalTicketsCount منها أولوية قصوى',
                      icon: Icons.support_agent,
                      color: Colors.blue,
                      isAlert: criticalTicketsCount > 0,
                      onTap: () => _navigateTo(const StaffSupportScreen()),
                    ),
                  
                  if (auth.hasPermission('التقارير الشاملة'))
                    _buildDashboardCard(
                      title: 'إجمالي المخزون',
                      value: '$totalCards كرت',
                      subValue: 'كروت متوفرة بالنظام',
                      icon: Icons.inventory_2,
                      color: Colors.teal,
                      onTap: () => _navigateTo(const ReportsScreen()),
                    ),
                  
                  if (auth.hasPermission('إدارة الوكلاء الشاملة'))
                    _buildDashboardCard(
                      title: 'الوكيل الأنشط',
                      value: topAgentName,
                      subValue: 'الأعلى رصيداً حالياً',
                      icon: Icons.star,
                      color: Colors.amber.shade600,
                      onTap: () => _navigateTo(const AgentManagementScreen()),
                    ),
                  
                  if (auth.hasPermission('بوابة رسائل الـ SMS'))
                    _buildDashboardCard(
                      title: 'رصيد الـ SMS',
                      value: smsBalance.toString(),
                      subValue: 'رسالة متبقية',
                      icon: Icons.sms,
                      color: Colors.purple,
                      onTap: () => _navigateTo(const SmsGatewayScreen()),
                    ),

                  if (auth.hasPermission('الإعلانات التسويقية'))
                    _buildDashboardCard(
                      title: 'الإعلانات والبنرات',
                      value: 'نشطة',
                      subValue: 'إدارة الحملات الحية',
                      icon: Icons.campaign,
                      color: Colors.pink,
                      onTap: () => _navigateTo(const BannersScreen()),
                    ),
                  
                  if (auth.hasPermission('الإعدادات العامة'))
                    _buildDashboardCard(
                      title: 'إعدادات النظام',
                      value: 'تحكم كامل',
                      subValue: 'هوية، حماية، سياسات',
                      icon: Icons.settings,
                      color: Colors.blueGrey,
                      onTap: () => _navigateTo(const GlobalSettingsScreen()),
                    ),

                  _buildDashboardCard(
                    title: 'التحكم الشامل',
                    value: 'إعادة تهيئة',
                    subValue: 'فرمتة أي جزء من النظام',
                    icon: Icons.cleaning_services,
                    color: Colors.red,
                    onTap: () {
                      uiProvider.playSound('click');
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedResetScreen()));
                    },
                  ),
                ]),
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
