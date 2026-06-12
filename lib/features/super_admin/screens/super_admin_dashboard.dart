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
import '../../../core/providers/transactions_provider.dart';
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
  DateTime? _startDate;
  DateTime? _endDate;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  // 🆕 خريطة الصلاحيات (نفسها الموجودة في CustomDrawer)
  static const Map<String, List<String>> _sectionPermissions = {
    'المركز المالي والمحافظ': ['المركز المالي والمحافظ', 'عرض الأرصدة', 'تسوية رصيد', 'عرض المعاملات'],
    'إدارة الوكلاء': ['إدارة الوكلاء الشاملة', 'عرض الوكلاء', 'إضافة وكيل', 'تعديل وكيل', 'حذف وكيل', 'تجميد/تنشيط وكيل'],
    'إدارة الموظفين والدعم': ['إدارة الموظفين والدعم', 'عرض الموظفين', 'إضافة موظف', 'تعديل موظف', 'حذف موظف', 'تجميد/تنشيط موظف', 'عرض الرواتب', 'تعديل الرواتب', 'تسليم راتب', 'عرض التذاكر', 'الرد على التذاكر', 'إحالة التذاكر', 'إغلاق التذاكر'],
    'التقارير الشاملة': ['التقارير الشاملة', 'عرض التقارير'],
    'بوابة رسائل SMS': ['بوابة رسائل الـ SMS', 'عرض SMS', 'إرسال SMS'],
    'الإعلانات والبنرات': ['الإعلانات التسويقية', 'عرض الإعلانات', 'إضافة إعلان', 'تعديل إعلان', 'حذف إعلان'],
    'الإعدادات العامة': ['الإعدادات العامة', 'عرض الإعدادات', 'تعديل الإعدادات'],
  };

  // 🆕 دالة ذكية للتحقق من صلاحية قسم (عامة أو دقيقة)
  bool _canAccessSection(String sectionName) {
    final auth = context.read<AuthProvider>();
    if (auth.currentUserRole == 'super_admin') return true;
    final permissions = _sectionPermissions[sectionName];
    if (permissions == null) return false;
    for (var perm in permissions) {
      if (auth.hasPermission(perm)) return true;
    }
    return false;
  }

  // ========== اختيار التواريخ ==========
  Future<void> _pickStartDate() async {
    final ui = context.read<UiProvider>();
    ui.playSound('click');
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
    final ui = context.read<UiProvider>();
    ui.playSound('click');
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
    final transactions = context.read<TransactionsProvider>();
    if (_startDate != null && _endDate != null) {
      transactions.setDashboardDateRange(DateTimeRange(start: _startDate!, end: _endDate!));
    } else {
      transactions.setDashboardDateRange(null);
    }
  }

  void _resetDates() {
    final ui = context.read<UiProvider>();
    ui.playSound('click');
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    context.read<TransactionsProvider>().setDashboardDateRange(null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إعادة التعيين إلى إحصائيات اليوم 📅', textDirection: TextDirection.rtl),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.year}/${date.month}/${date.day}';

  void _navigateTo(Widget screen) {
    context.read<UiProvider>().playSound('click');
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ========== طباعة PDF ==========
  Future<void> _generateAndPrintPDF(
    TransactionsProvider transactions,
    WalletProvider wallet,
    UiProvider uiProvider,
    String topAgent,
    int agentsDanger,
  ) async {
    uiProvider.playSound('click');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري تجهيز تقرير الـ PDF... 📄', textDirection: TextDirection.rtl),
      ),
    );

    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    String dateText = transactions.dashboardDateRange == null
        ? 'تقرير مبيعات اليوم'
        : 'تقرير من: ${_formatDate(transactions.dashboardDateRange!.start)} إلى ${_formatDate(transactions.dashboardDateRange!.end)}';

    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('غرفة العمليات - نظام كروت نت',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text(dateText, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: ctx,
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.center,
                data: <List<String>>[
                  ['البيان', 'القيمة'],
                  ['إجمالي المبيعات المحققة', '${transactions.filteredSales.toStringAsFixed(0)} ريال'],
                  ['إجمالي الأرباح', '${transactions.filteredProfit.toStringAsFixed(0)} ريال'],
                  ['طلبات الشحن المعلقة', '${wallet.pendingRechargeRequests.length} طلبات'],
                  ['وكلاء في مرحلة الخطر', '$agentsDanger وكلاء'],
                  ['الوكيل الأنشط بالفترة', topAgent],
                  ['إجمالي تذاكر الدعم المفتوحة', '${transactions.openTicketsCount} تذاكر'],
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Text('تم إنشاء هذا التقرير تلقائياً بواسطة نظام Super Admin',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'KrootNet_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    uiProvider.playSound('success');
  }

  // ========== طلبات الشحن المعلقة ==========
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
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
              ),
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
                              leading: const CircleAvatar(
                                backgroundColor: Colors.orange,
                                child: Icon(Icons.downloading, color: Colors.white),
                              ),
                              title: Text('طلب من: ${req['agentName'] ?? req['agentPhone']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'المبلغ المطلوب: ${req['amount']} ريال\nطريقة الدفع: ${req['paymentMethod'] ?? 'غير محدد'}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green),
                                    onPressed: () => _handleRequest(docId, req, true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () => _handleRequest(docId, req, false),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
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
      batch.update(reqRef, {
        'status': isApprove ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
      });

      if (isApprove) {
        DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(agentPhone);
        batch.update(userRef, {'balance': FieldValue.increment(amount)});

        DocumentReference notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'targetPhones': [agentPhone],
          'title': 'تم شحن رصيدك بنجاح! 🎉',
          'body': 'تمت الموافقة على طلبك وتمت إضافة مبلغ $amount ريال إلى محفظتك.',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        uiProvider.playSound('success');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الموافقة وإضافة الرصيد للوكيل بنجاح!'), backgroundColor: Colors.green),
        );
      } else {
        DocumentReference notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'targetPhones': [agentPhone],
          'title': 'عذراً، تم رفض طلب الشحن ❌',
          'body': 'تم رفض طلب الشحن الخاص بك بقيمة $amount ريال، يرجى مراجعة الإدارة.',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        uiProvider.playSound('error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب.'), backgroundColor: Colors.red),
        );
      }

      await batch.commit();
    } catch (e) {
      uiProvider.playSound('error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ========== البناء ==========
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;

    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final wallet = context.watch<WalletProvider>();
    final transactions = context.watch<TransactionsProvider>();
    final uiProvider = context.read<UiProvider>();

    final adminBalance = settings.adminMainBalance;
    final userName = wallet.currentUserName;
    final String userPhone = auth.activeUserPhone ?? '';
    final totalCards = settings.totalSystemCards;
    final double todaySales = transactions.filteredSales;
    final double todayProfit = transactions.filteredProfit;
    final int openTicketsCount = transactions.openTicketsCount;
    final int criticalTicketsCount = transactions.criticalTicketsCount;
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
      } catch (e) {
        topAgentName = 'غير محدد';
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomHeader(title: 'غرفة العمليات المركزية'),
      drawer: CustomDrawer(
        userName: userName,
        phoneNumber: userPhone,
        role: auth.currentUserRole == 'super_admin' ? 'مالك النظام' : 'موظف مخصص',
        balanceOrPoints: 'أرباح النظام: ${adminBalance.toStringAsFixed(0)} ريال',
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 300));
          uiProvider.playSound('success');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الصفحة بنجاح ✅', textDirection: TextDirection.rtl),
              backgroundColor: Colors.green,
            ),
          );
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickStartDate,
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
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickEndDate,
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
                        Container(
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                          child: IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                            tooltip: 'تصدير تقرير فوري',
                            onPressed: () => _generateAndPrintPDF(transactions, wallet, uiProvider, topAgentName, agentsInDanger),
                          ),
                        ),
                      ],
                    ),
                    if (_startDate != null || _endDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الفلترة: ${_startDate != null ? _formatDate(_startDate!) : "أول السنة"} - ${_endDate != null ? _formatDate(_endDate!) : "اليوم"}',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear_all, color: Colors.white70),
                              tooltip: 'إعادة تعيين الفلترة',
                              onPressed: _resetDates,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _buildDynamicDashboardGrid(
                auth: auth,
                wallet: wallet,
                transactions: transactions,
                settings: settings,
                uiProvider: uiProvider,
                todaySales: todaySales,
                todayProfit: todayProfit,
                openTicketsCount: openTicketsCount,
                criticalTicketsCount: criticalTicketsCount,
                totalCards: totalCards,
                agentsInDanger: agentsInDanger,
                topAgentName: topAgentName,
                smsBalance: smsBalance,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  // 🆕 بناء شبكة ديناميكية باستخدام _canAccessSection
  Widget _buildDynamicDashboardGrid({
    required AuthProvider auth,
    required WalletProvider wallet,
    required TransactionsProvider transactions,
    required SettingsProvider settings,
    required UiProvider uiProvider,
    required double todaySales,
    required double todayProfit,
    required int openTicketsCount,
    required int criticalTicketsCount,
    required int totalCards,
    required int agentsInDanger,
    required String topAgentName,
    required int smsBalance,
  }) {
    final List<Widget> allCards = [];

    // بطاقة المبيعات
    if (_canAccessSection('المركز المالي والمحافظ')) {
      allCards.add(_buildDashboardCard(
        title: 'المبيعات (مفلترة)',
        value: todaySales.toStringAsFixed(0),
        subValue: '+ أرباح: ${todayProfit.toStringAsFixed(0)}',
        icon: Icons.monetization_on,
        color: Colors.green,
        onTap: () => _navigateTo(const FinancialCenterScreen()),
      ));
    }

    // بطاقة طلبات الشحن المعلقة
    if (_canAccessSection('المركز المالي والمحافظ')) {
      allCards.add(
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('recharge_requests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
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
                if (pendingCount > 0 && snapshot.hasData) {
                  _showPendingRequestsModal(context, snapshot.data!.docs);
                } else {
                  uiProvider.playSound('click');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا توجد طلبات معلقة حالياً')),
                  );
                }
              },
            );
          },
        ),
      );
    }

    // بطاقة رادار الخطر
    if (_canAccessSection('إدارة الوكلاء')) {
      allCards.add(_buildDashboardCard(
        title: 'رادار الخطر',
        value: '$agentsInDanger وكلاء',
        subValue: agentsInDanger > 0 ? 'تجاوزوا حد الخطر المسموح!' : 'جميع الوكلاء في أمان',
        icon: Icons.warning_amber_rounded,
        color: agentsInDanger > 0 ? Colors.orange : Colors.grey,
        isAlert: agentsInDanger > 0,
        onTap: () => _navigateTo(const AgentManagementScreen()),
      ));
    }

    // بطاقة تذاكر الدعم
    if (_canAccessSection('إدارة الموظفين والدعم')) {
      allCards.add(_buildDashboardCard(
        title: 'تذاكر الدعم',
        value: '$openTicketsCount مفتوحة',
        subValue: '$criticalTicketsCount منها أولوية قصوى',
        icon: Icons.support_agent,
        color: Colors.blue,
        isAlert: criticalTicketsCount > 0,
        onTap: () => _navigateTo(const StaffSupportScreen()),
      ));
    }

    // بطاقة إجمالي المخزون
    if (_canAccessSection('التقارير الشاملة')) {
      allCards.add(_buildDashboardCard(
        title: 'إجمالي المخزون',
        value: '$totalCards كرت',
        subValue: 'كروت متوفرة بالنظام',
        icon: Icons.inventory_2,
        color: Colors.teal,
        onTap: () => _navigateTo(const ReportsScreen()),
      ));
    }

    // بطاقة الوكيل الأنشط
    if (_canAccessSection('إدارة الوكلاء')) {
      allCards.add(_buildDashboardCard(
        title: 'الوكيل الأنشط',
        value: topAgentName,
        subValue: 'الأعلى رصيداً حالياً',
        icon: Icons.star,
        color: Colors.amber.shade600,
        onTap: () => _navigateTo(const AgentManagementScreen()),
      ));
    }

    // بطاقة رصيد SMS
    if (_canAccessSection('بوابة رسائل SMS')) {
      allCards.add(_buildDashboardCard(
        title: 'رصيد الـ SMS',
        value: smsBalance.toString(),
        subValue: 'رسالة متبقية',
        icon: Icons.sms,
        color: Colors.purple,
        onTap: () => _navigateTo(const SmsGatewayScreen()),
      ));
    }

    // بطاقة الإعلانات والبنرات
    if (_canAccessSection('الإعلانات والبنرات')) {
      allCards.add(_buildDashboardCard(
        title: 'الإعلانات والبنرات',
        value: 'نشطة',
        subValue: 'إدارة الحملات الحية',
        icon: Icons.campaign,
        color: Colors.pink,
        onTap: () => _navigateTo(const BannersScreen()),
      ));
    }

    // بطاقة إعدادات النظام
    if (_canAccessSection('الإعدادات العامة')) {
      allCards.add(_buildDashboardCard(
        title: 'إعدادات النظام',
        value: 'تحكم كامل',
        subValue: 'هوية، حماية، سياسات',
        icon: Icons.settings,
        color: Colors.blueGrey,
        onTap: () => _navigateTo(const GlobalSettingsScreen()),
      ));
    }

    // بطاقة التحكم الشامل (تظهر للجميع)
    allCards.add(_buildDashboardCard(
      title: 'التحكم الشامل',
      value: 'إعادة تهيئة',
      subValue: 'فرمتة أي جزء من النظام',
      icon: Icons.cleaning_services,
      color: Colors.red,
      onTap: () {
        uiProvider.playSound('click');
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedResetScreen()));
      },
    ));

    if (allCards.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('لا توجد بطاقات متاحة لصلاحياتك', style: TextStyle(color: Colors.grey))),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      delegate: SliverChildListDelegate(allCards),
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
                if (isAlert) const Icon(Icons.circle, color: Colors.red, size: 12),
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
