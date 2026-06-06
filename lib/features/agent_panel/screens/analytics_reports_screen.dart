import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:typed_data';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/transactions_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key});

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTimeRange? _selectedDateRange;
  bool _isLoading = false;
  List<Map<String, dynamic>> _filteredTransactions = [];
  double _totalSales = 0.0;
  double _totalDiscounts = 0.0;
  double _netProfit = 0.0;
  Map<String, double> _dailySalesMap = {};
  List<Map<String, dynamic>> _topCategories = [];

  @override
  void initState() {
    super.initState();
    // تعيين الفترة الافتراضية: الشهر الحالي
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _play(String type) => context.read<UiProvider>().playSound(type);

  Future<void> _selectDateRange() async {
    _play('click');
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_selectedDateRange == null) return;
    final auth = context.read<AuthProvider>();
    final agentPhone = auth.activeUserPhone ?? '';
    if (agentPhone.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final start = _selectedDateRange!.start;
      final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month,
          _selectedDateRange!.end.day, 23, 59, 59);

      // جلب المعاملات من Firestore لهذا الوكيل في هذه الفترة
      final snapshot = await _db
          .collection('transactions')
          .where('agentPhone', isEqualTo: agentPhone)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('timestamp', descending: true)
          .get();

      final transactions = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();

      _filteredTransactions = transactions;

      // حساب الإحصائيات
      double totalSales = 0.0;
      double totalDiscounts = 0.0;
      Map<String, double> dailyMap = {};
      Map<String, int> categoryCount = {};

      for (var tx in transactions) {
        final amount = (tx['amount'] ?? 0.0).toDouble();
        final discount = (tx['discount'] ?? 0.0).toDouble();
        final type = tx['type'] ?? '';
        final title = tx['title'] ?? '';
        final date = (tx['timestamp'] as Timestamp?)?.toDate();

        if (type == 'sale') {
          totalSales += amount;
          totalDiscounts += discount;
          
          // تجميع حسب اليوم
          if (date != null) {
            final dayKey = intl.DateFormat('yyyy-MM-dd').format(date);
            dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + amount;
          }

          // تجميع الفئات
          // استخراج اسم الفئة من العنوان (عادة يكون بصيغة "بيع كرت: شبكة X - فئة Y")
          String categoryName = 'أخرى';
          if (title.contains('-')) {
            final parts = title.split('-');
            if (parts.length >= 2) {
              categoryName = parts.last.trim();
            }
          }
          categoryCount[categoryName] = (categoryCount[categoryName] ?? 0) + 1;
        }
      }

      // ترتيب الفئات الأكثر مبيعاً
      final sortedCategories = categoryCount.entries
          .map((e) => {'name': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() {
        _totalSales = totalSales;
        _totalDiscounts = totalDiscounts;
        _netProfit = totalSales - totalDiscounts;
        _dailySalesMap = dailyMap;
        _topCategories = sortedCategories.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ في تحميل التقارير: $e');
      setState(() => _isLoading = false);
    }
  }

  // ========== تصدير Excel ==========
  Future<void> _exportExcel() async {
    _play('click');
    if (_filteredTransactions.isEmpty) {
      _showToast('لا توجد بيانات للتصدير');
      return;
    }

    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['تقرير المبيعات'];
    excel.delete('Sheet1');

    // رأس التقرير
    sheet.appendRow([
      ex.TextCellValue('التاريخ'),
      ex.TextCellValue('النوع'),
      ex.TextCellValue('العنوان'),
      ex.TextCellValue('المبلغ'),
      ex.TextCellValue('الخصم'),
      ex.TextCellValue('المرجع'),
    ]);

    for (var tx in _filteredTransactions) {
      final date = (tx['timestamp'] as Timestamp?)?.toDate();
      sheet.appendRow([
        ex.TextCellValue(date != null ? intl.DateFormat('yyyy-MM-dd hh:mm').format(date) : ''),
        ex.TextCellValue(tx['type'] ?? ''),
        ex.TextCellValue(tx['title'] ?? ''),
        ex.TextCellValue('${tx['amount'] ?? 0}'),
        ex.TextCellValue('${tx['discount'] ?? 0}'),
        ex.TextCellValue(tx['reference'] ?? ''),
      ]);
    }

    var bytes = excel.encode();
    if (bytes != null) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: 'تقرير_المبيعات.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ], text: 'تقرير المبيعات');
    }
    _showToast('تم تصدير التقرير بنجاح');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textDirection: TextDirection.rtl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // تحضير بيانات الرسم البياني من المعاملات الحقيقية
    List<Map<String, dynamic>> chartData = [];
    if (_dailySalesMap.isNotEmpty) {
      final sortedDays = _dailySalesMap.keys.toList()..sort();
      final maxSales = _dailySalesMap.values.reduce((a, b) => a > b ? a : b);
      for (var day in sortedDays) {
        final sales = _dailySalesMap[day] ?? 0.0;
        chartData.add({
          'day': intl.DateFormat('E', 'ar').format(DateTime.parse(day)),
          'sales': sales.toInt(),
          'height': maxSales > 0 ? sales / maxSales : 0.0,
        });
      }
    }

    return Scaffold(
      appBar: const CustomHeader(title: 'التقارير التحليلية'),
      drawer: CustomAgentDrawer(
        agentName: wallet.currentUserName,
        phoneNumber: auth.activeUserPhone ?? '',
        role: 'وكيل معتمد',
        currentBalance: wallet.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // شريط الفلترة (يختفي مع التمرير)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.primary.withOpacity(0.4)
                        : colorScheme.primary.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _selectDateRange,
                              icon: const Icon(Icons.date_range, color: Colors.blueAccent),
                              label: Text(
                                _selectedDateRange != null
                                    ? '${intl.DateFormat('yyyy/MM/dd').format(_selectedDateRange!.start)} - ${intl.DateFormat('yyyy/MM/dd').format(_selectedDateRange!.end)}'
                                    : 'اختر الفترة',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _exportExcel,
                            icon: const Icon(Icons.table_view, color: Colors.white),
                            tooltip: 'تصدير Excel',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // مؤشر التحميل
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(),
                ),

              // الملخص المالي
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الملخص المالي',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'إجمالي المبيعات',
                              amount: _totalSales.toStringAsFixed(0),
                              icon: Icons.storefront,
                              color: Colors.blue,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'صافي الأرباح',
                              amount: _netProfit.toStringAsFixed(0),
                              icon: Icons.monetization_on,
                              color: Colors.green,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      if (_totalDiscounts > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'إجمالي الخصومات: ${_totalDiscounts.toStringAsFixed(0)} ريال',
                            style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // الرسم البياني
              if (chartData.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أداء المبيعات',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                        const SizedBox(height: 10),
                        Container(
                          height: 200,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade900 : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: chartData.map((data) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    width: 25,
                                    height: 120 * (data['height'] as double),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(
                                          (data['height'] as double) == 1.0 ? 1.0 : 0.5),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(data['day'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text('${data['sales']}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // أكثر الفئات مبيعاً
              if (_topCategories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أكثر الفئات مبيعاً',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                        const SizedBox(height: 10),
                        ..._topCategories.map((cat) {
                          final colors = [Colors.orange, Colors.blue, Colors.green, Colors.purple, Colors.teal];
                          final index = _topCategories.indexOf(cat);
                          final color = colors[index % colors.length];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.1),
                                child: Icon(Icons.wifi, color: color),
                              ),
                              title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text('${cat['count']} كرت',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),

              // رسالة "لا توجد بيانات"
              if (!_isLoading && _filteredTransactions.isEmpty && chartData.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('لا توجد بيانات للفترة المحددة',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('$amount ريال',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }
}
